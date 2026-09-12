import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../data/api.dart';
import 'app_state.dart';

final activeRoomProvider = FutureProvider<RoomSnapshot?>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.hasSession) return null;
  return ref.read(apiProvider).client.room.activeRoom();
});

final class OnlineState {
  const OnlineState({
    this.room,
    this.busy = false,
    this.connected = false,
    this.error,
  });
  final RoomSnapshot? room;
  final bool busy;
  final bool connected;
  final String? error;
  OnlineState copyWith({
    RoomSnapshot? room,
    bool? busy,
    bool? connected,
    String? error,
  }) => OnlineState(
    room: room ?? this.room,
    busy: busy ?? this.busy,
    connected: connected ?? this.connected,
    error: error,
  );
}

final onlineProvider = NotifierProvider<OnlineController, OnlineState>(
  OnlineController.new,
);

class OnlineController extends Notifier<OnlineState> {
  StreamSubscription<RoomSnapshot>? _subscription;
  Timer? _heartbeat;
  Timer? _retry;
  int _generation = 0;
  int _attempt = 0;
  String? _savedGame;

  @override
  OnlineState build() {
    ref.watch(ownerProvider);
    _generation++;
    ref.onDispose(() {
      _generation++;
      _heartbeat?.cancel();
      _retry?.cancel();
      unawaited(_subscription?.cancel());
    });
    return const OnlineState();
  }

  Future<RoomSnapshot> create() async {
    if (state.busy) throw const ApiFailure('please_wait');
    state = state.copyWith(busy: true);
    try {
      await ref.read(authProvider.notifier).ensureGuest();
      final id = const Uuid().v4();
      final room = await _retryRequest(
        () => ref.read(apiProvider).client.room.createRoom(id),
      );
      enter(room);
      ref.invalidate(activeRoomProvider);
      return room;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
      rethrow;
    }
  }

  Future<RoomSnapshot> join(String code) async {
    if (state.busy) throw const ApiFailure('please_wait');
    state = state.copyWith(busy: true);
    try {
      await ref.read(authProvider.notifier).ensureGuest();
      final id = const Uuid().v4();
      final room = await _retryRequest(
        () => ref
            .read(apiProvider)
            .client
            .room
            .joinRoom(code.toUpperCase().trim(), id),
      );
      enter(room);
      ref.invalidate(activeRoomProvider);
      return room;
    } catch (_) {
      if (ref.mounted) state = state.copyWith(busy: false);
      rethrow;
    }
  }

  Future<void> load(String roomId) async {
    if (state.room?.roomId == roomId) return;
    await ref.read(authProvider.notifier).ensureGuest();
    final room = await ref.read(apiProvider).client.room.snapshot(roomId);
    enter(room);
  }

  void enter(RoomSnapshot room) {
    state = OnlineState(room: room);
    _attempt = 0;
    _savedGame = null;
    _attach();
  }

  Future<void> send(RoomAction action, {int? row, int? col}) async {
    final room = state.room;
    if (room == null || state.busy) return;
    var command = RoomCommand(
      commandId: const Uuid().v4(),
      expectedRevision: room.revision,
      action: action,
      row: row,
      col: col,
    );
    final playerId = ref.read(authProvider).profile?.playerId;
    bool isCurrentRoom() =>
        ref.mounted &&
        state.room?.roomId == room.roomId &&
        ref.read(authProvider).profile?.playerId == playerId;
    state = state.copyWith(busy: true);
    try {
      for (var conflicts = 0; ; conflicts++) {
        try {
          final updated = await _retryRequest(
            () =>
                ref.read(apiProvider).client.room.command(room.roomId, command),
          );
          if (isCurrentRoom()) {
            _receive(updated);
            if (updated.status == RoomStatus.finished ||
                updated.status == RoomStatus.closed) {
              ref.invalidate(activeRoomProvider);
            }
          }
          return;
        } catch (error) {
          if (!isCurrentRoom() || errorCode(error) != 'stale_revision') rethrow;
          final latest = await ref
              .read(apiProvider)
              .client
              .room
              .snapshot(room.roomId);
          if (!isCurrentRoom()) rethrow;
          _receive(latest);
          // Votes are monotonic in one phase. A move must never be rebased.
          final canRetry =
              conflicts < 2 &&
              latest.gameId == room.gameId &&
              ((action == RoomAction.ready &&
                      latest.status == RoomStatus.waiting) ||
                  (action == RoomAction.rematch &&
                      latest.status == RoomStatus.finished));
          if (!canRetry) rethrow;
          command = RoomCommand(
            commandId: const Uuid().v4(),
            expectedRevision: latest.revision,
            action: action,
          );
        }
      }
    } finally {
      if (isCurrentRoom()) state = state.copyWith(busy: false);
    }
  }

