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
import '../widgets/common.dart';
import '../widgets/enter.dart';
import '../widgets/press.dart';

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
        StaggeredEnter(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= AppLayout.compact;
              return Container(
                padding: EdgeInsets.all(
                  wide ? AppSpacing.page : AppSpacing.section,
                ),
                decoration: ShapeDecoration(
                  color: colors.primaryContainer,
                  shape: AppShapes.feature,
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
                                                  .headlineLarge
                                            : Theme.of(context)
                                                  .textTheme
                                                  .headlineMedium)
                                        ?.copyWith(
                                          color: colors.onPrimaryContainer,
                                        ),
                              ),
                              const SizedBox(height: AppSpacing.tight),
                              Text(
                                s.t(resume ? 'resumeCaption' : 'homeCaption'),
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: colors.onPrimaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        if (wide) ...[
                          const SizedBox(width: AppSpacing.section),
                          const ExcludeSemantics(child: _PlayArtwork()),
                        ],
                      ],
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
                            duration: AppMotion.duration(
                              context,
                              AppMotion.fast,
                            ),
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
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
                          active != null
                              ? '${s.t('round', {'n': active.round})} · ${active.code}'
                              : unfinished != null
                              ? s.t('moves', {
                                  'n': unfinished.game.moves.length,
                                })
                              : s.t('rules'),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: colors.onPrimaryContainer),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.content),
        LayoutBuilder(
          builder: (context, constraints) {
            final friend = StaggeredEnter(
              delay: enterStagger(1),
              child: _PlayShortcut(
                title: s.t('playOnline'),
                subtitle: s.t('onlineShort'),
                icon: Icons.people_alt_outlined,
                color: colors.secondaryContainer,
                foreground: colors.onSecondaryContainer,
                onTap: () => context.go('/lobby'),
              ),
            );
            final local = StaggeredEnter(
              delay: enterStagger(2),
              child: _PlayShortcut(
                title: s.t(unfinished != null ? 'alsoLocal' : 'localPlay'),
                subtitle: s.t('localShort'),
                icon: Icons.grid_4x4_rounded,
                color: colors.tertiaryContainer,
                foreground: colors.onTertiaryContainer,
                onTap: _starting ? null : _local,
              ),
            );
            if (active == null && unfinished == null) return friend;
            if (constraints.maxWidth < AppLayout.compact) {
              return Column(
                children: [
                  friend,
                  const SizedBox(height: AppSpacing.content),
                  local,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: friend),
                const SizedBox(width: AppSpacing.content),
                Expanded(child: local),
              ],
            );
          },
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
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Material(
      color: color,
      shape: AppShapes.card,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.section),
          child: Row(
            children: [
              ClipRSuperellipse(
                borderRadius: BorderRadius.circular(AppShape.field),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: .12),
                  ),
                  child: SizedBox.square(
                    dimension: 48,
                    child: Icon(icon, color: foreground),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.content),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(color: foreground),
                    ),
                    const SizedBox(height: AppSpacing.tight),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.tight),
              Icon(Icons.arrow_forward_rounded, color: foreground),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PlayArtwork extends StatelessWidget {
  const _PlayArtwork();
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
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(AppShape.feature),
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
