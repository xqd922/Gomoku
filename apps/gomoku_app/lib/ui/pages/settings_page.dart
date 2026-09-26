import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/settings.dart';
import '../widgets/common.dart';

/// The playing-preferences group is shared by the Me tab and the in-game
/// settings sheet.
class PlayingPreferences extends ConsumerWidget {
  const PlayingPreferences({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    return SettingsGroup(
      title: s.t('playingSection'),
      children: [
        for (final (key, subtitle, icon, value, apply)
            in <(String, String?, IconData, bool, AppSettings Function(bool))>[
              (
                'confirmTouch',
                'confirmTouchBody',
                Icons.touch_app_outlined,
                settings.confirmTouch,
                (v) => settings.copyWith(confirmTouch: v),
              ),
              (
                'moveNumbers',
                null,
                Icons.format_list_numbered_rounded,
                settings.moveNumbers,
                (v) => settings.copyWith(moveNumbers: v),
              ),
              (
                'sound',
                null,
                Icons.volume_up_outlined,
                settings.sound,
                (v) => settings.copyWith(sound: v),
              ),
              if (DesignCapabilities.supportsHaptics)
                (
                  'haptics',
                  null,
                  Icons.vibration_rounded,
                  settings.haptics,
                  (v) => settings.copyWith(haptics: v),
                ),
            ])
          SwitchListTile(
            secondary: Icon(icon),
            title: Text(s.t(key)),
            subtitle: subtitle == null ? null : Text(s.t(subtitle)),
            value: value,
            onChanged: (v) async {
              try {
                await ref.read(settingsProvider.notifier).update(apply(v));
              } catch (error) {
                if (context.mounted) showFailure(context, error);
              }
            },
          ),
      ],
    );
  }
}

Future<void> showGameSettings(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: AppLayout.reading),
      builder: (context) => const SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: PlayingPreferences(),
        ),
      ),
    );
