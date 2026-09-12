import 'game.dart';

enum RecordSource { local, online }

final class GameRecord {
  const GameRecord({
    required this.id,
    required this.game,
    required this.source,
    required this.startedAt,
    required this.updatedAt,
    this.blackName = '',
    this.whiteName = '',
    this.roomCode,
  });

  final String id;
  final GameState game;
  final RecordSource source;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String blackName;
  final String whiteName;
  final String? roomCode;

  GameRecord copyWith({
    GameState? game,
    DateTime? updatedAt,
    String? blackName,
    String? whiteName,
  }) => GameRecord(
    id: id,
    game: game ?? this.game,
    source: source,
    startedAt: startedAt,
    updatedAt: updatedAt ?? this.updatedAt,
    blackName: blackName ?? this.blackName,
    whiteName: whiteName ?? this.whiteName,
    roomCode: roomCode,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 1,
    'id': id,
    'game': game.toJson(),
    'source': source.name,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'blackName': blackName,
    'whiteName': whiteName,
    'roomCode': roomCode,
  };

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1 ||
        json['id'] is! String ||
        !RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(json['id'] as String) ||
        json['game'] is! Map ||
        json['startedAt'] is! String ||
        json['updatedAt'] is! String) {
      throw const RuleViolation('invalid_record');
    }
    final start = DateTime.tryParse(json['startedAt'] as String)?.toUtc();
    final update = DateTime.tryParse(json['updatedAt'] as String)?.toUtc();
    if (start == null || update == null || update.isBefore(start)) {
      throw const RuleViolation('invalid_record');
    }
    final source = switch (json['source']) {
      'local' => RecordSource.local,
      'online' => RecordSource.online,
      _ => throw const RuleViolation('invalid_record'),
    };
    return GameRecord(
      id: json['id'] as String,
      game: GameState.fromJson(Map<String, dynamic>.from(json['game'] as Map)),
      source: source,
      startedAt: start,
      updatedAt: update,
      blackName: _name(json['blackName']),
      whiteName: _name(json['whiteName']),
      roomCode: json['roomCode'] as String?,
    );
  }

  static String _name(Object? value) {
    if (value is! String || value.runes.length > 32) {
      throw const RuleViolation('invalid_record');
    }
    return value;
  }
}
