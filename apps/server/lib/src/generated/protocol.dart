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
import 'package:serverpod/protocol.dart' as _i2;
import 'package:serverpod_auth_idp_server/serverpod_auth_idp_server.dart'
    as _i3;
import 'package:serverpod_auth_core_server/serverpod_auth_core_server.dart'
    as _i4;

import 'app_exception.dart' as _i5;
import 'player_profile.dart' as _i6;
import 'room_action.dart' as _i7;
import 'room_command.dart' as _i8;
import 'room_snapshot.dart' as _i9;
import 'room_status.dart' as _i10;
import 'sync_page.dart' as _i11;

import 'package:gomoku_server/src/generated/room_snapshot.dart' as _i12;

export 'app_exception.dart';
export 'player_profile.dart';
export 'room_action.dart';
export 'room_command.dart';
export 'room_snapshot.dart';
export 'room_status.dart';
export 'sync_page.dart';

class Protocol extends _i1.SerializationManagerServer {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

  static final List<_i2.TableDefinition> targetTableDefinitions = [
    ..._i3.Protocol.targetTableDefinitions,
    ..._i4.Protocol.targetTableDefinitions,
    ..._i2.Protocol.targetTableDefinitions,
  ];

  static String? getClassNameFromObjectJson(dynamic data) {
    if (data is! Map) return null;
    final className = data['__className__'] as String?;
    return className;
  }

  @override
  T deserialize<T>(
    dynamic data, [
    Type? t,
  ]) {
    t ??= T;

    final dataClassName = getClassNameFromObjectJson(data);
    if (dataClassName != null && dataClassName != getClassNameForType(t)) {
      try {
        return deserializeByClassName({
          'className': dataClassName,
          'data': data,
        });
      } on FormatException catch (_) {
        // If the className is not recognized (e.g., older client receiving
        // data with a new subtype), fall back to deserializing without the
        // className, using the expected type T.
      }
    }

    if (t == _i5.AppException) {
      return _i5.AppException.fromJson(data) as T;
    }
    if (t == _i6.PlayerProfile) {
      return _i6.PlayerProfile.fromJson(data) as T;
    }
    if (t == _i7.RoomAction) {
      return _i7.RoomAction.fromJson(data) as T;
    }
    if (t == _i8.RoomCommand) {
      return _i8.RoomCommand.fromJson(data) as T;
    }
    if (t == _i9.RoomSnapshot) {
      return _i9.RoomSnapshot.fromJson(data) as T;
    }
    if (t == _i10.RoomStatus) {
      return _i10.RoomStatus.fromJson(data) as T;
    }
    if (t == _i11.SyncPage) {
      return _i11.SyncPage.fromJson(data) as T;
    }
    if (t == _i1.getType<_i5.AppException?>()) {
      return (data != null ? _i5.AppException.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.PlayerProfile?>()) {
      return (data != null ? _i6.PlayerProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.RoomAction?>()) {
      return (data != null ? _i7.RoomAction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.RoomCommand?>()) {
      return (data != null ? _i8.RoomCommand.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i9.RoomSnapshot?>()) {
      return (data != null ? _i9.RoomSnapshot.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i10.RoomStatus?>()) {
      return (data != null ? _i10.RoomStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i11.SyncPage?>()) {
      return (data != null ? _i11.SyncPage.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<_i12.RoomSnapshot>) {
      return (data as List)
              .map((e) => deserialize<_i12.RoomSnapshot>(e))
              .toList()
          as T;
    }
    try {
      return _i3.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i4.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i2.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i5.AppException => 'AppException',
      _i6.PlayerProfile => 'PlayerProfile',
      _i7.RoomAction => 'RoomAction',
      _i8.RoomCommand => 'RoomCommand',
      _i9.RoomSnapshot => 'RoomSnapshot',
      _i10.RoomStatus => 'RoomStatus',
      _i11.SyncPage => 'SyncPage',
      _ => null,
    };
  }

  @override
  String? getClassNameForObject(Object? data) {
    String? className = super.getClassNameForObject(data);
    if (className != null) return className;

    if (data is Map<String, dynamic> && data['__className__'] is String) {
      return (data['__className__'] as String).replaceFirst('gomoku.', '');
    }

    switch (data) {
      case _i5.AppException():
        return 'AppException';
      case _i6.PlayerProfile():
        return 'PlayerProfile';
      case _i7.RoomAction():
        return 'RoomAction';
      case _i8.RoomCommand():
        return 'RoomCommand';
      case _i9.RoomSnapshot():
        return 'RoomSnapshot';
      case _i10.RoomStatus():
        return 'RoomStatus';
      case _i11.SyncPage():
        return 'SyncPage';
    }
    className = _i2.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod.$className';
    }
    className = _i3.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i4.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_core.$className';
    }
    return null;
  }

  @override
  dynamic deserializeByClassName(Map<String, dynamic> data) {
    var dataClassName = data['className'];
    if (dataClassName is! String) {
      return super.deserializeByClassName(data);
    }
    if (dataClassName == 'AppException') {
      return deserialize<_i5.AppException>(data['data']);
    }
    if (dataClassName == 'PlayerProfile') {
      return deserialize<_i6.PlayerProfile>(data['data']);
    }
    if (dataClassName == 'RoomAction') {
      return deserialize<_i7.RoomAction>(data['data']);
    }
    if (dataClassName == 'RoomCommand') {
      return deserialize<_i8.RoomCommand>(data['data']);
    }
    if (dataClassName == 'RoomSnapshot') {
      return deserialize<_i9.RoomSnapshot>(data['data']);
    }
    if (dataClassName == 'RoomStatus') {
      return deserialize<_i10.RoomStatus>(data['data']);
    }
    if (dataClassName == 'SyncPage') {
      return deserialize<_i11.SyncPage>(data['data']);
    }
    if (dataClassName.startsWith('serverpod.')) {
      data['className'] = dataClassName.substring(10);
      return _i2.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i3.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i4.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

  @override
  _i1.Table? getTableForType(Type t) {
    {
      var table = _i3.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i4.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    {
      var table = _i2.Protocol().getTableForType(t);
      if (table != null) {
        return table;
      }
    }
    return null;
  }

  @override
  List<_i2.TableDefinition> getTargetTableDefinitions() =>
      targetTableDefinitions;

  @override
  String getModuleName() => 'gomoku';

  /// Maps any `Record`s known to this [Protocol] to their JSON representation
  ///
  /// Throws in case the record type is not known.
  ///
  /// This method will return `null` (only) for `null` inputs.
  Map<String, dynamic>? mapRecordToJson(Record? record) {
    if (record == null) {
      return null;
    }
    try {
      return _i3.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i4.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
