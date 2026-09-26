import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../design/motion.dart';

import '../../design/tokens.dart';
import '../../l10n/strings.dart';

class KitMenuItem {
  const KitMenuItem({
    required this.label,
    this.icon,
    this.onTap,
    this.danger = false,
    this.subItems = const [],
  });

  /// A submenu header opens [subItems] inside the same card instead of
  /// dismissing the menu.
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool danger;
  final List<KitMenuItem> subItems;
}

/// An icon button that opens its menu growing out of its own anchor rect.
class KitMenuButton extends StatelessWidget {
  const KitMenuButton({
    super.key,
    required this.items,
    this.tooltip,
    this.icon = Icons.more_vert_rounded,
  });

  final List<KitMenuItem> items;
  final String? tooltip;
  final IconData icon;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    icon: Icon(icon),
    onPressed: () {
      final box = context.findRenderObject()! as RenderBox;
      showKitMenu(
        context,
        anchor: box.localToGlobal(Offset.zero) & box.size,
        items: items,
      );
    },
  );
}

Future<void> showKitMenu(
  BuildContext context, {
  required Rect anchor,
  required List<KitMenuItem> items,
}) => Navigator.of(context, rootNavigator: true).push(
  _KitMenuRoute(
    anchor: anchor,
    items: items,
    fast: AppMotion.duration(context, AppMotion.mid) == Duration.zero,
  ),
);

class _KitMenuRoute extends PopupRoute<void> {
  _KitMenuRoute({
    required this.anchor,
    required this.items,
    required this.fast,
  });

  final Rect anchor;
  final List<KitMenuItem> items;
  final bool fast;

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss menu';

  @override
  Duration get transitionDuration => fast ? Duration.zero : AppMotion.mid;

  @override
  Duration get reverseTransitionDuration =>
      fast ? Duration.zero : const Duration(milliseconds: 180);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => _MenuOverlay(anchor: anchor, items: items, route: this);
}

class _MenuOverlay extends StatefulWidget {
  const _MenuOverlay({
    required this.anchor,
    required this.items,
    required this.route,
  });

  final Rect anchor;
  final List<KitMenuItem> items;
  final _KitMenuRoute route;

  @override
  State<_MenuOverlay> createState() => _MenuOverlayState();
}

class _MenuOverlayState extends State<_MenuOverlay> {
  late List<List<KitMenuItem>> _levels = [widget.items];

  double get _progress => CurvedAnimation(
    parent: widget.route.animation!,
    curve: AppCurves.decelerate,
  ).value;

  ({Rect rect, double radius}) _layoutFor(
    List<KitMenuItem> level,
    double progress,
    Size screen,
  ) {
    // A submenu level renders an extra back row above its items.
    final rows = level.length + (_levels.length > 1 ? 1 : 0);
    final width = 248.0;
    final height = rows * 48 + AppSpacing.content;
    final margin = AppSpacing.content;
    var left = widget.anchor.left;
    left = math.min(left, screen.width - width - margin);
    left = math.max(left, margin);
    double top = widget.anchor.bottom + AppSpacing.tight;
    if (top + height > screen.height - margin) {
      top = widget.anchor.top - AppSpacing.tight - height;
    }
    top = math.max(top, margin);
    final target = Rect.fromLTWH(left, top, width, height);
    // The card grows out of the anchor: start as a small pill over it.
    final start = Rect.fromCenter(
      center: widget.anchor.center,
      width: widget.anchor.width,
      height: math.min(widget.anchor.height, 40),
    );
    return (
      rect: Rect.lerp(start, target, progress)!,
      radius: lerpDouble(14, AppShape.menu, progress)!,
    );
  }

  void _openSubItems(List<KitMenuItem> subItems) =>
      setState(() => _levels = [..._levels, subItems]);

  @override
  Widget build(BuildContext context) {
    final level = _levels.last;
    return AnimatedBuilder(
      animation: widget.route.animation!,
      builder: (context, _) {
        final progress = _progress.clamp(0, 1).toDouble();
        final screen = MediaQuery.sizeOf(context);
        final (:rect, :radius) = _layoutFor(level, progress, screen);
        final contentOpacity = ((progress - .35) / .65).clamp(0, 1).toDouble();
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: Navigator.of(context).pop,
              ),
            ),
            Positioned.fromRect(
              rect: rect,
              child: ClipRSuperellipse(
                borderRadius: BorderRadius.circular(radius),
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  elevation: progress * 3,
                  shadowColor: Colors.black,
                  child: AnimatedSize(
                    duration: AppMotion.duration(context, AppMotion.fast),
                    curve: AppCurves.decelerate,
                    alignment: Alignment.topCenter,
                    child: Opacity(
                      opacity: contentOpacity.toDouble(),
                      child: _MenuLevel(
                        key: ValueKey(_levels.length),
                        items: level,
                        canGoBack: _levels.length > 1,
                        onBack: () => setState(() {
                          _levels = _levels.sublist(0, _levels.length - 1);
                        }),
                        onSubItems: _openSubItems,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MenuLevel extends StatelessWidget {
  const _MenuLevel({
    super.key,
    required this.items,
    required this.canGoBack,
    required this.onBack,
    required this.onSubItems,
  });

  final List<KitMenuItem> items;
  final bool canGoBack;
  final VoidCallback onBack;
  final ValueChanged<List<KitMenuItem>> onSubItems;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canGoBack)
          _MenuRow(
            label: context.strings.t('back'),
            icon: Icons.arrow_back_rounded,
            onTap: onBack,
          ),
        for (final item in items)
          _MenuRow(
            label: item.label,
            icon: item.icon,
            danger: item.danger,
            hasSubmenu: item.subItems.isNotEmpty,
            onTap: item.subItems.isNotEmpty
                ? () => onSubItems(item.subItems)
                : () {
                    Navigator.of(context).pop();
                    item.onTap?.call();
                  },
          ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.icon,
    this.danger = false,
    this.hasSubmenu = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;
  final bool hasSubmenu;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = danger ? colors.error : colors.onSurface;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: AppSpacing.content),
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: danger ? colors.error : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 14),
            ] else
              const SizedBox(width: 2),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: ink),
              ),
            ),
            if (hasSubmenu)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: colors.onSurfaceVariant,
              ),
            const SizedBox(width: AppSpacing.content),
          ],
        ),
      ),
    );
  }
}
