import 'dart:convert';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import '../../auth/session_auth.dart';
import '../../generated/protocol.dart';
import '../../services/app_config.dart';
import '../../services/database.dart';
import '../../services/players.dart';
import '../../services/rate_limiter.dart';
import '../../services/private_accounts.dart';

/// The browser never receives a session secret in a JSON response.
/// The same provider services back native secure storage and web cookies.
final class AuthRoute extends Route {
  AuthRoute(this.config) : super(methods: {Method.post});
  final AppConfig config;

  @override
  Future<Response> handleCall(Session session, Request request) async {
    final isWeb =
        header(request, 'x-gomoku-client') == 'web' ||
        header(request, 'origin') != null ||
        header(request, 'sec-fetch-site') != null;
    try {
      verifyOrigin(request, config, required: isWeb);
      if (!applicationDatabaseReady) {
        throw AppException(code: 'service_unavailable');
      }
      if (!(header(request, 'content-type') ?? '').startsWith(
        'application/json',
      )) {
        return _json({'error': 'invalid_request'}, status: 415);
      }
      final body = jsonDecode(await request.readAsString(maxLength: 16384));
      if (body is! Map<String, dynamic>) {
        return _json({'error': 'invalid_request'}, status: 400);
      }
      final action = request.url.pathSegments.last;
      if (config.privateAccounts &&
          !{'session', 'login', 'logout'}.contains(action)) {
        throw AppException(code: 'feature_disabled');
      }
      final ip = clientAddress(request, config);
      await checkRateLimit(session, 'auth:$action:$ip', limit: 40);
      final oldToken = isWeb
          ? readSessionCookie(request, config)
          : _bearer(header(request, 'authorization'));
      final previous = oldToken == null
          ? null
          : await AuthServices.instance.authenticationHandler(
              session,
              oldToken,
            );
      final emailIdp = AuthServices.instance.emailIdp;
      final nickname = _string(body, 'nickname', fallback: 'Gomoku player');
      switch (action) {
        case 'session':
          if (previous == null) throw AppException(code: 'unauthenticated');
          await PrivateAccounts.requireAllowed(
            session,
            previous.userIdentifier,
          );
          final profile = await Players.forAuth(
            session,
            previous.userIdentifier,
          );
          return _json({'profile': profile.toJson()});
        case 'guest':
          if (previous != null) {
            final profile = await Players.forAuth(
              session,
              previous.userIdentifier,
            );
            return _json({
              'profile': profile.toJson(),
              if (!isWeb) 'token': oldToken,
            });
          }
          final guest = await Players.createGuest(session, nickname);
          return _signedIn(guest.auth, guest.profile, isWeb);
        case 'register/start':
        case 'register-start':
          final id = await emailIdp.startRegistration(
            session,
            email: _string(body, 'email'),
          );
          return _json({'requestId': id.toString()});
        case 'register-finish':
          final result = await session.db.transaction((transaction) async {
            await _preventIdentitySwitch(session, previous, transaction);
            final token = await emailIdp.verifyRegistrationCode(
              session,
              accountRequestId: UuidValue.fromString(
                _string(body, 'requestId'),
              ),
              verificationCode: _string(body, 'code'),
              transaction: transaction,
            );
            final auth = await emailIdp.finishRegistration(
              session,
              registrationToken: token,
              password: _string(body, 'password'),
              transaction: transaction,
            );
            final profile = await Players.claim(
              session,
              authenticated: auth,
              previous: previous,
              nickname: nickname,
              transaction: transaction,
            );
            return (auth: auth, profile: profile);
          });
          return _signedIn(result.auth, result.profile, isWeb);
        case 'login':
          final result = await session.db.transaction((transaction) async {
            await _preventIdentitySwitch(session, previous, transaction);
            final email = await PrivateAccounts.resolveEmail(
              session,
              _string(body, 'email'),
              transaction: transaction,
            );
            final auth = await emailIdp.login(
              session,
              email: email,
              password: _string(body, 'password'),
              transaction: transaction,
            );
            await PrivateAccounts.requireAllowed(
              session,
              auth.authUserId.toString(),
              transaction: transaction,
            );
            final profile = await Players.claim(
              session,
              authenticated: auth,
              previous: previous,
              nickname: nickname,
              transaction: transaction,
            );
            return (auth: auth, profile: profile);
          });
          return _signedIn(result.auth, result.profile, isWeb);
        case 'reset-start':
          final id = await emailIdp.startPasswordReset(
            session,
            email: _string(body, 'email'),
          );
          return _json({'requestId': id.toString()});
        case 'reset-finish':
          await session.db.transaction((transaction) async {
            final token = await emailIdp.verifyPasswordResetCode(
              session,
              passwordResetRequestId: UuidValue.fromString(
                _string(body, 'requestId'),
              ),
              verificationCode: _string(body, 'code'),
              transaction: transaction,
            );
            await emailIdp.finishPasswordReset(
              session,
              finishPasswordResetToken: token,
              newPassword: _string(body, 'password'),
              transaction: transaction,
            );
          });
          return _json({'ok': true});
        case 'logout':
          if (previous != null) {
            await session.db.transaction((transaction) async {
              final player = await Players.forAuth(
                session,
                previous.userIdentifier,
                transaction: transaction,
                lock: true,
              );
              await Players.requireNoActiveRoom(
                session,
                player.playerId,
                transaction: transaction,
              );
              await AuthServices.instance.tokenManager.revokeToken(
                session,
                tokenId: previous.authId,
                transaction: transaction,
              );
            });
          }
          return _json({
            'ok': true,
          }, cookie: isWeb ? _cookie('', clear: true) : null);
        default:
          return _json({'error': 'not_found'}, status: 404);
      }
    } on AppException catch (error) {
      final status = switch (error.code) {
        'unauthenticated' || 'invalid_credentials' => 401,
        'origin_rejected' => 403,
        'account_not_allowed' || 'feature_disabled' => 403,
        'rate_limited' => 429,
        'service_unavailable' => 503,
        _ => 400,
      };
      return _json({'error': error.code}, status: status);
    } on FormatException {
      return _json({'error': 'invalid_request'}, status: 400);
    } on EmailAccountLoginException {
      return _json({'error': 'invalid_credentials'}, status: 401);
    } on EmailAccountRequestException {
      return _json({'error': 'invalid_verification'}, status: 400);
    } on EmailAccountPasswordResetException {
      return _json({'error': 'invalid_verification'}, status: 400);
    } catch (error, stack) {
      session.log(
        'Authentication request failed: ${error.runtimeType}',
        level: LogLevel.error,
        stackTrace: stack,
      );
      return _json({'error': 'service_unavailable'}, status: 503);
    }
  }

