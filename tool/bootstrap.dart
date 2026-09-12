import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Generates development secrets once. It never prints credential values.
void main() {
  if (!File('pubspec.yaml').existsSync() ||
      !Directory('apps/server/config').existsSync()) {
    stderr.writeln('Run this command from the Gomoku repository root.');
    exitCode = 1;
    return;
  }
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    final random = Random.secure();
    String secret() => base64Url
        .encode(List.generate(36, (_) => random.nextInt(256)))
        .replaceAll('=', '');
    envFile.writeAsStringSync(
      [
        '# Generated local development configuration. Never commit this file.',
        'DATABASE_PASSWORD=${secret()}',
        'REDIS_PASSWORD=${secret()}',
        'EMAIL_SECRET_PEPPER=${secret()}',
        'SESSION_SECRET_PEPPER=${secret()}',
        'SMTP_HOST=127.0.0.1',
        'SMTP_PORT=1025',
        'SMTP_FROM=hello@gomoku.local',
        'SMTP_USERNAME=',
        'SMTP_PASSWORD=',
        'SMTP_SSL=false',
        'PUBLIC_WEB_URL=http://localhost:4280',
        'ALLOWED_ORIGINS=http://localhost:4280',
        'COOKIE_SECURE=false',
        '',
      ].join('\n'),
    );
  }
  final values = <String, String>{};
  for (final line in envFile.readAsLinesSync()) {
    final split = line.indexOf('=');
    if (split > 0 && !line.startsWith('#')) {
      values[line.substring(0, split)] = line.substring(split + 1);
    }
  }
  for (final key in [
    'DATABASE_PASSWORD',
    'REDIS_PASSWORD',
    'EMAIL_SECRET_PEPPER',
    'SESSION_SECRET_PEPPER',
  ]) {
    if ((values[key]?.length ?? 0) < 24) {
      throw StateError('Missing or short local secret: $key');
    }
  }
  File('apps/server/config/passwords.yaml').writeAsStringSync('''
shared:
  database: '${values['DATABASE_PASSWORD']}'
  redis: '${values['REDIS_PASSWORD']}'
  emailSecretHashPepper: '${values['EMAIL_SECRET_PEPPER']}'
  serverSideSessionKeyHashPepper: '${values['SESSION_SECRET_PEPPER']}'
''');
  stdout.writeln('Local configuration is ready. Secrets were not printed.');
  stdout.writeln('Start services: docker compose up -d --wait');
  stdout.writeln(
    'On Windows with WSL: wsl -d Ubuntu-22.04 -u root -- docker compose up -d --wait',
  );
}
