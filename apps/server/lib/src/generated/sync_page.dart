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
import 'package:gomoku_server/src/generated/protocol.dart' as _i2;

abstract class SyncPage
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  SyncPage._({
    required this.records,
    required this.cursor,
    required this.hasMore,
  });

  factory SyncPage({
    required List<String> records,
    required String cursor,
    required bool hasMore,
  }) = _SyncPageImpl;

  factory SyncPage.fromJson(Map<String, dynamic> jsonSerialization) {
    return SyncPage(
      records: _i2.Protocol().deserialize<List<String>>(
        jsonSerialization['records'],
      ),
      cursor: jsonSerialization['cursor'] as String,
      hasMore: _i1.BoolJsonExtension.fromJson(jsonSerialization['hasMore']),
    );
  }

  List<String> records;

  String cursor;

  bool hasMore;

  /// Returns a shallow copy of this [SyncPage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  SyncPage copyWith({
    List<String>? records,
    String? cursor,
    bool? hasMore,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'SyncPage',
      'records': records.toJson(),
      'cursor': cursor,
      'hasMore': hasMore,
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'SyncPage',
      'records': records.toJson(),
      'cursor': cursor,
      'hasMore': hasMore,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _SyncPageImpl extends SyncPage {
  _SyncPageImpl({
    required List<String> records,
    required String cursor,
    required bool hasMore,
  }) : super._(
         records: records,
         cursor: cursor,
         hasMore: hasMore,
       );

  /// Returns a shallow copy of this [SyncPage]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  SyncPage copyWith({
    List<String>? records,
    String? cursor,
    bool? hasMore,
  }) {
    return SyncPage(
      records: records ?? this.records.map((e0) => e0).toList(),
      cursor: cursor ?? this.cursor,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}
