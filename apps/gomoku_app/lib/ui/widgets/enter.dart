import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../design/motion.dart';
import '../../design/tokens.dart';

/// One-shot entrance: fades in while sliding up [distance] pixels. Plays once
/// per state with an optional [delay] for staggered lists; renders settled
/// immediately when animations are disabled.
class StaggeredEnter extends StatefulWidget {
  const StaggeredEnter({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.distance = 24,
  });

  final Widget child;
  final Duration delay;
  final double distance;

  @override
  State<StaggeredEnter> createState() => _StaggeredEnterState();
}

class _StaggeredEnterState extends State<StaggeredEnter>
    with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: AppMotion.transition,
  );
  bool _scheduled = false;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_scheduled) return;
    _scheduled = true;
    if (AppMotion.duration(context, AppMotion.transition) == Duration.zero) {
      _entrance.value = 1;
      return;
    }
    if (widget.delay <= Duration.zero) {
      _entrance.forward();
      return;
    }
    _timer = Timer(widget.delay, () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _entrance,
    child: widget.child,
    builder: (context, child) {
      final t = AppCurves.decelerate.transform(_entrance.value);
      return Opacity(
        opacity: math.min(1, t * 2),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * widget.distance),
          child: child,
        ),
      );
    },
  );
}

/// Stagger slot for list entrances: the first items cascade, everything
/// further down the list enters without waiting.
Duration enterStagger(int index, {int limit = 8, int stepMs = 30}) =>
    Duration(milliseconds: math.min(index, limit) * stepMs);
