@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final server = TestServer(9280);
  final restarting = TestServer(9480);
  late Directory temporary;
  late File accountsFile;
  final firstEmail = 'managed-${ids.v4()}@example.test';
  final secondEmail = 'managed-${ids.v4()}@example.test';
  const initialPassword = '48271635';
  final clients = <TestPlayer>[];

  Future<ProcessResult> admin(String operation, {File? reset}) => Process.run(
    Platform.resolvedExecutable,
    [
      'bin/main.dart',
      '--mode',
      'test',
      '--server-id',
      'account-admin',
      '--gomoku-admin=$operation',
    ],
    environment: {
      'COOKIE_SECURE': 'false',
      'GOMOKU_ACCOUNTS_FILE': accountsFile.absolute.path,
      if (reset != null) 'GOMOKU_RESET_FILE': reset.absolute.path,
    },
  ).timeout(const Duration(seconds: 45));

  Future<TestPlayer> login(
    String email, {
    String password = initialPassword,
  }) async {
    final player = TestPlayer(server, 'Managed');
    clients.add(player);
    await player.auth('login', {'email': email, 'password': password});
    return player;
  }

  setUpAll(() async {
    await server.start();
    final db = await testDatabase();
    await db.execute('DELETE FROM gm_private_accounts');
    await db.close();
    temporary = await Directory.systemTemp.createTemp('gomoku-admin-test-');
    accountsFile = File('${temporary.path}/accounts.json');
    await accountsFile.writeAsString(
      jsonEncode([
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
      ]),
    );
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
    if (await temporary.exists()) await temporary.delete(recursive: true);
  });

  test('email capabilities are published for every client', () async {
    final response = await http.get(Uri.parse('${server.web}app-config'));
    expect(jsonDecode(response.body), {
      'authMode': 'email',
      'guestOnline': true,
      'registration': true,
      'passwordReset': true,
    });
    expect(response.body, isNot(contains(firstEmail)));
  });

  test(
    'provisioned accounts sign in by email only and keep their records',
    () async {
      final a = await login(firstEmail);
      final b = await login(secondEmail);
      expect(a.profile!.playerId, isNot(b.profile!.playerId));
      final record = localRecord();
      await a.client.profile.syncRecords([jsonEncode(record.toJson())], '');
      expect((await b.client.profile.syncRecords([], '')).records, isEmpty);
      // The old short aliases are no longer sign-in identifiers.
      for (final alias in ['1', '2']) {
        await expectLater(
          login(alias),
          authError('invalid_credentials'),
        );
      }
      await expectLater(
        login(firstEmail, password: 'wrong-password'),
        authError('invalid_credentials'),
      );
      final again = await login(firstEmail);
      expect(
        (await again.client.profile.syncRecords([], '')).records.single,
        contains(record.id),
      );
    },
  );

  test(
    're-provisioning keeps identities, passwords and alias bookkeeping',
    () async {
      final a = await login(firstEmail);
      final id = a.profile!.playerId;
      final db = await testDatabase();
      await db.execute('UPDATE gm_private_accounts SET login_name=NULL');
      await db.close();
      final result = await admin('provision');
      expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
      expect((await login(firstEmail)).profile!.playerId, id);
      expect((await login(secondEmail)).profile!.playerId, isNot(id));
    },
  );

  test(
    'pending application migrations do not invalidate sessions',
    () async {
      final signedIn = await login(firstEmail);
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
    'admin password reset by email or alias revokes sessions; provisioning does not reset it',
    () async {
      final host = await login(firstEmail);
      final previous = await login(secondEmail);
      final room = await TestRoom.open(host, previous);
      addTearDown(room.close);
      const nextPassword = '93751628';
      final file = File('${temporary.path}/reset.json');
      await file.writeAsString(
        jsonEncode({'email': secondEmail, 'password': nextPassword}),
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
      final fresh = await login(secondEmail, password: nextPassword);
      expect(fresh.profile!.playerId, previous.profile!.playerId);
      await expectLater(
        previous.auth('login', {
          'email': secondEmail,
          'password': initialPassword,
        }),
        authError('invalid_credentials'),
      );
      // The legacy alias still resolves for administrator password resets.
      final aliasFile = File('${temporary.path}/reset-alias.json');
      await aliasFile.writeAsString(
        jsonEncode({'email': '1', 'password': nextPassword}),
      );
      final aliasReset = await admin('reset-password', reset: aliasFile);
      expect(
        aliasReset.exitCode,
        0,
        reason: '${aliasReset.stdout}\n${aliasReset.stderr}',
      );
      await login(firstEmail, password: nextPassword);
    },
  );
}
