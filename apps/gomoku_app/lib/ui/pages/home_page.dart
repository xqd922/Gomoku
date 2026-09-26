import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../kit/card.dart';
import '../kit/scaffold.dart';
import '../widgets/common.dart';

/// The play tab: a dashboard of cards — one loud start card plus status
/// tiles, in the FlClash dashboard idiom (fixed composition, responsive
/// columns).
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
    final games = ref.watch(gamesProvider).asData?.value ?? <GameRecord>[];
    final finished = games.where((r) => r.game.isOver).toList();
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
    final health = ref.watch(backendHealthProvider);
    final healthOk = health.asData?.value ?? false;
    final meta = active != null
        ? '${s.t('round', {'n': active.round})} · ${active.code}'
        : unfinished != null
        ? s.t('moves', {'n': unfinished.game.moves.length})
        : s.t('rules');
    return KitScaffold(
      title: s.t('play'),
      child: KitPageBody(
        scrollKey: const PageStorageKey('play-scroll'),
        children: [
          KitCard(
            radius: AppShape.feature,
            color: colors.primaryContainer,
            padding: EdgeInsets.all(
              MediaQuery.sizeOf(context).width >= AppLayout.compact
                  ? AppSpacing.page
                  : AppSpacing.section,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  s.t(resume ? 'resumeTitle' : 'homeTitle'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.tight),
                Text(
                  s.t(resume ? 'resumeCaption' : 'homeCaption'),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: AppSpacing.section),
                Wrap(
                  spacing: AppSpacing.content,
                  runSpacing: AppSpacing.content,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('start-game'),
                      onPressed: _starting
                          ? null
                          : () {
                              if (active != null) {
                                context.push('/room/${active.roomId}');
                              } else {
                                _local();
                              }
                            },
                      icon: AnimatedSwitcher(
                        duration: AppMotion.duration(context, AppMotion.fast),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: animation,
                            child: child,
                          ),
                        ),
                        child: Icon(
                          key: ValueKey(_starting),
                          _starting
                              ? Icons.hourglass_top_rounded
                              : Icons.play_arrow_rounded,
                        ),
                      ),
                      label: Text(s.t(primaryLabel)),
                    ),
                    Text(
                      meta,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1000 ? 4 : 2;
              final gap = AppSpacing.content;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) / columns;
              final tiles = <Widget>[
                if (resume)
                  _ShortcutCard(
                    title: s.t(
                      active != null ? 'returnRoom' : 'continueGame',
                    ),
                    subtitle: meta,
                    icon: Icons.schedule_rounded,
                    color: colors.tertiaryContainer,
                    foreground: colors.onTertiaryContainer,
                    onTap: () {
                      if (active != null) {
                        context.push('/room/${active.roomId}');
                      } else {
                        _local();
                      }
                    },
                  ),
                _ShortcutCard(
                  title: s.t('playOnline'),
                  subtitle: s.t('onlineShort'),
                  icon: Icons.people_alt_rounded,
                  color: colors.secondaryContainer,
                  foreground: colors.onSecondaryContainer,
                  onTap: () => context.go('/lobby'),
                ),
                _ShortcutCard(
                  title: s.t('localPlay'),
                  subtitle: s.t('localShort'),
                  icon: Icons.grid_4x4_rounded,
                  color: colors.surfaceContainerHigh,
                  foreground: colors.onSurface,
                  onTap: _starting ? null : _local,
                ),
                KitStatCard(
                  label: s.t('stats'),
                  value: '${finished.length}',
                  caption: s.t('gamesPlayed'),
                  icon: Icons.military_tech_rounded,
                  onTap: () => context.go('/history'),
                ),
                KitStatCard(
                  label: s.t('serviceStatus'),
                  value: s.t(healthOk ? 'online' : 'offline'),
                  caption: s.t(
                    healthOk ? 'connected' : 'connectionUnavailable',
                  ),
                  icon: healthOk ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  color: healthOk
                      ? colors.secondaryContainer
                      : colors.errorContainer,
                  onTap: () => ref.invalidate(backendHealthProvider),
                ),
              ];
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: width, height: 128, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A labelled tappable tile: icon well, title, subtitle, arrow — the name
/// merges for screen readers, matching the FlClash list-card pattern.
class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
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
  Widget build(BuildContext context) => KitCard(
    onTap: onTap,
    color: color,
    padding: const EdgeInsets.all(AppSpacing.content),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: ShapeDecoration(
            color: foreground.withValues(alpha: .12),
            shape: AppShapes.thumb,
          ),
          child: Icon(icon, size: 20, color: foreground),
        ),
        const SizedBox(width: AppSpacing.tight),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground.withValues(alpha: .8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.tight),
        Icon(Icons.arrow_forward_rounded, size: 18, color: foreground),
      ],
    ),
  );
}
