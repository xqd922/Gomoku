import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_flutter/data/api.dart';

import 'support/ui_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadUiFont);
  // Simulates a server that has not been upgraded yet; clients keep working
  // with a plain email sign-in until then.
  const legacyPrivate = ServiceConfig(authMode: 'private', guestOnline: false);

  testWidgets(
    'email sign-in from a room returns to the lobby and exposes registration',
    (tester) async {
      final app = await pumpGomoku(tester, loginSucceeds: true);
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
      expect(find.text('Your games, wherever you go.'), findsOneWidget);
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
      expect(find.text('Choose account'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'player@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'correct-password',
      );
      final submit = find.byKey(const ValueKey('account-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(app.router.routeInformationProvider.value.uri.path, '/lobby');
      expect(find.byKey(const ValueKey('create-room')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'a not-yet-upgraded private server still receives a plain email sign-in',
    (tester) async {
      final app = await pumpGomoku(
        tester,
        serviceConfig: legacyPrivate,
        loginSucceeds: true,
      );
      await openRoute(tester, app, '/account');
      expect(find.byKey(const ValueKey('account-email')), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
      expect(find.text('Forgot password?'), findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('account-email')),
        'player1@example.test',
      );
      await tester.enterText(
        find.byKey(const ValueKey('account-password')),
        'correct-password',
      );
      final submit = find.byKey(const ValueKey('account-submit'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(find.text('Account details'), findsOneWidget);
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
