import 'dart:convert';

import 'package:gomoku_core/gomoku_core.dart';
import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'database.dart';
import 'players.dart';

final class Records {
  static Future<void> saveOnline(
    Session session,
    GameRecord record,
    Iterable<String> owners,
    Transaction transaction,
  ) async {
    final payload = jsonEncode(record.toJson());
    await execute(
      session,
      '''INSERT INTO gm_records(id, source, payload, payload_hash)
         VALUES (@id, 'online', @payload, @hash) ON CONFLICT (id) DO NOTHING''',
      params: {'id': record.id, 'payload': payload, 'hash': digest(payload)},
      transaction: transaction,
    );
    final sortedOwners = owners.toSet().toList()..sort();
    for (final player in sortedOwners) {
      await execute(
        session,
        '''INSERT INTO gm_record_owners(record_id, player_id)
           VALUES (@record, @player) ON CONFLICT DO NOTHING''',
        params: {'record': record.id, 'player': player},
        transaction: transaction,
      );
    }
  }

  static Future<SyncPage> sync(
    Session session,
    List<String> uploads,
    String cursor,
  ) async {
    if (uploads.length > 50 || uploads.any((r) => r.length > 65536)) {
      throw AppException(code: 'invalid_record');
    }
    final player = await Players.current(session);
    if (player.isGuest) throw AppException(code: 'account_required');
    final parsed = <(String, GameRecord)>[];
    try {
      for (final upload in uploads) {
        final record = GameRecord.fromJson(
          jsonDecode(upload) as Map<String, dynamic>,
        );
        if (record.source != RecordSource.local || !record.game.isOver) {
          throw AppException(code: 'invalid_record');
        }
        parsed.add((jsonEncode(record.toJson()), record));
      }
    } on RuleViolation {
      throw AppException(code: 'invalid_record');
    } on FormatException {
      throw AppException(code: 'invalid_record');
    } on TypeError {
      throw AppException(code: 'invalid_record');
    }
    await session.db.transaction((transaction) async {
      await Players.current(session, transaction: transaction, lock: true);
      for (final (payload, record) in parsed) {
        final existing = await rows(
          session,
          '''SELECT r.source, r.payload_hash,
             EXISTS(SELECT 1 FROM gm_record_owners o
                    WHERE o.record_id=r.id AND o.player_id=@player) AS owned
             FROM gm_records r WHERE r.id=@id FOR UPDATE''',
          params: {'id': record.id, 'player': player.playerId},
          transaction: transaction,
        );
        if (existing.isNotEmpty) {
          final row = existing.single;
          if (row['owned'] != true ||
              row['source'] != 'local' ||
              row['payload_hash'] != digest(payload)) {
            throw AppException(code: 'record_conflict');
          }
          continue;
        }
        await execute(
          session,
          '''INSERT INTO gm_records(id, source, payload, payload_hash)
             VALUES (@id, 'local', @payload, @hash)''',
          params: {
            'id': record.id,
            'payload': payload,
            'hash': digest(payload),
          },
          transaction: transaction,
        );
        await execute(
          session,
          'INSERT INTO gm_record_owners(record_id, player_id) VALUES (@id,@player)',
          params: {'id': record.id, 'player': player.playerId},
          transaction: transaction,
        );
      }
    });
    var since = 0;
    if (cursor.isNotEmpty) {
      try {
        if (cursor.startsWith('r1:')) {
          since = int.parse(cursor.substring(3));
          if (since < 0) throw const FormatException();
        } else {
          // A pre-revision client gets one safe full rescan after migration.
          final pieces = utf8
              .decode(base64Url.decode(base64Url.normalize(cursor)))
              .split('|');
          if (pieces.length != 2) throw const FormatException();
          DateTime.parse(pieces[0]);
        }
      } catch (_) {
        throw AppException(code: 'invalid_cursor');
      }
    }
    final page = await rows(
      session,
      '''SELECT r.id,r.payload,o.sync_revision FROM gm_record_owners o
         JOIN gm_records r ON r.id=o.record_id
         WHERE o.player_id=@player
           AND o.sync_revision > @since
         ORDER BY o.sync_revision LIMIT 101''',
      params: {'player': player.playerId, 'since': since},
    );
    final visible = page.take(100).toList();
    var nextCursor = cursor;
    if (visible.isNotEmpty) {
      final row = visible.last;
      nextCursor = 'r1:${row['sync_revision']}';
    }
    return SyncPage(
      records: visible.map((r) => r['payload'] as String).toList(),
      cursor: nextCursor,
      hasMore: page.length > 100,
    );
  }
}