  Future<void> _preventIdentitySwitch(
    Session session,
    AuthenticationInfo? previous,
    Transaction transaction,
  ) async {
    if (previous == null) return;
    final player = await Players.forAuth(
      session,
      previous.userIdentifier,
      transaction: transaction,
      lock: true,
    );
    await Players.requireNoActiveRoom(
      session,
      player.playerId,
      transaction: transaction,
    );
  }

  Response _signedIn(AuthSuccess auth, PlayerProfile profile, bool web) =>
      _json(
        {
          'profile': profile.toJson(),
          if (!web) 'token': auth.token,
          'expiresAt': auth.tokenExpiresAt?.toUtc().toIso8601String(),
        },
        cookie: web ? _cookie(auth.token) : null,
      );

  String _cookie(String token, {bool clear = false}) =>
      '${cookieName(config)}=${Uri.encodeComponent(token)}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${clear ? '0' : '2592000'}${config.cookieSecure ? '; Secure' : ''}';

  Response _json(
    Map<String, dynamic> value, {
    int status = 200,
    String? cookie,
  }) => Response(
    status,
    body: Body.fromString(jsonEncode(value), mimeType: MimeType.json),
    headers: Headers.fromMap({
      'cache-control': ['no-store'],
      'x-content-type-options': ['nosniff'],
      if (cookie != null) 'set-cookie': [cookie],
    }),
  );

  String _string(Map<String, dynamic> body, String key, {String? fallback}) {
    final value = body[key] ?? fallback;
    if (value is! String || value.length > 1024 || value.isEmpty) {
      throw AppException(code: 'invalid_request');
    }
    return value;
  }

  String? _bearer(String? value) =>
      value != null && value.startsWith('Bearer ') ? value.substring(7) : null;
}
