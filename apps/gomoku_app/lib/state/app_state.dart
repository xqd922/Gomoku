import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gomoku_client/gomoku_client.dart';
import 'package:gomoku_core/gomoku_core.dart';

import '../data/api.dart';
import '../data/database.dart';
import 'settings.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => unawaited(db.close()));
  return db;
});
final apiProvider = Provider<Api>((ref) {
  final api = Api();
  ref.onDispose(api.close);
  return api;
});
final backendHealthProvider = FutureProvider<bool>(
  (ref) => ref.watch(apiProvider).healthy(),
);

final class AuthState {
  const AuthState({
    this.profile,
    this.resolving = false,
    this.hasSession = false,
  });
  final PlayerProfile? profile;
  final bool resolving;
  final bool hasSession;
}

final authProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
final ownerProvider = Provider<String>((ref) {
  final profile = ref.watch(authProvider).profile;
  if (profile != null && !profile.isGuest) return 'player:${profile.playerId}';
  return ref.watch(preferencesProvider).getString('guestScope')!;
});
final gamesProvider = StreamProvider<List<GameRecord>>(
  (ref) => ref.watch(databaseProvider).watchGames(ref.watch(ownerProvider)),
);
final recordProvider = FutureProvider.family<GameRecord?, String>(
  (ref, id) => ref.watch(databaseProvider).find(ref.watch(ownerProvider), id),
);

class AuthController extends Notifier<AuthState> {
  Future<void>? _restoring;
  @override
  AuthState build() {
    final prefs = ref.read(preferencesProvider);
    PlayerProfile? cached;
    try {
      final raw = prefs.getString('profile');
      if (raw != null) {
        cached = PlayerProfile.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      /* The server will restore the authoritative profile. */
    }
    Future.microtask(restore);
    return AuthState(profile: cached, resolving: true);
  }

  Future<void> restore({bool force = false}) {
    if (state.hasSession && !force) return Future.value();
    return _restoring ??= _restore().whenComplete(() => _restoring = null);
  }

  Future<void> _restore() async {
    final api = ref.read(apiProvider);
    try {
      await api.load();
      if (!kIsWeb && api.token == null) {
        if (ref.mounted) state = const AuthState();
        return;
      }
      final result = await api.auth(
        'session',
        {},
        timeout: const Duration(seconds: 4),
      );
      if (ref.mounted) await _accept(result, sync: true);
    } catch (error) {
      if (!ref.mounted) return;
      if (errorCode(error) == 'unauthenticated') {
        await api.clearCredential();
        await ref.read(preferencesProvider).remove('profile');
        state = const AuthState();
      } else {
        state = AuthState(profile: state.profile);
      }
    }
  }

  Future<PlayerProfile> ensureGuest() async {
    await restore();
    if (state.hasSession && state.profile != null) return state.profile!;
    if (state.profile != null) throw const ApiFailure('service_unavailable');
    final prefs = ref.read(preferencesProvider);
    final result = await ref.read(apiProvider).auth('guest', {
      'nickname':
          prefs.getString('nickname') ??
          '棋友 ${prefs.getString('guestScope')!.substring(6, 10)}',
    });
    await _accept(result);
    return state.profile!;
  }

  Future<String> startRegistration(String email) async =>
      (await ref.read(apiProvider).auth('register-start', {
            'email': email,
          }))['requestId']
          as String;

  Future<void> finishRegistration(
    String requestId,
    String code,
    String password,
    String nickname,
  ) async {
    final result = await ref.read(apiProvider).auth('register-finish', {
      'requestId': requestId,
      'code': code,
      'password': password,
      'nickname': nickname,
    });
    await _accept(result, sync: true);
  }

  Future<void> login(String email, String password) async {
    final result = await ref.read(apiProvider).auth('login', {
      'email': email,
      'password': password,
      'nickname':
          ref.read(preferencesProvider).getString('nickname') ??
          'Gomoku player',
    });
    await _accept(result, sync: true);
  }

  Future<String> startReset(String email) async =>
      (await ref.read(apiProvider).auth('reset-start', {
            'email': email,
          }))['requestId']
          as String;
  Future<void> finishReset(
    String requestId,
    String code,
    String password,
  ) async {
    await ref.read(apiProvider).auth('reset-finish', {
      'requestId': requestId,
      'code': code,
      'password': password,
    });
  }

  Future<void> rename(String nickname) async {
    if (state.profile != null) {
      final profile = await ref
          .read(apiProvider)
          .client
          .profile
          .rename(nickname);
      await _accept({'profile': profile.toJson()});
    }
    await ref.read(preferencesProvider).setString('nickname', nickname);
  }

  Future<void> logout() async {
    await ref.read(apiProvider).auth('logout', {});
    await ref.read(apiProvider).clearCredential();
    final prefs = ref.read(preferencesProvider);
    await prefs.remove('profile');
    await prefs.setString('guestScope', 'guest:${const Uuid().v4()}');
    state = const AuthState();
  }

  Future<void> _accept(Map<String, dynamic> data, {bool sync = false}) async {
    final profile = PlayerProfile.fromJson(
      data['profile'] as Map<String, dynamic>,
    );
    final prefs = ref.read(preferencesProvider);
    if (!profile.isGuest && (state.profile == null || state.profile!.isGuest)) {
      await ref
          .read(databaseProvider)
          .claimGuest(
            prefs.getString('guestScope')!,
            'player:${profile.playerId}',
          );
    }
    await prefs.setString('profile', jsonEncode(profile.toJson()));
    await prefs.setString('nickname', profile.nickname);
    if (!ref.mounted) return;
    state = AuthState(profile: profile, hasSession: true);
    ref.invalidate(backendHealthProvider);
    if (sync && !profile.isGuest) {
      unawaited(ref.read(syncProvider.notifier).sync());
    }
  }
}

final class SyncState {
  const SyncState({this.busy = false, this.error, this.lastSuccess});
  final bool busy;
  final String? error;
  final DateTime? lastSuccess;
}

final syncProvider = NotifierProvider<SyncController, SyncState>(
  SyncController.new,
);

class SyncController extends Notifier<SyncState> {
  @override
  SyncState build() => const SyncState();
  Future<void> sync() async {
    final auth = ref.read(authProvider);
    if (state.busy ||
        !auth.hasSession ||
        auth.profile == null ||
        auth.profile!.isGuest) {
      return;
    }
    final owner = 'player:${auth.profile!.playerId}';
    final db = ref.read(databaseProvider);
    state = SyncState(busy: true, lastSuccess: state.lastSuccess);
    try {
      var more = true;
      while (more) {
        final pending = await db.pending(owner);
        final cursor = await db.cursor(owner);
        final page = await ref
            .read(apiProvider)
            .client
            .profile
            .syncRecords(
              pending.map((r) => jsonEncode(r.toJson())).toList(),
              cursor,
            );
        final records = page.records
            .map(
              (raw) =>
                  GameRecord.fromJson(jsonDecode(raw) as Map<String, dynamic>),
            )
            .toList();
        await db.acceptSync(owner, pending, records, page.cursor);
        more = page.hasMore || pending.length == 50;
        if (!ref.mounted) return;
        if (ref.read(ownerProvider) != owner) {
          state = const SyncState();
          return;
        }
      }
      if (ref.mounted) state = SyncState(lastSuccess: DateTime.now());
    } catch (error) {
      if (ref.mounted) {
        state = SyncState(
          error: errorCode(error),
          lastSuccess: state.lastSuccess,
        );
      }
    }
  }
}

final localGameProvider = NotifierProvider<LocalGameController, GameRecord?>(
  LocalGameController.new,
);

class LocalGameController extends Notifier<GameRecord?> {
  Future<void>? _starting;
  @override
  GameRecord? build() {
    ref.watch(ownerProvider);
    ref.listen(gamesProvider, (_, next) {
      final current = state;
      if (current == null) return;
      final saved = next.asData?.value
          .where((r) => r.id == current.id)
          .firstOrNull;
      if (saved != null &&
          jsonEncode(saved.toJson()) != jsonEncode(current.toJson())) {
        state = saved;
      }
    });
    return null;
  }

