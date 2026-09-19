import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:uuid/uuid.dart' as uuid;

import '../generated/protocol.dart';
import 'database.dart';

final class Players {
  static const ids = uuid.Uuid();

  static String normalizeNickname(String input) {
    final name = input.trim();
    if (name.isEmpty ||
        name.runes.length > 24 ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(name)) {
      throw AppException(code: 'invalid_nickname');
    }
    return name;
  }

  static PlayerProfile fromRow(Row row) => PlayerProfile(
    playerId: row['id'] as String,
    nickname: row['nickname'] as String,
    isGuest: row['is_guest'] as bool,
  );

  static Future<PlayerProfile> current(
    Session session, {
    Transaction? transaction,
    bool lock = false,
  }) async {
    final auth = session.authenticated;
    if (auth == null) throw AppException(code: 'unauthenticated');
    return forAuth(
      session,
      auth.userIdentifier,
      transaction: transaction,
      lock: lock,
    );
  }

  static Future<PlayerProfile> forAuth(
    Session session,
    String authId, {
    Transaction? transaction,
    bool lock = false,
  }) async {
    final result = await rows(
      session,
      '''SELECT * FROM gm_players
         WHERE auth_user_id = CAST(@auth AS uuid) AND merged_into IS NULL${lock ? ' FOR NO KEY UPDATE' : ''}''',
      params: {'auth': authId},
      transaction: transaction,
    );
    if (result.isEmpty) throw AppException(code: 'unauthenticated');
    return fromRow(result.single);
  }

  static Future<void> requireNoActiveRoom(
    Session session,
    String playerId, {
    Transaction? transaction,
  }) async {
    final active = await rows(
      session,
      'SELECT room_id FROM gm_active_seats WHERE player_id = @id',
      params: {'id': playerId},
      transaction: transaction,
    );
    if (active.isNotEmpty) throw AppException(code: 'active_room');
  }

  static Future<({AuthSuccess auth, PlayerProfile profile})> createGuest(
    Session session,
    String nickname,
  ) => session.db.transaction((transaction) async {
    final name = normalizeNickname(nickname);
    final authUser = await AuthServices.instance.authUsers.create(
      session,
      transaction: transaction,
    );
    final profile = PlayerProfile(
      playerId: ids.v4(),
      nickname: name,
      isGuest: true,
    );
    await execute(
      session,
      '''INSERT INTO gm_players(id, auth_user_id, nickname, is_guest)
         VALUES (@id, CAST(@auth AS uuid), @name, true)''',
      params: {
        'id': profile.playerId,
        'auth': authUser.id.toString(),
        'name': name,
      },
      transaction: transaction,
    );
    final auth = await AuthServices.instance.tokenManager.issueToken(
      session,
      authUserId: authUser.id,
      method: 'gomoku_guest',
      transaction: transaction,
    );
    return (auth: auth, profile: profile);
  });

  /// Called in the same transaction as successful email authentication.
  /// The previous credential has already been validated by the auth route.
  static Future<PlayerProfile> claim(
    Session session, {
    required AuthSuccess authenticated,
    required AuthenticationInfo? previous,
    required String nickname,
    required Transaction transaction,
  }) async {
    final authId = authenticated.authUserId.toString();
    PlayerProfile? guest;
    if (previous != null && previous.userIdentifier != authId) {
      final old = await rows(
        session,
        '''SELECT * FROM gm_players WHERE auth_user_id = CAST(@auth AS uuid)
           AND merged_into IS NULL FOR UPDATE''',
        params: {'auth': previous.userIdentifier},
        transaction: transaction,
      );
      if (old.isNotEmpty) {
        final player = fromRow(old.single);
        await requireNoActiveRoom(
          session,
          player.playerId,
          transaction: transaction,
        );
        if (player.isGuest) guest = player;
      }
    }
    final existing = await rows(
      session,
      'SELECT * FROM gm_players WHERE auth_user_id = CAST(@auth AS uuid) FOR UPDATE',
      params: {'auth': authId},
      transaction: transaction,
    );
    late PlayerProfile target;
    if (existing.isNotEmpty) {
      target = fromRow(existing.single);
    } else if (guest != null) {
      final name = normalizeNickname(nickname);
      await execute(
        session,
        '''UPDATE gm_players SET auth_user_id = CAST(@auth AS uuid),
           is_guest = false, nickname = @name WHERE id = @id''',
        params: {'auth': authId, 'id': guest.playerId, 'name': name},
        transaction: transaction,
      );
      target = PlayerProfile(
        playerId: guest.playerId,
        nickname: name,
        isGuest: false,
      );
    } else {
      target = PlayerProfile(
        playerId: ids.v4(),
        nickname: normalizeNickname(nickname),
        isGuest: false,
      );
      await execute(
        session,
        '''INSERT INTO gm_players(id, auth_user_id, nickname, is_guest)
           VALUES (@id, CAST(@auth AS uuid), @name, false)''',
        params: {
          'id': target.playerId,
          'auth': authId,
          'name': target.nickname,
        },
        transaction: transaction,
      );
    }
    if (guest != null) {
      if (target.playerId != guest.playerId) {
        await execute(
          session,
          '''INSERT INTO gm_record_owners(record_id, player_id)
             SELECT record_id, @target FROM gm_record_owners WHERE player_id = @guest
             ON CONFLICT DO NOTHING''',
          params: {'target': target.playerId, 'guest': guest.playerId},
          transaction: transaction,
        );
        await execute(
          session,
          'UPDATE gm_players SET merged_into = @target WHERE id = @guest',
          params: {'target': target.playerId, 'guest': guest.playerId},
          transaction: transaction,
        );
      }
      await AuthServices.instance.tokenManager.revokeAllTokens(
        session,
        authUserId: UuidValue.fromString(previous!.userIdentifier),
        transaction: transaction,
      );
    }
    return target;
  }

  static Future<PlayerProfile> rename(Session session, String nickname) =>
      session.db.transaction((transaction) async {
        final profile = await current(
          session,
          transaction: transaction,
          lock: true,
        );
        await requireNoActiveRoom(
          session,
          profile.playerId,
          transaction: transaction,
        );
        final name = normalizeNickname(nickname);
        await execute(
          session,
          'UPDATE gm_players SET nickname = @name WHERE id = @id',
          params: {'id': profile.playerId, 'name': name},
          transaction: transaction,
        );
        return profile.copyWith(nickname: name);
      });
}
