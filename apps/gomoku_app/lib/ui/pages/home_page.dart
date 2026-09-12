import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/online.dart';
import '../widgets/brand.dart';
import '../widgets/common.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _code = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _local() async {
    try {
      await ref.read(localGameProvider.notifier).start();
      if (mounted) context.go('/local');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  Future<void> _join() async {
    try {
      final room = await ref.read(onlineProvider.notifier).join(_code.text);
      if (mounted) context.go('/room/${room.roomId}');
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    final games = ref.watch(gamesProvider).asData?.value ?? <GameRecord>[];
    final recent = games.where((r) => r.game.isOver).take(3).toList();
    final unfinished = games
        .where((r) => !r.game.isOver && r.source == RecordSource.local)
        .firstOrNull;
    final active = ref.watch(activeRoomProvider).asData?.value;
    final busy = ref.watch(onlineProvider).busy;
    return PageFrame(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 700;
            return Container(
              padding: EdgeInsets.all(wide ? 40 : 26),
              decoration: BoxDecoration(
                color: colors.primaryContainer.withValues(alpha: .55),
                borderRadius: BorderRadius.circular(wide ? 40 : 32),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.t('heroTag'),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                                letterSpacing: s.isZh ? 1 : 1.7,
                              ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          s.t('heroTitle'),
                          style:
                              (wide
                                      ? Theme.of(context)
                                            .textTheme
                                            .displayMedium
                                      : Theme.of(context)
                                            .textTheme
                                            .displaySmall)
                                  ?.copyWith(color: colors.onPrimaryContainer),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          s.t('heroBody'),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onPrimaryContainer.withValues(
                                  alpha: .73,
                                ),
                                height: 1.9,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (wide) ...[
                    const SizedBox(width: 20),
                    HeroBoard(size: constraints.maxWidth > 1000 ? 300 : 250),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        LayoutBuilder(
          builder: (context, constraints) {
            final friend = _ModeCard(
              title: s.t('friendPlay'),
              subtitle: s.t('friendBody'),
              label: s.t('createRoom'),
              icon: Icons.people_alt_rounded,
              background: colors.secondaryContainer,
              foreground: colors.onSecondaryContainer,
              onTap: () => context.go('/lobby'),
            );
            final local = _ModeCard(
              title: s.t('localPlay'),
              subtitle: s.t('localBody'),
              label: s.t('startPlaying'),
              icon: Icons.grid_4x4_rounded,
              background: colors.tertiaryContainer.withValues(alpha: .75),
              foreground: colors.onTertiaryContainer,
              onTap: _local,
            );
            if (constraints.maxWidth < 560) {
              return Column(
                children: [friend, const SizedBox(height: 14), local],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: friend),
                const SizedBox(width: 20),
                Expanded(child: local),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final field = TextField(
                key: const ValueKey('home-room-code'),
                controller: _code,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: s.t('roomCode'),
                  counterText: '',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  fillColor: colors.surface,
                ),
                onSubmitted: (_) => _join(),
              );
              final button = FilledButton.tonal(
                onPressed: busy ? null : _join,
                child: Text(s.t('join')),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.t('haveCode'),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: field),
                        const SizedBox(width: 10),
                        button,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  const SizedBox(width: 6),
                  Icon(Icons.link_rounded, color: colors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.t('haveCode'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  SizedBox(width: 240, child: field),
                  const SizedBox(width: 12),
                  button,
                ],
              );
            },
          ),
        ),
        if (unfinished != null || active != null) ...[
          const SizedBox(height: 22),
          Material(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: active != null
                  ? () {
                      ref.read(onlineProvider.notifier).enter(active);
                      context.go('/room/${active.roomId}');
                    }
                  : _local,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(
                      Icons.play_circle_outline_rounded,
                      size: 28,
                      color: colors.onPrimaryContainer,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        s.t('unfinished'),
                        style: Theme.of(context).textTheme.titleSmall
                            ?.copyWith(color: colors.onPrimaryContainer),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 34),
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
        if (recent.isEmpty) const EmptyGames(),
        for (final record in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RecordTile(record: record),
          ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                s.t('rulesTitle'),
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

class _ModeCard extends StatefulWidget {
  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
  });
  final String title, subtitle, label;
  final IconData icon;
  final Color background, foreground;
  final VoidCallback onTap;
  @override
  State<_ModeCard> createState() => _ModeCardState();
}

class _ModeCardState extends State<_ModeCard> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 200),
      transform: Matrix4.translationValues(0, _hover ? -3 : 0, 0),
      child: Material(
        color: widget.background,
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: widget.onTap,
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widget.foreground.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.foreground,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.foreground.withValues(alpha: .08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_outward_rounded,
                        size: 22,
                        color: widget.foreground,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineSmall
                      ?.copyWith(color: widget.foreground),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: widget.foreground.withValues(alpha: .75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
