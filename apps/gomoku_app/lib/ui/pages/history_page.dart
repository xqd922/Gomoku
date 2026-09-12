import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import 'local_page.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  String _filter = 'all';
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final sync = ref.watch(syncProvider);
    final auth = ref.watch(authProvider);
    return PageFrame(
      children: [
        PageHeading(
          title: s.t('history'),
          subtitle: s.t('historySubtitle'),
          action: auth.profile != null && !auth.profile!.isGuest
              ? IconButton.filledTonal(
                  tooltip: s.t('sync'),
                  onPressed: sync.busy
                      ? null
                      : () => ref.read(syncProvider.notifier).sync(),
                  icon: Icon(
                    sync.busy
                        ? Icons.hourglass_top_rounded
                        : Icons.sync_rounded,
                  ),
                )
              : null,
        ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
        const SizedBox(height: 24),
        ref
            .watch(gamesProvider)
            .when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(s.error('storage_unavailable')),
              data: (all) {
                final records = all
                    .where(
                      (r) =>
                          r.game.isOver &&
                          (_filter == 'all' || r.source.name == _filter),
                    )
                    .toList();
                if (records.isEmpty) return const EmptyGames();
                return Column(
                  children: [
                    for (final record in records)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: RecordTile(record: record),
                      ),
                  ],
                );
              },
            ),
        if (sync.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              s.t('syncPending'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class ReplayPage extends ConsumerStatefulWidget {
  const ReplayPage({super.key, required this.recordId});
  final String recordId;
  @override
  ConsumerState<ReplayPage> createState() => _ReplayPageState();
}

class _ReplayPageState extends ConsumerState<ReplayPage> {
  int? _ply;
  Timer? _timer;
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    return ref
        .watch(recordProvider(widget.recordId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text(s.error('storage_unavailable'))),
          data: (record) {
            if (record == null) return Center(child: Text(s.t('noRecord')));
            final total = record.game.moves.length;
            final ply = (_ply ?? total).clamp(0, total);
            final playing = _timer?.isActive ?? false;
            final panel = Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      resultLabel(record.game, s),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      dateLabel(record.updatedAt, s),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 26),
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
                      onChanged: total == 0
                          ? null
                          : (value) => _set(value.round()),
                    ),
                    Wrap(
                      alignment: WrapAlignment.center,
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
                            playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
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
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/history'),
                      icon: const Icon(Icons.arrow_back_rounded),
                      label: Text(s.t('history')),
                    ),
                  ],
                ),
              ),
            );
            return PageFrame(
              maxWidth: 1080,
              children: [
                PageHeading(
                  title: s.t('replay'),
                  subtitle: s.t('replaySubtitle'),
                ),
                GameLayout(
                  board: GameBoard(
                    game: record.game.positionAt(ply),
                    settings: ref.watch(settingsProvider),
                    readOnly: true,
                  ),
                  panel: panel,
                ),
              ],
            );
          },
        );
  }
}
