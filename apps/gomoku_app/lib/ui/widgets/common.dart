import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../data/api.dart';
import '../../l10n/strings.dart';

class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.children, this.maxWidth = 1200});
  final List<Widget> children;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final pad = constraints.maxWidth >= 840 ? 40.0 : 20.0;
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 12, pad, 36),
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
    padding: const EdgeInsets.only(top: 12, bottom: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineLarge),
            ?action,
          ],
        ),
        if (subtitle != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background ?? colors.secondaryContainer,
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 6),
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
      color: stone == Stone.black
          ? const Color(0xff302d35)
          : const Color(0xfffffdfa),
      border: Border.all(
        color: stone == Stone.black
            ? const Color(0xff514b59)
            : const Color(0xffc5bec8),
      ),
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
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.go('/history/${record.id}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: StoneDisc(
                    stone: record.game.result?.winner ?? Stone.black,
                    size: 27,
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
                    const SizedBox(height: 5),
                    Text(
                      '${s.t(record.source == RecordSource.local ? 'localMatch' : 'friendMatch')} · ${s.t('moves', {'n': record.game.moves.length})} · ${dateLabel(record.updatedAt, s)}',
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_outward_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              StoneDisc(stone: Stone.black, size: 22),
              SizedBox(width: 8),
              StoneDisc(stone: Stone.white, size: 22),
              SizedBox(width: 8),
              StoneDisc(stone: Stone.black, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.strings.t('emptyHistory'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            context.strings.t('emptyHistoryBody'),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
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
    await showDialog<bool>(
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
