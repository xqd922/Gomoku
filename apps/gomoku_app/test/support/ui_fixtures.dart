import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';
import 'package:gomoku_flutter/app.dart';
import 'package:gomoku_flutter/data/api.dart';
import 'package:gomoku_flutter/state/app_state.dart';
import 'package:gomoku_flutter/state/online.dart';
import 'package:gomoku_flutter/state/settings.dart';
import 'package:gomoku_flutter/ui/shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> loadUiFont() async {
  final loader = FontLoader('NotoSansSC')
    ..addFont(rootBundle.load('assets/fonts/NotoSansSC.ttf'));
  await loader.load();
}

GameState winningGame() {
  var game = GameState.newGame();
  for (var col = 7; col < 12; col++) {
    game = game.play(7, col);
    if (col < 11) game = game.play(8, col);
  }
  return game;
}

GameRecord uiRecord({
  String id = 'local-test',
  GameState? game,
  RecordSource source = RecordSource.local,
  DateTime? date,
}) => GameRecord(
  id: id,
  game: game ?? GameState.newGame(),
  source: source,
  startedAt: date ?? DateTime.utc(2026, 9, 12, 10),
  updatedAt: date ?? DateTime.utc(2026, 9, 12, 10),
  blackName: 'Robin',
  whiteName: 'Alex',
);

RoomSnapshot uiRoom({RoomStatus status = RoomStatus.playing, GameState? game}) {
  final now = DateTime.now().toUtc();
  return RoomSnapshot(
    roomId: 'room-test',
    code: 'ABC234',
    revision: 1,
    status: status,
    hostPlayerId: 'host',
    hostName: 'Robin',
    guestPlayerId: 'guest',
    guestName: 'Alex',
    hostReady: false,
    guestReady: false,
    blackPlayerId: 'host',
    whitePlayerId: 'guest',
    gameId: 'online-test',
    gameJson: jsonEncode((game ?? GameState.newGame()).toJson()),
    round: 1,
    hostConnected: true,
    guestConnected: true,
    createdAt: now,
    updatedAt: now,
    gameStartedAt: now,
    serverTime: now,
    resumeDeadline: status == RoomStatus.paused
        ? now.add(const Duration(seconds: 120))
        : null,
  );
}

class UiAuth extends AuthController {
  UiAuth({this.profile, this.loginSucceeds = false});
  final PlayerProfile? profile;
  final bool loginSucceeds;
  @override
  AuthState build() => AuthState(profile: profile, hasSession: profile != null);
  @override
  Future<void> restore({bool force = false}) async {}
  @override
  Future<void> login(String email, String password) async {
    if (!loginSucceeds) throw const ApiFailure('invalid_credentials');
    state = AuthState(
      profile: PlayerProfile(
        playerId: 'host',
        nickname: 'Player one',
        isGuest: false,
      ),
      hasSession: true,
    );
  }
}

class UiSync extends SyncController {
  @override
  SyncState build() => const SyncState();
  @override
  Future<void> sync() async {}
}

class UiLocal extends LocalGameController {
  UiLocal(this.initial);
  final GameRecord initial;
  @override
  GameRecord? build() => initial;
  @override
  Future<void> start({bool fresh = false}) async {
    if (fresh) state = uiRecord(id: 'new-local');
  }

  @override
  Future<void> play(int row, int col) async {
    state = state!.copyWith(game: state!.game.play(row, col));
  }

  @override
  Future<void> undo() async {
    state = state!.copyWith(game: state!.game.undoLast());
  }
}

class UiOnline extends OnlineController {
  UiOnline(this.initial);
  final OnlineState initial;
  final sent = <RoomAction>[];
  final joinedCodes = <String>[];
  @override
  OnlineState build() => initial;
  void receive(RoomSnapshot room, {bool connected = true}) {
    state = OnlineState(room: room, connected: connected);
  }

  @override
  Future<void> load(String roomId) async {}
  @override
  Future<RoomSnapshot> join(String code) async {
    joinedCodes.add(code);
    return uiRoom();
  }

  @override
  Future<void> send(RoomAction action, {int? row, int? col}) async {
    sent.add(action);
    final room = state.room!;
    if (action == RoomAction.move) {
      final game = GameState.fromJson(
        jsonDecode(room.gameJson) as Map<String, dynamic>,
      );
      receive(
        room.copyWith(
          gameJson: jsonEncode(game.play(row!, col!).toJson()),
          revision: room.revision + 1,
        ),
      );
    }
  }

  @override
  Future<void> leave() async {
    sent.add(RoomAction.leave);
    state = const OnlineState();
  }

  @override
  Future<void> reconnect() async {}
}

class UiHarness {
  UiHarness(this.container, this.router, this.preferences, this.online);
  final ProviderContainer container;
  final GoRouter router;
  final SharedPreferences preferences;
  final UiOnline online;
}

Future<UiHarness> pumpGomoku(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  String language = 'en',
  double scale = 1,
  ThemeMode theme = ThemeMode.light,
  List<GameRecord> records = const [],
  Stream<List<GameRecord>>? recordStream,
  GameRecord? local,
  RoomSnapshot? room,
  List<RoomSnapshot> lobbyRooms = const [],
  bool connected = true,
  ServiceConfig serviceConfig = const ServiceConfig(
    authMode: 'email',
    guestOnline: true,
  ),
  bool configUnavailable = false,
  bool loginSucceeds = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  SharedPreferences.setMockInitialValues({
    'guestScope': 'guest:ui-test',
    'nickname': 'Robin',
    'settings': jsonEncode({
      'language': language,
      'theme': theme.name,
      'dynamicColor': false,
      'reduceMotion': true,
      'sound': false,
      'haptics': false,
    }),
  });
  final preferences = await SharedPreferences.getInstance();
  final online = UiOnline(OnlineState(room: room, connected: connected));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preferencesProvider.overrideWithValue(preferences),
        authProvider.overrideWith(
          () => UiAuth(
            loginSucceeds: loginSucceeds,
            profile: room == null
                ? null
                : PlayerProfile(
                    playerId: 'host',
                    nickname: 'Robin',
                    isGuest: true,
                  ),
          ),
        ),
        syncProvider.overrideWith(UiSync.new),
        backendHealthProvider.overrideWith((_) async => true),
        serviceConfigProvider.overrideWith(
          (_) async {
            if (configUnavailable) {
              throw const ApiFailure('service_unavailable');
            }
            return serviceConfig;
          },
        ),
        gamesProvider.overrideWith(
          (_) => recordStream ?? Stream.value(records),
        ),
        localGameProvider.overrideWith(() => UiLocal(local ?? uiRecord())),
        onlineProvider.overrideWith(() => online),
        lobbyRoomsProvider.overrideWith((_) => Stream.value(lobbyRooms)),
        activeRoomProvider.overrideWith((ref) async {
          final room = ref.watch(onlineProvider).room;
          return room?.status == RoomStatus.closed ? null : room;
        }),
      ],
      child: const GomokuApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(AppShell));
  return UiHarness(
    ProviderScope.containerOf(context),
    GoRouter.of(context),
    preferences,
    online,
  );
}

Future<void> openRoute(WidgetTester tester, UiHarness app, String path) async {
  app.router.go(path);
  await tester.pumpAndSettle();
}
