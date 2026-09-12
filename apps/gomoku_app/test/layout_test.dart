import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_flutter/app.dart';
import 'package:gomoku_flutter/state/app_state.dart';
import 'package:gomoku_flutter/state/online.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _OfflineAuth extends AuthController {
  @override
  AuthState build() => const AuthState();
}

void main() {
  for (final (size, language, scale) in [
    (const Size(390, 844), 'zh', 1.0),
    (const Size(844, 390), 'en', 1.0),
    (const Size(900, 1200), 'en', 1.0),
    (const Size(1440, 1000), 'zh', 1.0),
    (const Size(390, 844), 'en', 2.0),
  ]) {
    testWidgets('responsive navigation $size $language at text scale $scale', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({
        'guestScope': 'guest:test',
        'settings': jsonEncode({
          'language': language,
          'dynamicColor': false,
          'reduceMotion': true,
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesProvider.overrideWithValue(preferences),
            authProvider.overrideWith(_OfflineAuth.new),
            backendHealthProvider.overrideWith((_) async => true),
            gamesProvider.overrideWith((_) => Stream.value([])),
            activeRoomProvider.overrideWith((_) async => null),
          ],
          child: const GomokuApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (size.width >= 720) {
        expect(find.byType(NavigationRail), findsOneWidget);
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .onDestinationSelected!(3);
      } else {
        expect(find.byType(NavigationBar), findsOneWidget);
        tester
            .widget<NavigationBar>(find.byType(NavigationBar))
            .onDestinationSelected!(3);
      }
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'zh' ? '让它，更像你。' : 'Make yourself at home.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    });
  }
}
