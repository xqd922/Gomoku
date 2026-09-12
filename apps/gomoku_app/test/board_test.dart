import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:gomoku_flutter/l10n/strings.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:gomoku_flutter/ui/widgets/board.dart';

void main() {
  testWidgets('touch previews and confirms; keyboard and mouse place once', (
    tester,
  ) async {
    var game = GameState.newGame();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [AppStrings.delegate],
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 360,
                child: GameBoard(
                  game: game,
                  settings: const AppSettings(
                    sound: false,
                    haptics: false,
                    reduceMotion: true,
                  ),
                  onMove: (row, col) async => setState(() {
                    game = game.play(row, col);
                  }),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final board = find.byKey(const ValueKey('game-board'));
    await tester.tapAt(tester.getCenter(board));
    await tester.pumpAndSettle();
    expect(game.moves, isEmpty);
    expect(find.byKey(const ValueKey('confirm-move')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-move')));
    await tester.pumpAndSettle();
    expect(game.moves.length, 1);
    expect(game.at(7, 7), Stone.black);
    await tester.tapAt(tester.getCenter(board));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(game.moves.length, 2);
    expect(game.at(7, 8), Stone.white);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    final corner = tester.getTopLeft(board) + const Offset(22, 22);
    await mouse.addPointer(location: corner);
    await mouse.moveTo(corner);
    expect(game.moves.length, 2);
    await mouse.down(corner);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(game.at(0, 0), Stone.black);
    expect(game.moves.length, 3);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed server move stays empty and exposes a recoverable error',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppStrings.supportedLocales,
          localizationsDelegates: const [AppStrings.delegate],
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 360,
                child: GameBoard(
                  game: GameState.newGame(),
                  settings: const AppSettings(
                    sound: false,
                    haptics: false,
                    confirmTouch: false,
                  ),
                  onMove: (_, _) async => throw const RuleViolation('occupied'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('game-board'))),
      );
      await tester.pumpAndSettle();
      expect(find.text('There’s already a stone here.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('all intersections are labeled for screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppStrings.supportedLocales,
        localizationsDelegates: const [AppStrings.delegate],
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: GameBoard(
                game: GameState.newGame().play(7, 7),
                settings: const AppSettings(),
                onMove: (_, _) async {},
              ),
            ),
          ),
        ),
      ),
    );
    final labels = <String>[];
    void visit(SemanticsNode node) {
      labels.add(node.getSemanticsData().label);
      node.visitChildren((child) {
        visit(child);
        return true;
      });
    }

    tester.binding.rootPipelineOwner.visitChildren((owner) {
      final root = owner.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    });
    expect(labels, containsAll(['H8, Black', 'A1, Empty', 'O15, Empty']));
    expect(
      labels.where((label) => RegExp(r'^[A-O]\d+, ').hasMatch(label)).length,
      225,
    );
    semantics.dispose();
  });
}
