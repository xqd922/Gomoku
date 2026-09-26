import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../design/motion.dart';
import '../design/tokens.dart';
import '../l10n/strings.dart';
import '../state/settings.dart';
import 'widgets/brand.dart';

class _Destination {
  const _Destination(this.outline, this.filled, this.labelKey);
  final IconData outline, filled;
  final String labelKey;
}

const _destinations = [
  _Destination(
    Icons.sports_esports_outlined,
    Icons.sports_esports_rounded,
    'play',
  ),
  _Destination(
    Icons.people_alt_outlined,
    Icons.people_alt_rounded,
    'tabOnline',
  ),
  _Destination(Icons.menu_book_outlined, Icons.menu_book_rounded, 'history'),
  _Destination(Icons.person_outline_rounded, Icons.person_rounded, 'tabMe'),
];

/// Adaptive navigation: a bottom bar on compact screens, a side rail once the
/// window expands — the tabs themselves stay kept-alive in an IndexedStack.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;

  void _goBranch(BuildContext context, WidgetRef ref, int index) {
    if (ref.read(settingsProvider).haptics &&
        DesignCapabilities.supportsHaptics) {
      HapticFeedback.selectionClick();
    }
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.expanded;
    final index = navigationShell.currentIndex;
    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const StorageNotice(),
            Expanded(
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        NavigationRail(
                          selectedIndex: index,
                          onDestinationSelected: (value) =>
                              _goBranch(context, ref, value),
                          labelType: NavigationRailLabelType.all,
                          leading: const Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppSpacing.content,
                            ),
                            child: BrandMark(size: 30),
                          ),
                          destinations: [
                            for (final destination in _destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.outline),
                                selectedIcon: Icon(destination.filled),
                                label: Text(s.t(destination.labelKey)),
                              ),
                          ],
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(
                          child: _BranchEntrance(
                            index: index,
                            child: navigationShell,
                          ),
                        ),
                      ],
                    )
                  : _BranchEntrance(index: index, child: navigationShell),
            ),
          ],
        ),
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (value) => _goBranch(context, ref, value),
              destinations: [
                for (final destination in _destinations)
                  NavigationDestination(
                    icon: Icon(destination.outline),
                    selectedIcon: Icon(destination.filled),
                    label: s.t(destination.labelKey),
                  ),
              ],
            ),
    );
  }
}

/// The newly selected branch fades and slides in; the IndexedStack keeps
/// every branch alive underneath, so state survives the transition.
class _BranchEntrance extends StatefulWidget {
  const _BranchEntrance({required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<_BranchEntrance> createState() => _BranchEntranceState();
}

class _BranchEntranceState extends State<_BranchEntrance>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.mid,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _play();
  }

  @override
  void didUpdateWidget(_BranchEntrance old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) _play();
  }

  void _play() {
    if (AppMotion.duration(context, AppMotion.mid) == Duration.zero) {
      _entrance.value = 1;
      return;
    }
    _entrance.forward(from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _entrance,
    child: widget.child,
    builder: (context, child) {
      final t = AppCurves.decelerate.transform(_entrance.value);
      return Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 8),
          child: child,
        ),
      );
    },
  );
}

/// Secondary routes own their title and support direct deep-link entry.
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.fallback = '/',
    this.actions = const [],
  });
  final String title, fallback;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    void back() => context.canPop() ? context.pop() : context.go(fallback);
    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go(fallback);
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 56,
          leading: IconButton(
            tooltip: context.strings.t('back'),
            onPressed: back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [...actions, const SizedBox(width: 8)],
        ),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              const StorageNotice(),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class StorageNotice extends StatelessWidget {
  const StorageNotice({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: browserStoragePersistent,
    builder: (context, persistent, _) => persistent
        ? const SizedBox.shrink()
        : Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.errorContainer,
            padding: const EdgeInsets.all(AppSpacing.content),
            child: Text(
              context.strings.t('storageWarning'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
  );
}
