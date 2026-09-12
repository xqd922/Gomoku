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

import 'room_status.dart' as _i2;

abstract class RoomSnapshot
    implements _i1.SerializableModel, _i1.ProtocolSerialization {
  RoomSnapshot._({
    required this.roomId,
    required this.code,
    required this.revision,
    required this.status,
    required this.hostPlayerId,
    required this.hostName,
    this.guestPlayerId,
    this.guestName,
    required this.hostReady,
    required this.guestReady,
    required this.blackPlayerId,
    this.whitePlayerId,
    required this.gameId,
    required this.gameJson,
    required this.round,
    this.undoRequestedBy,
    this.resumeDeadline,
    required this.hostConnected,
    required this.guestConnected,
    required this.createdAt,
    required this.updatedAt,
    required this.gameStartedAt,
    required this.serverTime,
  });

  factory RoomSnapshot({
    required String roomId,
    required String code,
    required int revision,
    required _i2.RoomStatus status,
    required String hostPlayerId,
    required String hostName,
    String? guestPlayerId,
    String? guestName,
    required bool hostReady,
    required bool guestReady,
    required String blackPlayerId,
    String? whitePlayerId,
    required String gameId,
    required String gameJson,
    required int round,
    String? undoRequestedBy,
    DateTime? resumeDeadline,
    required bool hostConnected,
    required bool guestConnected,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime gameStartedAt,
    required DateTime serverTime,
  }) = _RoomSnapshotImpl;

  factory RoomSnapshot.fromJson(Map<String, dynamic> jsonSerialization) {
    return RoomSnapshot(
      roomId: jsonSerialization['roomId'] as String,
      code: jsonSerialization['code'] as String,
      revision: jsonSerialization['revision'] as int,
      status: _i2.RoomStatus.fromJson((jsonSerialization['status'] as String)),
      hostPlayerId: jsonSerialization['hostPlayerId'] as String,
      hostName: jsonSerialization['hostName'] as String,
      guestPlayerId: jsonSerialization['guestPlayerId'] as String?,
      guestName: jsonSerialization['guestName'] as String?,
      hostReady: _i1.BoolJsonExtension.fromJson(jsonSerialization['hostReady']),
      guestReady: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['guestReady'],
      ),
      blackPlayerId: jsonSerialization['blackPlayerId'] as String,
      whitePlayerId: jsonSerialization['whitePlayerId'] as String?,
      gameId: jsonSerialization['gameId'] as String,
      gameJson: jsonSerialization['gameJson'] as String,
      round: jsonSerialization['round'] as int,
      undoRequestedBy: jsonSerialization['undoRequestedBy'] as String?,
      resumeDeadline: jsonSerialization['resumeDeadline'] == null
          ? null
          : _i1.DateTimeJsonExtension.fromJson(
              jsonSerialization['resumeDeadline'],
            ),
      hostConnected: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['hostConnected'],
      ),
      guestConnected: _i1.BoolJsonExtension.fromJson(
        jsonSerialization['guestConnected'],
      ),
      createdAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['createdAt'],
      ),
      updatedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['updatedAt'],
      ),
      gameStartedAt: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['gameStartedAt'],
      ),
      serverTime: _i1.DateTimeJsonExtension.fromJson(
        jsonSerialization['serverTime'],
      ),
    );
  }

  String roomId;

  String code;

  int revision;

  _i2.RoomStatus status;

  String hostPlayerId;

  String hostName;

  String? guestPlayerId;

  String? guestName;

  bool hostReady;

  bool guestReady;

  String blackPlayerId;

  String? whitePlayerId;

  String gameId;

  String gameJson;

  int round;

  String? undoRequestedBy;

  DateTime? resumeDeadline;

  bool hostConnected;

  bool guestConnected;

  DateTime createdAt;

  DateTime updatedAt;

  DateTime gameStartedAt;

  DateTime serverTime;

  /// Returns a shallow copy of this [RoomSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  RoomSnapshot copyWith({
    String? roomId,
    String? code,
    int? revision,
    _i2.RoomStatus? status,
    String? hostPlayerId,
    String? hostName,
    String? guestPlayerId,
    String? guestName,
    bool? hostReady,
    bool? guestReady,
    String? blackPlayerId,
    String? whitePlayerId,
    String? gameId,
    String? gameJson,
    int? round,
    String? undoRequestedBy,
    DateTime? resumeDeadline,
    bool? hostConnected,
    bool? guestConnected,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? gameStartedAt,
    DateTime? serverTime,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      '__className__': 'RoomSnapshot',
      'roomId': roomId,
      'code': code,
      'revision': revision,
      'status': status.toJson(),
      'hostPlayerId': hostPlayerId,
      'hostName': hostName,
      if (guestPlayerId != null) 'guestPlayerId': guestPlayerId,
      if (guestName != null) 'guestName': guestName,
      'hostReady': hostReady,
      'guestReady': guestReady,
      'blackPlayerId': blackPlayerId,
      if (whitePlayerId != null) 'whitePlayerId': whitePlayerId,
      'gameId': gameId,
      'gameJson': gameJson,
      'round': round,
      if (undoRequestedBy != null) 'undoRequestedBy': undoRequestedBy,
      if (resumeDeadline != null) 'resumeDeadline': resumeDeadline?.toJson(),
      'hostConnected': hostConnected,
      'guestConnected': guestConnected,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'gameStartedAt': gameStartedAt.toJson(),
      'serverTime': serverTime.toJson(),
    };
  }

  @override
  Map<String, dynamic> toJsonForProtocol() {
    return {
      '__className__': 'RoomSnapshot',
      'roomId': roomId,
      'code': code,
      'revision': revision,
      'status': status.toJson(),
      'hostPlayerId': hostPlayerId,
      'hostName': hostName,
      if (guestPlayerId != null) 'guestPlayerId': guestPlayerId,
      if (guestName != null) 'guestName': guestName,
      'hostReady': hostReady,
      'guestReady': guestReady,
      'blackPlayerId': blackPlayerId,
      if (whitePlayerId != null) 'whitePlayerId': whitePlayerId,
      'gameId': gameId,
      'gameJson': gameJson,
      'round': round,
      if (undoRequestedBy != null) 'undoRequestedBy': undoRequestedBy,
      if (resumeDeadline != null) 'resumeDeadline': resumeDeadline?.toJson(),
      'hostConnected': hostConnected,
      'guestConnected': guestConnected,
      'createdAt': createdAt.toJson(),
      'updatedAt': updatedAt.toJson(),
      'gameStartedAt': gameStartedAt.toJson(),
      'serverTime': serverTime.toJson(),
    };
  }

  @override
  String toString() {
    return _i1.SerializationManager.encode(this);
  }
}

