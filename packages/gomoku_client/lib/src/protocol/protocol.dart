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
import 'app_exception.dart' as _i2;
import 'player_profile.dart' as _i3;
import 'room_action.dart' as _i4;
import 'room_command.dart' as _i5;
import 'room_snapshot.dart' as _i6;
import 'room_status.dart' as _i7;
import 'sync_page.dart' as _i8;
import 'package:serverpod_auth_idp_client/serverpod_auth_idp_client.dart'
    as _i9;
import 'package:serverpod_auth_core_client/serverpod_auth_core_client.dart'
    as _i10;
export 'app_exception.dart';
export 'player_profile.dart';
export 'room_action.dart';
export 'room_command.dart';
export 'room_snapshot.dart';
export 'room_status.dart';
export 'sync_page.dart';
export 'client.dart';

class Protocol extends _i1.SerializationManager {
  Protocol._();

  factory Protocol() => _instance;

  static final Protocol _instance = Protocol._();

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

    if (t == _i2.AppException) {
      return _i2.AppException.fromJson(data) as T;
    }
    if (t == _i3.PlayerProfile) {
      return _i3.PlayerProfile.fromJson(data) as T;
    }
    if (t == _i4.RoomAction) {
      return _i4.RoomAction.fromJson(data) as T;
    }
    if (t == _i5.RoomCommand) {
      return _i5.RoomCommand.fromJson(data) as T;
    }
    if (t == _i6.RoomSnapshot) {
      return _i6.RoomSnapshot.fromJson(data) as T;
    }
    if (t == _i7.RoomStatus) {
      return _i7.RoomStatus.fromJson(data) as T;
    }
    if (t == _i8.SyncPage) {
      return _i8.SyncPage.fromJson(data) as T;
    }
    if (t == _i1.getType<_i2.AppException?>()) {
      return (data != null ? _i2.AppException.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i3.PlayerProfile?>()) {
      return (data != null ? _i3.PlayerProfile.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i4.RoomAction?>()) {
      return (data != null ? _i4.RoomAction.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i5.RoomCommand?>()) {
      return (data != null ? _i5.RoomCommand.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i6.RoomSnapshot?>()) {
      return (data != null ? _i6.RoomSnapshot.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i7.RoomStatus?>()) {
      return (data != null ? _i7.RoomStatus.fromJson(data) : null) as T;
    }
    if (t == _i1.getType<_i8.SyncPage?>()) {
      return (data != null ? _i8.SyncPage.fromJson(data) : null) as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    if (t == List<String>) {
      return (data as List).map((e) => deserialize<String>(e)).toList() as T;
    }
    try {
      return _i9.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    try {
      return _i10.Protocol().deserialize<T>(data, t);
    } on _i1.DeserializationTypeNotFoundException catch (_) {}
    return super.deserialize<T>(data, t);
  }

  static String? getClassNameForType(Type type) {
    return switch (type) {
      _i2.AppException => 'AppException',
      _i3.PlayerProfile => 'PlayerProfile',
      _i4.RoomAction => 'RoomAction',
      _i5.RoomCommand => 'RoomCommand',
      _i6.RoomSnapshot => 'RoomSnapshot',
      _i7.RoomStatus => 'RoomStatus',
      _i8.SyncPage => 'SyncPage',
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
      case _i2.AppException():
        return 'AppException';
      case _i3.PlayerProfile():
        return 'PlayerProfile';
      case _i4.RoomAction():
        return 'RoomAction';
      case _i5.RoomCommand():
        return 'RoomCommand';
      case _i6.RoomSnapshot():
        return 'RoomSnapshot';
      case _i7.RoomStatus():
        return 'RoomStatus';
      case _i8.SyncPage():
        return 'SyncPage';
    }
    className = _i9.Protocol().getClassNameForObject(data);
    if (className != null) {
      return 'serverpod_auth_idp.$className';
    }
    className = _i10.Protocol().getClassNameForObject(data);
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
      return deserialize<_i2.AppException>(data['data']);
    }
    if (dataClassName == 'PlayerProfile') {
      return deserialize<_i3.PlayerProfile>(data['data']);
    }
    if (dataClassName == 'RoomAction') {
      return deserialize<_i4.RoomAction>(data['data']);
    }
    if (dataClassName == 'RoomCommand') {
      return deserialize<_i5.RoomCommand>(data['data']);
    }
    if (dataClassName == 'RoomSnapshot') {
      return deserialize<_i6.RoomSnapshot>(data['data']);
    }
    if (dataClassName == 'RoomStatus') {
      return deserialize<_i7.RoomStatus>(data['data']);
    }
    if (dataClassName == 'SyncPage') {
      return deserialize<_i8.SyncPage>(data['data']);
    }
    if (dataClassName.startsWith('serverpod_auth_idp.')) {
      data['className'] = dataClassName.substring(19);
      return _i9.Protocol().deserializeByClassName(data);
    }
    if (dataClassName.startsWith('serverpod_auth_core.')) {
      data['className'] = dataClassName.substring(20);
      return _i10.Protocol().deserializeByClassName(data);
    }
    return super.deserializeByClassName(data);
  }

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
      return _i9.Protocol().mapRecordToJson(record);
    } catch (_) {}
    try {
      return _i10.Protocol().mapRecordToJson(record);
    } catch (_) {}
    throw Exception('Unsupported record type ${record.runtimeType}');
  }
}
