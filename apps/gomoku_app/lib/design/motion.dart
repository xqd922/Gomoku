import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Spring presets for the motion language: a spring feel with deterministic
/// timing, so an interrupted animation always lands exactly on target.
abstract final class AppSprings {
  /// Settle moments: stone placement, result entrance.
  static final settle = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 380,
    ratio: .72,
  );

  /// Press feedback: quick compression, elastic release.
  static final press = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 720,
    ratio: .8,
  );

  /// Sliding selections that follow a gesture (Cupertino thumb constants).
  static const slide = SpringDescription(
    mass: 1,
    stiffness: 503.55,
    damping: 44.88,
  );
}

/// Plays [spring] over the first [seconds], then eases out the residual
/// linearly so the curve still ends exactly at 1.
class SpringCurve extends Curve {
  SpringCurve(this.spring, {required this.seconds})
    : _simulation = SpringSimulation(spring, 0, 1, 0);

  final SpringDescription spring;
  final double seconds;

  final SpringSimulation _simulation;
  late final double _residual = 1 - _simulation.x(seconds);

  @override
  double transformInternal(double t) =>
      _simulation.x(t * seconds) + _residual * t;
}

abstract final class AppCurves {
  /// Entrances and size changes: fast start, gentle landing.
  static const decelerate = Easing.emphasizedDecelerate;

  /// State swaps that read as a single coherent change.
  static const emphasized = Curves.easeInOutCubicEmphasized;

  /// The settled stone and the result moment.
  static final settle = SpringCurve(AppSprings.settle, seconds: .4);

  /// Selection indicators sliding between slots.
  static final slide = SpringCurve(AppSprings.slide, seconds: .35);
}
