import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../../l10n/strings.dart';
import '../../design/tokens.dart';
import '../../state/settings.dart';
import 'common.dart';

String pointName(BoardPoint point) =>
    String.fromCharCode(65 + point.col) + (point.row + 1).toString();

/// The board owns input and move acceptance; layouts only present these actions.
class BoardInteractionController extends ChangeNotifier {
  BoardPoint? get selectedPoint => _selected;
  bool get submitting => _submitting;
  bool get canConfirm => _enabled && !_submitting && _selected != null;
  BoardPoint? _selected;
  bool _submitting = false, _enabled = false, _disposed = false;
  Object? _owner;
  Future<void> Function()? _confirm;
  VoidCallback? _cancel;
  bool _notificationScheduled = false;

  Future<void> confirm() async {
    if (canConfirm) await _confirm?.call();
  }

  void cancel() {
    if (!_submitting) _cancel?.call();
  }

  void _attach(
    Object owner,
    Future<void> Function() confirm,
    VoidCallback cancel,
  ) {
    _owner = owner;
    _confirm = confirm;
    _cancel = cancel;
  }

  void _detach(Object owner) {
    if (_owner != owner) return;
    _owner = null;
    _confirm = null;
    _cancel = null;
    _publish(null, false, false, deferred: true);
  }

  void _publish(
    BoardPoint? point,
    bool submitting,
    bool enabled, {
    bool deferred = false,
  }) {
    if (_selected == point &&
        _submitting == submitting &&
        _enabled == enabled) {
      return;
    }
    _selected = point;
    _submitting = submitting;
    _enabled = enabled;
    if (!deferred) {
      if (!_disposed) notifyListeners();
    } else if (!_notificationScheduled) {
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _confirm = null;
    _cancel = null;
    super.dispose();
  }
}

class GameBoard extends StatefulWidget {
  const GameBoard({
    super.key,
    required this.game,
    required this.settings,
    this.onMove,
    this.enabled = true,
    this.readOnly = false,
    this.interaction,
    this.showControls = true,
  });
  final GameState game;
  final AppSettings settings;
  final Future<void> Function(int row, int col)? onMove;
  final bool enabled;
  final bool readOnly;
  final BoardInteractionController? interaction;
  final bool showControls;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard>
    with SingleTickerProviderStateMixin {
  final _focus = FocusNode(debugLabel: 'Gomoku board');
  final _audio = AudioPlayer();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 230),
    value: 1,
  );
  BoardPoint? _selected;
  BoardPoint? _hover;
  BoardPoint _cursor = const BoardPoint(7, 7);
  PointerDeviceKind _pointer = PointerDeviceKind.mouse;
  bool _moving = false;
  bool _focused = false;
  Size _paintSize = Size.zero;
  late BoardInteractionController _interaction;
  @override
  void initState() {
    super.initState();
    _attachInteraction();
  }

  void _attachInteraction() {
    _interaction = widget.interaction ?? BoardInteractionController();
    _interaction._attach(
      this,
      () async {
        final point = _selected;
        if (point != null) await _place(point);
      },
      () {
        if (!mounted) return;
        setState(() => _selected = null);
        _publish();
        _focus.requestFocus();
      },
    );
  }

  void _publish({bool deferred = false}) =>
      _interaction._publish(_selected, _moving, _canPlay, deferred: deferred);

  bool get _canPlay =>
      widget.enabled &&
      !widget.readOnly &&
      !widget.game.isOver &&
      !_moving &&
      widget.onMove != null;
  double _padding(Size size) => size.width < 400 ? 22 : 30;

  @override
  void didUpdateWidget(GameBoard old) {
    super.didUpdateWidget(old);
    if (old.interaction != widget.interaction) {
      _interaction._detach(this);
      if (old.interaction == null) _interaction.dispose();
      _attachInteraction();
    }
    if (old.game.moves.length != widget.game.moves.length ||
        old.game.lastMove != widget.game.lastMove) {
      _selected = null;
      if (widget.settings.reduceMotion ||
          MediaQuery.maybeOf(context)?.disableAnimations == true) {
        _animation.value = 1;
      } else {
        _animation.forward(from: 0);
      }
    }
    if (!_canPlay) _selected = null;
    _publish(deferred: true);
  }

  @override
  void dispose() {
    _interaction._detach(this);
    if (widget.interaction == null) _interaction.dispose();
    _focus.dispose();
    _animation.dispose();
    _audio.dispose();
    super.dispose();
  }

  BoardPoint? _point(Offset position) {
    final pad = _padding(_paintSize);
    final step = (_paintSize.width - pad * 2) / (boardSize - 1);
    if (step <= 0) return null;
    final col = ((position.dx - pad) / step).round();
    final row = ((position.dy - pad) / step).round();
    final point = BoardPoint(row, col);
    if (!point.isOnBoard ||
        (position.dx - (pad + col * step)).abs() > step * .53 ||
        (position.dy - (pad + row * step)).abs() > step * .53) {
      return null;
    }
    return point;
  }

