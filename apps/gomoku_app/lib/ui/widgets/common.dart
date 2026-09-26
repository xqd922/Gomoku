import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../data/api.dart';
import '../../design/board_palette.dart';
import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../../l10n/strings.dart';
import 'enter.dart';
import 'press.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.maxWidth = AppLayout.content,
    this.scrollKey,
  });
  final List<Widget> children;
  final double maxWidth;
  final Key? scrollKey;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pad = AppLayout.pageInset(constraints.maxWidth);
      return SingleChildScrollView(
        key: scrollKey,
        padding: EdgeInsets.fromLTRB(
          pad,
          AppSpacing.section,
          pad,
          AppSpacing.page,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      );
    },
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });
  final String title;
  final String? subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.section),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            ?action,
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.tight),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
    this.background,
  });
  final String label;
  final IconData? icon;
  final Color? color, background;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = color ?? colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.content,
        vertical: AppSpacing.tight,
      ),
      decoration: BoxDecoration(
        color: background ?? colors.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: AppSpacing.tight),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: ink, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
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

class RecordTile extends StatelessWidget {
  const RecordTile({super.key, required this.record});
  final GameRecord record;
  @override
  Widget build(BuildContext context) {
    final s = context.strings;
    final colors = Theme.of(context).colorScheme;
    return Pressable(
      onTap: () => context.push('/history/${record.id}'),
      child: Material(
        color: colors.surfaceContainerLow,
        shape: AppShapes.menu,
        clipBehavior: Clip.antiAlias,
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
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
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

class EmptyGames extends StatelessWidget {
  const EmptyGames({super.key});
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.section,
        vertical: AppSpacing.page,
      ),
      decoration: ShapeDecoration(
        color: colors.surfaceContainerLow,
        shape: AppShapes.card,
      ),
      child: Column(
        children: [
          StaggeredEnter(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                StoneDisc(stone: Stone.black, size: 22),
                SizedBox(width: 8),
                StoneDisc(stone: Stone.white, size: 22),
                SizedBox(width: 8),
                StoneDisc(stone: Stone.black, size: 22),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StaggeredEnter(
            delay: const Duration(milliseconds: 60),
            child: Text(
              context.strings.t('libraryEmpty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.tight),
          StaggeredEnter(
            delay: const Duration(milliseconds: 120),
            child: Text(
              context.strings.t('emptyHistoryBody'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.content),
          StaggeredEnter(
            delay: const Duration(milliseconds: 180),
            child: FilledButton.tonalIcon(
              onPressed: () => context.go('/'),
              icon: const Icon(Icons.add_rounded),
              label: Text(context.strings.t('startPlaying')),
            ),
          ),
        ],
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

class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.content,
            AppSpacing.tight,
            AppSpacing.content,
            AppSpacing.content,
          ),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Material(
          color: colors.surfaceContainerLow,
          clipBehavior: Clip.antiAlias,
          shape: AppShapes.card,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    indent: AppSpacing.content,
                    endIndent: AppSpacing.content,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class InlineNotice extends StatelessWidget {
  const InlineNotice({
    super.key,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.action,
    this.error = false,
  });
  final String message;
  final IconData icon;
  final Widget? action;
  final bool error;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = error
        ? colors.onErrorContainer
        : colors.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.content),
        decoration: ShapeDecoration(
          color: error ? colors.errorContainer : colors.secondaryContainer,
          shape: AppShapes.menu,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 22, color: foreground),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            if (action != null)
              Align(alignment: Alignment.centerRight, child: action),
          ],
        ),
      ),
    );
  }
}

Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  final duration = AppMotion.duration(
    context,
    const Duration(milliseconds: 240),
  );
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: .32),
    transitionDuration: duration,
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        builder(dialogContext),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        duration <= Duration.zero
        ? child
        : FadeScaleTransition(animation: animation, child: child),
  );
}

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
    return showAppDialog(
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

void showFailure(BuildContext context, Object error) {
  if (!context.mounted) return;
  final code = error is RuleViolation ? error.code : errorCode(error);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.strings.error(code))),
  );
}

Future<bool> confirmAction(
  BuildContext context,
  String title,
  String body, {
  String? confirmLabel,
}) async =>
    await showAppDialog<bool>(
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
