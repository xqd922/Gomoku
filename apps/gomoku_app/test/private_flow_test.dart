import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_flutter/data/api.dart';

import 'support/ui_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFont);
  const private = ServiceConfig(authMode: 'private', guestOnline: false);

  testWidgets(
    'private invite survives login and still requires an explicit join',
    (tester) async {
      final app = await pumpGomoku(
        tester,
        serviceConfig: private,
        loginSucceeds: true,
      );
      await openRoute(tester, app, '/join/ABC234');
      expect(find.byKey(const ValueKey('join-room')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('lobby-login')));
      await tester.pumpAndSettle();
      expect(
        app
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['returnTo'],
        '/join/ABC234',
      );
      expect(find.text('Register'), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      expect(find.text('Enter 1 or 2, or use your email'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        '48271635',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('account-submit')));
      await tester.tap(find.byKey(const ValueKey('account-submit')));
      await tester.pumpAndSettle();
      expect(
        app.router.routeInformationProvider.value.uri.path,
        '/join/ABC234',
      );
      expect(find.byKey(const ValueKey('join-room')), findsOneWidget);
      final field = tester.widget<TextFormField>(
        find.byKey(const ValueKey('join-room-code')),
      );
      expect(field.controller!.text, 'ABC234');
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('room-nickname')))
            .controller!
            .text,
        'Player one',
      );
      expect(app.online.sent, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'configuration outage keeps local play available and online retry reachable',
    (tester) async {
      final app = await pumpGomoku(tester, configUnavailable: true);
      await openRoute(tester, app, '/local');
      expect(find.byKey(const ValueKey('game-board')), findsOneWidget);
      await openRoute(tester, app, '/lobby');
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byKey(const ValueKey('create-room')), findsNothing);
      await openRoute(tester, app, '/account');
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('account-submit')))
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a room without a session provides sign-in instead of a spinner',
    (tester) async {
      final app = await pumpGomoku(tester, serviceConfig: private);
      await openRoute(tester, app, '/room/expired-session-room');
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final login = find.widgetWithText(FilledButton, 'Sign in');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();
      expect(app.router.routeInformationProvider.value.uri.path, '/account');
      expect(
        app
            .router
            .routeInformationProvider
            .value
            .uri
            .queryParameters['returnTo'],
        '/lobby',
      );
    },
  );

  test('terminal room and identity errors never trigger automatic retries', () {
    for (final code in [
      'unauthenticated',
      'account_not_allowed',
      'not_a_player',
      'room_not_found',
      'room_closed',
      'room_expired',
      'stale_revision',
    ]) {
      expect(retryableFailure(AppException(code: code)), isFalse, reason: code);
    }
    expect(retryableFailure(const ApiFailure('connection_lost')), isTrue);
    expect(retryableFailure(const ApiFailure('service_unavailable')), isTrue);
    expect(sessionFailure(const ApiFailure('account_not_allowed')), isTrue);
  });

  test('invalid public configuration fails closed', () {
    expect(
      () =>
          ServiceConfig.fromJson({'authMode': 'private', 'guestOnline': true}),
      throwsA(isA<ApiFailure>()),
    );
    expect(
      () =>
          ServiceConfig.fromJson({'authMode': 'unknown', 'guestOnline': false}),
      throwsA(isA<ApiFailure>()),
    );
  });
}
