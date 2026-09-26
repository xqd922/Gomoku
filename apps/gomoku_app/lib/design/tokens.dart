import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

abstract final class AppSpacing {
  static const tight = 8.0;
  static const content = 16.0;
  static const section = 24.0;
  static const page = 32.0;
}

abstract final class AppShape {
  static const joined = 6.0;
  static const thumb = 14.0;
  static const field = 20.0;
  static const menu = 24.0;
  static const card = 28.0;
  static const feature = 32.0;
}

abstract final class AppLayout {
  static const compact = 600.0;
  static const expanded = 840.0;
  static const content = 1160.0;
  static const reading = 680.0;
  static const board = 688.0;
  static double pageInset(double width) => width >= expanded
      ? AppSpacing.page
      : width >= compact
      ? AppSpacing.section
      : AppSpacing.content;
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const feedback = Duration(milliseconds: 180);
  static const mid = Duration(milliseconds: 220);
  static const transition = Duration(milliseconds: 320);
  static const settle = Duration(milliseconds: 420);
  static Duration duration(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Describes system capabilities independently of persisted user preferences.
class DesignCapabilities extends InheritedWidget {
  const DesignCapabilities({
    super.key,
    required this.dynamicColor,
    required super.child,
  });
  final bool dynamicColor;
  static bool supportsDynamicColor(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<DesignCapabilities>()
          ?.dynamicColor ??
      false;
  static bool get supportsHaptics =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  @override
  bool updateShouldNotify(DesignCapabilities oldWidget) =>
      dynamicColor != oldWidget.dynamicColor;
}
