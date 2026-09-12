import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:http/http.dart' as http;

// Run from the repository root on a trusted administrator's workstation.
// Credentials are read from a private file and are never written to the report.
const ids = Uuid();

// A diagnostic DNS override avoids a workstation's synthetic proxy DNS while
// retaining the HTTPS hostname, SNI, certificate verification and public route.
class ValidationDns extends HttpOverrides {
  ValidationDns(this.host, this.address);
  final String host, address;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (url, proxyHost, proxyPort) async {
      // dart:io converts an implicit wss port to HTTPS port 0 before calling
      // a custom connection factory. Its default connector resolves that to
      // 443; a diagnostic factory must perform the same normalization.
      final port = url.port == 0
          ? (url.scheme == 'https' ? 443 : 80)
          : url.port;
      final task = await Socket.startConnect(
        proxyHost ?? (url.host == host ? address : url.host),
        proxyPort ?? port,
      );
      Socket? active;
      final socket = task.socket.then<Socket>((raw) async {
        active = raw;
        if (url.scheme == 'https' && proxyHost == null) {
          active = await SecureSocket.secure(
            raw,
            host: url.host,
            context: context,
          );
        }
        return active!;
      });
      return ConnectionTask.fromSocket(socket, () {
        task.cancel();
        active?.destroy();
      });
    };
    return client;
  }
}

final _secrets = <String>{};

String safeIssue(Object? error) {
  var message = error?.toString() ?? 'stream_closed';
  for (final secret in _secrets) {
    message = message.replaceAll(secret, '[redacted]');
  }
  message = message.replaceAll(
    RegExp(r'Bearer\s+[^\s,;"}]+', caseSensitive: false),
    'Bearer [redacted]',
  );
  return message.length <= 500 ? message : message.substring(0, 500);
}

void require(bool condition, String reason) {
  if (!condition) throw StateError(reason);
}

