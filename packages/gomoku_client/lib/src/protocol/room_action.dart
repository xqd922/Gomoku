/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: implementation_imports
// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: public_member_api_docs
// ignore_for_file: type_literal_in_constant_pattern
// ignore_for_file: use_super_parameters
// ignore_for_file: invalid_use_of_internal_member

// ignore_for_file: no_leading_underscores_for_library_prefixes

import 'package:serverpod_client/serverpod_client.dart' as _i1;

enum RoomAction implements _i1.SerializableModel {
  ready,
  move,
  requestUndo,
  acceptUndo,
  rejectUndo,
  resign,
  rematch,
  leave;

  static RoomAction fromJson(String name) {
    switch (name) {
      case 'ready':
        return RoomAction.ready;
      case 'move':
        return RoomAction.move;
      case 'requestUndo':
        return RoomAction.requestUndo;
      case 'acceptUndo':
        return RoomAction.acceptUndo;
      case 'rejectUndo':
        return RoomAction.rejectUndo;
      case 'resign':
        return RoomAction.resign;
      case 'rematch':
        return RoomAction.rematch;
      case 'leave':
        return RoomAction.leave;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "RoomAction"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
