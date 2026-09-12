import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';

class LocalPage extends ConsumerStatefulWidget {
  const LocalPage({super.key});
  @override
  ConsumerState<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends ConsumerState<LocalPage> {
  bool _starting = false;
  Object? _error;
  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      await ref.read(localGameProvider.notifier).start();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      _starting = false;
    }
  }

  Future<void> _restart() async {
    final game = ref.read(localGameProvider)?.game;
    final s = context.strings;
    if (game != null &&
        !game.isOver &&
        !await confirmAction(
          context,
          s.t('restartTitle'),
          s.t('restartBody'),
        )) {
      return;
    }
    try {
      await ref.read(localGameProvider.notifier).start(fresh: true);
    } catch (error) {
      if (mounted) showFailure(context, error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(localGameProvider);
    final s = context.strings;
    if (record == null) {
      if (_error != null) {
        return Center(
          child: FilledButton(
            onPressed: () {
              setState(() => _error = null);
              _start();
            },
            child: Text(s.t('retry')),
          ),
        );
      }
      if (!_starting) Future.microtask(_start);
      return const Center(child: CircularProgressIndicator());
    }
    final game = record.game;
    final colors = Theme.of(context).colorScheme;
    final status = game.isOver
        ? resultLabel(game, s)
        : s.t(game.turn == Stone.black ? 'blackTurn' : 'whiteTurn');
    final panel = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                StoneDisc(stone: game.result?.winner ?? game.turn, size: 38),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              s.t('moves', {'n': game.moves.length}),
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(),
            ),
            if (!game.isOver)
              OutlinedButton.icon(
                onPressed: game.canUndo
                    ? () async {
                        try {
                          await ref.read(localGameProvider.notifier).undo();
                        } catch (error) {
                          if (context.mounted) showFailure(context, error);
                        }
                      }
                    : null,
                icon: const Icon(Icons.undo_rounded),
                label: Text(s.t('undo')),
              ),
            if (game.isOver)
              FilledButton.icon(
                onPressed: () => context.go('/history/${record.id}'),
                icon: const Icon(Icons.replay_rounded),
                label: Text(s.t('replay')),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _restart,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(s.t('newGame')),
            ),
            const SizedBox(height: 24),
            Text(
              s.t('rulesBody'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.t('savedLocally'),
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    return PageFrame(
      maxWidth: 1080,
      children: [
        PageHeading(
          title: s.t('localMatch'),
          subtitle: s.t('rules'),
          action: StatusPill(
            label: status,
            icon: game.isOver ? Icons.emoji_events_outlined : Icons.circle,
          ),
        ),
        GameLayout(
          board: GameBoard(
            game: game,
            settings: ref.watch(settingsProvider),
            onMove: (row, col) =>
                ref.read(localGameProvider.notifier).play(row, col),
          ),
          panel: panel,
        ),
      ],
    );
  }
}

class GameLayout extends StatelessWidget {
  const GameLayout({super.key, required this.board, required this.panel});
  final Widget board, panel;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 800 ||
          MediaQuery.textScalerOf(context).scale(16) > 24) {
        return Column(children: [board, const SizedBox(height: 22), panel]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: board),
          const SizedBox(width: 28),
          SizedBox(width: 280, child: panel),
        ],
      );
    },
  );
}
