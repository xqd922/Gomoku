import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (ref) => throw StateError('Preferences must be initialized before runApp.'),
);

final class AppSettings {
  const AppSettings({
    this.theme = ThemeMode.system,
    this.seed = 0xff7560c7,
    this.dynamicColor = true,
    this.language = 'system',
    this.sound = true,
    this.haptics = true,
    this.confirmTouch = true,
    this.reduceMotion = false,
    this.moveNumbers = false,
  });
  final ThemeMode theme;
  final int seed;
  final bool dynamicColor;
  final String language;
  final bool sound;
  final bool haptics;
  final bool confirmTouch;
  final bool reduceMotion;
  final bool moveNumbers;

  AppSettings copyWith({
    ThemeMode? theme,
    int? seed,
    bool? dynamicColor,
    String? language,
    bool? sound,
    bool? haptics,
    bool? confirmTouch,
    bool? reduceMotion,
    bool? moveNumbers,
  }) => AppSettings(
    theme: theme ?? this.theme,
    seed: seed ?? this.seed,
    dynamicColor: dynamicColor ?? this.dynamicColor,
    language: language ?? this.language,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    confirmTouch: confirmTouch ?? this.confirmTouch,
    reduceMotion: reduceMotion ?? this.reduceMotion,
    moveNumbers: moveNumbers ?? this.moveNumbers,
  );
  Map<String, Object> toJson() => {
    'theme': theme.name,
    'seed': seed,
    'dynamicColor': dynamicColor,
    'language': language,
    'sound': sound,
    'haptics': haptics,
    'confirmTouch': confirmTouch,
    'reduceMotion': reduceMotion,
    'moveNumbers': moveNumbers,
  };
  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    theme:
        ThemeMode.values.where((v) => v.name == json['theme']).firstOrNull ??
        ThemeMode.system,
    seed: json['seed'] as int? ?? 0xff7560c7,
    dynamicColor: json['dynamicColor'] as bool? ?? true,
    language: json['language'] as String? ?? 'system',
    sound: json['sound'] as bool? ?? true,
    haptics: json['haptics'] as bool? ?? true,
    confirmTouch: json['confirmTouch'] as bool? ?? true,
    reduceMotion: json['reduceMotion'] as bool? ?? false,
    moveNumbers: json['moveNumbers'] as bool? ?? false,
  );
}

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final encoded = ref.read(preferencesProvider).getString('settings');
    if (encoded != null) {
      try {
        return AppSettings.fromJson(
          jsonDecode(encoded) as Map<String, dynamic>,
        );
      } catch (_) {
        /* Keep usable defaults when preferences are corrupt. */
      }
    }
    return const AppSettings();
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await ref
        .read(preferencesProvider)
        .setString('settings', jsonEncode(settings.toJson()));
  }
}
