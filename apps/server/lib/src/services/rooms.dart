import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:gomoku_core/gomoku_core.dart';
import 'package:serverpod/serverpod.dart';
import 'package:uuid/uuid.dart' as uuid;

import '../generated/protocol.dart';
import 'database.dart';
import 'players.dart';
import 'rate_limiter.dart';
import 'records.dart';

final class Rooms {
  static const ids = uuid.Uuid();
  static const reconnectGrace = Duration(seconds: 120);
  static const presenceLease = Duration(seconds: 25);
  static const waitingLifetime = Duration(minutes: 30);
  static final _random = Random.secure();
  static final _uuidPattern = RegExp(
    r'^[a-fA-F0-9]{8}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{4}-[a-fA-F0-9]{12}$',
  );

  static DateTime get now => DateTime.now().toUtc();
  static GameState gameOf(RoomSnapshot room) =>
      GameState.fromJson(jsonDecode(room.gameJson) as Map<String, dynamic>);
  static bool isMember(RoomSnapshot room, String player) =>
      room.hostPlayerId == player || room.guestPlayerId == player;
  static Stone stoneOf(RoomSnapshot room, String player) {
    if (room.blackPlayerId == player) return Stone.black;
    if (room.whitePlayerId == player) return Stone.white;
    throw AppException(code: 'not_a_player');
  }

  static void validateId(String id) {
    if (!_uuidPattern.hasMatch(id)) throw AppException(code: 'invalid_request');
  }

  static Future<RoomSnapshot> create(Session session, String commandId) async {
    validateId(commandId);
    final caller = await Players.current(session);
    await checkRateLimit(session, 'room-create:${caller.playerId}', limit: 15);
    final hash = digest('create');
    return session.db.transaction((transaction) async {
      final player = await Players.current(
        session,
        transaction: transaction,
        lock: true,
      );
      final duplicate = await _previous(
        session,
        player.playerId,
        commandId,
        hash,
        transaction,
      );
      if (duplicate != null) return duplicate;
      await Players.requireNoActiveRoom(
        session,
        player.playerId,
        transaction: transaction,
      );
      const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      String code;
      do {
        code = List.generate(
          6,
          (_) => alphabet[_random.nextInt(alphabet.length)],
        ).join();
      } while ((await rows(
        session,
        'SELECT id FROM gm_rooms WHERE code=@code',
        params: {'code': code},
        transaction: transaction,
      )).isNotEmpty);
      final time = now;
      final room = RoomSnapshot(
        roomId: ids.v4(),
        code: code,
        revision: 0,
        status: RoomStatus.waiting,
        hostPlayerId: player.playerId,
        hostName: player.nickname,
        hostReady: false,
        guestReady: false,
        blackPlayerId: player.playerId,
        gameId: ids.v4(),
        gameJson: jsonEncode(GameState.newGame().toJson()),
        round: 1,
        hostConnected: false,
        guestConnected: false,
        createdAt: time,
        updatedAt: time,
        gameStartedAt: time,
        serverTime: time,
      );
      await execute(
        session,
        '''INSERT INTO gm_rooms(id,code,revision,status,host_id,payload,updated_at)
           VALUES(@id,@code,0,'waiting',@host,@payload,@now)''',
        params: {
          'id': room.roomId,
          'code': code,
          'host': player.playerId,
          'payload': jsonEncode(room.toJson()),
          'now': time,
        },
        transaction: transaction,
      );
      await _reserve(session, room.roomId, player.playerId, transaction);
      await _remember(
        session,
        player.playerId,
        commandId,
        hash,
        room,
        transaction,
      );
      return room;
    });
  }

