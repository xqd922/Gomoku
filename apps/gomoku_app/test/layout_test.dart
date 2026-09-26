import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:gomoku_flutter/ui/widgets/board.dart';

import 'support/ui_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFont);
  for (final (size, language, scale, theme) in [
    (const Size(360, 640), 'zh', 1.0, ThemeMode.light),
    (const Size(390, 844), 'en', 1.0, ThemeMode.dark),
    (const Size(844, 390), 'en', 1.0, ThemeMode.light),
    (const Size(900, 1200), 'en', 1.0, ThemeMode.light),
    (const Size(1440, 1000), 'zh', 1.0, ThemeMode.dark),
    (const Size(390, 844), 'en', 2.0, ThemeMode.light),
    (const Size(360, 640), 'zh', 2.0, ThemeMode.dark),
    (const Size(599, 800), 'en', 1.0, ThemeMode.light),
    (const Size(600, 800), 'en', 1.0, ThemeMode.dark),
    (const Size(839, 800), 'en', 1.0, ThemeMode.light),
    (const Size(840, 800), 'en', 1.0, ThemeMode.dark),
  ]) {
    testWidgets(
      'adaptive navigation and personal pages at $size $language scale $scale $theme',
      (tester) async {
        final app = await pumpGomoku(
          tester,
          size: size,
          language: language,
          scale: scale,
          theme: theme,
        );
        final wide = size.width >= 840;
        expect(
          find.byType(NavigationBar),
          wide ? findsNothing : findsOneWidget,
        );
        expect(
          find.byType(NavigationRail),
          wide ? findsOneWidget : findsNothing,
        );
        final labels = language == 'zh'
            ? ['对弈', '联机', '棋谱', '我的']
            : ['Play', 'Online', 'Library', 'Me'];
        for (final label in labels) {
          expect(
            wide ? find.text(label) : find.byTooltip(label),
            wide ? findsWidgets : findsOneWidget,
            reason: label,
          );
        }
        expect(find.text(language == 'zh' ? '对弈' : 'Play'), findsWidgets);
        expect(find.text(language == 'zh' ? '棋谱' : 'Library'), findsWidgets);
        expect(tester.takeException(), isNull);
        await openRoute(tester, app, '/me');
        expect(
          find.text(language == 'zh' ? '你的配色' : 'Your palette'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await openRoute(tester, app, '/account');
        expect(
          find.text(language == 'zh' ? '你的配色' : 'Your palette'),
          findsOneWidget,
        );
        await openRoute(tester, app, '/join/ABC234');
        expect(find.widgetWithText(TextFormField, 'ABC234'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('theme choice persists across the me and library tabs', (
    tester,
  ) async {
    final app = await pumpGomoku(tester);
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
    expect(app.router.routeInformationProvider.value.uri.path, '/history');
    await tester.tap(find.byTooltip('Me'));
    await tester.pumpAndSettle();
    final appearance = find.widgetWithText(ListTile, 'Appearance');
    await tester.ensureVisible(appearance);
    await tester.tap(appearance);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(app.container.read(settingsProvider).theme, ThemeMode.dark);
    expect(jsonDecode(app.preferences.getString('settings')!)['theme'], 'dark');
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
    expect(app.router.routeInformationProvider.value.uri.path, '/history');
    expect(tester.takeException(), isNull);
  });

  testWidgets('library keeps its filter and scroll position across tabs', (
    tester,
  ) async {
    await pumpGomoku(
      tester,
      records: [
        for (var i = 0; i < 30; i++)
          uiRecord(
            id: 'game-$i',
            game: winningGame(),
            source: RecordSource.online,
            date: DateTime.utc(2026, 9, 12, 10, i),
          ),
      ],
    );
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'With friends'));
    await tester.pumpAndSettle();
    final library = find.byType(CustomScrollView);
    await tester.drag(library, const Offset(0, -480));
    await tester.pumpAndSettle();
    final scrollable = find
        .descendant(of: library, matching: find.byType(Scrollable))
        .first;
    final offset = tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset, greaterThan(100));
    await tester.tap(find.byTooltip('Play'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Library'));
    await tester.pumpAndSettle();
    expect(
      tester.state<ScrollableState>(scrollable).position.pixels,
      closeTo(offset, .1),
    );
    await tester.drag(library, const Offset(0, 600));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'With friends'))
          .selected,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  for (final size in [
    const Size(360, 640),
    const Size(844, 390),
    const Size(900, 1200),
    const Size(1440, 1000),
  ]) {
    testWidgets('the board and move action fit the viewport $size', (
      tester,
    ) async {
      final app = await pumpGomoku(tester, size: size);
      await openRoute(tester, app, '/local');
      final board = find.byKey(const ValueKey('game-board'));
      final confirm = find.byKey(const ValueKey('confirm-move'));
      final bounds = tester.getRect(board);
      final action = tester.getRect(confirm);
      expect(bounds.width, closeTo(bounds.height, .1));
      expect(bounds.top, greaterThanOrEqualTo(0));
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      expect(action.bottom, lessThanOrEqualTo(size.height));
      expect(action.right, lessThanOrEqualTo(size.width));
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tapAt(tester.getCenter(board));
      await tester.pumpAndSettle();
      expect(tester.getRect(board), bounds);
      expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('large text keeps every game action reachable', (tester) async {
    final app = await pumpGomoku(tester, size: const Size(360, 640), scale: 2);
    await openRoute(tester, app, '/local');
    final board = find.byType(GameBoard);
    await tester.ensureVisible(board);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('confirm-move')), findsOneWidget);
    final action = tester.getRect(find.byKey(const ValueKey('confirm-move')));
    expect(action.bottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  for (final (size, language, scale) in [
    (const Size(360, 640), 'zh', 1.0),
    (const Size(360, 640), 'zh', 2.0),
    (const Size(844, 390), 'en', 2.0),
    (const Size(900, 1200), 'en', 1.0),
  ]) {
    testWidgets('room and replay states fit $size $language scale $scale', (
      tester,
    ) async {
      final record = uiRecord(id: 'finished', game: winningGame());
      final app = await pumpGomoku(
        tester,
        size: size,
        language: language,
        scale: scale,
        room: uiRoom(status: RoomStatus.waiting),
        records: [record],
      );
      await openRoute(tester, app, '/room/room-test');
      final ready = find.byKey(const ValueKey('ready-room'));
      await tester.ensureVisible(ready);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final room in [
        uiRoom(),
        uiRoom(status: RoomStatus.paused),
        uiRoom(game: GameState.newGame().play(7, 7))
            .copyWith(undoRequestedBy: 'guest'),
        uiRoom(status: RoomStatus.finished, game: winningGame()),
      ]) {
        app.online.receive(room);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await openRoute(tester, app, '/history/finished');
      expect(tester.takeException(), isNull);
      final last = find.byTooltip(language == 'zh' ? '最后一手' : 'Last position');
      await tester.ensureVisible(last);
      await tester.pumpAndSettle();
      expect(find.byType(GameBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