  Future<void> leave() async {
    final room = state.room;
    if (room != null && room.status != RoomStatus.closed) {
      await send(RoomAction.leave);
    }
    _generation++;
    _heartbeat?.cancel();
    _retry?.cancel();
    await _subscription?.cancel();
    if (ref.mounted) {
      state = const OnlineState();
      ref.invalidate(activeRoomProvider);
    }
  }

  void reconnect() {
    if (state.room == null) return;
    _attempt = 0;
    _attach();
  }

  void _attach() {
    final room = state.room;
    if (room == null || !ref.mounted) return;
    final generation = ++_generation;
    _heartbeat?.cancel();
    _retry?.cancel();
    unawaited(_subscription?.cancel());
    final connection = const Uuid().v4();
    final api = ref.read(apiProvider).client;
    state = state.copyWith(connected: false);
    _subscription = api.room
        .watch(room.roomId, connection)
        .listen(
          (snapshot) {
            if (!ref.mounted || generation != _generation) return;
            _attempt = 0;
            _receive(snapshot);
            state = state.copyWith(connected: true);
          },
          onError: (Object error) {
            if (ref.mounted && generation == _generation) {
              _scheduleReconnect(error);
            }
          },
          onDone: () {
            if (ref.mounted &&
                generation == _generation &&
                state.room?.status != RoomStatus.closed) {
              _scheduleReconnect(const ApiFailure('connection_lost'));
            }
          },
        );
    var sendingHeartbeat = false;
    _heartbeat = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!ref.mounted || generation != _generation || sendingHeartbeat) return;
      sendingHeartbeat = true;
      try {
        await api.room.heartbeat(room.roomId, connection);
      } catch (error) {
        if (ref.mounted && generation == _generation) _scheduleReconnect(error);
      } finally {
        sendingHeartbeat = false;
      }
    });
  }

  void _scheduleReconnect(Object error) {
    if (_retry?.isActive ?? false) return;
    state = state.copyWith(connected: false, error: errorCode(error));
    _heartbeat?.cancel();
    final seconds = min(10, 1 << min(_attempt++, 4));
    _retry = Timer(Duration(seconds: seconds), () {
      if (ref.mounted) _attach();
    });
  }

  void _receive(RoomSnapshot room) {
    if (!ref.mounted) return;
    final current = state.room;
    if (current != null &&
        current.roomId == room.roomId &&
        current.revision > room.revision) {
      return;
    }
    final profile = ref.read(authProvider).profile;
    if (profile == null ||
        (room.hostPlayerId != profile.playerId &&
            room.guestPlayerId != profile.playerId)) {
      return;
    }
    state = state.copyWith(room: room);
    final game = GameState.fromJson(
      jsonDecode(room.gameJson) as Map<String, dynamic>,
    );
    if (game.isOver &&
        _savedGame != room.gameId &&
        room.guestPlayerId != null) {
      _savedGame = room.gameId;
      unawaited(_saveFinished(room, game));
    }
  }

  Future<void> _saveFinished(RoomSnapshot room, GameState game) async {
    final owner = ref.read(ownerProvider);
    final hostBlack = room.blackPlayerId == room.hostPlayerId;
    try {
      await ref
          .read(databaseProvider)
          .save(
            owner,
            GameRecord(
              id: room.gameId,
              game: game,
              source: RecordSource.online,
              startedAt: room.gameStartedAt,
              updatedAt: room.updatedAt,
              blackName: hostBlack ? room.hostName : room.guestName!,
              whiteName: hostBlack ? room.guestName! : room.hostName,
              roomCode: room.code,
            ),
          );
      if (ref.mounted) unawaited(ref.read(syncProvider.notifier).sync());
    } catch (_) {
      _savedGame = null;
      if (ref.mounted) state = state.copyWith(error: 'storage_unavailable');
    }
  }

  Future<T> _retryRequest<T>(Future<T> Function() request) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await request();
      } catch (error) {
        if (error is AppException || attempt >= 1) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
  }
}
