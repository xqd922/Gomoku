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

abstract class PlayerProfile implements _i1.SerializableModel {
  PlayerProfile._({
    required this.playerId,
    required this.nickname,
    required this.isGuest,
  });

  factory PlayerProfile({
    required String playerId,
    required String nickname,
    required bool isGuest,
  }) = _PlayerProfileImpl;

  factory PlayerProfile.fromJson(Map<String, dynamic> jsonSerialization) {
    return PlayerProfile(
      playerId: jsonSerialization['playerId'] as String,
      nickname: jsonSerialization['nickname'] as String,
      isGuest: _i1.BoolJsonExtension.fromJson(jsonSerialization['isGuest']),
    );
  }

  String playerId;

  String nickname;

  bool isGuest;

  /// Returns a shallow copy of this [PlayerProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  PlayerProfile copyWith({
    String? playerId,
    String? nickname,
    bool? isGuest,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'PlayerProfile',
      'playerId': playerId,
      'nickname': nickname,
      'isGuest': isGuest,
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _PlayerProfileImpl extends PlayerProfile {
  _PlayerProfileImpl({
    required String playerId,
    required String nickname,
    required bool isGuest,
  }) : super._(
         playerId: playerId,
         nickname: nickname,
         isGuest: isGuest,
       );

  /// Returns a shallow copy of this [PlayerProfile]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  PlayerProfile copyWith({
    String? playerId,
    String? nickname,
    bool? isGuest,
  }) {
    return PlayerProfile(
      playerId: playerId ?? this.playerId,
      nickname: nickname ?? this.nickname,
      isGuest: isGuest ?? this.isGuest,
    );
  }
}
