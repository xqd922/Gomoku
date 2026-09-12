import 'dart:math' as math;

import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color ?? Theme.of(context).colorScheme.primary),
    ),
  );
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 4.2;
    final paint = Paint()..color = color;
    for (final (x, y) in [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)]) {
      canvas.drawCircle(
        Offset((x + 1.1) * unit, (y + 1.1) * unit),
        unit * .48,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Code-drawn artwork stays sharp and ships with every platform.
class HeroBoard extends StatelessWidget {
  const HeroBoard({super.key, this.size = 300});
  final double size;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _HeroPainter(colors)),
      ),
    );
  }
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.colors);
  final ColorScheme colors;
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    canvas.save();
    canvas.translate(w / 2, w / 2);
    canvas.rotate(-math.pi / 24);
    final board = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: w * .78, height: w * .78),
      Radius.circular(w * .13),
    );
    canvas.drawRRect(
      board.shift(Offset(0, w * .035)),
      Paint()..color = colors.primary.withValues(alpha: .08),
    );
    canvas.drawRRect(
      board,
      Paint()..color = colors.surface.withValues(alpha: .82),
    );
    final step = w * .09;
    final grid = Paint()
      ..color = colors.primary.withValues(alpha: .13)
      ..strokeWidth = 1;
    for (var i = -3; i <= 3; i++) {
      canvas.drawLine(
        Offset(-3 * step, i * step),
        Offset(3 * step, i * step),
        grid,
      );
      canvas.drawLine(
        Offset(i * step, -3 * step),
        Offset(i * step, 3 * step),
        grid,
      );
    }
    final line = Paint()
      ..color = colors.primary.withValues(alpha: .17)
      ..strokeWidth = step * .75
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(-2 * step, 2 * step),
      Offset(2 * step, -2 * step),
      line,
    );
    final stones = <(int, int, bool)>[
      (-2, 2, true),
      (-1, 1, true),
      (0, 0, true),
      (1, -1, true),
      (2, -2, true),
      (-2, 0, false),
      (-1, -1, false),
      (0, 1, false),
      (1, 1, false),
    ];
    for (final (x, y, black) in stones) {
      final point = Offset(x * step, y * step);
      canvas.drawCircle(
        point + Offset(0, step * .09),
        step * .4,
        Paint()..color = Colors.black.withValues(alpha: .10),
      );
      canvas.drawCircle(
        point,
        step * .4,
        Paint()
          ..color = black ? const Color(0xff36313f) : const Color(0xfffffbf5),
      );
      if (!black) {
        canvas.drawCircle(
          point,
          step * .4,
          Paint()
            ..color = const Color(0xffded7cb)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      }
    }
    canvas.drawCircle(
      Offset(2 * step, -2 * step),
      step * .09,
      Paint()..color = colors.primaryContainer,
    );
    canvas.restore();
    canvas.drawCircle(
      Offset(w * .92, w * .24),
      w * .052,
      Paint()..color = colors.tertiaryContainer,
    );
    canvas.drawCircle(
      Offset(w * .10, w * .79),
      w * .024,
      Paint()..color = colors.primary.withValues(alpha: .45),
    );
    final plus = Paint()
      ..color = colors.primary.withValues(alpha: .6)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * .12, w * .15), Offset(w * .12, w * .20), plus);
    canvas.drawLine(
      Offset(w * .095, w * .175),
      Offset(w * .145, w * .175),
      plus,
    );
  }

  @override
  bool shouldRepaint(_HeroPainter old) => old.colors != colors;
}