  void _choose(BoardPoint? point, {bool forceConfirm = false}) {
    if (!_canPlay ||
        point == null ||
        widget.game.at(point.row, point.col) != null) {
      return;
    }
    // Accessibility activation has no pointer event to focus the board.
    _focus.requestFocus();
    final touch =
        _pointer == PointerDeviceKind.touch ||
        _pointer == PointerDeviceKind.stylus;
    if (forceConfirm || (touch && widget.settings.confirmTouch)) {
      setState(() {
        _selected = point;
        _cursor = point;
      });
      _publish();
    } else {
      _place(point);
    }
  }

  Future<void> _place(BoardPoint point) async {
    if (!_canPlay) return;
    setState(() {
      _moving = true;
      _selected = point;
    });
    _publish();
    try {
      await widget.onMove!(point.row, point.col);
      if (widget.settings.haptics && DesignCapabilities.supportsHaptics) {
        await HapticFeedback.selectionClick();
      }
      if (widget.settings.sound) {
        try {
          await _audio.play(AssetSource('sounds/stone.wav'), volume: .4);
        } catch (_) {
          /* Sound is optional and never changes move acceptance. */
        }
      }
    } catch (error) {
      if (mounted) showFailure(context, error);
    } finally {
      if (mounted) {
        setState(() {
          _moving = false;
          _selected = null;
        });
        _publish();
      }
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (widget.readOnly) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    var row = _cursor.row;
    var col = _cursor.col;
    if (key == LogicalKeyboardKey.arrowLeft) {
      col--;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      col++;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      row--;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      row++;
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent &&
          _canPlay &&
          widget.game.at(row, col) == null) {
        _place(_cursor);
      }
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.escape) {
      setState(() => _selected = null);
      _publish();
      return KeyEventResult.handled;
    } else {
      return KeyEventResult.ignored;
    }
    setState(() {
      _cursor = BoardPoint(row.clamp(0, 14), col.clamp(0, 14));
      _selected = _canPlay && widget.game.at(_cursor.row, _cursor.col) == null
          ? _cursor
          : null;
    });
    _publish();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    _publish(deferred: true);
    final colors = Theme.of(context).colorScheme;
    final strings = context.strings;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Focus(
          focusNode: _focus,
          onKeyEvent: _key,
          onFocusChange: (value) => setState(() => _focused = value),
          child: Listener(
            onPointerDown: (event) {
              _pointer = event.kind;
              _focus.requestFocus();
            },
            child: MouseRegion(
              cursor: _canPlay
                  ? SystemMouseCursors.precise
                  : SystemMouseCursors.basic,
              onExit: (_) => setState(() => _hover = null),
              onHover: (event) {
                final point = _point(event.localPosition);
                if (point != _hover) setState(() => _hover = point);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _choose(_point(details.localPosition)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      _paintSize = Size.square(constraints.maxWidth);
                      return Semantics(
                        label: strings.t('board'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppShape.card),
                          child: AnimatedBuilder(
                            animation: _animation,
                            builder: (context, _) => CustomPaint(
                              key: const ValueKey('game-board'),
                              size: _paintSize,
                              painter: _BoardPainter(
                                game: widget.game,
                                padding: _padding(_paintSize),
                                accent: colors.primary,
                                background: dark
                                    ? const Color(0xff27252c)
                                    : const Color(0xfff4f0e8),
                                gridColor: dark
                                    ? const Color(0xff817889)
                                    : const Color(0xff979087),
                                labelColor: colors.onSurfaceVariant,
                                selected: _selected,
                                hover: _canPlay ? _hover : null,
                                cursor: _focused && !widget.readOnly
                                    ? _cursor
                                    : null,
                                showNumbers:
                                    widget.settings.moveNumbers ||
                                    widget.readOnly,
                                progress: Curves.easeOutBack.transform(
                                  _animation.value,
                                ),
                                strings: strings,
                                onSelect: _canPlay
                                    ? (point) =>
                                          _choose(point, forceConfirm: true)
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!widget.readOnly && widget.showControls)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: AnimatedSwitcher(
              duration:
                  widget.settings.reduceMotion ||
                      MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              child: _selected != null
                  ? Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.t('selectedPoint', {
                              'point': pointName(_selected!),
                            }),
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ),
                        FilledButton.icon(
                          key: const ValueKey('confirm-move'),
                          onPressed: _canPlay ? () => _place(_selected!) : null,
                          icon: const Icon(Icons.check_rounded, size: 20),
                          label: Text(strings.t('placeStone')),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 44,
                      child: Center(
                        child: Text(
                          strings.t(
                            widget.settings.confirmTouch
                                ? 'selectPoint'
                                : 'keyboardHint',
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

class _BoardPainter extends CustomPainter {
  _BoardPainter({
    required this.game,
    required this.padding,
    required this.accent,
    required this.background,
    required this.gridColor,
    required this.labelColor,
    required this.selected,
    required this.hover,
    required this.cursor,
    required this.showNumbers,
    required this.progress,
    required this.strings,
    this.onSelect,
  });
  final GameState game;
  final double padding;
  final Color accent, background, gridColor, labelColor;
  final BoardPoint? selected, hover, cursor;
  final bool showNumbers;
  final double progress;
  final AppStrings strings;
  final void Function(BoardPoint)? onSelect;

  Offset _offset(BoardPoint point, double step) => Offset(
    padding + point.col * step,
    padding + point.row * step,
  );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final step = (size.width - 2 * padding) / 14;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = .8;
    for (var i = 0; i < boardSize; i++) {
      final at = padding + i * step;
      canvas.drawLine(
        Offset(padding, at),
        Offset(size.width - padding, at),
        grid,
      );
      canvas.drawLine(
        Offset(at, padding),
        Offset(at, size.height - padding),
        grid,
      );
      _text(
        canvas,
        String.fromCharCode(65 + i),
        Offset(at, padding * .40),
        labelColor,
        math.min(10, step * .43),
      );
      _text(
        canvas,
        (i + 1).toString(),
        Offset(padding * .40, at),
        labelColor,
        math.min(10, step * .43),
      );
    }
    for (final (r, c) in [(3, 3), (3, 11), (7, 7), (11, 3), (11, 11)]) {
      canvas.drawCircle(
        _offset(BoardPoint(r, c), step),
        step * .08,
        Paint()..color = gridColor.withValues(alpha: .9),
      );
    }
    final line = game.result?.winningLine;
    if (line != null && line.length >= 5) {
      canvas.drawLine(
        _offset(line.first, step),
        _offset(line.last, step),
        Paint()
          ..color = accent.withValues(alpha: .23)
          ..strokeWidth = step * .8
          ..strokeCap = StrokeCap.round,
      );
    }
    for (var i = 0; i < game.moves.length; i++) {
      final move = game.moves[i];
      final point = _offset(move.point, step);
      final scale = i == game.moves.length - 1 ? .7 + .3 * progress : 1.0;
      final radius = step * .405 * scale;
      canvas.drawCircle(
        point + Offset(0, step * .05),
        radius,
        Paint()..color = Colors.black.withValues(alpha: .13),
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = move.stone == Stone.black
              ? const Color(0xff302d35)
              : const Color(0xfffffdfa),
      );
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = move.stone == Stone.black
              ? const Color(0xff4c4752)
              : const Color(0xffbfb8ba)
          ..strokeWidth = .9
          ..style = PaintingStyle.stroke,
      );
      final ink = move.stone == Stone.black
          ? Colors.white
          : const Color(0xff302d35);
      if (showNumbers) {
        _text(
          canvas,
          (i + 1).toString(),
          point,
          ink,
          step * (i >= 99 ? .29 : .35),
        );
      } else if (i == game.moves.length - 1) {
        canvas.drawCircle(point, step * .09, Paint()..color = ink);
      }
    }
    final preview = selected ?? hover;
    if (preview != null && game.at(preview.row, preview.col) == null) {
      final point = _offset(preview, step);
      canvas.drawCircle(
        point,
        step * .40,
        Paint()
          ..color =
              (game.turn == Stone.black
                      ? const Color(0xff302d35)
                      : Colors.white)
                  .withValues(alpha: .35),
      );
      canvas.drawCircle(
        point,
        step * .43,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (cursor != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: _offset(cursor!, step),
            width: step * .96,
            height: step * .96,
          ),
          Radius.circular(step * .2),
        ),
        Paint()
          ..color = accent.withValues(alpha: .75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    Color color,
    double size,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: FontWeight.w500,
          fontFamily: 'NotoSansSC',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final step = (size.width - padding * 2) / 14;
    return List.generate(boardSize * boardSize, (i) {
      final point = BoardPoint(i ~/ boardSize, i % boardSize);
      final stone = game.at(point.row, point.col);
      return CustomPainterSemantics(
        rect: Rect.fromCenter(
          center: _offset(point, step),
          width: step,
          height: step,
        ),
        properties: SemanticsProperties(
          label: strings.t('cell', {
            'point': pointName(point),
            'stone': strings.t(stone?.name ?? 'empty'),
          }),
          textDirection: TextDirection.ltr,
          button: onSelect != null && stone == null,
          onTap: onSelect != null && stone == null
              ? () => onSelect!(point)
              : null,
        ),
      );
    });
  };

  @override
  bool shouldRepaint(_BoardPainter old) => true;
  @override
  bool shouldRebuildSemantics(_BoardPainter old) =>
      old.game != game ||
      old.strings.locale != strings.locale ||
      old.onSelect != onSelect;
}
