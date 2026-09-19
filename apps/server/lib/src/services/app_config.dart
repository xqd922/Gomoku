import 'dart:io';

final class AppConfig {
  AppConfig._(this.values);
  final Map<String, String> values;
  static late AppConfig current;

  String get version => get(
    'GOMOKU_VERSION',
    const String.fromEnvironment('GOMOKU_VERSION', defaultValue: '1.3.0'),
  );
  String get commit => get(
    'GOMOKU_COMMIT',
    const String.fromEnvironment('GOMOKU_COMMIT', defaultValue: 'development'),
  );

  factory AppConfig.load() {
    final result = <String, String>{};
    final file = File('../../.env');
    if (file.existsSync()) {
      for (final line in file.readAsLinesSync()) {
        final equals = line.indexOf('=');
        if (equals > 0 && !line.startsWith('#')) {
          result[line.substring(0, equals)] = line.substring(equals + 1);
        }
      }
    }
    result.addAll(Platform.environment);
    return AppConfig._(result);
  }

  String get(String key, [String fallback = '']) => values[key] ?? fallback;
  bool get cookieSecure => get('COOKIE_SECURE', 'true') == 'true';
  Set<String> get allowedOrigins => get(
    'ALLOWED_ORIGINS',
    'http://localhost:4280',
  ).split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
}
