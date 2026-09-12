import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/strings.dart';
import '../../state/settings.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final settings = ref.watch(settingsProvider);
    final colors = Theme.of(context).colorScheme;
    void update(AppSettings value) =>
        ref.read(settingsProvider.notifier).update(value);
    Widget section(String title, List<Widget> children) => Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
    return PageFrame(
      maxWidth: 860,
      children: [
        PageHeading(title: s.t('appearance'), subtitle: s.t('appearanceBody')),
        section(s.t('theme'), [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (mode, icon) in [
                (ThemeMode.system, Icons.brightness_auto_rounded),
                (ThemeMode.light, Icons.light_mode_outlined),
                (ThemeMode.dark, Icons.dark_mode_outlined),
              ])
                ChoiceChip(
                  label: Text(s.t(mode.name)),
                  avatar: Icon(icon, size: 18),
                  selected: settings.theme == mode,
                  onSelected: (_) => update(settings.copyWith(theme: mode)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(s.t('accent'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final (name, seed) in [
                ('iris', 0xff7560c7),
                ('sage', 0xff597759),
                ('peach', 0xffab6348),
                ('ocean', 0xff386c9b),
              ])
                Tooltip(
                  message: s.t(name),
                  child: Semantics(
                    label: s.t(name),
                    selected: settings.seed == seed,
                    button: true,
                    child: InkWell(
                      onTap: () => update(
                        settings.copyWith(seed: seed, dynamicColor: false),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Color(seed),
                          borderRadius: BorderRadius.circular(
                            settings.seed == seed ? 20 : 32,
                          ),
                          border: Border.all(
                            color: settings.seed == seed
                                ? colors.onSurface
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: settings.seed == seed
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.t('dynamicColor')),
            subtitle: Text(s.t('dynamicColorBody')),
            value: settings.dynamicColor,
            onChanged: (value) =>
                update(settings.copyWith(dynamicColor: value)),
          ),
        ]),
        const SizedBox(height: 20),
        section(s.t('language'), [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final language in ['system', 'zh', 'en'])
                ChoiceChip(
                  label: Text(s.t(language)),
                  selected: settings.language == language,
                  onSelected: (_) =>
                      update(settings.copyWith(language: language)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
            ],
          ),
        ]),
        const SizedBox(height: 20),
        section(s.t('playPreferences'), [
          for (final (key, subtitle, value, apply)
              in <(String, String?, bool, AppSettings Function(bool))>[
                (
                  'confirmTouch',
                  'confirmTouchBody',
                  settings.confirmTouch,
                  (v) => settings.copyWith(confirmTouch: v),
                ),
                (
                  'moveNumbers',
                  null,
                  settings.moveNumbers,
                  (v) => settings.copyWith(moveNumbers: v),
                ),
                (
                  'sound',
                  null,
                  settings.sound,
                  (v) => settings.copyWith(sound: v),
                ),
                (
                  'haptics',
                  null,
                  settings.haptics,
                  (v) => settings.copyWith(haptics: v),
                ),
                (
                  'reduceMotion',
                  'reduceMotionBody',
                  settings.reduceMotion,
                  (v) => settings.copyWith(reduceMotion: v),
                ),
              ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.t(key)),
              subtitle: subtitle == null ? null : Text(s.t(subtitle)),
              value: value,
              onChanged: (v) => update(apply(v)),
            ),
        ]),
        const SizedBox(height: 28),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BrandMark(size: 40),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                s.t('aboutBody'),
                style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
