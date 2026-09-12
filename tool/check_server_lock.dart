import 'dart:io';

import 'package:yaml/yaml.dart';

/// The standalone server image must match the full workspace dependencies.
void main() {
  final root =
      loadYaml(File('pubspec.lock').readAsStringSync())['packages'] as YamlMap;
  final server =
      loadYaml(File('infra/server.pubspec.lock').readAsStringSync())['packages']
          as YamlMap;
  final mismatches = <String>[];
  var checked = 0;
  for (final entry in server.entries) {
    final package = entry.value as YamlMap;
    if (package['source'] != 'hosted') continue;
    checked++;
    final other = root[entry.key] as YamlMap?;
    if (other == null ||
        other['version'] != package['version'] ||
        other['source'] != package['source'] ||
        other['description']['sha256'] != package['description']['sha256'] ||
        other['description']['url'] != package['description']['url']) {
      mismatches.add(entry.key as String);
    }
  }
  if (mismatches.isNotEmpty) {
    stderr.writeln(
      'Server lock differs from the workspace: ${mismatches.join(', ')}',
    );
    stderr.writeln(
      'Regenerate infra/server.pubspec.lock using docs/DEPLOYMENT.md.',
    );
    exitCode = 1;
  } else {
    stdout.writeln('Server lock matches all $checked shared hosted packages.');
  }
}
