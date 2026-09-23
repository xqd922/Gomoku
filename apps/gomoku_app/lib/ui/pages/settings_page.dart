import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/settings.dart';
import '../widgets/common.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    final dynamicSupported = DesignCapabilities.supportsDynamicColor(context);
    Future<void> update(AppSettings value) async {
      try {
        await ref.read(settingsProvider.notifier).update(value);
      } catch (error) {
        if (context.mounted) showFailure(context, error);
      }
    }

    return PageFrame(
      maxWidth: AppLayout.reading,
      scrollKey: const PageStorageKey('settings-scroll'),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.section),
          decoration: BoxDecoration(
            color: colors.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppShape.feature),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.t('colorPreview'),
                style: Theme.of(context).textTheme.headlineMedium
                    ?.copyWith(color: colors.onTertiaryContainer),
              ),
              const SizedBox(height: 10),
              Text(
                s.t('preferencesCaption'),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
              const SizedBox(height: AppSpacing.section),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final (key, seed) in [
                    ('iris', 0xff7560c7),
                    ('sage', 0xff526e57),
                    ('peach', 0xffa45439),
                    ('ocean', 0xff376a91),
                  ])
                    Tooltip(
                      excludeFromSemantics: true,
                      message: s.t(key),
                      child: Semantics(
                        button: true,
                        selected:
                            !(settings.dynamicColor && dynamicSupported) &&
                            settings.seed == seed,
                        label: s.t(key),
                        child: InkResponse(
                          onTap: () => update(
                            settings.copyWith(seed: seed, dynamicColor: false),
                          ),
                          radius: 30,
                          child: AnimatedContainer(
                            duration: AppMotion.duration(
                              context,
                              AppMotion.feedback,
                            ),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: Color(seed),
                              borderRadius: BorderRadius.circular(
                                AppShape.card,
                              ),
                            ),
                            child:
                                settings.seed == seed &&
                                    !(settings.dynamicColor && dynamicSupported)
                                ? Center(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        shape: BoxShape.circle,
                                      ),
                                      child: SizedBox.square(
                                        dimension: 28,
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 18,
                                          color: colors.primary,
                                        ),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (settings.dynamicColor && dynamicSupported) ...[
                const SizedBox(height: AppSpacing.content),
                Text(s.t('colorFromSystem')),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        SettingsGroup(
          title: s.t('appearanceSection'),
          children: [
            ListTile(
              leading: const Icon(Icons.contrast_rounded),
              title: Text(s.t('theme')),
              subtitle: Text(s.t(settings.theme.name)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final value = await showChoice<ThemeMode>(
                  context,
                  title: s.t('theme'),
                  value: settings.theme,
                  choices: [
                    for (final mode in ThemeMode.values) (mode, s.t(mode.name)),
                  ],
                );
                if (value != null && context.mounted) {
                  await update(
                    ref.read(settingsProvider).copyWith(theme: value),
                  );
                }
              },
            ),
            if (dynamicSupported)
              SwitchListTile(
                secondary: const Icon(Icons.palette_outlined),
                title: Text(s.t('dynamicColor')),
                subtitle: Text(s.t('dynamicColorBody')),
                value: settings.dynamicColor,
                onChanged: (value) =>
                    update(settings.copyWith(dynamicColor: value)),
              ),
          ],
        ),
        const SizedBox(height: 24),
        const PlayingPreferences(),
        const SizedBox(height: 24),
        SettingsGroup(
          title: s.t('accessibilitySection'),
          children: [
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(s.t('language')),
              subtitle: Text(s.t(settings.language)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final value = await showChoice<String>(
                  context,
                  title: s.t('language'),
                  value: settings.language,
                  choices: [
                    for (final language in ['system', 'zh', 'en'])
                      (language, s.t(language)),
                  ],
                );
                if (value != null && context.mounted) {
                  await update(
                    ref.read(settingsProvider).copyWith(language: value),
                  );
                }
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.animation_rounded),
              title: Text(s.t('reduceMotion')),
              subtitle: Text(s.t('reduceMotionBody')),
              value: settings.reduceMotion,
              onChanged: (value) =>
                  update(settings.copyWith(reduceMotion: value)),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          s.t('aboutBody'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}

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
