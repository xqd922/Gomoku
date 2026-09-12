import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:http/http.dart' as http;

import 'http_client.dart';

final class ApiFailure implements Exception {
  const ApiFailure(this.code);
  final String code;
  @override
  String toString() => code;
}

String errorCode(Object error) => switch (error) {
  ApiFailure(:final code) => code,
  AppException(:final code) => code,
  ServerpodClientUnauthorized() => 'unauthenticated',
  TimeoutException() => 'service_unavailable',
  _ => 'service_unavailable',
};

final class Api {
  Api() {
    client = Client(
      apiUrl,
      connectionTimeout: const Duration(seconds: 12),
      streamingConnectionTimeout: const Duration(seconds: 12),
    )..authKeyProvider = _KeyProvider(this);
  }

  static String get apiUrl =>
      const String.fromEnvironment('GOMOKU_API_URL').isNotEmpty
      ? const String.fromEnvironment('GOMOKU_API_URL')
      : kIsWeb
      ? '${Uri.base.origin}/api/'
      : 'http://127.0.0.1:8080/';
  static String get authUrl =>
      const String.fromEnvironment('GOMOKU_AUTH_URL').isNotEmpty
      ? const String.fromEnvironment('GOMOKU_AUTH_URL')
      : kIsWeb
      ? '${Uri.base.origin}/auth/'
      : 'http://127.0.0.1:8082/auth/';
  static String get webUrl =>
      const String.fromEnvironment('GOMOKU_WEB_URL').isNotEmpty
      ? const String.fromEnvironment('GOMOKU_WEB_URL')
      : kIsWeb
      ? Uri.base.origin
      : 'http://localhost:4280';

  final http.Client httpClient = createHttpClient();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Client client;
  String? token;
  Future<void>? _load;
  String get _storageKey => 'gomoku.session.${Uri.encodeComponent(apiUrl)}';

  Future<void> load() => _load ??= () async {
    if (!kIsWeb) token = await _storage.read(key: _storageKey);
  }();

  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await load();
    final response = await httpClient
        .post(
          Uri.parse(authUrl).resolve(action),
          headers: {
            'Content-Type': 'application/json',
            'X-Gomoku-Client': kIsWeb ? 'web' : 'native',
            if (!kIsWeb && token != null) 'Authorization': 'Bearer ${token!}',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final value = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw ApiFailure(value['error'] as String? ?? 'service_unavailable');
    }
    if (!kIsWeb && value['token'] is String) {
      token = value['token'] as String;
      await _storage.write(key: _storageKey, value: token);
    }
    return value;
  }

  Future<void> clearCredential() async {
    token = null;
    if (!kIsWeb) await _storage.delete(key: _storageKey);
  }

  Future<bool> healthy() async {
    try {
      final response = await httpClient
          .get(Uri.parse(authUrl).resolve('../health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void close() {
    client.close();
    httpClient.close();
  }
}

final class _KeyProvider implements ClientAuthKeyProvider {
  _KeyProvider(this.api);
  final Api api;
  @override
  Future<String?> get authHeaderValue async {
    await api.load();
    if (kIsWeb) return 'Bearer web-session';
    return api.token == null ? null : 'Bearer ${api.token!}';
  }
}
