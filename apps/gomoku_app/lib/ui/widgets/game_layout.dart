import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../design/motion.dart';
import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../shell.dart';
import 'board.dart';
import 'common.dart';

/// Fits the playing surface using both axes. Text and controls never scale down.
class GameScaffold extends StatelessWidget {
  const GameScaffold({
    super.key,
    required this.title,
    required this.board,
    required this.status,
    required this.controls,
    this.details,
    this.actions = const [],
    this.fallback = '/',
  });
  final String title, fallback;
  final Widget board, status, controls;
  final Widget? details;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => SectionScaffold(
    title: title,
    actions: actions,
    fallback: fallback,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
        final sideBySide =
            width >= AppLayout.expanded ||
            (width >= AppLayout.compact && height < 480);
        if (sideBySide) {
          final inset = width >= 1000 ? 24.0 : 12.0;
          final panelWidth = width >= 1000 ? 320.0 : 260.0;
          final side = math.max(
            0.0,
            math.min(
              AppLayout.board,
              math.min(height - inset * 2, width - panelWidth - inset * 3),
            ),
          );
          return Padding(
            padding: EdgeInsets.all(inset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: SizedBox.square(dimension: side, child: board),
                  ),
                ),
                SizedBox(width: inset),
                SizedBox(
                  width: panelWidth,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        status,
                        const SizedBox(height: 20),
                        _AnimatedControls(child: controls),
                        if (details != null) ...[
                          const SizedBox(height: 24),
                          details!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, body) {
                  if (largeText || body.maxHeight < 380) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                            child: status,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: SizedBox.square(
                              dimension: math.min(width - 24, AppLayout.board),
                              child: board,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: status,
                      ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, boardArea) {
                            final side = math.max(
                              0.0,
                              math.min(
                                AppLayout.board,
                                math.min(width - 24, boardArea.maxHeight - 12),
                              ),
                            );
                            return Center(
                              child: SizedBox.square(
                                dimension: side,
                                child: board,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            ClipRSuperellipse(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppShape.card),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: _AnimatedControls(child: controls),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Grows and shrinks with the controls' state change so the board settles
/// instead of jumping. Reduce-motion renders without the wrapper entirely:
/// a zero-duration AnimatedSize completes synchronously inside layout.
class _AnimatedControls extends StatelessWidget {
  const _AnimatedControls({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final duration = AppMotion.duration(
      context,
      const Duration(milliseconds: 280),
    );
    if (duration <= Duration.zero) return child;
    return AnimatedSize(
      duration: duration,
      curve: AppCurves.decelerate,
      alignment: Alignment.topCenter,
      child: child,
    );
  }
}

class MoveControls extends StatelessWidget {
  const MoveControls({
    super.key,
    required this.interaction,
    this.undo,
    this.message,
  });
  final BoardInteractionController interaction;
  final Widget? undo;
  final String? message;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: interaction,
    builder: (context, _) {
      final s = context.strings;
      final point = interaction.selectedPoint;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: math.max(
              48,
              MediaQuery.textScalerOf(context).scale(14) * 1.5 + 8,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      interaction.submitting
                          ? s.t('placing')
                          : point == null
                          ? message ?? s.t('chooseMove')
                          : s.t('selectedPoint', {'point': pointName(point)}),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
                if (point != null)
                  IconButton(
                    tooltip: s.t('clearSelection'),
                    onPressed: interaction.submitting
                        ? null
                        : interaction.cancel,
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (undo != null) ...[undo!, const SizedBox(width: 8)],
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('confirm-move'),
                  onPressed: interaction.canConfirm
                      ? interaction.confirm
                      : null,
                  icon: interaction.submitting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(s.t('placeStone')),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class PlayerStrip extends StatelessWidget {
  const PlayerStrip({
    super.key,
    required this.blackName,
    required this.whiteName,
    required this.label,
    required this.moves,
    this.activeStone,
    this.blackOnline,
    this.whiteOnline,
  });
  final String blackName, whiteName, label;
  final int moves;
  final Stone? activeStone;
  final bool? blackOnline, whiteOnline;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget player(String name, Stone stone, bool? online) => Expanded(
      child: AnimatedContainer(
        duration: AppMotion.duration(context, AppMotion.mid),
        curve: AppCurves.emphasized,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.content,
          vertical: AppSpacing.tight,
        ),
        decoration: ShapeDecoration(
          color: activeStone == stone
              ? colors.secondaryContainer
              : colors.surfaceContainerLow,
          shape: AppShapes.card,
        ),
        child: Row(
          children: [
            StoneDisc(stone: stone, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Tooltip(
                excludeFromSemantics: true,
                message: name,
                child: Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ),
            if (online == false)
              Icon(
                Icons.wifi_off_rounded,
                size: 16,
                color: colors.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            player(blackName, Stone.black, blackOnline),
            const SizedBox(width: 8),
            player(whiteName, Stone.white, whiteOnline),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall
                      ?.copyWith(color: colors.primary),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.strings.t('moves', {'n': moves}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

final _celebratedGames = Provider<Set<String>>((ref) => {});

class ResultMoment extends ConsumerStatefulWidget {
  const ResultMoment({
    super.key,
    required this.gameId,
    required this.label,
    required this.child,
  });
  final String gameId, label;
  final Widget child;
  @override
  ConsumerState<ResultMoment> createState() => _ResultMomentState();
}

class _ResultMomentState extends ConsumerState<ResultMoment> {
  late final bool _animate = ref.read(_celebratedGames).add(widget.gameId);
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _animate ? .92 : 1, end: 1),
      duration: AppMotion.duration(context, AppMotion.settle),
      curve: AppCurves.settle,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.content),
        decoration: ShapeDecoration(
          color: colors.tertiaryContainer,
          shape: AppShapes.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                widget.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: colors.onTertiaryContainer),
              ),
            ),
            const SizedBox(height: AppSpacing.content),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class EndGameActions extends StatelessWidget {
  const EndGameActions({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onReplay,
  });
  final String primaryLabel;
  final VoidCallback? onPrimary, onReplay;
  @override
  Widget build(BuildContext context) {
    final primary = FilledButton(
      onPressed: onPrimary,
      child: Text(primaryLabel, textAlign: TextAlign.center),
    );
    final replay = OutlinedButton.icon(
      onPressed: onReplay,
      icon: const Icon(Icons.replay_rounded),
      label: Text(context.strings.t('replay')),
    );
    if (MediaQuery.textScalerOf(context).scale(16) > 24) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [primary, const SizedBox(height: 8), replay],
      );
    }
    return Row(
      children: [
        Expanded(child: primary),
        const SizedBox(width: 8),
        Expanded(child: replay),
      ],
    );
  }
}
