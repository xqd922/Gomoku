import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// Paint-only press feedback: while pressed the child compresses toward
/// [scale] on a spring, then releases with an elastic settle. Layout, hit
/// testing, and anything anchored to the child observe it at rest, so taps
/// never move out from under the finger.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = .96,
  });

  final Widget child;

  /// When null the child only renders at rest; the guard keeps disabled
  /// surfaces from compressing.
  final VoidCallback? onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final _scale = AnimationController.unbounded(vsync: this, value: 1);
  bool _pressed = false;

  @override
  void dispose() {
    _scale.dispose();
    super.dispose();
  }

  void _compress() {
    if (widget.onTap == null || _pressed) return;
    _pressed = true;
    _retarget(widget.scale);
  }

  void _release() {
    if (!_pressed) return;
    _pressed = false;
    _retarget(1);
  }

  void _retarget(double target) {
    if (AppMotion.duration(context, AppMotion.feedback) == Duration.zero) {
      _scale.value = target;
      return;
    }
    _scale.animateWith(
      SpringSimulation(AppSprings.press, _scale.value, target, 0),
    );
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _compress(),
    onPointerUp: (_) => _release(),
    onPointerCancel: (_) => _release(),
    child: AnimatedBuilder(
      animation: _scale,
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        transformHitTests: false,
        child: child,
      ),
    ),
  );
}
