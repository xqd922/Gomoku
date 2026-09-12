import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';
import 'package:gomoku_server/src/services/app_config.dart';

const ids = Uuid();

class TestServer {
  TestServer(this.port);
  final int port;
  Process? _process;
  IOSink? _logs;
  String get api => 'http://127.0.0.1:$port/';
  String get web => 'http://127.0.0.1:${port + 2}/';
  Future<void> start() async {
    final folder = Directory('../../.local')..createSync(recursive: true);
    _logs = File('${folder.path}/test-server-$port.log')
        .openWrite(mode: FileMode.append);
    _process = await Process.start(
      Platform.resolvedExecutable,
      [
        'bin/main.dart',
        '--mode',
        'test',
        '--apply-migrations',
        '--server-id',
        'gomoku-test-$port',
      ],
      environment: {
        'SERVERPOD_API_SERVER_PORT': '$port',
        'SERVERPOD_API_SERVER_PUBLIC_PORT': '$port',
        'SERVERPOD_WEB_SERVER_PORT': '${port + 2}',
        'SERVERPOD_WEB_SERVER_PUBLIC_PORT': '${port + 2}',
        'SERVERPOD_INSIGHTS_SERVER_PORT': '${port + 1}',
        'COOKIE_SECURE': 'false',
        'ALLOWED_ORIGINS': 'http://localhost:4280',
      },
    );
    _process!.stdout.listen(_logs!.add);
    _process!.stderr.listen(_logs!.add);
    await eventually(
      () async {
        try {
          return (await http.get(Uri.parse('${web}health'))).statusCode == 200;
        } catch (_) {
          return false;
        }
      },
      timeout: const Duration(seconds: 90),
      reason: 'Server $port failed to start. See .local/test-server-$port.log.',
    );
  }

  Future<void> stop() async {
    final process = _process;
    if (process == null) return;
    process.kill();
    await process.exitCode.timeout(const Duration(seconds: 15));
    await _logs?.flush();
    await _logs?.close();
    _process = null;
  }
}

Future<void> eventually(
  FutureOr<bool> Function() predicate, {
  Duration timeout = const Duration(seconds: 8),
  String reason = 'Condition timed out.',
}) async {
  final watch = Stopwatch()..start();
  while (!await predicate()) {
    if (watch.elapsed > timeout) fail(reason);
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }
}

class AuthFailure implements Exception {
  AuthFailure(this.code, this.status);
  final String code;
  final int status;
  @override
  String toString() => 'AuthFailure($status, $code)';
}

class TestPlayer implements ClientAuthKeyProvider {
  TestPlayer(this.server, this.name) {
    client = Client(server.api, connectionTimeout: const Duration(seconds: 15))
      ..authKeyProvider = this;
  }
  final TestServer server;
  final String name;
  late Client client;
  String? token;
  PlayerProfile? profile;
  String? email;
  static const password = 'Gomoku-test!937';
  @override
  Future<String?> get authHeaderValue async =>
      token == null ? null : 'Bearer $token';
  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, Object?> data, {
    bool accept = true,
  }) async {
    final response = await http.post(
      Uri.parse('${server.web}auth/$action'),
      headers: {
        'content-type': 'application/json',
        'x-gomoku-client': 'native',
        if (token != null) 'authorization': 'Bearer $token',
      },
      body: jsonEncode(data),
    );
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw AuthFailure(result['error'] as String, response.statusCode);
    }
    if (accept) {
      if (result['token'] is String) token = result['token'] as String;
      if (result['profile'] is Map) {
        profile = PlayerProfile.fromJson(
          result['profile'] as Map<String, dynamic>,
        );
      }
    }
    return result;
  }

  Future<void> guest() async {
    await auth('guest', {'nickname': name});
  }

  Future<void> register({String? nickname}) async {
    email = 'gomoku-${ids.v4()}@example.test';
    final request = await auth('register-start', {'email': email});
    final code = await emailCode(email!);
    await auth('register-finish', {
      'requestId': request['requestId'],
      'code': code,
      'password': password,
      'nickname': nickname ?? name,
    });
  }

  Future<RoomSnapshot> send(
    String roomId,
    RoomAction action, {
    int? row,
    int? col,
  }) async {
    for (var retry = 0; ; retry++) {
      final snapshot = await client.room.snapshot(roomId);
      try {
        return await client.room.command(
          roomId,
          RoomCommand(
            commandId: ids.v4(),
            expectedRevision: snapshot.revision,
            action: action,
            row: row,
            col: col,
          ),
        );
      } on AppException catch (error) {
        if (error.code != 'stale_revision' || retry == 3) rethrow;
      }
    }
  }

  void close() => client.close();
}

