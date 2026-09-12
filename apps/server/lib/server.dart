import 'dart:async';
import 'dart:io';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:serverpod/serverpod.dart' hide Message;
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';

import 'src/auth/session_auth.dart';
import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';
import 'src/services/app_config.dart';
import 'src/services/database.dart';
import 'src/services/rooms.dart';
import 'src/web/routes/auth_route.dart';
import 'src/web/routes/health_route.dart';

Future<void> run(List<String> args) async {
  final config = AppConfig.load();
  final pod = Serverpod(args, Protocol(), Endpoints());
  if (pod.runMode == ServerpodRunMode.production && !config.cookieSecure) {
    throw StateError('Production requires COOKIE_SECURE=true and HTTPS.');
  }
  pod.initializeAuthServices(
    tokenManagerBuilders: [
      ServerSideSessionsConfigFromPasswords(
        defaultSessionLifetime: const Duration(days: 30),
        defaultSessionInactivityTimeout: const Duration(days: 7),
      ),
    ],
    identityProviderBuilders: [
      EmailIdpConfigFromPasswords(
        sendRegistrationVerificationCode: (
          session, {
          required email,
          required accountRequestId,
          required verificationCode,
          required transaction,
        }) => _sendCode(config, email, verificationCode, false),
        sendPasswordResetVerificationCode: (
          session, {
          required email,
          required passwordResetRequestId,
          required verificationCode,
          required transaction,
        }) => _sendCode(config, email, verificationCode, true),
      ),
    ],
  );
  pod.authenticationHandler = (session, token) =>
      authenticateSession(session, token, config);
  pod.webServer.addRoute(AuthRoute(config), '/auth/**');
  pod.webServer.addRoute(HealthRoute(), '/health');
  await pod.start();
  final migration = await pod.createSession(enableLogging: false);
  try {
    await migrateApplication(migration);
  } finally {
    await migration.close();
  }
  final timers = <Timer>[];
  var dispatching = false;
  var maintaining = false;
  timers.add(
    Timer.periodic(const Duration(milliseconds: 250), (_) async {
      if (dispatching) return;
      dispatching = true;
      final session = await pod.createSession(enableLogging: false);
      try {
        await Rooms.dispatchOutbox(session);
      } catch (error) {
        stderr.writeln('Outbox will retry: ${error.runtimeType}');
      } finally {
        await session.close();
        dispatching = false;
      }
    }),
  );
  timers.add(
    Timer.periodic(const Duration(seconds: 2), (_) async {
      if (maintaining) return;
      maintaining = true;
      final session = await pod.createSession(enableLogging: false);
      try {
        await Rooms.maintain(session);
      } catch (error) {
        stderr.writeln('Room maintenance will retry: ${error.runtimeType}');
      } finally {
        await session.close();
        maintaining = false;
      }
    }),
  );
  timers.add(
    Timer.periodic(const Duration(hours: 1), (_) async {
      final session = await pod.createSession(enableLogging: false);
      try {
        await execute(
          session,
          "DELETE FROM gm_rate_limits WHERE window_start < floor(extract(epoch from now()) / 60) - 1440",
        );
        await execute(
          session,
          "DELETE FROM gm_outbox WHERE delivered_at < now() - interval '7 days'",
        );
        await execute(
          session,
          "DELETE FROM gm_commands WHERE created_at < now() - interval '30 days'",
        );
        await execute(
          session,
          "DELETE FROM gm_presence WHERE expires_at < now() - interval '1 day'",
        );
      } finally {
        await session.close();
      }
    }),
  );
  stdout.writeln(
    'Gomoku is ready: persistent rooms, email authentication, and record sync.',
  );
  if (!Platform.isWindows) {
    ProcessSignal.sigterm.watch().listen((_) async {
      for (final timer in timers) {
        timer.cancel();
      }
      await pod.shutdown(exitProcess: false);
      exit(0);
    });
  }
}

Future<void> _sendCode(
  AppConfig config,
  String email,
  String code,
  bool reset,
) async {
  final ssl = config.get('SMTP_SSL', 'false') == 'true';
  final username = config.get('SMTP_USERNAME');
  final server = SmtpServer(
    config.get('SMTP_HOST', '127.0.0.1'),
    port: int.parse(config.get('SMTP_PORT', '1025')),
    username: username.isEmpty ? null : username,
    password: username.isEmpty ? null : config.get('SMTP_PASSWORD'),
    ssl: ssl,
    allowInsecure: !ssl && username.isEmpty,
  );
  final message = Message()
    ..from = Address(config.get('SMTP_FROM', 'hello@gomoku.local'), 'Gomoku')
    ..recipients.add(email)
    ..subject = reset
        ? 'Gomoku · 重置密码 / Reset password'
        : 'Gomoku · 验证邮箱 / Verify email'
    ..text =
        '你的验证码 / Your verification code:\n\n$code\n\n请回到 Gomoku 完成验证。请勿向他人提供此验证码。\nReturn to Gomoku to complete verification. Keep this code private.';
  await send(message, server);
}