  static Future<RoomSnapshot> join(
    Session session,
    String code,
    String commandId,
  ) async {
    validateId(commandId);
    code = code.trim().toUpperCase();
    if (!RegExp(r'^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(code)) {
      throw AppException(code: 'invalid_room_code');
    }
    final hash = digest('join:$code');
    final caller = await Players.current(session);
    await checkRateLimit(session, 'room-join:${caller.playerId}', limit: 30);
    return session.db.transaction((transaction) async {
      final player = await Players.current(
        session,
        transaction: transaction,
        lock: true,
      );
      final duplicate = await _previous(
        session,
        player.playerId,
        commandId,
        hash,
        transaction,
      );
      if (duplicate != null) return duplicate;
      final result = await rows(
        session,
        'SELECT payload FROM gm_rooms WHERE code=@code FOR UPDATE',
        params: {'code': code},
        transaction: transaction,
      );
      if (result.isEmpty) throw AppException(code: 'room_not_found');
      final room = _decode(result.single['payload'] as String);
      await _tick(session, room, transaction);
      if (room.status == RoomStatus.closed) {
        throw AppException(code: 'room_expired');
      }
      if (!isMember(room, player.playerId)) {
        if (room.guestPlayerId != null) throw AppException(code: 'room_full');
        if (room.status != RoomStatus.waiting) {
          throw AppException(code: 'game_started');
        }
        await _reserve(session, room.roomId, player.playerId, transaction);
        room.guestPlayerId = player.playerId;
        room.guestName = player.nickname;
        room.whitePlayerId = player.playerId;
        await _save(session, room, transaction);
      }
      await _remember(
        session,
        player.playerId,
        commandId,
        hash,
        room,
        transaction,
      );
      return room;
    });
  }

  static Future<RoomSnapshot?> active(Session session) async {
    final player = await Players.current(session);
    final result = await rows(
      session,
      'SELECT room_id FROM gm_active_seats WHERE player_id=@player',
      params: {'player': player.playerId},
    );
    if (result.isEmpty) return null;
    final room = await get(session, result.single['room_id'] as String);
    return room.status == RoomStatus.closed ? null : room;
  }

  static Future<RoomSnapshot> get(Session session, String roomId) async {
    validateId(roomId);
    final player = await Players.current(session);
    return session.db.transaction((transaction) async {
      final room = await _read(session, roomId, transaction);
      if (!isMember(room, player.playerId)) {
        throw AppException(code: 'not_a_player');
      }
      await _tick(session, room, transaction);
      room.serverTime = now;
      return room;
    });
  }

  static Future<RoomSnapshot> command(
    Session session,
    String roomId,
    RoomCommand command,
  ) async {
    validateId(roomId);
    validateId(command.commandId);
    final hash = digest(roomId + jsonEncode(command.toJson()));
    final caller = await Players.current(session);
    await checkRateLimit(
      session,
      'room-command:${caller.playerId}',
      limit: 300,
    );
    try {
      return await session.db.transaction((transaction) async {
        final player = await Players.current(
          session,
          transaction: transaction,
          lock: true,
        );
        final duplicate = await _previous(
          session,
          player.playerId,
          command.commandId,
          hash,
          transaction,
        );
        if (duplicate != null) return duplicate;
        final room = await _read(session, roomId, transaction);
        if (!isMember(room, player.playerId)) {
          throw AppException(code: 'not_a_player');
        }
        // The revision check rejects intervening client commands only: a
        // time-driven _tick transition is not a command, and rejecting after
        // it would both misreport stale_revision and roll the transition back.
        // Status checks below still run on the ticked room.
        if (room.revision != command.expectedRevision) {
          throw AppException(code: 'stale_revision');
        }
        await _tick(session, room, transaction);
        if (room.status == RoomStatus.closed) {
          throw AppException(code: 'room_expired');
        }
        final host = player.playerId == room.hostPlayerId;
        var game = gameOf(room);
        final wasOver = game.isOver;
        switch (command.action) {
          case RoomAction.ready:
            if (room.status != RoomStatus.waiting) {
              throw AppException(code: 'game_started');
            }
            if (host) {
              room.hostReady = true;
            } else {
              room.guestReady = true;
            }
            if (room.hostReady &&
                room.guestReady &&
                room.guestPlayerId != null) {
              _requireConnected(room);
              room.status = RoomStatus.playing;
              room.gameStartedAt = now;
            }
          case RoomAction.move:
            _requirePlaying(room);
            if (room.undoRequestedBy != null) {
              throw AppException(code: 'undo_pending');
            }
            if (command.row == null || command.col == null) {
              throw AppException(code: 'invalid_request');
            }
            game = game.play(
              command.row!,
              command.col!,
              player: stoneOf(room, player.playerId),
            );
          case RoomAction.requestUndo:
            _requirePlaying(room);
            if (room.undoRequestedBy != null) {
              throw AppException(code: 'undo_pending');
            }
            game.undoBeforeLastMoveBy(stoneOf(room, player.playerId));
            room.undoRequestedBy = player.playerId;
          case RoomAction.acceptUndo:
          case RoomAction.rejectUndo:
            _requirePlaying(room);
            final requester = room.undoRequestedBy;
            if (requester == null || requester == player.playerId) {
              throw AppException(code: 'invalid_undo');
            }
            if (command.action == RoomAction.acceptUndo) {
              game = game.undoBeforeLastMoveBy(stoneOf(room, requester));
            }
            room.undoRequestedBy = null;
          case RoomAction.resign:
            if (room.status != RoomStatus.playing &&
                room.status != RoomStatus.paused) {
              throw AppException(code: 'game_not_started');
            }
            game = game.resign(stoneOf(room, player.playerId));
          case RoomAction.rematch:
            if (room.status != RoomStatus.finished ||
                room.guestPlayerId == null) {
              throw AppException(code: 'game_not_over');
            }
            if (host) {
              room.hostReady = true;
            } else {
              room.guestReady = true;
            }
            if (room.hostReady && room.guestReady) {
              _requireConnected(room);
              final players = [room.hostPlayerId, room.guestPlayerId!]..sort();
              for (final participant in players) {
                await _reserve(session, roomId, participant, transaction);
              }
              room.round++;
              room.blackPlayerId = room.round.isOdd
                  ? room.hostPlayerId
                  : room.guestPlayerId!;
              room.whitePlayerId = room.round.isOdd
                  ? room.guestPlayerId
                  : room.hostPlayerId;
              room.gameId = ids.v4();
              room.gameStartedAt = now;
              room.status = RoomStatus.playing;
              room.resumeDeadline = null;
              game = GameState.newGame();
            }
          case RoomAction.leave:
            if (room.status == RoomStatus.playing ||
                room.status == RoomStatus.paused) {
              game = game.resign(stoneOf(room, player.playerId));
            }
            if (room.status == RoomStatus.waiting && !host) {
              await execute(
                session,
                'DELETE FROM gm_active_seats WHERE player_id=@player AND room_id=@room',
                params: {'player': player.playerId, 'room': roomId},
                transaction: transaction,
              );
              room.guestPlayerId = null;
              room.guestName = null;
              room.whitePlayerId = null;
              room.guestReady = false;
              room.hostReady = false;
              room.guestConnected = false;
            } else {
              room.status = RoomStatus.closed;
            }
        }
        room.gameJson = jsonEncode(game.toJson());
        if (game.isOver && !wasOver && room.status != RoomStatus.waiting) {
          await _finish(session, room, game, transaction);
        }
        if (room.status == RoomStatus.closed) {
          await execute(
            session,
            'DELETE FROM gm_active_seats WHERE room_id=@room',
            params: {'room': roomId},
            transaction: transaction,
          );
        }
        await _save(session, room, transaction);
        await _remember(
          session,
          player.playerId,
          command.commandId,
          hash,
          room,
          transaction,
        );
        return room;
      });
    } on RuleViolation catch (error) {
      throw AppException(code: error.code);
    }
  }

  static void _requirePlaying(RoomSnapshot room) {
    if (room.status == RoomStatus.paused) {
      throw AppException(code: 'opponent_disconnected');
    }
    if (room.status != RoomStatus.playing) {
      throw AppException(code: 'game_not_started');
    }
  }

  static void _requireConnected(RoomSnapshot room) {
    if (!room.hostConnected || !room.guestConnected) {
      throw AppException(code: 'opponent_disconnected');
    }
  }

  static Future<void> _reserve(
    Session session,
    String roomId,
    String playerId,
    Transaction transaction,
  ) async {
    final result = await rows(
      session,
      '''INSERT INTO gm_active_seats(player_id,room_id) VALUES(@player,@room)
         ON CONFLICT(player_id) DO UPDATE SET room_id=EXCLUDED.room_id
         WHERE gm_active_seats.room_id=EXCLUDED.room_id RETURNING room_id''',
      params: {'room': roomId, 'player': playerId},
      transaction: transaction,
    );
    if (result.isEmpty) throw AppException(code: 'active_room');
  }

  static Future<RoomSnapshot?> _previous(
    Session session,
    String playerId,
    String commandId,
    String hash,
    Transaction transaction,
  ) async {
    final previous = await rows(
      session,
      '''SELECT request_hash,response FROM gm_commands
         WHERE player_id=@player AND command_id=@command''',
      params: {'player': playerId, 'command': commandId},
      transaction: transaction,
    );
    if (previous.isEmpty) return null;
    if (previous.single['request_hash'] != hash) {
      throw AppException(code: 'command_conflict');
    }
    return _decode(previous.single['response'] as String);
  }

  static Future<void> _remember(
    Session session,
    String playerId,
    String commandId,
    String hash,
    RoomSnapshot room,
    Transaction transaction,
  ) => execute(
    session,
    '''INSERT INTO gm_commands(player_id,command_id,request_hash,room_id,response)
         VALUES(@player,@command,@hash,@room,@response)''',
    params: {
      'player': playerId,
      'command': commandId,
      'hash': hash,
      'room': room.roomId,
      'response': jsonEncode(room.toJson()),
    },
    transaction: transaction,
  ).then((_) {});

  static RoomSnapshot _decode(String payload) =>
      RoomSnapshot.fromJson(jsonDecode(payload) as Map<String, dynamic>);

  static Future<RoomSnapshot> _read(
    Session session,
    String roomId,
    Transaction transaction,
  ) async {
    final result = await rows(
      session,
      'SELECT payload FROM gm_rooms WHERE id=@id FOR UPDATE',
      params: {'id': roomId},
      transaction: transaction,
    );
    if (result.isEmpty) throw AppException(code: 'room_not_found');
    return _decode(result.single['payload'] as String);
  }

  static Future<void> _save(
    Session session,
    RoomSnapshot room,
    Transaction transaction,
  ) async {
    room.revision++;
    room.updatedAt = now;
    room.serverTime = now;
    final payload = jsonEncode(room.toJson());
    await execute(
      session,
      '''UPDATE gm_rooms SET revision=@revision,status=@status,guest_id=@guest,
         payload=@payload,updated_at=@time,deadline_at=@deadline WHERE id=@id''',
      params: {
        'id': room.roomId,
        'revision': room.revision,
        'status': room.status.name,
        'guest': room.guestPlayerId,
        'payload': payload,
        'time': room.updatedAt,
        'deadline': room.resumeDeadline,
      },
      transaction: transaction,
    );
    await execute(
      session,
      '''INSERT INTO gm_outbox(room_id,revision,payload) VALUES(@room,@revision,@payload)''',
      params: {
        'room': room.roomId,
        'revision': room.revision,
        'payload': payload,
      },
      transaction: transaction,
    );
  }

  static Future<void> _finish(
    Session session,
    RoomSnapshot room,
    GameState game,
    Transaction transaction,
  ) async {
    if (room.status != RoomStatus.closed) room.status = RoomStatus.finished;
    room.undoRequestedBy = null;
    room.resumeDeadline = null;
    room.hostReady = false;
    room.guestReady = false;
    if (room.guestPlayerId != null) {
      final hostBlack = room.blackPlayerId == room.hostPlayerId;
      await Records.saveOnline(
        session,
        GameRecord(
          id: room.gameId,
          game: game,
          source: RecordSource.online,
          startedAt: room.gameStartedAt,
          updatedAt: now,
          blackName: hostBlack ? room.hostName : room.guestName!,
          whiteName: hostBlack ? room.guestName! : room.hostName,
          roomCode: room.code,
        ),
        [room.hostPlayerId, room.guestPlayerId!],
        transaction,
      );
    }
    await execute(
      session,
      'DELETE FROM gm_active_seats WHERE room_id=@room',
      params: {'room': room.roomId},
      transaction: transaction,
    );
  }

  static Future<void> _tick(
    Session session,
    RoomSnapshot room,
    Transaction transaction,
  ) async {
    if (room.status == RoomStatus.closed) return;
    final time = now;
    var changed = false;
    final leases = await rows(
      session,
      'SELECT player_id,max(expires_at) AS expires FROM gm_presence WHERE room_id=@room GROUP BY player_id',
      params: {'room': room.roomId},
      transaction: transaction,
    );
    final seen = {
      for (final row in leases)
        row['player_id'] as String: (row['expires'] as DateTime).toUtc(),
    };
    final hostOnline = seen[room.hostPlayerId]?.isAfter(time) ?? false;
    final guestOnline = seen[room.guestPlayerId]?.isAfter(time) ?? false;
    if (room.hostConnected != hostOnline ||
        room.guestConnected != guestOnline) {
      changed = true;
    }
    room.hostConnected = hostOnline;
    room.guestConnected = guestOnline;
    if (room.status == RoomStatus.waiting &&
        time.difference(room.updatedAt) >= waitingLifetime) {
      room.status = RoomStatus.closed;
      await execute(
        session,
        'DELETE FROM gm_active_seats WHERE room_id=@room',
        params: {'room': room.roomId},
        transaction: transaction,
      );
      changed = true;
    } else if (room.status == RoomStatus.playing ||
        room.status == RoomStatus.paused) {
      if (room.resumeDeadline != null && !room.resumeDeadline!.isAfter(time)) {
        final game = gameOf(room).interrupt();
        room.gameJson = jsonEncode(game.toJson());
        await _finish(session, room, game, transaction);
        changed = true;
      } else if (hostOnline &&
          guestOnline &&
          room.status == RoomStatus.paused) {
        room.status = RoomStatus.playing;
        room.resumeDeadline = null;
        changed = true;
      } else if ((!hostOnline || !guestOnline) &&
          room.status == RoomStatus.playing) {
        final missingSince = [
          if (!hostOnline) seen[room.hostPlayerId] ?? time,
          if (!guestOnline) seen[room.guestPlayerId] ?? time,
        ]..sort();
        room.status = RoomStatus.paused;
        room.resumeDeadline = missingSince.first.add(reconnectGrace);
        room.undoRequestedBy = null;
        if (!room.resumeDeadline!.isAfter(time)) {
          final game = gameOf(room).interrupt();
          room.gameJson = jsonEncode(game.toJson());
          await _finish(session, room, game, transaction);
        }
        changed = true;
      }
    }
    if (changed) await _save(session, room, transaction);
  }

  static Future<void> heartbeat(
    Session session,
    String roomId,
    String connectionId,
  ) async {
    validateId(roomId);
    validateId(connectionId);
    final player = await Players.current(session);
    await session.db.transaction((transaction) async {
      final room = await _read(session, roomId, transaction);
      if (!isMember(room, player.playerId)) {
        throw AppException(code: 'not_a_player');
      }
      // Expired games cannot be resurrected by a late heartbeat.
      await _tick(session, room, transaction);
      if (room.status == RoomStatus.closed) return;
      await execute(
        session,
        '''INSERT INTO gm_presence(room_id,player_id,connection_id,expires_at)
           VALUES(@room,@player,@connection,@expires)
           ON CONFLICT(room_id,player_id,connection_id)
           DO UPDATE SET expires_at=EXCLUDED.expires_at''',
        params: {
          'room': roomId,
          'player': player.playerId,
          'connection': connectionId,
          'expires': now.add(presenceLease),
        },
        transaction: transaction,
      );
      await _tick(session, room, transaction);
    });
  }

  static Future<void> disconnect(
    Session session,
    String roomId,
    String playerId,
    String connectionId,
  ) async {
    await session.db.transaction((transaction) async {
      final room = await _read(session, roomId, transaction);
      await execute(
        session,
        '''UPDATE gm_presence SET expires_at=@now
           WHERE room_id=@room AND player_id=@player AND connection_id=@connection''',
        params: {
          'room': roomId,
          'player': playerId,
          'connection': connectionId,
          'now': now,
        },
        transaction: transaction,
      );
      await _tick(session, room, transaction);
    });
  }

  static Stream<RoomSnapshot> watch(
    Session session,
    String roomId,
    String connectionId,
  ) {
    // A controller handles cancellation immediately. An async generator waiting
    // for its next notification can defer its finally block until the next yield.
    final controller = StreamController<RoomSnapshot>();
    StreamSubscription<RoomSnapshot>? subscription;
    PlayerProfile? player;
    Timer? timer;
    var closed = false;
    var polling = false;
    var hasPresence = false;
    late Future<void> initializing;
    void emit(RoomSnapshot snapshot) {
      if (closed) return;
      if (!isMember(snapshot, player!.playerId)) {
        unawaited(controller.close());
        return;
      }
      controller.add(snapshot);
      if (snapshot.status == RoomStatus.closed) unawaited(controller.close());
    }

    Future<void> initialize() async {
      try {
        player = await Players.current(session);
        await get(session, roomId);
        if (closed) return;
        subscription = session.messages
            .createStream<RoomSnapshot>('gm.room.$roomId')
            .listen(
              emit,
              onError: (Object error, StackTrace stack) {
                if (!closed) controller.addError(error, stack);
              },
            );
        await heartbeat(session, roomId, connectionId);
        hasPresence = true;
        if (closed) return;
        final initial = await get(session, roomId);
        emit(initial);
        if (closed || initial.status == RoomStatus.closed) return;
        timer = Timer.periodic(const Duration(seconds: 10), (_) async {
          if (closed || polling) return;
          polling = true;
          try {
            // Repairs a final notification lost during a Redis interruption.
            emit(await get(session, roomId));
          } catch (error, stack) {
            if (!closed) controller.addError(error, stack);
          } finally {
            polling = false;
          }
        });
      } catch (error, stack) {
        if (!closed) {
          controller.addError(error, stack);
          unawaited(controller.close());
        }
      }
    }

    controller.onListen = () {
      initializing = initialize();
    };
    controller.onCancel = () async {
      closed = true;
      timer?.cancel();
      await initializing;
      await subscription?.cancel();
      if (!hasPresence || player == null) return;
      final cleanup = await session.serverpod.createSession(
        enableLogging: false,
      );
      try {
        await disconnect(cleanup, roomId, player!.playerId, connectionId);
      } catch (_) {
        // The persisted lease still expires if storage is unavailable.
      } finally {
        await cleanup.close();
      }
    };
    return controller.stream;
  }

  static Future<void> maintain(Session session) async {
    final candidates = await rows(
      session,
      '''SELECT id FROM gm_rooms WHERE status IN ('waiting','playing','paused')
         ORDER BY updated_at LIMIT 1000''',
    );
    for (final row in candidates) {
      await session.db.transaction((transaction) async {
        final room = await _read(session, row['id'] as String, transaction);
        await _tick(session, room, transaction);
      });
    }
  }

  static Future<void> dispatchOutbox(Session session) async {
    await session.db.transaction((transaction) async {
      final pending = await rows(
        session,
        '''SELECT id,payload FROM gm_outbox WHERE delivered_at IS NULL
           ORDER BY id FOR UPDATE SKIP LOCKED LIMIT 100''',
        transaction: transaction,
      );
      for (final row in pending) {
        final snapshot = _decode(row['payload'] as String);
        final delivered = await session.messages.postMessage(
          'gm.room.${snapshot.roomId}',
          snapshot,
          global: true,
        );
        if (!delivered) {
          throw StateError('Redis did not accept the room event.');
        }
        await execute(
          session,
          'UPDATE gm_outbox SET delivered_at=now() WHERE id=@id',
          params: {'id': row['id']},
          transaction: transaction,
        );
      }
    });
  }
}
