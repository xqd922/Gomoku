import 'dart:convert';

import 'package:serverpod/serverpod.dart';

/// Every deployment signs in with email accounts. The flags remain in the
/// payload so slightly older clients keep parsing the configuration.
final class AppConfigRoute extends Route {
  @override
  Future<Response> handleCall(Session session, Request request) async =>
      Response.ok(
        body: Body.fromString(
          jsonEncode({
            'authMode': 'email',
            'guestOnline': true,
            'registration': true,
            'passwordReset': true,
          }),
          mimeType: MimeType.json,
        ),
        headers: Headers.fromMap({
          'cache-control': ['no-store'],
        }),
      );
}
