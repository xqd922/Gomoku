import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_flutter/design/motion.dart';
import 'package:gomoku_flutter/ui/widgets/enter.dart';
import 'package:gomoku_flutter/ui/widgets/press.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SpringCurve', () {
    test('starts at zero and lands exactly on one', () {
      final curve = SpringCurve(
        SpringDescription(mass: 1, stiffness: 380, damping: 20),
        seconds: .4,
      );
      expect(curve.transform(0), 0);
      expect(curve.transform(1), closeTo(1, 1e-9));
      expect(curve.transform(.5), inExclusiveRange(0, 1.5));
    });

    test('the settle spring overshoots before settling', () {
      final values = [
        for (var i = 0; i <= 100; i++) AppCurves.settle.transform(i / 100),
      ];
      expect(values.any((value) => value > 1.005), isTrue);
      expect(values.last, closeTo(1, 1e-9));
    });
  });

  group('StaggeredEnter', () {
    testWidgets('fades in from below and settles at full opacity', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StaggeredEnter(child: Text('entering')),
          ),
        ),
      );
      expect(
        tester.widget<Opacity>(find.byType(Opacity)).opacity,
        lessThan(1),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
      final offset = tester.getTopLeft(find.text('entering'));
      await tester.pumpAndSettle(const Duration(milliseconds: 50));
      expect(tester.getTopLeft(find.text('entering')), offset);
    });

    testWidgets('renders settled when animations are disabled', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const MaterialApp(
            home: Scaffold(body: StaggeredEnter(child: Text('calm'))),
          ),
        ),
      );
      await tester.pump();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });

  group('Pressable', () {
    double scaleOf(WidgetTester tester) {
      final transform = tester.widget<Transform>(
        find
            .descendant(
              of: find.byType(Pressable),
              matching: find.byType(Transform),
            )
            .first,
      );
      return transform.transform.storage[0];
    }

    testWidgets('compresses while pressed and springs back on release', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Pressable(
                onTap: () => taps++,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const Text('press me'),
                ),
              ),
            ),
          ),
        ),
      );
      expect(scaleOf(tester), 1);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('press me')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump(const Duration(milliseconds: 60));
      expect(scaleOf(tester), lessThan(0.99));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scaleOf(tester), closeTo(1, .001));
      expect(taps, 1);
      await tester.tap(find.text('press me'));
      expect(taps, 2);
    });

    testWidgets('stays at rest when there is no handler', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Pressable(child: Text('still'))),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('still')),
      );
      await tester.pump(const Duration(milliseconds: 60));
      expect(scaleOf(tester), 1);
      await gesture.up();
      await tester.pumpAndSettle();
    });
  });
}
