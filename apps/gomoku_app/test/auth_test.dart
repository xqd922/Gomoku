import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_flutter/data/api.dart';
import 'package:gomoku_flutter/state/app_state.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FakeApi implements Api {
  FakeApi({this.logoutSucceeds = true});
  final bool logoutSucceeds;
  final calls = <String>[];
  bool cleared = false;
  @override
  String? token;
  @override
  final http.Client httpClient = http.Client();

  // Auth flows never touch the Serverpod channel; leave it unassigned.
  @override
  late final Client client;
  @override
  Future<void> load() async {}
  @override
  Future<Map<String, dynamic>> auth(
    String action,
    Map<String, Object?> body, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    calls.add(action);
    if (!logoutSucceeds) throw const ApiFailure('service_unavailable');
    return {'ok': true};
  }

  @override
  Future<void> clearCredential() async => cleared = true;
  @override
  Future<bool> healthy() async => false;
  @override
  Future<ServiceConfig> serviceConfig() => throw UnimplementedError();
  @override
  void close() {}
}

Future<(ProviderContainer, FakeApi)> _container({
  required bool logoutSucceeds,
}) async {
  SharedPreferences.setMockInitialValues({
    'guestScope': 'guest:old-scope',
    Api.profileStorageKey: 'profile-payload',
    'profile': 'legacy-payload',
  });
  final prefs = await SharedPreferences.getInstance();
  final api = FakeApi(logoutSucceeds: logoutSucceeds);
  final container = ProviderContainer(
    overrides: [
      preferencesProvider.overrideWithValue(prefs),
      apiProvider.overrideWithValue(api),
    ],
  );
  return (container, api);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'logout clears local credentials after a successful server logout',
    () async {
      final (container, api) = await _container(logoutSucceeds: true);
      addTearDown(container.dispose);
      final prefs = container.read(preferencesProvider);
      await container.read(authProvider.notifier).logout();
      expect(api.calls, ['logout']);
      expect(api.cleared, isTrue);
      expect(prefs.getString('guestScope'), isNot('guest:old-scope'));
      expect(prefs.getString(Api.profileStorageKey), isNull);
      expect(prefs.getString('profile'), isNull);
      final auth = container.read(authProvider);
      expect(auth.profile, isNull);
      expect(auth.hasSession, isFalse);
    },
  );

  test(
    'logout still clears local credentials when the service is unreachable',
    () async {
      final (container, api) = await _container(logoutSucceeds: false);
      addTearDown(container.dispose);
      final prefs = container.read(preferencesProvider);
      await container.read(authProvider.notifier).logout();
      expect(api.calls, ['logout']);
      expect(api.cleared, isTrue);
      expect(prefs.getString('guestScope'), isNot('guest:old-scope'));
      expect(prefs.getString(Api.profileStorageKey), isNull);
      expect(prefs.getString('profile'), isNull);
      final auth = container.read(authProvider);
      expect(auth.profile, isNull);
      expect(auth.hasSession, isFalse);
    },
  );
}
