import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:serverpod/serverpod.dart';

typedef Row = Map<String, dynamic>;

bool _applicationDatabaseReady = false;
bool get applicationDatabaseReady => _applicationDatabaseReady;

Future<List<Row>> rows(
  Session session,
  String sql, {
  Map<String, Object?> params = const {},
  Transaction? transaction,
}) async {
  final result = await session.db.unsafeQuery(
    sql,
    parameters: QueryParameters.named(params),
    transaction: transaction,
  );
  return result.map((row) => row.toColumnMap()).toList();
}

Future<int> execute(
  Session session,
  String sql, {
  Map<String, Object?> params = const {},
  Transaction? transaction,
}) => session.db.unsafeExecute(
  sql,
  parameters: QueryParameters.named(params),
  transaction: transaction,
);

String digest(String value) => sha256.convert(utf8.encode(value)).toString();

/// Framework migrations run first. App migrations are checksummed and applied
/// under an advisory lock so multiple instances may start safely.
Future<void> migrateApplication(Session session) async {
  await session.db.transaction((transaction) async {
    await rows(
      session,
      'SELECT pg_advisory_xact_lock(7744112200)',
      transaction: transaction,
    );
    await execute(
      session,
      '''CREATE TABLE IF NOT EXISTS gm_schema_migrations (
        version integer PRIMARY KEY,
        checksum text NOT NULL,
        applied_at timestamptz NOT NULL DEFAULT now()
      )''',
      transaction: transaction,
    );
    final files = await Directory('db')
        .list()
        .where(
          (entry) =>
              entry is File &&
              RegExp(r'[/\\]\d{3}_[^/\\]+\.sql$').hasMatch(entry.path),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) throw StateError('Application migrations are missing.');
    var expectedVersion = 1;
    for (final file in files) {
      final version = int.parse(file.uri.pathSegments.last.split('_').first);
      if (version != expectedVersion++) {
        throw StateError('Application migrations must be contiguous.');
      }
      final sql = await file.readAsString();
      final checksum = digest(sql.replaceAll('\r\n', '\n'));
      final applied = await rows(
        session,
        'SELECT checksum FROM gm_schema_migrations WHERE version=@version',
        params: {'version': version},
        transaction: transaction,
      );
      if (applied.isNotEmpty) {
        if (applied.single['checksum'] != checksum) {
          throw StateError('An applied migration was changed: ${file.path}');
        }
        continue;
      }
      await session.db.unsafeSimpleExecute(sql, transaction: transaction);
      await execute(
        session,
        'INSERT INTO gm_schema_migrations(version, checksum) VALUES (@version, @checksum)',
        params: {'version': version, 'checksum': checksum},
        transaction: transaction,
      );
    }
  });
  _applicationDatabaseReady = true;
}
