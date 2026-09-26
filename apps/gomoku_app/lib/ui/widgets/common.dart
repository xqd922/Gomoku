import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../data/api.dart';
import '../../design/board_palette.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import '../kit/card.dart';
import '../kit/sheet.dart';
import 'press.dart';

/// Error surfaces as a localized snackbar; never raw exception text.
void showFailure(BuildContext context, Object error) {
  if (!context.mounted) return;
  final code = error is RuleViolation ? error.code : errorCode(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.strings.error(code))),
  );
}

class StoneDisc extends StatelessWidget {
  const StoneDisc({super.key, required this.stone, this.size = 32});
  final Stone stone;
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: BoardPalette.stoneFill(stone),
      border: Border.all(color: BoardPalette.stoneBorder(stone)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .08),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
  );
}

String resultLabel(GameState game, AppStrings strings) {
  if (game.result?.isInterrupted == true) return strings.t('interrupted');
  if (game.result?.isDraw == true) return strings.t('draw');
  if (game.result?.winner == Stone.black) return strings.t('blackWon');
  if (game.result?.winner == Stone.white) return strings.t('whiteWon');
  return strings.t('inProgress');
}

String dateLabel(DateTime date, AppStrings strings) {
  final local = date.toLocal();
  final now = DateTime.now();
  final days = DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(local.year, local.month, local.day)).inDays;
  if (days == 0) return strings.t('today');
  if (days == 1) return strings.t('yesterday');
  return '${local.year}.${local.month.toString().padLeft(2, '0')}.${local.day.toString().padLeft(2, '0')}';
}

/// A single-choice picker: a dialog on wide screens, a bottom sheet on
/// compact ones — both through the kit.
Future<T?> showChoice<T>(
  BuildContext context, {
  required String title,
  required T value,
  required List<(T, String)> choices,
}) {
  Widget contents(BuildContext sheetContext) => RadioGroup<T>(
    groupValue: value,
    onChanged: (next) {
      if (next != null) Navigator.pop(sheetContext, next);
    },
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final choice in choices)
          RadioListTile<T>(value: choice.$1, title: Text(choice.$2)),
      ],
    ),
  );
  if (MediaQuery.sizeOf(context).width >= AppLayout.compact) {
    return showKitDialog<T>(
      context: context,
      builder: (sheetContext) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(child: contents(sheetContext)),
        ),
      ),
    );
  }
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            contents(sheetContext),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body, {
  String? confirmLabel,
}) async =>
    await showKitDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel ?? context.strings.t('confirm')),
          ),
        ],
      ),
    ) ??
    false;

/// A finished-game row: preview disc grid, result title, players and meta.
class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});
  final GameRecord record;
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => context.push('/history/${record.id}'),
      child: KitCard(
        radius: AppShape.menu,
        child: InkWell(
          onTap: () => context.push('/history/${record.id}'),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.content),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: ClipRSuperellipse(
                    borderRadius: BorderRadius.circular(AppShape.thumb),
                    child: CustomPaint(
                      size: const Size.square(64),
                      painter: _RecordPreview(record.game, colors),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resultLabel(record.game, s),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.tight),
                      Text(
                        s.t('players', {
                          'black': record.blackName,
                          'white': record.whiteName,
                        }),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.tight),
                      Text(
                        '${s.t(record.source == RecordSource.local ? 'localMatch' : 'friendMatch')} · ${s.t('moves', {'n': record.game.moves.length})} · ${record.updatedAt.toLocal().hour.toString().padLeft(2, '0')}:${record.updatedAt.toLocal().minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordPreview extends CustomPainter {
  _RecordPreview(this.game, this.colors);
  final GameState game;
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = BoardPalette.canvas(colors.brightness),
    );
    const pad = 8.0;
    final step = (size.width - pad * 2) / 14;
    final grid = Paint()
      ..color = BoardPalette.grid(colors.brightness)
      ..strokeWidth = .6;
    for (var i = 0; i < 15; i++) {
      final p = pad + i * step;
      canvas.drawLine(Offset(p, pad), Offset(p, size.height - pad), grid);
      canvas.drawLine(Offset(pad, p), Offset(size.width - pad, p), grid);
    }
    for (final move in game.moves) {
      canvas.drawCircle(
        Offset(pad + move.col * step, pad + move.row * step),
        step * .43,
        Paint()..color = BoardPalette.stoneFill(move.stone),
      );
    }
  }

  @override
  bool shouldRepaint(_RecordPreview old) =>
      old.game != game || old.colors != colors;
}
