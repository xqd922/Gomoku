import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:http/http.dart' as http;

// Run from the repository root on a trusted administrator's workstation.
// Credentials are read from a private file and are never written to the report.
const ids = Uuid();

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
  final connectionId = ids.v4();
  StreamSubscription<RoomSnapshot>? subscription;
  Timer? timer;
  bool heartbeatBusy = false;

  @override
  Future<String?> get authHeaderValue async =>
      token == null ? null : 'Bearer $token';

  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, Object?> body,
  ) async {
    final response = await httpClient
        .post(
          Uri.parse('$origin/auth/$action'),
          headers: {
            'content-type': 'application/json',
            'x-gomoku-client': 'native',
            if (token != null) 'authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    require(
      response.statusCode == 200,
      'Authentication failed (${data['error']}).',
    );
    token = data['token'] as String? ?? token;
    if (data['profile'] != null) {
      profile = PlayerProfile.fromJson(data['profile'] as Map<String, dynamic>);
    }
    return data;
  }

  void watch(String id) {
    roomId = id;
    subscription = rpc.room.watch(id, connectionId).listen((value) {
      if (latest == null || value.revision >= latest!.revision) latest = value;
    }, onError: (Object error) => streamError = error);
    timer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (heartbeatBusy) return;
      heartbeatBusy = true;
      try {
        await rpc.room.heartbeat(id, connectionId);
      } catch (error) {
        streamError = error;
      } finally {
        heartbeatBusy = false;
      }
    });
  }

  Future<RoomSnapshot> send(RoomAction action, {int? row, int? col}) async {
    for (var attempt = 0; ; attempt++) {
      final snapshot = await rpc.room.snapshot(roomId!);
      try {
        return await rpc.room.command(
          roomId!,
          RoomCommand(
            commandId: ids.v4(),
            expectedRevision: snapshot.revision,
            action: action,
            row: row,
            col: col,
          ),
        );
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
    timer?.cancel();
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
  final origin =
      Platform.environment['GOMOKU_WEB_URL'] ?? 'https://gomoku.xqd.pp.ua';
  require(
    Uri.parse(origin).scheme == 'https',
    'Public validation requires HTTPS.',
  );
  final folder = Directory('artifacts/production')..createSync(recursive: true);
  final reportFile = File(
    '${folder.path}/capacity-${DateTime.now().millisecondsSinceEpoch}.json',
  );
  final devices = <Device>[];
  final latencies = <int>[];
  final report = <String, Object?>{
    'startedAt': DateTime.now().toUtc().toIso8601String(),
    'origin': origin,
    'clients': 10,
    'accounts': 2,
    'requestedMinutes': minutes,
    'status': 'running',
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
        'email': account['email'],
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
    for (final device in devices) {
      device.watch(room.roomId);
    }
    await until(
      () => devices.every(
        (d) =>
            d.latest?.hostConnected == true && d.latest?.guestConnected == true,
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
            () => devices.every((d) => d.latest?.gameJson == expected),
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
