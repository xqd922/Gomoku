import 'dart:convert';
import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:uuid/uuid.dart' as uuid;

import '../generated/protocol.dart';
import 'app_config.dart';
import 'database.dart';
import 'players.dart';

final class PrivateAccounts {
  /// Short login names identify the existing fixed accounts. Email remains a
  /// compatible login identifier, including for already-installed clients.
  static Future<String> resolveEmail(
    Session session,
    String identifier, {
    Transaction? transaction,
  }) async {
    final normalized = identifier.trim().toLowerCase();
    if (!AppConfig.current.privateAccounts || normalized.contains('@')) {
      return normalized;
    }
    final account = await rows(
      session,
      'SELECT email FROM gm_private_accounts WHERE login_name=@login',
      params: {'login': normalized},
      transaction: transaction,
    );
    if (account.length != 1) throw AppException(code: 'invalid_credentials');
    return account.single['email'] as String;
  }

  static Future<bool> allowed(
    Session session,
    String authId, {
    Transaction? transaction,
  }) async {
    if (!AppConfig.current.privateAccounts) return true;
    if (!applicationDatabaseReady) return false;
    return (await rows(
      session,
      '''SELECT 1 FROM gm_private_accounts a JOIN gm_players p ON p.id=a.player_id
         WHERE p.auth_user_id=CAST(@auth AS uuid) AND NOT p.is_guest AND p.merged_into IS NULL''',
      params: {'auth': authId},
      transaction: transaction,
    )).isNotEmpty;
  }

  static Future<void> requireAllowed(
    Session session,
    String authId, {
    Transaction? transaction,
  }) async {
    if (!await allowed(session, authId, transaction: transaction)) {
      throw AppException(code: 'account_not_allowed');
    }
  }

  /// A local administrator supplies the two accounts through a private file.
  /// Existing accounts are never taken over or reset by rerunning provisioning.
  static Future<void> provision(Session session, File file) async {
    final value = jsonDecode(await file.readAsString());
    if (value is! List || value.length != 2) {
      throw StateError('Exactly two private accounts are required.');
    }
    final accounts = value.indexed.map((item) {
      final (index, entry) = item;
      if (entry is! Map) throw const FormatException('Invalid account file.');
      final email = (entry['email'] as String).trim().toLowerCase();
      final login = entry['login'] as String? ?? '${index + 1}';
      final password = entry['password'] as String;
      final nickname = Players.normalizeNickname(entry['nickname'] as String);
      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
          !{'1', '2'}.contains(login) ||
          password.length < 8 ||
          password.length > 128) {
        throw const FormatException(
          'Private accounts require login 1 or 2, an email and an 8–128 character password.',
        );
      }
      return (
        email: email,
        login: login,
        password: password,
        nickname: nickname,
      );
    }).toList();
    if (accounts.map((a) => a.email).toSet().length != 2 ||
        accounts.map((a) => a.login).toSet().length != 2) {
      throw StateError('Account emails and login names must differ.');
    }
    await session.db.transaction((transaction) async {
      await rows(
        session,
        'SELECT pg_advisory_xact_lock(7744112201)',
        transaction: transaction,
      );
      final existing = await rows(
        session,
        'SELECT email, login_name FROM gm_private_accounts',
        transaction: transaction,
      );
      final expected = accounts.map((a) => a.email).toSet();
      if (existing.any((a) => !expected.contains(a['email']))) {
        throw StateError(
          'The configured account list cannot replace existing identities.',
        );
      }
      for (final account in accounts) {
        final saved = existing
            .where((a) => a['email'] == account.email)
            .firstOrNull;
        if (saved != null) {
          if (saved['login_name'] != null &&
              saved['login_name'] != account.login) {
            throw StateError(
              'Provisioning cannot change an existing login name.',
            );
          }
          await execute(
            session,
            'UPDATE gm_private_accounts SET login_name=@login WHERE email=@email AND login_name IS NULL',
            params: {'login': account.login, 'email': account.email},
            transaction: transaction,
          );
          continue;
        }
        final idp = AuthServices.instance.emailIdp;
        if (await idp.admin.findAccount(
              session,
              email: account.email,
              transaction: transaction,
            ) !=
            null) {
          throw StateError(
            'Provisioning cannot take over an existing email account.',
          );
        }
        final user = await AuthServices.instance.authUsers.create(
          session,
          transaction: transaction,
        );
        await idp.admin.createEmailAuthentication(
          session,
          authUserId: user.id,
          email: account.email,
          password: account.password,
          transaction: transaction,
        );
        final id = const uuid.Uuid().v4();
        await execute(
          session,
          '''INSERT INTO gm_players(id,auth_user_id,nickname,is_guest)
             VALUES(@id,CAST(@auth AS uuid),@name,false)''',
          params: {
            'id': id,
            'auth': user.id.toString(),
            'name': account.nickname,
          },
          transaction: transaction,
        );
        await execute(
          session,
          'INSERT INTO gm_private_accounts(player_id,email,login_name) VALUES(@id,@email,@login)',
          params: {'id': id, 'email': account.email, 'login': account.login},
          transaction: transaction,
        );
      }
    });
  }

  static Future<void> resetPassword(
    Session session,
    String email,
    String password,
  ) async {
    if (password.length < 8 || password.length > 128) {
      throw StateError('Use an 8–128 character password.');
    }
    await session.db.transaction((transaction) async {
      final resolvedEmail = await resolveEmail(
        session,
        email,
        transaction: transaction,
      );
      final account = await rows(
        session,
        '''SELECT p.auth_user_id FROM gm_private_accounts a JOIN gm_players p ON p.id=a.player_id
           WHERE a.email=@email FOR UPDATE OF p''',
        params: {'email': resolvedEmail},
        transaction: transaction,
      );
      if (account.length != 1) throw StateError('Private account not found.');
      await AuthServices.instance.emailIdp.admin.setPassword(
        session,
        email: resolvedEmail,
        password: password,
        transaction: transaction,
      );
      await AuthServices.instance.tokenManager.revokeAllTokens(
        session,
        authUserId: UuidValue.fromString(
          account.single['auth_user_id'].toString(),
        ),
        transaction: transaction,
      );
    });
  }
}