  Future<void> start({bool fresh = false}) =>
      _starting ??= _start(fresh: fresh).whenComplete(() => _starting = null);

  Future<void> _start({required bool fresh}) async {
    final db = ref.read(databaseProvider);
    final owner = ref.read(ownerProvider);
    final previous = state ?? await db.unfinished(owner);
    if (!fresh && previous != null && !previous.game.isOver) {
      state = previous;
      return;
    }
    if (previous != null && !previous.game.isOver) {
      await db.saveLocalChange(
        owner,
        previous,
        previous.copyWith(
          game: previous.game.interrupt(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    }
    final time = DateTime.now().toUtc();
    final record = GameRecord(
      id: const Uuid().v4(),
      game: GameState.newGame(),
      source: RecordSource.local,
      startedAt: time,
      updatedAt: time,
    );
    await db.save(owner, record);
    if (ref.mounted && owner == ref.read(ownerProvider)) state = record;
  }

  Future<void> play(int row, int col) async {
    final record = state;
    if (record == null) return;
    final next = record.copyWith(
      game: record.game.play(row, col),
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(record, next);
    if (next.game.isOver) unawaited(ref.read(syncProvider.notifier).sync());
  }

  Future<void> undo() async {
    final record = state;
    if (record == null) return;
    final next = record.copyWith(
      game: record.game.undoLast(),
      updatedAt: DateTime.now().toUtc(),
    );
    await _persist(record, next);
  }

  Future<void> _persist(GameRecord previous, GameRecord next) async {
    final owner = ref.read(ownerProvider);
    final db = ref.read(databaseProvider);
    try {
      await db.saveLocalChange(owner, previous, next);
      if (ref.mounted && owner == ref.read(ownerProvider)) state = next;
    } on LocalGameConflict {
      final latest = await db.find(owner, previous.id);
      if (ref.mounted && owner == ref.read(ownerProvider)) state = latest;
      throw const ApiFailure('local_game_updated');
    }
  }
}
