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
import 'room_action.dart' as _i2;

abstract class RoomCommand implements _i1.SerializableModel {
  RoomCommand._({
    required this.commandId,
    required this.expectedRevision,
    required this.action,
    this.row,
    this.col,
  });

  factory RoomCommand({
    required String commandId,
    required int expectedRevision,
    required _i2.RoomAction action,
    int? row,
    int? col,
  }) = _RoomCommandImpl;

  factory RoomCommand.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoomCommand(
      commandId: jsonSerialization['commandId'] as String,
      expectedRevision: jsonSerialization['expectedRevision'] as int,
      action: _i2.RoomAction.fromJson((jsonSerialization['action'] as String)),
      row: jsonSerialization['row'] as int?,
      col: jsonSerialization['col'] as int?,
    );
  }

  String commandId;

  int expectedRevision;

  _i2.RoomAction action;

  int? row;

  int? col;

  /// Returns a shallow copy of this [RoomCommand]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RoomCommand copyWith({
    String? commandId,
    int? expectedRevision,
    _i2.RoomAction? action,
    int? row,
    int? col,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoomCommand',
      'commandId': commandId,
      'expectedRevision': expectedRevision,
      'action': action.toJson(),
      if (row != null) 'row': row,
      if (col != null) 'col': col,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoomCommandImpl extends RoomCommand {
  _RoomCommandImpl({
    required String commandId,
    required int expectedRevision,
    required _i2.RoomAction action,
    int? row,
    int? col,
  }) : super._(
         commandId: commandId,
         expectedRevision: expectedRevision,
         action: action,
         row: row,
         col: col,
       );

  /// Returns a shallow copy of this [RoomCommand]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RoomCommand copyWith({
    String? commandId,
    int? expectedRevision,
    _i2.RoomAction? action,
    Object? row = _Undefined,
    Object? col = _Undefined,
  }) {
    return RoomCommand(
      commandId: commandId ?? this.commandId,
      expectedRevision: expectedRevision ?? this.expectedRevision,
      action: action ?? this.action,
      row: row is int? ? row : this.row,
      col: col is int? ? col : this.col,
    );
  }
}
