import 'dart:io';

import 'package:yaml/yaml.dart';

/// Pins direct dependencies to the reviewed lockfile and uses canonical hosts.
void main() {
  final lockFile = File('pubspec.lock');
  final lock = loadYaml(lockFile.readAsStringSync()) as YamlMap;
  final packages = lock['packages'] as YamlMap;
  for (final path in [
    'pubspec.yaml',
    'packages/gomoku_core/pubspec.yaml',
    'packages/gomoku_client/pubspec.yaml',
    'apps/server/pubspec.yaml',
    'apps/gomoku_app/pubspec.yaml',
  ]) {
    final file = File(path);
    final pinned = file.readAsStringSync().replaceAllMapped(
      RegExp(r'^(  )([a-zA-Z_0-9]+): \^?([0-9][^\r\n]*)$', multiLine: true),
      (match) {
        final package = packages[match[2]];
        if (package is! YamlMap || package['source'] != 'hosted') {
          return match[0]!;
        }
        return '  ${match[2]}: ${package['version']}';
      },
    );
    file.writeAsStringSync(pinned);
  }
  lockFile.writeAsStringSync(
    lockFile.readAsStringSync().replaceAll(
      'https://pub.flutter-io.cn',
      'https://pub.dev',
    ),
  );
  stdout.writeln(
    'Pinned direct versions and normalized the lockfile package host.',
  );
}