class Presence {
  Presence(this.player, this.roomId) {
    subscription = player.client.room
        .watch(roomId, connectionId)
        .listen(
          (value) {
            if (latest == null || value.revision >= latest!.revision) {
              latest = value;
            }
          },
          onError: (Object error) {
            lastError = error;
          },
        );
    timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        await player.client.room.heartbeat(roomId, connectionId);
      } catch (error) {
        lastError = error;
      }
    });
  }
  final TestPlayer player;
  final String roomId;
  final String connectionId = ids.v4();
  late StreamSubscription<RoomSnapshot> subscription;
  Timer? timer;
  RoomSnapshot? latest;
  Object? lastError;
  Future<RoomSnapshot> until(bool Function(RoomSnapshot) condition) async {
    await eventually(
      () => latest != null && condition(latest!),
      reason: 'Streaming snapshot was not delivered within 8s (poll fallback is 10s).',
    );
    return latest!;
  }

  Future<void> close() async {
    timer?.cancel();
    await subscription.cancel();
  }
}

class TestRoom {
  TestRoom(this.a, this.b, this.id, this.first, this.second);
  final TestPlayer a, b;
  final String id;
  final Presence first, second;
  static Future<TestRoom> open(TestPlayer a, TestPlayer b) async {
    final room = await a.client.room.createRoom(ids.v4());
    await b.client.room.joinRoom(room.code, ids.v4());
    final first = Presence(a, room.roomId);
    final second = Presence(b, room.roomId);
    await first.until((r) => r.hostConnected && r.guestConnected);
    await second.until((r) => r.hostConnected && r.guestConnected);
    await a.send(room.roomId, RoomAction.ready);
    await b.send(room.roomId, RoomAction.ready);
    await first.until((r) => r.status == RoomStatus.playing);
    return TestRoom(a, b, room.roomId, first, second);
  }

  Future<void> close() async {
    try {
      await a.send(id, RoomAction.leave);
    } catch (_) {}
    await first.close();
    await second.close();
  }
}

Future<String> emailCode(String email) async {
  String? code;
  await eventually(
    () async {
      final query = Uri.parse('http://127.0.0.1:8025/api/v1/search')
          .replace(queryParameters: {'query': 'to:$email'});
      final search =
          jsonDecode((await http.get(query)).body) as Map<String, dynamic>;
      final messages = search['messages'] as List? ?? [];
      if (messages.isEmpty) return false;
      final id = (messages.first as Map)['ID'];
      final message = jsonDecode(
        (await http.get(Uri.parse('http://127.0.0.1:8025/api/v1/message/$id')))
            .body,
      ) as Map<String, dynamic>;
      final text = message['Text'] as String? ?? '';
      code = RegExp(r'code:\s+([A-Za-z0-9]+)').firstMatch(text)?.group(1);
      return code != null;
    },
    reason: 'Mailpit did not receive a verification code for the test address.',
  );
  return code!;
}

GameState gameOf(RoomSnapshot room) =>
    GameState.fromJson(jsonDecode(room.gameJson) as Map<String, dynamic>);
Matcher appError(String code) =>
    throwsA(isA<AppException>().having((e) => e.code, 'code', code));
Matcher authError(String code) =>
    throwsA(isA<AuthFailure>().having((e) => e.code, 'code', code));

Future<Connection> testDatabase() => Connection.open(
  Endpoint(
    host: '127.0.0.1',
    port: 8090,
    database: 'gomoku_test',
    username: 'postgres',
    password: AppConfig.load().get('DATABASE_PASSWORD'),
  ),
  settings: const ConnectionSettings(sslMode: SslMode.disable),
);

GameRecord localRecord() {
  var game = GameState.newGame();
  for (var col = 0; col < 4; col++) {
    game = game.play(0, col).play(1, col);
  }
  game = game.play(0, 4);
  final now = DateTime.now().toUtc();
  return GameRecord(
    id: ids.v4(),
    game: game,
    source: RecordSource.local,
    startedAt: now,
    updatedAt: now,
    blackName: 'Black',
    whiteName: 'White',
  );
}
