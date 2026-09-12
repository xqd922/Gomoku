import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../l10n/strings.dart';
import '../../state/app_state.dart';
import '../../state/settings.dart';
import '../shell.dart';
import '../widgets/board.dart';
import '../widgets/common.dart';
import '../widgets/game_layout.dart';
import 'settings_page.dart';

class LocalPage extends ConsumerStatefulWidget {
  const LocalPage({super.key});
  @override
  ConsumerState<LocalPage> createState() => _LocalPageState();
}

class _LocalPageState extends ConsumerState<LocalPage> {
  final _boardKey = GlobalKey(debugLabel: 'local-board');
  final _interaction = BoardInteractionController();
  bool _starting = false, _undoing = false;
  Object? _error;
  @override
  void dispose() {
    _interaction.dispose();
    super.dispose();
  }

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
    if (_starting || _undoing) return;
    final game = ref.read(localGameProvider)?.game;
    final s = context.strings;
    if (game != null &&
        !game.isOver &&
        game.moves.isNotEmpty &&
        !await confirmAction(
          context,
          s.t('restartTitle'),
          s.t('restartBody'),
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _starting = true);
    try {
      await ref.read(localGameProvider.notifier).start(fresh: true);
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _undo() async {
    if (_undoing || _starting) return;
    setState(() => _undoing = true);
    try {
      await ref.read(localGameProvider.notifier).undo();
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) setState(() => _undoing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final record = ref.watch(localGameProvider);
    final s = context.strings;
    if (record == null) {
      if (!_starting && _error == null) Future.microtask(_start);
      return SectionScaffold(
        title: s.t('localMatch'),
        compact: true,
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : FilledButton(
                  onPressed: () {
                    setState(() => _error = null);
                    _start();
                  },
                  child: Text(s.t('retry')),
                ),
        ),
      );
    }
    final game = record.game;
    final status = game.isOver
        ? s.t('finished')
        : s.t(game.turn == Stone.black ? 'blackTurn' : 'whiteTurn');
    return GameScaffold(
      title: s.t('localMatch'),
      actions: [
        PopupMenuButton<String>(
          tooltip: s.t('gameOptions'),
          onSelected: (action) async {
            if (action == 'new') await _restart();
            if (action == 'settings' && context.mounted) {
              await showGameSettings(context);
            }
            if (action == 'rules' && context.mounted) {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(s.t('rulesTitle')),
                  content: Text(s.t('rulesBody')),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s.t('confirm')),
                    ),
                  ],
                ),
              );
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'new',
              enabled: !_starting && !_undoing,
              child: Text(s.t('newGame')),
            ),
            PopupMenuItem(value: 'settings', child: Text(s.t('gameSettings'))),
            PopupMenuItem(value: 'rules', child: Text(s.t('rules'))),
          ],
        ),
      ],
      board: GameBoard(
        key: _boardKey,
        game: game,
        settings: ref.watch(settingsProvider),
        interaction: _interaction,
        showControls: false,
        enabled: !_starting && !_undoing,
        onMove: (row, col) =>
            ref.read(localGameProvider.notifier).play(row, col),
      ),
      status: PlayerStrip(
        blackName: s.t('black'),
        whiteName: s.t('white'),
        label: status,
        moves: game.moves.length,
        activeStone: game.isOver ? null : game.turn,
      ),
      controls: game.isOver
          ? ResultMoment(
              key: ValueKey(record.id),
              gameId: record.id,
              label: resultLabel(game, s),
              child: EndGameActions(
                primaryLabel: s.t('rematch'),
                onPrimary: _starting ? null : _restart,
                onReplay: () => context.push('/history/${record.id}'),
              ),
            )
          : MoveControls(
              interaction: _interaction,
              undo: IconButton.filledTonal(
                tooltip: s.t('undo'),
                onPressed: game.canUndo && !_starting && !_undoing
                    ? _undo
                    : null,
                icon: const Icon(Icons.undo_rounded),
              ),
            ),
      details: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.t('rules'), style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Text(s.t('rulesBody'), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.t('savedLocally'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
