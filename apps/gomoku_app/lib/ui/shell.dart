import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'widgets/brand.dart';
import 'widgets/common.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;
  static const _paths = ['/', '/history', '/account', '/settings'];
  static const _icons = [
    Icons.grid_view_outlined,
    Icons.auto_stories_outlined,
    Icons.person_outline_rounded,
    Icons.tune_rounded,
  ];
  static const _selectedIcons = [
    Icons.grid_view_rounded,
    Icons.auto_stories_rounded,
    Icons.person_rounded,
    Icons.tune_rounded,
  ];
  static const _labels = ['play', 'history', 'account', 'settings'];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 720;
    final expanded = width >= 1200;
    final index = location.startsWith('/history')
        ? 1
        : location == '/account'
        ? 2
        : location == '/settings'
        ? 3
        : 0;
    final nested = location != _paths[index];
    final healthy = ref.watch(backendHealthProvider).asData?.value ?? false;
    final profile = ref.watch(authProvider).profile;
    final nav = NavigationRail(
      extended: expanded,
      minWidth: 88,
      minExtendedWidth: 212,
      selectedIndex: index,
      groupAlignment: -.75,
      labelType: expanded ? null : NavigationRailLabelType.all,
      onDestinationSelected: (i) => context.go(_paths[i]),
      leading: Padding(
        padding: EdgeInsets.fromLTRB(
          expanded ? 16 : 0,
          22,
          expanded ? 16 : 0,
          44,
        ),
        child: expanded
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: 12),
                  Text('Gomoku', style: Theme.of(context).textTheme.titleLarge),
                ],
              )
            : const BrandMark(size: 40),
      ),
      destinations: [
        for (var i = 0; i < _paths.length; i++)
          NavigationRailDestination(
            icon: Icon(_icons[i]),
            selectedIcon: Icon(_selectedIcons[i]),
            label: Text(s.t(_labels[i])),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
      ],
    );
    final content = Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(wide ? 36 : 16, 14, wide ? 36 : 16, 18),
          child: Row(
            children: [
              if (nested) ...[
                IconButton(
                  tooltip: s.t('back'),
                  onPressed: () => context.go(index == 1 ? '/history' : '/'),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 6),
              ] else if (!wide) ...[
                const BrandMark(size: 32),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  wide && !nested ? s.t('hello') : s.t(_labels[index]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style:
                      (wide
                              ? Theme.of(context).textTheme.titleSmall
                              : Theme.of(context).textTheme.titleLarge)
                          ?.copyWith(
                            color: wide
                                ? colors.onSurfaceVariant
                                : colors.onSurface,
                          ),
                ),
              ),
              if (width >= 960) ...[
                StatusPill(
                  label: s.t(healthy ? 'connected' : 'offlineAvailable'),
                  icon: healthy
                      ? Icons.cloud_done_outlined
                      : Icons.offline_bolt_outlined,
                  background: colors.surfaceContainerLow,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 16),
              ],
              IconButton.filledTonal(
                tooltip: profile?.nickname ?? s.t('account'),
                onPressed: () => context.go('/account'),
                icon: const Icon(Icons.person_outline_rounded),
              ),
            ],
          ),
        ),
        ValueListenableBuilder(
          valueListenable: browserStoragePersistent,
          builder: (context, persistent, _) => persistent
              ? const SizedBox.shrink()
              : Container(
                  width: double.infinity,
                  color: colors.errorContainer,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    s.t('storageWarning'),
                    style: TextStyle(color: colors.onErrorContainer),
                  ),
                ),
        ),
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            child: child,
          ),
        ),
      ],
    );
    return Scaffold(
      body: SafeArea(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(child: IntrinsicHeight(child: nav)),
                  VerticalDivider(
                    width: 1,
                    color: colors.outlineVariant.withValues(alpha: .45),
                  ),
                  Expanded(child: content),
                ],
              )
            : content,
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => context.go(_paths[i]),
              destinations: [
                for (var i = 0; i < _paths.length; i++)
                  NavigationDestination(
                    icon: Icon(_icons[i]),
                    selectedIcon: Icon(_selectedIcons[i]),
                    label: s.t(_labels[i]),
                  ),
              ],
            ),
    );
  }
}
