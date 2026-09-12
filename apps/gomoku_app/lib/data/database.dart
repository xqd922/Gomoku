import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:gomoku_core/gomoku_core.dart';

part 'database.g.dart';

final browserStoragePersistent = ValueNotifier(true);

final class LocalGameConflict implements Exception {
  const LocalGameConflict();
}

class GameEntries extends Table {
  TextColumn get recordId => text()();
  TextColumn get ownerKey => text()();
  TextColumn get payload => text()();
  DateTimeColumn get updatedAt => dateTime()();
  BoolColumn get pendingSync => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {recordId, ownerKey};
}

class SyncCursors extends Table {
  TextColumn get ownerKey => text()();
  TextColumn get cursor => text()();

  @override
  Set<Column<Object>> get primaryKey => {ownerKey};
}

@DriftDatabase(tables: [GameEntries, SyncCursors])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'gomoku',
          native: const DriftNativeOptions(shareAcrossIsolates: true),
          web: DriftWebOptions(
            sqlite3Wasm: Uri.base.resolve('/sqlite3.wasm'),
            driftWorker: Uri.base.resolve('/drift_worker.js'),
            onResult: (result) {
              browserStoragePersistent.value =
                  result.chosenImplementation !=
                  WasmStorageImplementation.inMemory;
            },
          ),
        ),
      );

  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Stream<List<GameRecord>> watchGames(String owner) =>
      (select(gameEntries)
            ..where((row) => row.ownerKey.equals(owner))
            ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
          .watch()
          .map((rows) => rows.map(_record).toList());

  Future<GameRecord?> find(String owner, String id) async {
    final row =
        await (select(gameEntries)..where(
              (row) => row.ownerKey.equals(owner) & row.recordId.equals(id),
            ))
            .getSingleOrNull();
    return row == null ? null : _record(row);
  }

  Future<GameRecord?> unfinished(String owner) async {
    final entries =
        await (select(gameEntries)
              ..where((row) => row.ownerKey.equals(owner))
              ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]))
            .get();
    for (final entry in entries) {
      final record = _record(entry);
      if (record.source == RecordSource.local && !record.game.isOver) {
        return record;
      }
    }
    return null;
  }

  Future<void> save(
    String owner,
    GameRecord record, {
    bool fromCloud = false,
  }) => into(gameEntries).insertOnConflictUpdate(
    GameEntriesCompanion.insert(
      recordId: record.id,
      ownerKey: owner,
      payload: jsonEncode(record.toJson()),
      updatedAt: record.updatedAt,
      pendingSync: Value(
        !fromCloud && record.source == RecordSource.local && record.game.isOver,
      ),
    ),
  );

  Future<List<GameRecord>> pending(String owner) async =>
      (await (select(gameEntries)
                ..where(
                  (row) =>
                      row.ownerKey.equals(owner) & row.pendingSync.equals(true),
                )
                ..limit(50))
              .get())
          .map(_record)
          .toList();

  /// Atomic compare-and-set prevents another tab overwriting a newer position.
  Future<void> saveLocalChange(
    String owner,
    GameRecord previous,
    GameRecord next,
  ) async {
    final affected =
        await (update(gameEntries)..where(
              (row) =>
                  row.ownerKey.equals(owner) &
                  row.recordId.equals(previous.id) &
                  row.payload.equals(jsonEncode(previous.toJson())),
            ))
            .write(
              GameEntriesCompanion(
                payload: Value(jsonEncode(next.toJson())),
                updatedAt: Value(next.updatedAt),
                pendingSync: Value(next.game.isOver),
              ),
            );
    if (affected != 1) throw const LocalGameConflict();
  }

  Future<String> cursor(String owner) async =>
      (await (select(
        syncCursors,
      )..where((r) => r.ownerKey.equals(owner))).getSingleOrNull())?.cursor ??
      '';

  Future<void> acceptSync(
    String owner,
    Iterable<GameRecord> uploaded,
    Iterable<GameRecord> downloaded,
    String cursor,
  ) => transaction(() async {
    for (final record in uploaded) {
      await (update(gameEntries)..where(
            (r) => r.ownerKey.equals(owner) & r.recordId.equals(record.id),
          ))
          .write(const GameEntriesCompanion(pendingSync: Value(false)));
    }
    for (final record in downloaded) {
      await save(owner, record, fromCloud: true);
    }
    await into(syncCursors).insertOnConflictUpdate(
      SyncCursorsCompanion.insert(ownerKey: owner, cursor: cursor),
    );
  });

  /// Atomic and repeatable, including after an interrupted login.
  Future<void> claimGuest(String guestOwner, String accountOwner) =>
      transaction(() async {
        if (guestOwner == accountOwner) return;
        final entries = await (select(
          gameEntries,
        )..where((r) => r.ownerKey.equals(guestOwner))).get();
        for (final entry in entries) {
          await into(gameEntries).insert(
            entry.copyWith(ownerKey: accountOwner),
            mode: InsertMode.insertOrIgnore,
          );
        }
        await (delete(
          gameEntries,
        )..where((r) => r.ownerKey.equals(guestOwner))).go();
      });

  GameRecord _record(GameEntry entry) =>
      GameRecord.fromJson(jsonDecode(entry.payload) as Map<String, dynamic>);
}