Future<void> until(FutureOr<bool> Function() check, String reason) async {
  final watch = Stopwatch()..start();
  while (!await check()) {
    if (watch.elapsed > const Duration(seconds: 15)) throw StateError(reason);
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

class Device implements ClientAuthKeyProvider {
  Device(this.origin) {
    rpc = Client('$origin/api/', connectionTimeout: const Duration(seconds: 12))
      ..authKeyProvider = this;
  }
  final String origin;
  final http.Client httpClient = http.Client();
  late final Client rpc;
  String? token;
  late PlayerProfile profile;
  String? roomId;
  RoomSnapshot? latest;
  Object? streamError;
  String connectionId = ids.v4();
  StreamSubscription<RoomSnapshot>? subscription;
  Timer? timer;
  bool heartbeatBusy = false;
  int transportRetries = 0;
  int streamReconnects = 0;
  bool connected = false;
  bool _closing = false;
  int _generation = 0, _attempt = 0;
  Timer? _reconnect;
  DateTime? lastSnapshotAt;
  String? lastStreamIssue;
  final streamEvents = <Map<String, Object?>>[];

  Future<T> request<T>(Future<T> Function() send) async {
    try {
      return await send();
    } catch (error) {
      final transient =
          error is SocketException ||
          error is HandshakeException ||
          error is http.ClientException ||
          error is TimeoutException;
      if (!transient) rethrow;
      transportRetries++;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      return send();
    }
  }

  @override
  Future<String?> get authHeaderValue async =>
      token == null ? null : 'Bearer $token';

  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, Object?> body,
  ) async {
    final response = await request(
      () => httpClient
          .post(
            Uri.parse('$origin/auth/$action'),
            headers: {
              'content-type': 'application/json',
              'x-gomoku-client': 'native',
              if (token != null) 'authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15)),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    require(
      response.statusCode == 200,
      'Authentication failed (${data['error']}).',
    );
    token = data['token'] as String? ?? token;
    if (token != null) _secrets.add(token!);
    if (data['profile'] != null) {
      profile = PlayerProfile.fromJson(data['profile'] as Map<String, dynamic>);
    }
    return data;
  }

  Future<void> watch(String id) async {
    roomId = id;
    await _attach();
  }

  Future<void> _attach() async {
    final generation = ++_generation;
    connected = false;
    timer?.cancel();
    _reconnect?.cancel();
    unawaited(subscription?.cancel());
    final id = roomId!;
    final connection = connectionId = ids.v4();
    // Match the app: restore the session, fetch the authoritative snapshot,
    // then establish a new streaming method and a fresh presence lease.
    await auth('session', {});
    final snapshot = await request(() => rpc.room.snapshot(id));
    if (_closing || generation != _generation) return;
    latest = snapshot;
    subscription = rpc.room
        .watch(id, connection)
        .listen(
          (value) {
            if (_closing || generation != _generation) return;
            if (latest == null || value.revision >= latest!.revision) {
              latest = value;
            }
            lastSnapshotAt = DateTime.now().toUtc();
            connected = true;
            _attempt = 0;
          },
          onError: (Object error) {
            if (!_closing && generation == _generation) _lost(error);
          },
          onDone: () {
            if (!_closing &&
                generation == _generation &&
                latest?.status != RoomStatus.closed) {
              _lost(null);
            }
          },
        );
    timer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (_closing || generation != _generation || heartbeatBusy) return;
      heartbeatBusy = true;
      try {
        await request(() => rpc.room.heartbeat(id, connection));
      } catch (error) {
        if (!_closing && generation == _generation) _lost(error);
      } finally {
        heartbeatBusy = false;
      }
    });
  }

  void _lost(Object? error) {
    if (_closing || (_reconnect?.isActive ?? false)) return;
    connected = false;
    timer?.cancel();
    lastStreamIssue = error is AppException
        ? error.code
        : error?.runtimeType.toString() ?? 'stream_closed';
    streamEvents.add({
      'at': DateTime.now().toUtc().toIso8601String(),
      'issue': lastStreamIssue,
      'detail': safeIssue(error),
      'revision': latest?.revision,
    });
    if (error is AppException ||
        error is ServerpodClientUnauthorized ||
        error is StateError) {
      streamError = error;
      return;
    }
    final seconds = [1, 2, 4, 8, 10][_attempt.clamp(0, 4)];
    _attempt++;
    _reconnect = Timer(Duration(seconds: seconds), () async {
      streamReconnects++;
      try {
        await _attach();
      } catch (error) {
        if (!_closing) _lost(error);
      }
    });
  }

  Future<RoomSnapshot> send(RoomAction action, {int? row, int? col}) async {
    for (var attempt = 0; ; attempt++) {
      final snapshot = await request(() => rpc.room.snapshot(roomId!));
      final command = RoomCommand(
        commandId: ids.v4(),
        expectedRevision: snapshot.revision,
        action: action,
        row: row,
        col: col,
      );
      try {
        // Match the app's one transport retry, including its delay in P95.
        // The exact command, ID and revision are retained across that retry.
        return await request(() => rpc.room.command(roomId!, command));
      } on AppException catch (error) {
        if (error.code != 'stale_revision' ||
            attempt >= 2 ||
            !{RoomAction.ready, RoomAction.rematch}.contains(action)) {
          rethrow;
        }
      }
    }
  }

  Future<void> close() async {
    _closing = true;
    _generation++;
    timer?.cancel();
    _reconnect?.cancel();
    await subscription?.cancel();
    rpc.close();
    httpClient.close();
  }

  Future<List<String>> records() async {
    var cursor = '';
    final result = <String>[];
    while (true) {
      final page = await rpc.profile.syncRecords([], cursor);
      result.addAll(page.records);
      if (!page.hasMore) return result;
      cursor = page.cursor;
    }
  }
}

GameRecord testRecord() {
  var game = GameState.newGame();
  for (var col = 0; col < 5; col++) {
    game = game.play(0, col);
    if (col < 4) game = game.play(1, col);
  }
  final now = DateTime.now().toUtc();
  return GameRecord(
    id: ids.v4(),
    game: game,
    source: RecordSource.local,
    startedAt: now,
    updatedAt: now,
    blackName: 'Validation',
    whiteName: 'Validation',
  );
}

Future<void> main(List<String> args) async {
  final minutes = int.parse(args.firstOrNull ?? '1');
  require(
    minutes >= 1 && minutes <= 60,
    'Use a duration from 1 to 60 minutes.',
  );
  final path = Platform.environment['GOMOKU_ACCOUNTS_FILE'];
  require(path != null, 'Set GOMOKU_ACCOUNTS_FILE to a private account file.');
  final accounts = jsonDecode(await File(path!).readAsString()) as List;
  require(accounts.length == 2, 'Two provisioned accounts are required.');
  for (final account in accounts) {
    _secrets.add((account as Map)['password'] as String);
  }
  final origin =
      Platform.environment['GOMOKU_WEB_URL'] ?? 'https://gomoku.xqd.pp.ua';
  require(
    Uri.parse(origin).scheme == 'https',
    'Public validation requires HTTPS.',
  );
  final connectionAddress = Platform.environment['GOMOKU_CONNECT_IP'];
  if (connectionAddress != null) {
    require(
      InternetAddress.tryParse(connectionAddress) != null,
      'Use an IP address for the diagnostic DNS override.',
    );
    HttpOverrides.global = ValidationDns(
      Uri.parse(origin).host,
      connectionAddress,
    );
  }
  final folder = Directory('artifacts/production')..createSync(recursive: true);
  final reportFile = File(
    '${folder.path}/capacity-${DateTime.now().millisecondsSinceEpoch}.json',
  );
  final devices = <Device>[];
  final latencies = <int>[];
  final report = <String, Object?>{
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'origin': origin,
    'connectionAddress': connectionAddress ?? 'system DNS',
    'clients': 10,
    'accounts': 2,
    'requestedMinutes': minutes,
    'status': 'running',
    'transportRetryPolicy': 'One retry after 500 ms, retaining command ID and revision; latency includes retries.',
  };
  var rounds = 0;
  var moves = 0;
  final elapsed = Stopwatch();
  int p95() {
    if (latencies.isEmpty) return 0;
    final sorted = [...latencies]..sort();
    return sorted[(sorted.length * .95).ceil() - 1];
  }

  Future<void> save() async {
    report.addAll({
      'elapsedSeconds': elapsed.elapsed.inSeconds,
      'rounds': rounds,
      'moves': moves,
      'moveP95Ms': p95(),
      'samples': latencies.length,
      'transportRetries': devices.fold<int>(
        0,
        (count, device) => count + device.transportRetries,
      ),
      'streamReconnects': devices.fold<int>(
        0,
        (count, device) => count + device.streamReconnects,
      ),
    });
    await reportFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(report),
    );
  }

  try {
    final config = await http.get(Uri.parse('$origin/app-config'));
    require(
      config.statusCode == 200 &&
          jsonDecode(config.body)['authMode'] == 'private',
      'The production deployment must use private authentication.',
    );
    final health = await http.get(Uri.parse('$origin/health'));
    final healthData = jsonDecode(health.body) as Map;
    require(
      health.statusCode == 200 && healthData['status'] == 'ok',
      'Health check failed.',
    );
    report['commit'] = healthData['commit'];
    for (final action in [
      'guest',
      'register-start',
      'register-finish',
      'reset-start',
      'reset-finish',
    ]) {
      final response = await http.post(
        Uri.parse('$origin/auth/$action'),
        headers: {
          'content-type': 'application/json',
          'x-gomoku-client': 'native',
        },
        body: '{}',
      );
      require(
        response.statusCode == 403 &&
            jsonDecode(response.body)['error'] == 'feature_disabled',
        'A disabled authentication operation was reachable.',
      );
    }
    for (var i = 0; i < 10; i++) {
      final device = Device(origin);
      devices.add(device);
      final account = accounts[i % 2] as Map;
      await device.auth('login', {
        'email': account['login'] ?? account['email'],
        'password': account['password'],
      });
      await device.auth('session', {});
      require(
        device.profile.isGuest == false,
        'A provisioned identity became a guest.',
      );
    }
    require(
      devices.map((d) => d.profile.playerId).toSet().length == 2,
      'Identity duplication.',
    );
    final a = devices[0], b = devices[1];
    require(
      await a.rpc.room.activeRoom() == null &&
          await b.rpc.room.activeRoom() == null,
      'A human may be playing: finish the active room before running capacity checks.',
    );
    final record = testRecord();
    report['localRecordId'] = record.id;
    await a.rpc.profile.syncRecords([jsonEncode(record.toJson())], '');
    await a.rpc.profile.syncRecords([
      jsonEncode(record.toJson()),
    ], '');
    require(
      (await a.records())
              .where((raw) => jsonDecode(raw)['id'] == record.id)
              .length ==
          1,
      'Repeated upload duplicated a record.',
    );
    require(
      !(await b.records()).any((raw) => jsonDecode(raw)['id'] == record.id),
      'A local record leaked to another account.',
    );
    final createId = ids.v4();
    var room = await a.rpc.room.createRoom(createId);
    a.roomId = room.roomId;
    report['roomId'] = room.roomId;
    require(
      (await a.rpc.room.createRoom(createId)).roomId == room.roomId,
      'Create was not idempotent.',
    );
    final joinId = ids.v4();
    await b.rpc.room.joinRoom(room.code, joinId);
    await b.rpc.room.joinRoom(room.code, joinId);
    await Future.wait(devices.map((device) => device.watch(room.roomId)));
    await until(
      () => devices.every(
        (d) =>
            d.connected &&
            d.latest?.hostConnected == true &&
            d.latest?.guestConnected == true,
      ),
      'Ten clients did not receive the occupied room.',
    );
    await a.send(RoomAction.ready);
    room = await b.send(RoomAction.ready);
    require(
      room.status == RoomStatus.playing,
      'Both ready votes did not start a game.',
    );
    final command = RoomCommand(
      commandId: ids.v4(),
      expectedRevision: room.revision,
      action: RoomAction.move,
      row: 7,
      col: 7,
    );
    final first = await a.rpc.room.command(room.roomId, command);
    final duplicate = await a.rpc.room.command(room.roomId, command);
    require(
      first.gameJson == duplicate.gameJson &&
          first.revision == duplicate.revision,
      'A repeated command changed the board.',
    );
    await b.send(RoomAction.move, row: 8, col: 7);
    await a.send(RoomAction.requestUndo);
    room = await b.send(RoomAction.acceptUndo);
    require(
      GameState.fromJson(jsonDecode(room.gameJson) as Map<String, dynamic>)
          .moves
          .isEmpty,
      'Consented undo did not restore the requester turn.',
    );
    final concurrent = await Future.wait(
      List.generate(2, (_) async {
        try {
          return await a.rpc.room.command(
            room.roomId,
            RoomCommand(
              commandId: ids.v4(),
              expectedRevision: room.revision,
              action: RoomAction.move,
              row: 0,
              col: 0,
            ),
          );
        } on AppException catch (error) {
          return error;
        }
      }),
    );
    require(
      concurrent.whereType<RoomSnapshot>().length == 1 &&
          concurrent.whereType<AppException>().single.code == 'stale_revision',
      'Concurrent commands did not have a single winner.',
    );
    await a.send(RoomAction.resign);
    await a.send(RoomAction.rematch);
    room = await b.send(RoomAction.rematch);
    require(
      room.blackPlayerId == b.profile.playerId,
      'Rematch did not exchange colors.',
    );
    // Exercise the same onError/onDone restoration used by the real app before
    // the timed run. This intentional closure is reported separately.
    await devices.last.rpc.closeStreamingMethodConnections();
    await until(
      () =>
          devices.last.streamReconnects > 0 &&
          devices.last.connected &&
          devices.last.latest?.gameJson == room.gameJson,
      'The validation client did not recover its closed stream.',
    );
    report['intentionalStreamClosures'] = 1;
    report['protocolChecks'] = 'passed';
    elapsed.start();
    var lastMinute = -1;
    String? completedGame;
    while (elapsed.elapsed < Duration(minutes: minutes)) {
      final black = room.blackPlayerId == a.profile.playerId ? a : b;
      final white = black == a ? b : a;
      for (var col = 0; col < 5; col++) {
        for (final move in [(black, 0), if (col < 4) (white, 1)]) {
          final watch = Stopwatch()..start();
          room = await move.$1.send(RoomAction.move, row: move.$2, col: col);
          latencies.add(watch.elapsedMilliseconds);
          moves++;
          final expected = room.gameJson;
          await until(
            () => devices.every(
              (d) => d.connected && d.latest?.gameJson == expected,
            ),
            'The ten clients disagreed about the board.',
          );
          require(
            devices.every((d) => d.streamError == null),
            'A realtime connection failed during the soak.',
          );
          await Future<void>.delayed(const Duration(milliseconds: 1000));
        }
      }
      require(
        room.status == RoomStatus.finished,
        'Winning line did not finish the round.',
      );
      completedGame ??= room.gameId;
      rounds++;
      await a.send(RoomAction.rematch);
      room = await b.send(RoomAction.rematch);
      final minute = elapsed.elapsed.inMinutes;
      if (minute != lastMinute) {
        lastMinute = minute;
        for (final device in devices) {
          await device.auth('session', {});
        }
        await save();
        stdout.writeln(
          'Capacity: ${elapsed.elapsed.inSeconds}s; $rounds rounds; $moves moves; P95 ${p95()} ms.',
        );
      }
    }
    require(p95() <= 2000, 'Move confirmation P95 exceeded 2 seconds.');
    for (final player in [a, b]) {
      require(
        (await player.records()).any(
          (raw) => jsonDecode(raw)['id'] == completedGame,
        ),
        'The confirmed online record was not synchronized to both accounts.',
      );
    }
    report['status'] = 'passed';
  } catch (error) {
    report['status'] = 'failed';
    // Error type/code only: remote responses and credentials are never copied.
    report['error'] = error is AppException
        ? error.code
        : error.runtimeType.toString();
    if (error is StateError) report['detail'] = error.message;
    if (error is HandshakeException) report['tlsError'] = error.message;
    report['clientStates'] = [
      for (var i = 0; i < devices.length; i++)
        {
          'index': i,
          'connected': devices[i].connected,
          'revision': devices[i].latest?.revision,
          'lastSnapshotAt': devices[i].lastSnapshotAt?.toIso8601String(),
          'terminalError': devices[i].streamError?.runtimeType.toString(),
          'streamEvents': [...devices[i].streamEvents],
        },
    ];
    if (devices.isNotEmpty && devices.first.roomId != null) {
      try {
        final authoritative = await devices.first.request(
          () => devices.first.rpc.room.snapshot(devices.first.roomId!),
        );
        report['serverRevisionAtFailure'] = authoritative.revision;
        report['clientBoardsMatchServer'] = [
          for (final device in devices)
            device.latest?.gameJson == authoritative.gameJson,
        ];
      } catch (_) {
        /* The original failure remains authoritative. */
      }
    }
    exitCode = 1;
  } finally {
    elapsed.stop();
    if (devices.isNotEmpty && devices.first.roomId != null) {
      try {
        await devices.first.send(RoomAction.leave);
      } catch (_) {
        /* Preserve the original failure. */
      }
    }
    for (final device in devices) {
      await device.close();
    }
    report['finishedAt'] = DateTime.now().toUtc().toIso8601String();
    await save();
    stdout.writeln('${report['status']}: ${reportFile.path}');
  }
}
