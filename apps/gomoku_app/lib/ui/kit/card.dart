import 'package:flutter/material.dart';

import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../widgets/enter.dart';
import '../widgets/press.dart';

/// The universal tappable surface: press-spring feedback, selection tint,
/// superellipse silhouette.
class KitCard extends StatelessWidget {
  const KitCard({
    super.key,
    required this.child,
    this.onTap,
    this.selected = false,
    this.radius = AppShape.card,
    this.color,
    this.padding,
    this.margin,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool selected;
  final double radius;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Pressable(
        onTap: onTap,
        child: Material(
          color:
              color ??
              (selected
                  ? colors.secondaryContainer
                  : colors.surfaceContainerLow),
          shape: AppShapes.of(radius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: IconTheme.merge(
              data: IconThemeData(
                color: selected ? colors.onSecondaryContainer : null,
              ),
              child: padding == null
                  ? child
                  : Padding(padding: padding!, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled group of rows in one rounded surface; the group ends carry the
/// full radius while inner rows stay square, FlClash list-group style.
class KitSection extends StatelessWidget {
  const KitSection({super.key, required this.title, required this.children});

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
            AppSpacing.tight,
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

/// A settings row. Built on ListTile so semantics, focus traversal and the
/// theme stay consistent; [kind] decides the trailing widget.
class KitListTile extends StatelessWidget {
  const KitListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.onTap,
    this.value,
    this.onValueChanged,
    this.enabled = true,
  }) : _switch = false;

  const KitListTile.toggle({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.value,
    required this.onValueChanged,
    this.enabled = true,
  }) : _switch = true,
       onTap = null;

  final String title;
  final String? subtitle;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool? value;
  final ValueChanged<bool>? onValueChanged;
  final bool enabled;
  final bool _switch;

  @override
  Widget build(BuildContext context) {
    if (_switch) {
      return SwitchListTile(
        secondary: icon == null ? null : Icon(icon),
        title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle!),
        value: value ?? false,
        onChanged: enabled ? onValueChanged : null,
      );
    }
    return ListTile(
      leading: icon == null ? null : Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      enabled: enabled,
      trailing: onTap == null ? null : const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}

/// Small status pill with an optional leading icon.
class KitPill extends StatelessWidget {
  const KitPill({
    super.key,
    required this.label,
    this.icon,
    this.error = false,
  });

  final String label;
  final IconData? icon;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = error
        ? colors.errorContainer
        : colors.secondaryContainer;
    final ink = error ? colors.onErrorContainer : colors.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.content,
        vertical: 6,
      ),
      decoration: ShapeDecoration(color: background, shape: AppShapes.thumb),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: ink),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: ink,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dashboard metric card: a tinted icon well, one loud value and a caption.
class KitStatCard extends StatelessWidget {
  const KitStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.caption,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? caption;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = color ?? colors.secondaryContainer;
    final ink = color != null
        ? colors.onSecondaryContainer
        : colors.onSecondaryContainer;
    return KitCard(
      onTap: onTap,
      radius: AppShape.card,
      color: background,
      padding: const EdgeInsets.all(AppSpacing.content),
      // Large text scales inside the fixed dashboard tile: shrink to fit
      // instead of overflowing, like FlClash's per-card text scale.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: ShapeDecoration(
                color: ink.withValues(alpha: .12),
                shape: AppShapes.thumb,
              ),
              child: Icon(icon, size: 20, color: ink),
            ),
            const SizedBox(height: AppSpacing.tight),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: ink.withValues(alpha: .8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline live-region notice (connection state, errors, actions).
class KitNotice extends StatelessWidget {
  const KitNotice({
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

/// Standard scrollable page frame: toolbar inset at the top, responsive
/// page insets on the sides, content centered under [maxWidth].
class KitPageBody extends StatelessWidget {
  const KitPageBody({
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
          AppSpacing.content,
          pad,
          AppSpacing.page,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.content),
                  StaggeredEnter(
                    delay: enterStagger(i, stepMs: 40),
                    child: children[i],
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}
