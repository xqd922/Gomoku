@Timeout(Duration(minutes: 5))
library;

import 'dart:async';
import 'dart:convert';

import 'package:gomoku_server/src/services/database.dart' show digest;
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final first = TestServer(9080);
  final second = TestServer(9180);
  late Connection db;
  final players = <TestPlayer>[];
  final rooms = <TestRoom>[];

  Future<TestPlayer> guest(TestServer server, String nickname) async {
    final player = TestPlayer(server, nickname);
    players.add(player);
    await player.guest();
    return player;
  }

  Future<TestRoom> room() async {
    final a = await guest(first, 'Black');
    final b = await guest(second, 'White');
    final result = await TestRoom.open(a, b);
    rooms.add(result);
    return result;
  }

  setUpAll(() async {
    await first.start();
    await second.start();
    db = await testDatabase();
  });
  tearDown(() async {
    for (final item in rooms) {
      await item.close();
    }
    rooms.clear();
    for (final player in players) {
      player.close();
    }
    players.clear();
  });
  tearDownAll(() async {
    await first.stop();
    await second.stop();
    await db.close();
  });

  test(
    'two real servers deliver rooms, enforce seats, identity, and revisions',
    () async {
      final game = await room();
      final snapshot = await game.a.client.room.snapshot(game.id);
      expect(snapshot.blackPlayerId, game.a.profile!.playerId);
      expect(snapshot.status, RoomStatus.playing);
      final third = await guest(second, 'Spectator');
      await expectLater(
        third.client.room.joinRoom(snapshot.code, ids.v4()),
        appError('room_full'),
      );
      await expectLater(
        third.client.room.snapshot(game.id),
        appError('not_a_player'),
      );
      await expectLater(
        game.a.client.profile.rename('Changed'),
        appError('active_room'),
      );
      await expectLater(game.a.auth('logout', {}), authError('active_room'));
      await expectLater(
        game.b.send(game.id, RoomAction.move, row: 7, col: 7),
        appError('not_your_turn'),
      );
      await game.a.send(game.id, RoomAction.move, row: 7, col: 7);
      final delivered = await game.second.until(
        (r) => gameOf(r).moves.length == 1,
      );
      expect(gameOf(delivered).at(7, 7), Stone.black);
    },
  );

  test('create and commands are idempotent; concurrent revisions cannot double-play', () async {
    final a = await guest(first, 'Retry');
    final id = ids.v4();
    final created = await Future.wait([
      a.client.room.createRoom(id),
      a.client.room.createRoom(id),
    ]);
    expect(created[0].roomId, created[1].roomId);
    await a.send(created.first.roomId, RoomAction.leave);
    final game = await room();
    final snapshot = await game.a.client.room.snapshot(game.id);
    final command = RoomCommand(
      commandId: ids.v4(),
      expectedRevision: snapshot.revision,
      action: RoomAction.move,
      row: 7,
      col: 7,
    );
    final duplicates = await Future.wait([
      game.a.client.room.command(game.id, command),
      game.a.client.room.command(game.id, command),
    ]);
    expect(duplicates[0].revision, duplicates[1].revision);
    expect(gameOf(duplicates[1]).moves.length, 1);
    await expectLater(
      game.a.client.room.command(game.id, command.copyWith(col: 8)),
      appError('command_conflict'),
    );
    await expectLater(
      game.b.client.room.command(
        game.id,
        RoomCommand(
          commandId: ids.v4(),
          expectedRevision: snapshot.revision,
          action: RoomAction.move,
          row: 8,
          col: 7,
        ),
      ),
      appError('stale_revision'),
    );
    final next = await game.b.client.room.snapshot(game.id);
    Future<Object> attempt(int col) async {
      try {
        return await game.b.client.room.command(
          game.id,
          RoomCommand(
            commandId: ids.v4(),
            expectedRevision: next.revision,
            action: RoomAction.move,
            row: 8,
            col: col,
          ),
        );
      } catch (error) {
        return error;
      }
    }

    final results = await Future.wait([attempt(7), attempt(8)]);
    expect(results.whereType<RoomSnapshot>().length, 1);
    expect(results.whereType<AppException>().single.code, 'stale_revision');
    expect(gameOf(await game.a.client.room.snapshot(game.id)).moves.length, 2);
  });

  test(
    'agreed undo, complete game, durable record, and rematch swap',
    () async {
      final game = await room();
      await game.a.send(game.id, RoomAction.move, row: 7, col: 7);
      await game.b.send(game.id, RoomAction.move, row: 8, col: 7);
      await game.a.send(game.id, RoomAction.move, row: 7, col: 8);
      await game.b.send(game.id, RoomAction.requestUndo);
      await expectLater(
        game.b.send(game.id, RoomAction.acceptUndo),
        appError('invalid_undo'),
      );
      final undone = await game.a.send(game.id, RoomAction.acceptUndo);
      expect(gameOf(undone).moves.length, 1);
      expect(gameOf(undone).turn, Stone.white);
      await game.b.send(game.id, RoomAction.move, row: 8, col: 7);
      for (var col = 8; col <= 10; col++) {
        await game.a.send(game.id, RoomAction.move, row: 7, col: col);
        await game.b.send(game.id, RoomAction.move, row: 8, col: col);
      }
      final done = await game.a.send(game.id, RoomAction.move, row: 7, col: 11);
      expect(done.status, RoomStatus.finished);
      expect(gameOf(done).result!.winner, Stone.black);
      await game.second.until((r) => r.status == RoomStatus.finished);
      final stored = await db.execute(
        Sql.named('SELECT payload FROM gm_records WHERE id=@id'),
        parameters: {'id': done.gameId},
      );
      expect(
        GameRecord.fromJson(
          jsonDecode(stored.single[0] as String) as Map<String, dynamic>,
        ).game.moves.length,
        9,
      );
      final owners = await db.execute(
        Sql.named('SELECT player_id FROM gm_record_owners WHERE record_id=@id'),
        parameters: {'id': done.gameId},
      );
      expect(owners.length, 2);
      await game.a.send(game.id, RoomAction.rematch);
      final again = await game.b.send(game.id, RoomAction.rematch);
      expect(again.round, 2);
      expect(again.gameId, isNot(done.gameId));
      expect(again.blackPlayerId, game.b.profile!.playerId);
      expect(gameOf(again).moves, isEmpty);
      final resigned = await game.b.send(game.id, RoomAction.resign);
      expect(gameOf(resigned).result!.winner, Stone.white);
    },
  );

  test(
    'disconnect pauses for 120s, reconnect restores, timeout interrupts',
    () async {
      final game = await room();
      await game.a.send(game.id, RoomAction.move, row: 7, col: 7);
      await game.second.close();
      final paused = await game.first.until(
        (r) => r.status == RoomStatus.paused,
      );
      expect(
        paused.resumeDeadline!.difference(paused.serverTime).inSeconds,
        inInclusiveRange(115, 120),
      );
      await expectLater(
        game.b.send(game.id, RoomAction.move, row: 8, col: 7),
        appError('opponent_disconnected'),
      );
      final returned = Presence(game.b, game.id);
      await returned.until((r) => r.status == RoomStatus.playing);
      expect(gameOf(returned.latest!).moves.length, 1);
      await returned.close();
      await game.first.until(
        (r) => r.status == RoomStatus.paused && r.revision > paused.revision,
      );
      final expired = (await game.a.client.room.snapshot(game.id))
        ..resumeDeadline = DateTime.now().toUtc().subtract(
          const Duration(seconds: 1),
        );
      await db.execute(
        Sql.named(
          'UPDATE gm_rooms SET payload=@payload,deadline_at=@deadline WHERE id=@id',
        ),
        parameters: {
          'payload': jsonEncode(expired.toJson()),
          'deadline': expired.resumeDeadline,
          'id': game.id,
        },
      );
      final interrupted = await game.a.client.room.snapshot(game.id);
      expect(gameOf(interrupted).result!.isInterrupted, isTrue);
      await expectLater(
        game.b.send(game.id, RoomAction.move, row: 9, col: 9),
        appError('game_not_started'),
      );
    },
  );

  test('idle waiting room expires after thirty minutes', () async {
    final a = await guest(first, 'Waiting');
    final b = await guest(second, 'Late');
    final waiting = await a.client.room.createRoom(ids.v4());
    waiting.updatedAt = DateTime.now().toUtc().subtract(
      const Duration(minutes: 31),
    );
    await db.execute(
      Sql.named(
        'UPDATE gm_rooms SET payload=@payload,updated_at=@updated WHERE id=@id',
      ),
      parameters: {
        'payload': jsonEncode(waiting.toJson()),
        'updated': waiting.updatedAt,
        'id': waiting.roomId,
      },
    );
    await expectLater(
      b.client.room.joinRoom(waiting.code, ids.v4()),
      appError('room_expired'),
    );
    final closed = await a.client.room.snapshot(waiting.roomId);
    expect(closed.status, RoomStatus.closed);
    expect(await a.client.room.activeRoom(), isNull);
  });

  test(
    'service restart preserves seats, moves, sessions, and streaming',
    () async {
      final game = await room();
      await game.a.send(game.id, RoomAction.move, row: 7, col: 7);
      await game.first.close();
      await first.stop();
      await first.start();
      final restored = await game.a.client.room.snapshot(game.id);
      expect(gameOf(restored).moves.length, 1);
      expect(restored.hostPlayerId, game.a.profile!.playerId);
      final connection = Presence(game.a, game.id);
      try {
        await connection.until((r) => r.status == RoomStatus.playing);
        await game.b.send(game.id, RoomAction.move, row: 8, col: 7);
        await connection.until((r) => gameOf(r).moves.length == 2);
      } finally {
        await connection.close();
      }
    },
  );

  test('email verification upgrades a guest; uploads deduplicate and isolate accounts', () async {
    final a = await guest(first, 'Account A');
    final guestId = a.profile!.playerId;
    final oldToken = a.token;
    await a.register(nickname: 'Registered A');
    expect(a.profile!.isGuest, isFalse);
    expect(a.profile!.playerId, guestId);
    expect(a.profile!.nickname, 'Registered A');
    final old = TestPlayer(first, 'Old guest')..token = oldToken;
    players.add(old);
    await expectLater(
      old.client.profile.me(),
      throwsA(isA<ServerpodClientUnauthorized>()),
    );
    final record = localRecord();
    final payload = jsonEncode(record.toJson());
    final page = await a.client.profile.syncRecords([payload], '');
    expect(page.records.map((r) => jsonDecode(r)['id']), contains(record.id));
    final duplicate = await a.client.profile.syncRecords([
      payload,
      payload,
    ], '');
    expect(
      duplicate.records.where((r) => jsonDecode(r)['id'] == record.id).length,
      1,
    );
    final altered = record.copyWith(blackName: 'Tampered');
    await expectLater(
      a.client.profile.syncRecords([jsonEncode(altered.toJson())], ''),
      appError('record_conflict'),
    );
    final forged = record.toJson();
    (forged['game'] as Map<String, dynamic>)['result'] = {
      'reason': 'five',
      'winner': 'white',
      'winningLine': [],
    };
    await expectLater(
      a.client.profile.syncRecords([jsonEncode(forged)], ''),
      appError('invalid_record'),
    );
    final b = await guest(second, 'Account B');
    await b.register();
    expect((await b.client.profile.syncRecords([], '')).records, isEmpty);
    await expectLater(
      b.client.profile.syncRecords([payload], ''),
      appError('record_conflict'),
    );
    await expectLater(
      a.auth('login', {'email': a.email, 'password': 'Wrong password'}),
      authError('invalid_credentials'),
    );
    final sessionToken = a.token;
    await a.auth('logout', {});
    final loggedOut = TestPlayer(first, 'Revoked')..token = sessionToken;
    players.add(loggedOut);
    await expectLater(
      loggedOut.client.profile.me(),
      throwsA(isA<ServerpodClientUnauthorized>()),
    );
    a.token = null;
    await a.auth('login', {'email': a.email, 'password': TestPlayer.password});
    expect((await a.client.profile.syncRecords([], '')).records.length, 1);
  });

  test('existing account keeps its profile and transactionally claims guest online records', () async {
    final account = await guest(first, 'Original nickname');
    await account.register();
    final originalId = account.profile!.playerId;
    final game = await room();
    final ended = await game.a.send(game.id, RoomAction.resign);
    final guestId = game.a.profile!.playerId;
    final before = await account.client.profile.syncRecords([], '');
    await game.a.auth('login', {
      'email': account.email,
      'password': TestPlayer.password,
      'nickname': 'Must not replace account nickname',
    });
    expect(game.a.profile!.playerId, originalId);
    expect(game.a.profile!.nickname, 'Original nickname');
    final sync = await game.a.client.profile.syncRecords([], before.cursor);
    expect(
      sync.records.map((r) => jsonDecode(r)['id']),
      contains(ended.gameId),
    );
    final merged = await db.execute(
      Sql.named('SELECT merged_into FROM gm_players WHERE id=@id'),
      parameters: {'id': guestId},
    );
    expect(merged.single[0], originalId);
    final online = GameRecord.fromJson(
      jsonDecode(sync.records.single) as Map<String, dynamic>,
    );
    final disguised = online.toJson()..['source'] = 'local';
    await expectLater(
      game.a.client.profile.syncRecords([jsonEncode(disguised)], ''),
      appError('record_conflict'),
    );
  });

  test(
    'password reset through Mailpit revokes sessions and verifies new password',
    () async {
      final a = await guest(first, 'Reset');
      await a.register();
      final previousToken = a.token;
      final request = await a.auth('reset-start', {'email': a.email});
      final code = await emailCode(a.email!);
      await expectLater(
        a.auth('reset-finish', {
          'requestId': request['requestId'],
          'code': 'INVALID',
          'password': 'Different!5678',
        }),
        authError('invalid_verification'),
      );
      await a.auth('reset-finish', {
        'requestId': request['requestId'],
        'code': code,
        'password': 'Different!5678',
      });
      final old = TestPlayer(second, 'Old session')..token = previousToken;
      players.add(old);
      await expectLater(
        old.client.profile.me(),
        throwsA(isA<ServerpodClientUnauthorized>()),
      );
      a.token = null;
      await expectLater(
        a.auth('login', {'email': a.email, 'password': TestPlayer.password}),
        authError('invalid_credentials'),
      );
      await a.auth('login', {'email': a.email, 'password': 'Different!5678'});
      expect(a.profile!.isGuest, isFalse);
    },
  );

  test(
    'a transaction started before a sync cannot commit an invisible record',
    () async {
      final a = await guest(first, 'Concurrent sync');
      await a.register();
      final delayed = localRecord();
      final payload = jsonEncode(delayed.toJson());
      final transactionStarted = Completer<void>();
      final allowCommit = Completer<void>();
      final writer = db.runTx((transaction) async {
        await transaction.execute('SELECT now()');
        transactionStarted.complete();
        await allowCommit.future;
        await transaction.execute(
          Sql.named(
            "INSERT INTO gm_records(id,source,payload,payload_hash) VALUES (@id,'local',@payload,@hash)",
          ),
          parameters: {
            'id': delayed.id,
            'payload': payload,
            'hash': digest(payload),
          },
        );
        await transaction.execute(
          Sql.named(
            'INSERT INTO gm_record_owners(record_id,player_id) VALUES (@id,@player)',
          ),
          parameters: {'id': delayed.id, 'player': a.profile!.playerId},
        );
      });
      await transactionStarted.future;
      final cursor = await a.client.profile.syncRecords([
        jsonEncode(localRecord().toJson()),
      ], '');
      allowCommit.complete();
      await writer;
      final next = await a.client.profile.syncRecords([], cursor.cursor);
      expect(
        next.records.map((r) => jsonDecode(r)['id']),
        contains(delayed.id),
      );
    },
  );

  test(
    'browser authentication uses HttpOnly cookies and rejects foreign origins',
    () async {
      final uri = Uri.parse('${first.web}auth/guest');
      final response = await http.post(
        uri,
        headers: {
          'content-type': 'application/json',
          'x-gomoku-client': 'web',
          'origin': 'http://localhost:4280',
        },
        body: jsonEncode({'nickname': 'Cookie player'}),
      );
      expect(response.statusCode, 200);
      expect((jsonDecode(response.body) as Map).containsKey('token'), isFalse);
      final cookie = response.headers['set-cookie']!;
      expect(cookie, contains('HttpOnly'));
      expect(cookie, contains('SameSite=Lax'));
      final rejected = await http.post(
        Uri.parse('${first.web}auth/session'),
        headers: {
          'content-type': 'application/json',
          'x-gomoku-client': 'web',
          'cookie': cookie.split(';').first,
          'origin': 'https://foreign.example',
        },
        body: '{}',
      );
      expect(rejected.statusCode, 403);
      final missingOrigin = await http.post(
        Uri.parse('${first.web}auth/session'),
        headers: {
          'content-type': 'application/json',
          'x-gomoku-client': 'web',
          'cookie': cookie.split(';').first,
        },
        body: '{}',
      );
      expect(missingOrigin.statusCode, 403);
    },
  );

  test(
    'waiting rooms are listed for one-tap joining, hidden from their host',
    () async {
      final host = await guest(first, 'Host');
      final watcher = await guest(second, 'Watcher');
      final room = await host.client.room.createRoom(ids.v4());
      final listed = await watcher.client.room.openRooms();
      final entry = listed.singleWhere(
        (item) => item.roomId == room.roomId,
        orElse: () => throw StateError('Open room was not listed.'),
      );
      expect(entry.code, room.code);
      expect(entry.hostName, 'Host');
      expect(
        (await host.client.room.openRooms()).map((item) => item.roomId),
        isNot(contains(room.roomId)),
      );
      // Once the seat is taken the room leaves the list again.
      await watcher.client.room.joinRoom(room.code, ids.v4());
      expect(
        (await watcher.client.room.openRooms()).map((item) => item.roomId),
        isNot(contains(room.roomId)),
      );
    },
  );
}
