import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:gomoku_flutter/state/app_state.dart';
import 'package:gomoku_flutter/ui/widgets/board.dart';

import 'support/ui_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFont);

  testWidgets('secondary routes expose their URL and return to their entry', (
    tester,
  ) async {
    final app = await pumpGomoku(tester, size: const Size(1440, 1000));
    String currentPath() => app.router.routeInformationParser
        .restoreRouteInformation(
          app.router.routerDelegate.currentConfiguration,
        )!
        .uri
        .path;
    await openRoute(tester, app, '/history');
    await tester.tap(find.byTooltip('Account and settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(currentPath(), '/settings');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(currentPath(), '/history');
    await openRoute(tester, app, '/join/ABC234');
    expect(currentPath(), '/join/ABC234');
    expect(find.text('ABC234'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(currentPath(), '/');
    expect(tester.takeException(), isNull);
  });

  testWidgets('selection survives rotation and confirmation places once', (
    tester,
  ) async {
    final app = await pumpGomoku(tester);
    await openRoute(tester, app, '/local');
    final board = find.byKey(const ValueKey('game-board'));
    await tester.tapAt(tester.getCenter(board));
    await tester.pumpAndSettle();
    final interaction = tester
        .widget<GameBoard>(find.byType(GameBoard))
        .interaction!;
    expect(interaction.selectedPoint, const BoardPoint(7, 7));
    tester.view.physicalSize = const Size(844, 390);
    await tester.pumpAndSettle();
    expect(
      tester.widget<GameBoard>(find.byType(GameBoard)).interaction,
      same(interaction),
    );
    expect(interaction.selectedPoint, const BoardPoint(7, 7));
    await tester.tap(find.byKey(const ValueKey('confirm-move')));
    await tester.pumpAndSettle();
    expect(app.container.read(localGameProvider)!.game.moves.length, 1);
    expect(interaction.selectedPoint, isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('start-game')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<GameBoard>(find.byType(GameBoard)).game.at(7, 7),
      Stone.black,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'back keeps an online seat; leaving requires explicit confirmation',
    (tester) async {
      final app = await pumpGomoku(tester, room: uiRoom());
      await openRoute(tester, app, '/room/room-test');
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(app.online.sent, isEmpty);
      await tester.tap(find.byKey(const ValueKey('start-game')));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Game options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave room'));
      await tester.pumpAndSettle();
      expect(app.online.sent, isEmpty);
      expect(
        find.text('If a game is in progress, leaving counts as resigning.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(app.online.sent, isEmpty);
      await tester.tap(find.byTooltip('Game options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Leave room'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave room'));
      await tester.pumpAndSettle();
      expect(app.online.sent, [RoomAction.leave]);
      expect(app.router.routeInformationProvider.value.uri.path, '/');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a paused snapshot clears preview and disables move confirmation',
    (tester) async {
      final app = await pumpGomoku(tester, room: uiRoom());
      await openRoute(tester, app, '/room/room-test');
      await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('game-board'))),
      );
      await tester.pumpAndSettle();
      final interaction = tester
          .widget<GameBoard>(find.byType(GameBoard))
          .interaction!;
      expect(interaction.canConfirm, isTrue);
      app.online.receive(uiRoom(status: RoomStatus.paused), connected: false);
      await tester.pumpAndSettle();
      expect(interaction.selectedPoint, isNull);
      expect(interaction.canConfirm, isFalse);
      expect(find.text('Game paused'), findsWidgets);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('confirm-move')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('undo negotiation blocks the board and exposes both decisions', (
    tester,
  ) async {
    final room = uiRoom(game: GameState.newGame().play(7, 7).play(8, 7))
        .copyWith(undoRequestedBy: 'guest');
    final app = await pumpGomoku(tester, room: room);
    await openRoute(tester, app, '/room/room-test');
    expect(tester.widget<GameBoard>(find.byType(GameBoard)).enabled, isFalse);
    expect(find.text('Decline'), findsOneWidget);
    final accept = find.widgetWithText(FilledButton, 'Accept');
    await tester.ensureVisible(accept);
    await tester.tap(accept);
    await tester.pumpAndSettle();
    expect(app.online.sent, [RoomAction.acceptUndo]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active room explains why account fields cannot change', (
    tester,
  ) async {
    final app = await pumpGomoku(tester, room: uiRoom());
    await openRoute(tester, app, '/account');
    expect(
      find.text(
        'Finish or leave your room before changing your account or nickname.',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextFormField>(find.byKey(const ValueKey('account-email')))
          .enabled,
      isFalse,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('account-submit')))
          .onPressed,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in errors stay next to the password and clear on editing', (
    tester,
  ) async {
    final app = await pumpGomoku(tester);
    await openRoute(tester, app, '/account');
    await tester.enterText(
      find.byKey(const ValueKey('account-email')),
      'player@example.test',
    );
    final password = find.byKey(const ValueKey('account-password'));
    await tester.enterText(password, 'incorrect-password');
    final submit = find.byKey(const ValueKey('account-submit'));
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    final passwordInput = find.descendant(
      of: password,
      matching: find.byType(TextField),
    );
    expect(
      tester.widget<TextField>(passwordInput).decoration?.errorText,
      'That email or password doesn’t look right.',
    );
    await tester.enterText(password, 'changed-password');
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(passwordInput).decoration?.errorText,
      isNull,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('replay keys work from board focus and keep progress on resize', (
    tester,
  ) async {
    final record = uiRecord(id: 'replay-test', game: winningGame());
    final app = await pumpGomoku(tester, records: [record]);
    await openRoute(tester, app, '/history/replay-test');
    await tester.tapAt(
      tester.getCenter(find.byKey(const ValueKey('game-board'))),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 0);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 9);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump(const Duration(milliseconds: 710));
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
    tester.view.physicalSize = const Size(900, 1200);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(find.byType(Slider)).value, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replay updates when a just-finished record reaches local storage',
    (tester) async {
      final records = StreamController<List<GameRecord>>.broadcast();
      addTearDown(records.close);
      final app = await pumpGomoku(tester, recordStream: records.stream);
      records.add([]);
      await tester.pumpAndSettle();
      await openRoute(tester, app, '/history/late-save');
      expect(find.text('This game could not be found'), findsOneWidget);
      records.add([uiRecord(id: 'late-save', game: winningGame())]);
      await tester.pumpAndSettle();
      expect(find.byType(GameBoard), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 9);
      expect(tester.takeException(), isNull);
    },
  );
}
