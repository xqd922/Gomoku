import 'dart:convert';
import 'dart:io';

import 'package:gomoku_client/gomoku_client.dart';

import 'verify_production.dart' as validation;

// Leave only a room explicitly identified by one of our validation reports.
// Never close an unrelated active room or remove a player's saved records.
Future<void> main(List<String> args) async {
  validation.require(args.length == 1, 'Provide the validation report path.');
  final report = jsonDecode(await File(args.single).readAsString()) as Map;
  final origin = report['origin'] as String;
  validation.require(
    origin == 'https://gomoku.xqd.pp.ua',
    'Unexpected validation origin.',
  );
  final roomId = report['roomId'] as String?;
  if (roomId == null) return;
  final accounts = jsonDecode(
    await File(
      Platform.environment['GOMOKU_ACCOUNTS_FILE']!,
    ).readAsString(),
  ) as List;
  final device = validation.Device(origin);
  try {
    final account = accounts.first as Map;
    await device.auth('login', {
      'email': account['email'],
      'password': account['password'],
    });
    final active = await device.rpc.room.activeRoom();
    if (active?.roomId == roomId) {
      device.roomId = roomId;
      await device.send(RoomAction.leave);
      stdout.writeln('The validation room was closed. Saved records retained.');
    } else {
      stdout.writeln('No matching active validation room. Nothing changed.');
    }
  } catch (error) {
    stderr.writeln('Validation cleanup failed (${error.runtimeType}).');
    exitCode = 1;
  } finally {
    await device.close();
  }
}
