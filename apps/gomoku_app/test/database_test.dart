import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:gomoku_flutter/data/database.dart';
import 'package:uuid/uuid.dart';

GameRecord record({
  bool finished = false,
  RecordSource source = RecordSource.local,
}) {
  final now = DateTime.now().toUtc();
  final game = GameState.newGame().play(7, 7);
  return GameRecord(
    id: const Uuid().v4(),
    game: finished ? game.interrupt() : game,
    source: source,
    startedAt: now,
    updatedAt: now,
    blackName: 'A',
    whiteName: 'B',
  );
}

void main() {
  // Each test connection uses a separate file or independent in-memory database.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('unfinished games survive reopening the versioned database', () async {
    final directory = await Directory.systemTemp.createTemp(
      'gomoku-drift-test-',
    );
    final file = File('${directory.path}/games.sqlite');
    final original = record();
    final first = AppDatabase.forTesting(NativeDatabase(file));
    await first.save('guest:one', original);
    await first.close();
    final restored = AppDatabase.forTesting(NativeDatabase(file));
    expect(
      (await restored.unfinished('guest:one'))!.game.at(7, 7),
      Stone.black,
    );
    expect(await restored.unfinished('guest:two'), isNull);
    expect(
      (await restored.customSelect('PRAGMA user_version').getSingle())
          .data
          .values
          .single,
      1,
    );
    await restored.close();
    await directory.delete(recursive: true);
  });

  test('guest namespace claim is atomic, idempotent, and keeps other accounts isolated', () async {
    final guest = record(finished: true);
    final other = record(finished: true);
    await db.save('guest:one', guest);
    await db.save('player:other', other);
    await db.claimGuest('guest:one', 'player:account');
    await db.claimGuest('guest:one', 'player:account');
    expect(await db.find('guest:one', guest.id), isNull);
    expect((await db.pending('player:account')).map((r) => r.id), [guest.id]);
    expect(await db.find('player:other', guest.id), isNull);
    expect((await db.find('player:other', other.id))!.id, other.id);
  });

  test('offline queue only uploads finished local games and commits sync atomically', () async {
    final local = record(finished: true);
    final online = record(finished: true, source: RecordSource.online);
    await db.save('player:a', local);
    await db.save('player:a', online);
    await db.save('player:a', record());
    expect((await db.pending('player:a')).map((r) => r.id), [local.id]);
    await db.acceptSync('player:a', [local], [online], 'cursor-one');
    expect(await db.pending('player:a'), isEmpty);
    expect(await db.cursor('player:a'), 'cursor-one');
    expect(
      jsonEncode((await db.find('player:a', online.id))!.toJson()),
      jsonEncode(online.toJson()),
    );
    expect(await db.cursor('player:b'), '');
  });

  test(
    'stale tab cannot overwrite a move already saved by another tab',
    () async {
      final original = record();
      await db.save('guest:one', original);
      final accepted = original.copyWith(
        game: original.game.play(7, 8),
        updatedAt: DateTime.now().toUtc(),
      );
      final stale = original.copyWith(
        game: original.game.play(8, 8),
        updatedAt: DateTime.now().toUtc(),
      );
      await db.saveLocalChange('guest:one', original, accepted);
      await expectLater(
        db.saveLocalChange('guest:one', original, stale),
        throwsA(isA<LocalGameConflict>()),
      );
      expect(
        (await db.find('guest:one', original.id))!.game.at(7, 8),
        Stone.white,
      );
      expect((await db.find('guest:one', original.id))!.game.at(8, 8), isNull);
    },
  );
}
