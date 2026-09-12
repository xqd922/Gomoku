import 'package:serverpod/serverpod.dart';

import '../generated/protocol.dart';
import '../services/players.dart';
import '../services/records.dart';
import '../services/rate_limiter.dart';

class ProfileEndpoint extends Endpoint {
  @override
  bool get requireLogin => true;

  Future<PlayerProfile> me(Session session) => Players.current(session);
  Future<PlayerProfile> rename(Session session, String nickname) =>
      Players.rename(session, nickname);
  Future<SyncPage> syncRecords(
    Session session,
    List<String> uploads,
    String cursor,
  ) async {
    await checkRateLimit(
      session,
      'sync:${session.authenticated!.userIdentifier}',
      limit: 60,
    );
    return Records.sync(session, uploads, cursor);
  }
}
