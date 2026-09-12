@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final server = TestServer(9280, environment: {'GOMOKU_AUTH_MODE': 'private'});
  final open = TestServer(9380);
  late Directory temporary;
  late File accountsFile;
  final firstEmail = 'private-${ids.v4()}@example.test';
  final secondEmail = 'private-${ids.v4()}@example.test';
  const initialPassword = '48271635';
  final accounts = <Map<String, String>>[];
  final clients = <TestPlayer>[];

  Future<ProcessResult> admin(String operation, {File? reset}) => Process.run(
    Platform.resolvedExecutable,
    [
      'bin/main.dart',
      '--mode',
      'test',
      '--server-id',
      'private-admin',
      '--gomoku-admin=$operation',
    ],
    environment: {
      'GOMOKU_AUTH_MODE': 'private',
      'COOKIE_SECURE': 'false',
      'GOMOKU_ACCOUNTS_FILE': accountsFile.absolute.path,
      if (reset != null) 'GOMOKU_RESET_FILE': reset.absolute.path,
    },
  ).timeout(const Duration(seconds: 45));

  Future<TestPlayer> login(
    String email, {
    String password = initialPassword,
  }) async {
    final player = TestPlayer(server, 'Private');
    clients.add(player);
    await player.auth('login', {'email': email, 'password': password});
    return player;
  }

  setUpAll(() async {
    await server.start();
    await open.start();
    final db = await testDatabase();
    await db.execute('DELETE FROM gm_private_accounts');
    await db.close();
    temporary = await Directory.systemTemp.createTemp('gomoku-private-test-');
    accountsFile = File('${temporary.path}/accounts.json');
    accounts.addAll([
      {
        'email': firstEmail,
        'password': initialPassword,
        'nickname': 'Player one',
      },
      {
        'email': secondEmail,
        'password': initialPassword,
        'nickname': 'Player two',
      },
    ]);
    await accountsFile.writeAsString(jsonEncode(accounts));
    final result = await admin('provision');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });
  tearDown(() {
    for (final player in clients) {
      player.close();
    }
    clients.clear();
  });
  tearDownAll(() async {
    await server.stop();
    await open.stop();
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test(
    'private capabilities and HTTP/RPC/stream permissions are enforced',
    () async {
      final response = await http.get(Uri.parse('${server.web}app-config'));
      expect(jsonDecode(response.body), {
        'authMode': 'private',
        'guestOnline': false,
        'registration': false,
        'passwordReset': false,
      });
      expect(response.body, isNot(contains(firstEmail)));
      final anonymous = TestPlayer(server, 'Anonymous');
      clients.add(anonymous);
      for (final action in [
        'guest',
        'register-start',
        'register-finish',
        'reset-start',
        'reset-finish',
      ]) {
        await expectLater(
          anonymous.auth(action, {}),
          authError('feature_disabled'),
        );
      }
      final outsider = TestPlayer(open, 'Outsider');
      clients.add(outsider);
      await outsider.guest();
      anonymous.token = outsider.token;
      await expectLater(
        anonymous.auth('session', {}),
        authError('account_not_allowed'),
      );
      await expectLater(
        anonymous.client.room.createRoom(ids.v4()),
        throwsA(isA<ServerpodClientUnauthorized>()),
      );
      await expectLater(
        anonymous.client.room.watch(ids.v4(), ids.v4()),
        emitsError(isA<Object>()),
      );
      await outsider.register();
      await expectLater(
        anonymous.auth('login', {
          'email': outsider.email,
          'password': TestPlayer.password,
        }),
        authError('account_not_allowed'),
      );
      anonymous.token = null;
      await expectLater(
        anonymous.auth('login', {
          'email': firstEmail,
          'password': 'wrong-password',
        }),
        authError('invalid_credentials'),
      );
      await expectLater(
        anonymous.auth('login', {'email': '3', 'password': initialPassword}),
        authError('invalid_credentials'),
      );
      await expectLater(
        outsider.auth('login', {'email': '1', 'password': initialPassword}),
        authError('invalid_credentials'),
      );
    },
  );

  test('two fixed identities persist, synchronize records, and enforce active seats', () async {
    final a = await login(firstEmail);
    final b = await login(secondEmail);
    final id = a.profile!.playerId;
    final record = localRecord();
    await a.client.profile.syncRecords([jsonEncode(record.toJson())], '');
    expect((await b.client.profile.syncRecords([], '')).records, isEmpty);
    // Simulate the added, nullable alias column on an existing deployment.
    final db = await testDatabase();
    await db.execute('UPDATE gm_private_accounts SET login_name=NULL');
    await db.close();
    final result = await admin('provision');
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
    final again = await login('1');
    expect(again.profile!.playerId, id);
    expect((await login('2')).profile!.playerId, b.profile!.playerId);
    expect((await login(firstEmail)).profile!.playerId, id);
    expect(
      (await again.client.profile.syncRecords([], '')).records.single,
      contains(record.id),
    );
    final room = await TestRoom.open(a, b);
    try {
      await expectLater(
        again.client.room.createRoom(ids.v4()),
        appError('active_room'),
      );
      for (var col = 0; col < 5; col++) {
        await a.send(room.id, RoomAction.move, row: 0, col: col);
        if (col < 4) await b.send(room.id, RoomAction.move, row: 1, col: col);
      }
      await room.second.until((r) => r.status == RoomStatus.finished);
    } finally {
      await room.close();
    }
  });

  test(
    'pending application migrations do not invalidate private sessions',
    () async {
      final signedIn = await login('1');
      final restarting = TestServer(
        9480,
        environment: {'GOMOKU_AUTH_MODE': 'private'},
      );
      final db = await testDatabase();
      await db.execute('SELECT pg_advisory_lock(7744112200)');
      final started = restarting.start();
      addTearDown(() async {
        await started;
        await restarting.stop();
      });
      final client = TestPlayer(restarting, 'Restart')..token = signedIn.token;
      clients.add(client);
      Future<RoomSnapshot?>? pendingRpc;
      Future<Map<String, dynamic>>? pendingSession;
      try {
        await eventually(() async {
          try {
            return (await http.get(Uri.parse('${restarting.web}app-config')))
                    .statusCode ==
                200;
          } catch (_) {
            return false;
          }
        }, timeout: const Duration(seconds: 45));
        pendingSession = client.auth('session', {});
        pendingRpc = client.client.room.activeRoom();
        final web = await http.post(
          Uri.parse('${restarting.web}auth/session'),
          headers: {
            'content-type': 'application/json',
            'x-gomoku-client': 'web',
            'origin': 'http://localhost:4280',
            'cookie': 'gomoku_session=${signedIn.token}',
          },
          body: '{}',
        );
        expect(web.statusCode, 503);
        expect(jsonDecode(web.body)['error'], 'service_unavailable');
      } finally {
        await db.execute('SELECT pg_advisory_unlock(7744112200)');
        await db.close();
      }
      await started;
      expect(await pendingRpc, isNull);
      await pendingSession;
      expect(client.profile!.playerId, signedIn.profile!.playerId);
    },
  );

  test(
    'admin password reset revokes sessions and provisioning does not reset it',
    () async {
      final host = await login(firstEmail);
      final previous = await login(secondEmail);
      final room = await TestRoom.open(host, previous);
      addTearDown(room.close);
      const nextPassword = '93751628';
      final file = File('${temporary.path}/reset.json');
      await file.writeAsString(
        jsonEncode({'email': '2', 'password': nextPassword}),
      );
      final reset = await admin('reset-password', reset: file);
      expect(reset.exitCode, 0, reason: '${reset.stdout}\n${reset.stderr}');
      await eventually(
        () => room.second.streamEnded,
        timeout: const Duration(seconds: 15),
        reason: 'Revoked session must close its existing subscription.',
      );
      await room.first.until((r) => r.status == RoomStatus.paused);
      await expectLater(
        previous.auth('session', {}),
        authError('unauthenticated'),
      );
      final seeded = await admin('provision');
      expect(seeded.exitCode, 0, reason: '${seeded.stdout}\n${seeded.stderr}');
      final fresh = await login('2', password: nextPassword);
      expect(fresh.profile!.playerId, previous.profile!.playerId);
      expect(
        (await login(secondEmail, password: nextPassword)).profile!.playerId,
        previous.profile!.playerId,
      );
      await expectLater(
        previous.auth('login', {
          'email': secondEmail,
          'password': initialPassword,
        }),
        authError('invalid_credentials'),
      );
    },
  );
}
