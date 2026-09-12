import 'dart:convert';

import 'package:serverpod/serverpod.dart';

import '../../services/app_config.dart';

final class AppConfigRoute extends Route {
  AppConfigRoute(this.config);
  final AppConfig config;

  @override
  Future<Response> handleCall(Session session, Request request) async =>
      Response.ok(
        body: Body.fromString(
          jsonEncode({
            'authMode': config.privateAccounts ? 'private' : 'email',
            'guestOnline': !config.privateAccounts,
            'registration': !config.privateAccounts,
            'passwordReset': !config.privateAccounts,
          }),
          mimeType: MimeType.json,
        ),
        headers: Headers.fromMap({
          'cache-control': ['no-store'],
        }),
      );
}
