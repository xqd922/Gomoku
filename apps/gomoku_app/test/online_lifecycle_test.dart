import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_flutter/state/app_state.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RefreshAuth extends AuthController {
  @override
  AuthState build() => AuthState(profile: profile(), hasSession: true);
  PlayerProfile profile() => PlayerProfile(
    playerId: 'same-player',
    nickname: 'Player',
    isGuest: false,
  );
  void refresh({bool hasSession = true}) {
    state = AuthState(profile: profile(), hasSession: hasSession);
  }

  void revoke() => state = const AuthState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('same-identity session restoration keeps pending room work mounted', () async {
    SharedPreferences.setMockInitialValues({'guestScope': 'guest:fixture'});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith(RefreshAuth.new),
      ],
    );
    addTearDown(container.dispose);
    // Async room work checks ref.mounted immediately after restoring a session.
    final roomLifetime = Provider<bool Function()>((ref) {
      ref.watch(ownerProvider);
      return () => ref.mounted;
    });
    final mounted = container.read(roomLifetime);
    final auth = container.read(authProvider.notifier) as RefreshAuth;
    auth.refresh(hasSession: false);
    expect(mounted(), isTrue);
    auth.refresh();
    expect(mounted(), isTrue);
    expect(container.read(ownerProvider), 'player:same-player');
    auth.revoke();
    expect(container.read(ownerProvider), 'guest:fixture');
    container.read(roomLifetime);
    expect(mounted(), isFalse);
  });
}
