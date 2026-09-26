import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../design/tokens.dart';
import '../../l10n/strings.dart';

import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../kit/card.dart';
import '../kit/scaffold.dart';
import '../kit/states.dart';
import '../shell.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../widgets/game_layout.dart';

/// The library tab: floating toolbar with in-bar search, filter chips, and
/// date-grouped record cards.
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _filter = 'all';
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final sync = ref.watch(syncProvider);
    final auth = ref.watch(authProvider);
    final games = ref.watch(gamesProvider);
    final signedIn = auth.profile != null && !auth.profile!.isGuest;
    final query = _query.toLowerCase();
    final records =
        (games.asData?.value ?? <GameRecord>[])
            .where(
              (r) =>
                  r.game.isOver &&
                  (_filter == 'all' || r.source.name == _filter) &&
                  (query.isEmpty ||
                      r.blackName.toLowerCase().contains(query) ||
                      r.whiteName.toLowerCase().contains(query) ||
                      resultLabel(r.game, s).toLowerCase().contains(query)),
            )
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final entries = <Object>[];
    String? previousDay;
    for (final record in records) {
      final day = dateLabel(record.updatedAt, s);
      if (previousDay != day) {
        entries.add(day);
        previousDay = day;
      }
      entries.add(record);
    }
    final inset = AppLayout.pageInset(MediaQuery.sizeOf(context).width);
    return KitScaffold(
      title: s.t('history'),
      searchable: true,
      searchHint: s.t('searchGamesHint'),
      onSearch: (value) => setState(() => _query = value),
      actions: [
        if (signedIn)
          KitToolbarAction(
            icon: sync.busy ? Icons.hourglass_top_rounded : Icons.sync_rounded,
            tooltip: s.t('sync'),
            onPressed: sync.busy
                ? null
                : () => ref.read(syncProvider.notifier).sync(),
          ),
      ],
      child: CustomScrollView(
        key: const PageStorageKey('library-scroll'),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              inset,
              AppSpacing.content,
              inset,
              AppSpacing.tight,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.t('libraryTitle'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.tight),
                  Text(
                    s.t(
                      !signedIn
                          ? 'guestLocal'
                          : sync.busy
                          ? 'syncing'
                          : sync.error == null && sync.lastSuccess != null
                          ? 'synced'
                          : 'syncPending',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.content),
                  Wrap(
                    spacing: AppSpacing.tight,
                    runSpacing: AppSpacing.tight,
                    children: [
                      for (final (value, label) in [
                        ('all', 'allGames'),
                        ('local', 'localGames'),
                        ('online', 'onlineGames'),
                      ])
                        ChoiceChip(
                          label: Text(s.t(label)),
                          selected: _filter == value,
                          onSelected: (_) => setState(() => _filter = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.content),
                  if (signedIn && sync.error != null) ...[
                    KitNotice(
                      message: s.error(sync.error!),
                      error: true,
                      action: TextButton(
                        onPressed: sync.busy
                            ? null
                            : () => ref.read(syncProvider.notifier).sync(),
                        child: Text(s.t('retry')),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.tight),
                  ],
                  if (games.hasError)
                    KitNotice(
                      message: s.error('storage_unavailable'),
                      error: true,
                      action: TextButton(
                        onPressed: () => ref.invalidate(gamesProvider),
                        child: Text(s.t('retry')),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(inset, 0, inset, AppSpacing.page),
            sliver: games.isLoading
                ? SliverToBoxAdapter(
                    child: Column(
                      children: [
                        for (var i = 0; i < 3; i++) ...[
                          if (i > 0) const SizedBox(height: AppSpacing.tight),
                          const KitSkeleton(height: 84, radius: AppShape.menu),
                        ],
                      ],
                    ),
                  )
                : SliverList.builder(
                    itemCount: records.isEmpty ? 1 : entries.length,
                    itemBuilder: (context, index) {
                      if (records.isEmpty) {
                        return _filter == 'all' || query.isNotEmpty
                            ? KitEmptyState(
                                title: s.t(
                                  query.isNotEmpty || _filter != 'all'
                                      ? 'noFilterResult'
                                      : 'libraryEmpty',
                                ),
                                body: query.isNotEmpty || _filter != 'all'
                                    ? null
                                    : s.t('emptyHistoryBody'),
                                icon: Icons.menu_book_outlined,
                                action: FilledButton.tonalIcon(
                                  onPressed: () => context.go('/'),
                                  icon: const Icon(Icons.add_rounded),
                                  label: Text(s.t('startPlaying')),
                                ),
                              )
                            : KitNotice(
                                message: s.t('filterEmpty'),
                                action: TextButton(
                                  onPressed: () =>
                                      setState(() => _filter = 'all'),
                                  child: Text(s.t('allGames')),
                                ),
                              );
                      }
                      final item = entries[index];
                      return frame(
                        item is String
                            ? Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpacing.tight,
                                  AppSpacing.section,
                                  AppSpacing.tight,
                                  AppSpacing.content,
                                ),
                                child: Text(
                                  item,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: colors.onSurfaceVariant,
                                      ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: RecordTile(record: item as GameRecord),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget frame(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 880),
      child: SizedBox(width: double.infinity, child: child),
    ),
  );
}

class ReplayPage extends ConsumerStatefulWidget {
  const ReplayPage({super.key, required this.recordId});
  final String recordId;
  @override
  ConsumerState<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends ConsumerState<ReplayPage>
    with WidgetsBindingObserver {
  final _boardKey = GlobalKey(debugLabel: 'replay-board');
  final _focus = FocusNode(debugLabel: 'replay-shortcuts');
  int? _ply;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && (_timer?.isActive ?? false)) {
      _timer?.cancel();
      if (mounted) setState(() {});
    }
  }

  @override
  void didUpdateWidget(ReplayPage old) {
    super.didUpdateWidget(old);
    if (old.recordId != widget.recordId) {
      _ply = null;
      _timer?.cancel();
    }
  }

  void _set(int value) {
    _timer?.cancel();
    setState(() => _ply = value);
  }

  void _auto(int total) {
    if (total == 0) return;
    if (_timer?.isActive ?? false) {
      _timer?.cancel();
      setState(() {});
      return;
    }
    setState(() {
      if ((_ply ?? total) >= total) _ply = 0;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _ply = (_ply ?? 0) + 1;
        if (_ply! >= total) timer.cancel();
      });
    });
  }

  KeyEventResult _key(KeyEvent event, int ply, int total) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _set((ply - 1).clamp(0, total));
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _set((ply + 1).clamp(0, total));
    } else if (key == LogicalKeyboardKey.home) {
      _set(0);
    } else if (key == LogicalKeyboardKey.end) {
      _set(total);
    } else if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      _auto(total);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final value = ref.watch(recordProvider(widget.recordId));
    final record = value.asData?.value;
    if (record == null) {
      return SectionScaffold(
        title: s.t('replay'),
        fallback: '/history',
        child: Center(
          child: value.isLoading
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    value.hasError
                        ? s.error('storage_unavailable')
                        : s.t('noRecord'),
                  ),
                ),
        ),
      );
    }
    final total = record.game.moves.length;
    final ply = (_ply ?? total).clamp(0, total);
    final playing = _timer?.isActive ?? false;
    return Focus(
      autofocus: true,
      focusNode: _focus,
      onKeyEvent: (_, event) => _key(event, ply, total),
      child: GameScaffold(
        title: s.t('replay'),
        fallback: '/history',
        board: GameBoard(
          key: _boardKey,
          game: record.game.positionAt(ply),
          settings: ref.watch(settingsProvider),
          readOnly: true,
        ),
        status: PlayerStrip(
          blackName: record.blackName,
          whiteName: record.whiteName,
          label: resultLabel(record.game, s),
          moves: total,
        ),
        controls: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.t('moveProgress', {'n': ply, 'total': total}),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Slider(
              value: ply.toDouble(),
              min: 0,
              max: total == 0 ? 1 : total.toDouble(),
              divisions: total == 0 ? null : total,
              semanticFormatterCallback: (value) =>
                  s.t('moveProgress', {'n': value.round(), 'total': total}),
              onChanged: total == 0 ? null : (value) => _set(value.round()),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                IconButton(
                  tooltip: s.t('firstMove'),
                  onPressed: ply > 0 ? () => _set(0) : null,
                  icon: const Icon(Icons.first_page_rounded),
                ),
                IconButton(
                  tooltip: s.t('previousMove'),
                  onPressed: ply > 0 ? () => _set(ply - 1) : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                IconButton.filled(
                  tooltip: s.t(playing ? 'pause' : 'autoPlay'),
                  onPressed: total > 0 ? () => _auto(total) : null,
                  icon: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  ),
                ),
                IconButton(
                  tooltip: s.t('nextMove'),
                  onPressed: ply < total ? () => _set(ply + 1) : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
                IconButton(
                  tooltip: s.t('lastMove'),
                  onPressed: ply < total ? () => _set(total) : null,
                  icon: const Icon(Icons.last_page_rounded),
                ),
              ],
            ),
          ],
        ),
        details: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              s.t('matchDetails'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.tight),
            Text(dateLabel(record.updatedAt, s)),
            const SizedBox(height: 8),
            Text(
              s.t(
                record.source == RecordSource.local
                    ? 'localMatch'
                    : 'friendMatch',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
