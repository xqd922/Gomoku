import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../widgets/common.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  bool _starting = false;
  Future<void> _local() async {
    if (_starting) return;
    setState(() => _starting = true);
    try {
      await ref.read(localGameProvider.notifier).start();
      if (mounted) context.push('/local');
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final records = ref.watch(gamesProvider);
    final games = records.asData?.value ?? <GameRecord>[];
    final recent = games.where((r) => r.game.isOver).take(3).toList();
    final unfinished = games
        .where((r) => !r.game.isOver && r.source == RecordSource.local)
        .firstOrNull;
    final live = ref.watch(onlineProvider).room;
    final active =
        ref.watch(activeRoomProvider).asData?.value ??
        (live != null &&
                [
                  RoomStatus.waiting,
                  RoomStatus.playing,
                  RoomStatus.paused,
                ].contains(live.status)
            ? live
            : null);
    final resume = active != null || unfinished != null;
    final primaryLabel = active != null
        ? 'returnRoom'
        : unfinished != null
        ? 'continueGame'
        : 'playTogether';
    return PageFrame(
      scrollKey: const PageStorageKey('play-scroll'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= AppLayout.compact;
            return Container(
              padding: EdgeInsets.all(wide ? 32 : 24),
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppShape.feature),
                  topRight: Radius.circular(wide ? 88 : 56),
                  bottomLeft: const Radius.circular(AppShape.feature),
                  bottomRight: const Radius.circular(AppShape.feature),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t(resume ? 'resumeTitle' : 'homeTitle'),
                              style:
                                  (wide
                                          ? Theme.of(context)
                                                .textTheme
                                                .displayLarge
                                          : Theme.of(context)
                                                .textTheme
                                                .displayMedium)
                                      ?.copyWith(color: colors.onPrimary),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              s.t(resume ? 'resumeCaption' : 'homeCaption'),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: colors.onPrimary),
                            ),
                          ],
                        ),
                      ),
                      if (wide) ...[
                        const SizedBox(width: 28),
                        ExcludeSemantics(
                          child: _PlayArtwork(color: colors.onPrimary),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 28),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton(
                        key: const ValueKey('start-game'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colors.onPrimary,
                          foregroundColor: colors.primary,
                          minimumSize: const Size(180, 64),
                          textStyle: Theme.of(context).textTheme.titleMedium,
                        ),
                        onPressed: _starting
                            ? null
                            : () {
                                if (active != null) {
                                  context.push('/room/${active.roomId}');
                                } else {
                                  _local();
                                }
                              },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _starting
                                  ? Icons.hourglass_top_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            const SizedBox(width: 10),
                            Flexible(child: Text(s.t(primaryLabel))),
                          ],
                        ),
                      ),
                      Text(
                        active != null
                            ? '${s.t('round', {'n': active.round})} · ${active.code}'
                            : unfinished != null
                            ? s.t('moves', {'n': unfinished.game.moves.length})
                            : s.t('rules'),
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: colors.onPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final friend = _PlayShortcut(
              title: s.t('playOnline'),
              subtitle: s.t('onlineShort'),
              icon: Icons.people_alt_outlined,
              color: colors.secondaryContainer,
              foreground: colors.onSecondaryContainer,
              onTap: () => context.push('/lobby'),
            );
            final local = _PlayShortcut(
              title: s.t(unfinished != null ? 'alsoLocal' : 'localPlay'),
              subtitle: s.t('localShort'),
              icon: Icons.grid_4x4_rounded,
              color: colors.tertiaryContainer,
              foreground: colors.onTertiaryContainer,
              onTap: _starting ? null : _local,
            );
            if (active == null && unfinished == null) return friend;
            if (constraints.maxWidth < AppLayout.compact) {
              return Column(
                children: [friend, const SizedBox(height: 12), local],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: friend),
                const SizedBox(width: 16),
                Expanded(child: local),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: Text(
                s.t('recentGames'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton(
              onPressed: () => context.go('/history'),
              child: Text(s.t('viewAll')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (records.hasError)
          InlineNotice(
            message: s.error('storage_unavailable'),
            error: true,
            action: TextButton(
              onPressed: () => ref.invalidate(gamesProvider),
              child: Text(s.t('retry')),
            ),
          )
        else if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              s.t('emptyHistoryBody'),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          )
        else
          for (final record in recent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: RecordTile(record: record),
            ),
      ],
    );
  }
}

class _PlayShortcut extends StatelessWidget {
  const _PlayShortcut({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.foreground,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final Color color, foreground;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(AppShape.card),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppShape.card),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.section),
        child: Row(
          children: [
            Icon(icon, size: 32, color: foreground),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium
                        ?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, color: foreground),
          ],
        ),
      ),
    ),
  );
}

class _PlayArtwork extends StatelessWidget {
  const _PlayArtwork({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 160,
    height: 124,
    child: Stack(
      children: [
        Positioned(
          left: 0,
          top: 0,
          child: Transform.rotate(
            angle: -.16,
            child: Container(
              width: 114,
              height: 114,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Center(
                child: StoneDisc(stone: Stone.black, size: 70),
              ),
            ),
          ),
        ),
        const Positioned(
          right: 0,
          bottom: 0,
          child: StoneDisc(stone: Stone.white, size: 74),
        ),
      ],
    ),
  );
}
