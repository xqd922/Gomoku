import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import 'database.dart';

/// PostgreSQL-backed limits apply across all server instances.
Future<void> checkRateLimit(
  Session session,
  String key, {
  int limit = 60,
  Duration window = const Duration(minutes: 1),
}) async {
  final slot =
      DateTime.now().toUtc().millisecondsSinceEpoch ~/ window.inMilliseconds;
  final result = await rows(
    session,
    '''INSERT INTO gm_rate_limits(key_hash, window_start, hits)
       VALUES (@key, @slot, 1)
       ON CONFLICT (key_hash, window_start)
       DO UPDATE SET hits = gm_rate_limits.hits + 1
       RETURNING hits''',
    params: {'key': digest(key), 'slot': slot},
  );
  if ((result.single['hits'] as int) > limit) {
    throw AppException(code: 'rate_limited');
  }
}
