import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/shape.dart';
import '../../design/tokens.dart';
import '../widgets/enter.dart';

/// Wall-clock-synced pulsing bar: every skeleton on screen breathes in step
/// because the phase derives from the clock, not from controller start time.
class KitSkeleton extends StatefulWidget {
  const KitSkeleton({
    super.key,
    this.height = 14,
    this.radius = AppShape.thumb,
  });

  final double height;
  final double radius;

  @override
  State<KitSkeleton> createState() => _KitSkeletonState();
}

class _KitSkeletonState extends State<KitSkeleton>
    with SingleTickerProviderStateMixin {
  static const _period = Duration(milliseconds: 1200);
  late final _controller = AnimationController(vsync: this, duration: _period);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().millisecondsSinceEpoch;
    _controller.value = (now % _period.inMilliseconds) / _period.inMilliseconds;
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wave = (math.sin(_controller.value * 2 * math.pi) + 1) / 2;
        return Container(
          height: widget.height,
          decoration: ShapeDecoration(
            color: colors.surfaceContainerHighest.withValues(
              alpha: .55 + .35 * wave,
            ),
            shape: AppShapes.of(widget.radius),
          ),
        );
      },
    );
  }
}

/// Composed empty state: illustration disc, title, body and action staggered
/// in — never bare text.
class KitEmptyState extends StatelessWidget {
  const KitEmptyState({
    super.key,
    required this.title,
    this.body,
    this.action,
    this.icon = Icons.grid_on_rounded,
  });

  final String title;
  final String? body;
  final Widget? action;
  final IconData icon;

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
            child: Container(
              width: 88,
              height: 88,
              decoration: ShapeDecoration(
                color: colors.primary.withValues(alpha: .12),
                shape: AppShapes.feature,
              ),
              child: Icon(icon, size: 36, color: colors.primary),
            ),
          ),
          const SizedBox(height: AppSpacing.content),
          StaggeredEnter(
            delay: const Duration(milliseconds: 60),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: AppSpacing.tight),
            StaggeredEnter(
              delay: const Duration(milliseconds: 120),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: AppSpacing.content),
            StaggeredEnter(
              delay: const Duration(milliseconds: 180),
              child: action!,
            ),
          ],
        ],
      ),
    );
  }
}

/// Loading / empty / content triage, the NullStatus pattern: pickers stay
/// declarative and the empty state never flashes during a fast load.
class KitStateSwitcher extends StatelessWidget {
  const KitStateSwitcher({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.empty,
    required this.content,
  });

  final bool isLoading;
  final bool isEmpty;
  final Widget empty;
  final Widget content;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.tight),
            const KitSkeleton(height: 72, radius: AppShape.menu),
          ],
        ],
      );
    }
    return isEmpty ? empty : content;
  }
}
