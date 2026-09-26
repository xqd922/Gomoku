import 'package:flutter/material.dart';

import 'tokens.dart';

/// Superellipse (continuous-corner) expressions of the rounding scale: the
/// same radii as `AppShape`, drawn with `RoundedSuperellipseBorder` so every
/// surface shares the softer Material 3 Expressive corner.
abstract final class AppShapes {
  static const joined = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.joined)),
  );
  static const thumb = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.thumb)),
  );
  static const field = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.field)),
  );
  static const menu = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.menu)),
  );
  static const card = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.card)),
  );
  static const feature = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShape.feature)),
  );
  static const pill = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(999)),
  );

  /// Bottom sheets: feature radius on the top corners only.
  static const topFeature = RoundedSuperellipseBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.feature)),
  );

  static RoundedSuperellipseBorder of(double radius) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
}

extension AppThemeShapes on ThemeData {
  /// Injects the superellipse language into every themed surface at once.
  ThemeData get withAppShapes => copyWith(
    cardTheme: cardTheme.copyWith(shape: AppShapes.card),
    dialogTheme: dialogTheme.copyWith(shape: AppShapes.feature),
    bottomSheetTheme: bottomSheetTheme.copyWith(shape: AppShapes.topFeature),
    snackBarTheme: snackBarTheme.copyWith(shape: AppShapes.field),
    chipTheme: chipTheme.copyWith(shape: AppShapes.thumb),
    popupMenuTheme: popupMenuTheme.copyWith(shape: AppShapes.menu),
    navigationBarTheme: navigationBarTheme.copyWith(
      indicatorShape: AppShapes.pill,
    ),
    navigationRailTheme: navigationRailTheme.copyWith(
      indicatorShape: AppShapes.pill,
    ),
  );
}