class _Undefined {}

class _RoomSnapshotImpl extends RoomSnapshot {
  _RoomSnapshotImpl({
    required String roomId,
    required String code,
    required int revision,
    required _i2.RoomStatus status,
    required String hostPlayerId,
    required String hostName,
    String? guestPlayerId,
    String? guestName,
    required bool hostReady,
    required bool guestReady,
    required String blackPlayerId,
    String? whitePlayerId,
    required String gameId,
    required String gameJson,
    required int round,
    String? undoRequestedBy,
    DateTime? resumeDeadline,
    required bool hostConnected,
    required bool guestConnected,
    required DateTime createdAt,
    required DateTime updatedAt,
    required DateTime gameStartedAt,
    required DateTime serverTime,
  }) : super._(
         roomId: roomId,
         code: code,
         revision: revision,
         status: status,
         hostPlayerId: hostPlayerId,
         hostName: hostName,
         guestPlayerId: guestPlayerId,
         guestName: guestName,
         hostReady: hostReady,
         guestReady: guestReady,
         blackPlayerId: blackPlayerId,
         whitePlayerId: whitePlayerId,
         gameId: gameId,
         gameJson: gameJson,
         round: round,
         undoRequestedBy: undoRequestedBy,
         resumeDeadline: resumeDeadline,
         hostConnected: hostConnected,
         guestConnected: guestConnected,
         createdAt: createdAt,
         updatedAt: updatedAt,
         gameStartedAt: gameStartedAt,
         serverTime: serverTime,
       );

  /// Returns a shallow copy of this [RoomSnapshot]
  /// with some or all fields replaced by the given arguments.
  @_i1.useResult
  @override
  RoomSnapshot copyWith({
    String? roomId,
    String? code,
    int? revision,
    _i2.RoomStatus? status,
    String? hostPlayerId,
    String? hostName,
    Object? guestPlayerId = _Undefined,
    Object? guestName = _Undefined,
    bool? hostReady,
    bool? guestReady,
    String? blackPlayerId,
    Object? whitePlayerId = _Undefined,
    String? gameId,
    String? gameJson,
    int? round,
    Object? undoRequestedBy = _Undefined,
    Object? resumeDeadline = _Undefined,
    bool? hostConnected,
    bool? guestConnected,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? gameStartedAt,
    DateTime? serverTime,
  }) {
    return RoomSnapshot(
      roomId: roomId ?? this.roomId,
      code: code ?? this.code,
      revision: revision ?? this.revision,
      status: status ?? this.status,
      hostPlayerId: hostPlayerId ?? this.hostPlayerId,
      hostName: hostName ?? this.hostName,
      guestPlayerId: guestPlayerId is String?
          ? guestPlayerId
          : this.guestPlayerId,
      guestName: guestName is String? ? guestName : this.guestName,
      hostReady: hostReady ?? this.hostReady,
      guestReady: guestReady ?? this.guestReady,
      blackPlayerId: blackPlayerId ?? this.blackPlayerId,
      whitePlayerId: whitePlayerId is String?
          ? whitePlayerId
          : this.whitePlayerId,
      gameId: gameId ?? this.gameId,
      gameJson: gameJson ?? this.gameJson,
      round: round ?? this.round,
      undoRequestedBy: undoRequestedBy is String?
          ? undoRequestedBy
          : this.undoRequestedBy,
      resumeDeadline: resumeDeadline is DateTime?
          ? resumeDeadline
          : this.resumeDeadline,
      hostConnected: hostConnected ?? this.hostConnected,
      guestConnected: guestConnected ?? this.guestConnected,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      gameStartedAt: gameStartedAt ?? this.gameStartedAt,
      serverTime: serverTime ?? this.serverTime,
    );
  }
}
