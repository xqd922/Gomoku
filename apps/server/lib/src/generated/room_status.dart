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

import 'package:serverpod/serverpod.dart' as _i1;

enum RoomStatus implements _i1.SerializableModel {
  waiting,
  playing,
  paused,
  finished,
  closed;

  static RoomStatus fromJson(String name) {
    switch (name) {
      case 'waiting':
        return RoomStatus.waiting;
      case 'playing':
        return RoomStatus.playing;
      case 'paused':
        return RoomStatus.paused;
      case 'finished':
        return RoomStatus.finished;
      case 'closed':
        return RoomStatus.closed;
      default:
        throw ArgumentError(
          'Value "$name" cannot be converted to "RoomStatus"',
        );
    }
  }

  @override
  String toJson() => name;

  @override
  String toString() => name;
}
