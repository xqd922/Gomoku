import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/database.dart';
import '../design/tokens.dart';
import '../l10n/strings.dart';
import '../state/app_state.dart';
import 'widgets/brand.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.navigationShell});
  final StatefulNavigationShell navigationShell;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.navigationShell.currentIndex,
  );
  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabs.index != widget.navigationShell.currentIndex) {
      _tabs.index = widget.navigationShell.currentIndex;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final width = MediaQuery.sizeOf(context).width;
    final inset = AppLayout.pageInset(width);
    final tabHeight = math.max(
      48.0,
      MediaQuery.textScalerOf(context).scale(16) + 22,
    );
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 64,
        titleSpacing: inset,
        title: const Row(
          children: [
            BrandMark(size: 32),
            SizedBox(width: 10),
            Text('Gomoku'),
          ],
        ),
        actions: [
          const AccountMenuButton(),
          SizedBox(width: inset - 4),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(tabHeight),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: width >= AppLayout.compact ? 420 : width,
              ),
              child: TabBar(
                controller: _tabs,
                onTap: (index) => widget.navigationShell.goBranch(index),
                tabs: [
                  Tab(height: tabHeight, text: s.t('play')),
                  Tab(height: tabHeight, text: s.t('history')),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const StorageNotice(),
            Expanded(child: widget.navigationShell),
          ],
        ),
      ),
    );
  }
}

/// Secondary routes own their title and support direct deep-link entry.
class SectionScaffold extends StatelessWidget {
  const SectionScaffold({
    super.key,
    required this.title,
    required this.child,
    this.fallback = '/',
    this.actions = const [],
    this.compact = false,
  });
  final String title, fallback;
  final Widget child;
  final List<Widget> actions;
  final bool compact;
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
          toolbarHeight: compact ? 56 : 64,
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
            padding: const EdgeInsets.all(12),
            child: Text(
              context.strings.t('storageWarning'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
  );
}

class AccountMenuButton extends ConsumerWidget {
  const AccountMenuButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final profile = ref.watch(authProvider).profile;
    final identified = profile != null && !profile.isGuest;
    final avatar = Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: identified
            ? colors.tertiaryContainer
            : colors.surfaceContainerHighest,
        border: identified ? null : Border.all(color: colors.outlineVariant),
      ),
      child: ExcludeSemantics(
        child: !identified || profile.nickname.isEmpty
            ? Icon(
                Icons.person_outline_rounded,
                color: identified
                    ? colors.onTertiaryContainer
                    : colors.onSurfaceVariant,
              )
            : Text(
                profile.nickname.characters.first.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(color: colors.onTertiaryContainer),
              ),
      ),
    );
    void open(String path) {
      if (context.mounted) context.push(path);
    }

    if (MediaQuery.sizeOf(context).width >= AppLayout.compact) {
      return PopupMenuButton<String>(
        key: const ValueKey('profile-menu'),
        tooltip: s.t('profileMenu'),
        position: PopupMenuPosition.under,
        constraints: const BoxConstraints(minWidth: 300, maxWidth: 340),
        onSelected: open,
        itemBuilder: (_) => [
          const PopupMenuItem<String>(enabled: false, child: _AccountSummary()),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: '/account',
            child: _MenuLabel(Icons.person_outline_rounded, s.t('account')),
          ),
          PopupMenuItem(
            value: '/settings',
            child: _MenuLabel(Icons.settings_outlined, s.t('settings')),
          ),
        ],
        icon: avatar,
      );
    }
    return IconButton(
      key: const ValueKey('profile-menu'),
      tooltip: s.t('profileMenu'),
      icon: avatar,
      onPressed: () async {
        final path = await showModalBottomSheet<String>(
          context: context,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: _AccountSummary(),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.person_outline_rounded),
                    title: Text(s.t('account')),
                    onTap: () => Navigator.pop(sheetContext, '/account'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: Text(s.t('settings')),
                    onTap: () => Navigator.pop(sheetContext, '/settings'),
                  ),
                ],
              ),
            ),
          ),
        );
        if (path != null) open(path);
      },
    );
  }
}

class _AccountSummary extends ConsumerWidget {
  const _AccountSummary();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.strings;
    final profile = ref.watch(authProvider).profile;
    final sync = ref.watch(syncProvider);
    final guest = profile == null || profile.isGuest;
    final status = guest
        ? 'guestLocal'
        : sync.busy
        ? 'syncing'
        : sync.lastSuccess != null && sync.error == null
        ? 'synced'
        : 'syncPending';
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            profile?.nickname ?? s.t('guest'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            s.t(guest ? 'guest' : 'registeredPlayer'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 10),
          Text(
            s.t(status),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuLabel extends StatelessWidget {
  const _MenuLabel(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon),
      const SizedBox(width: 14),
      Expanded(child: Text(label)),
    ],
  );
}
