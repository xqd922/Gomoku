import 'dart:math' as math;

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import '../../design/motion.dart';

import '../../design/tokens.dart';

/// Dialogs scale-fade in over a 32% scrim, the FlClash dialog feel.
Future<T?> showKitDialog<T>({
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

/// Responsive sheet dispatch: a detented bottom sheet on compact screens, a
/// side panel that springs in from the end edge on wide ones. Forms and
/// detail pickers all travel through here.
Future<T?> showKitSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String? title,
  double maxExtent = .85,
}) {
  final wide = MediaQuery.sizeOf(context).width >= AppLayout.compact;
  if (wide) return _showSideSheet<T>(context, builder: builder, title: title);
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(maxHeight: maxExtent * 100),
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
              ),
            builder(sheetContext),
          ],
        ),
      ),
    ),
  );
}

Future<T?> _showSideSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  final fast = AppMotion.duration(context, AppMotion.mid) == Duration.zero;
  return Navigator.of(context, rootNavigator: true).push(
    _KitSideSheetRoute<T>(
      fast: fast,
      scrim: Theme.of(context).colorScheme.scrim.withValues(alpha: .32),
      builder: builder,
      title: title,
    ),
  );
}

class _KitSideSheetRoute<T> extends PopupRoute<T> {
  _KitSideSheetRoute({
    required this.fast,
    required this.scrim,
    required this.builder,
    this.title,
  });

  final bool fast;
  final Color scrim;
  final WidgetBuilder builder;
  final String? title;

  @override
  Color? get barrierColor => scrim;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss panel';

  @override
  Duration get transitionDuration =>
      fast ? Duration.zero : AppMotion.transition;

  @override
  Duration get reverseTransitionDuration =>
      fast ? Duration.zero : const Duration(milliseconds: 200);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => const SizedBox.shrink();

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final title = this.title;
    final slide =
        Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: fast ? Curves.linear : AppCurves.decelerate,
          ),
        );
    return SlideTransition(
      position: slide,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FractionallySizedBox(
          heightFactor: 1,
          child: Material(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            shape: const RoundedSuperellipseBorder(
              borderRadius: BorderRadius.horizontal(
                left: Radius.circular(AppShape.feature),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            elevation: 4,
            shadowColor: Colors.black,
            child: SizedBox(
              width: math.min(MediaQuery.sizeOf(context).width * .42, 400),
              child: SafeArea(
                left: false,
                top: false,
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (title != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.section,
                          AppSpacing.section,
                          AppSpacing.section,
                          AppSpacing.content,
                        ),
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.section,
                          0,
                          AppSpacing.section,
                          AppSpacing.page,
                        ),
                        child: builder(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
