import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../../generated/protocol.dart';
import '../../services/database.dart';

final class HealthRoute extends Route {
  @override
  Future<Response> handleCall(Session session, Request request) async {
    try {
      if (!applicationDatabaseReady) {
        throw StateError('Migrations are pending.');
      }
      await rows(
        session,
        'SELECT version FROM gm_schema_migrations WHERE version=1',
      );
      await session.caches.global.get<RoomSnapshot>('gm.health');
      final pending = await rows(
        session,
        'SELECT count(*) AS count FROM gm_outbox WHERE delivered_at IS NULL',
      );
      return Response.ok(
        body: Body.fromString(
          jsonEncode({
            'status': 'ok',
            'version': '1.0.0',
            'outboxPending': pending.single['count'],
          }),
          mimeType: MimeType.json,
        ),
        headers: Headers.fromMap({
          'cache-control': ['no-store'],
        }),
      );
    } catch (_) {
      return Response(
        503,
        body: Body.fromString(
          '{"status":"unavailable"}',
          mimeType: MimeType.json,
        ),
      );
    }
  }
}
