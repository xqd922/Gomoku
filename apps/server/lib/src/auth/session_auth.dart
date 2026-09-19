import 'dart:io';

import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';

import '../generated/protocol.dart';
import '../services/app_config.dart';
import '../services/database.dart';

String? header(Request? request, String name) =>
    request?.headers[name]?.firstOrNull;

String clientAddress(Request request, AppConfig config) {
  // Only enable this behind our proxy, which overwrites X-Real-IP.
  if (config.get('TRUST_PROXY') == 'true') {
    final forwarded = InternetAddress.tryParse(
      header(request, 'x-real-ip') ?? '',
    );
    if (forwarded != null) return forwarded.address;
  }
  return request.connectionInfo.remote.address.toString();
}

String cookieName(AppConfig config) =>
    config.cookieSecure ? '__Host-gomoku_session' : 'gomoku_session';

String? readSessionCookie(Request? request, AppConfig config) {
  final cookies = request?.headers['cookie']?.join(';') ?? '';
  for (final pair in cookies.split(';')) {
    final split = pair.indexOf('=');
    if (split > 0 && pair.substring(0, split).trim() == cookieName(config)) {
      try {
        return Uri.decodeComponent(pair.substring(split + 1).trim());
      } on FormatException {
        return null;
      }
    }
  }
  return null;
}

void verifyOrigin(Request? request, AppConfig config, {bool required = false}) {
  final origin = header(request, 'origin');
  if ((required && origin == null) ||
      (origin != null && !config.allowedOrigins.contains(origin))) {
    throw AppException(code: 'origin_rejected');
  }
}

Future<AuthenticationInfo?> authenticateSession(
  Session session,
  String credential,
  AppConfig config,
) async {
  await waitForApplicationDatabase();
  var token = credential;
  if (token.startsWith('Bearer ')) token = token.substring(7);
  if (token == 'web-session') {
    verifyOrigin(session.request, config, required: true);
    final cookie = readSessionCookie(session.request, config);
    if (cookie == null) return null;
    token = cookie;
  } else {
    // Browsers may never use a native bearer token to bypass origin checks.
    verifyOrigin(session.request, config);
  }
  final auth = await AuthServices.instance.authenticationHandler(
    session,
    token,
  );
  return auth;
}
