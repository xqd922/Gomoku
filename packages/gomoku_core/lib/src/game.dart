import 'dart:collection';

const boardSize = 15;
const rulesVersion = 1;

enum Stone {
  black,
  white;

  Stone get opponent => this == black ? white : black;
}

enum EndReason { five, boardFull, resignation, interruption }

final class RuleViolation implements Exception {
  const RuleViolation(this.code);
  final String code;

  @override
  String toString() => 'RuleViolation($code)';
}

final class BoardPoint {
  const BoardPoint(this.row, this.col);
  final int row;
  final int col;

  bool get isOnBoard =>
      row >= 0 && row < boardSize && col >= 0 && col < boardSize;

  Map<String, dynamic> toJson() => {'row': row, 'col': col};

  factory BoardPoint.fromJson(Map<String, dynamic> json) {
    final row = json['row'];
    final col = json['col'];
    if (row is! int || col is! int) {
      throw const RuleViolation('invalid_record');
    }
    return BoardPoint(row, col);
  }

  @override
  bool operator ==(Object other) =>
      other is BoardPoint && other.row == row && other.col == col;
  @override
  int get hashCode => Object.hash(row, col);
}

final class Move {
  const Move({required this.row, required this.col, required this.stone});
  final int row;
  final int col;
  final Stone stone;
  BoardPoint get point => BoardPoint(row, col);

  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
    'stone': stone.name,
  };

  factory Move.fromJson(Map<String, dynamic> json) {
    final point = BoardPoint.fromJson(json);
    final stone = switch (json['stone']) {
      'black' => Stone.black,
      'white' => Stone.white,
      _ => throw const RuleViolation('invalid_record'),
    };
    return Move(row: point.row, col: point.col, stone: stone);
  }

  @override
  bool operator ==(Object other) =>
      other is Move && other.point == point && other.stone == stone;
  @override
  int get hashCode => Object.hash(point, stone);
}

final class GameResult {
  GameResult({
    required this.reason,
    this.winner,
    Iterable<BoardPoint> winningLine = const [],
  }) : winningLine = List.unmodifiable(winningLine);

  final EndReason reason;
  final Stone? winner;
  final List<BoardPoint> winningLine;
  bool get isDraw => reason == EndReason.boardFull;
  bool get isInterrupted => reason == EndReason.interruption;

  Map<String, dynamic> toJson() => {
    'reason': reason.name,
    'winner': winner?.name,
    'winningLine': winningLine.map((p) => p.toJson()).toList(),
  };
}

/// The sole rules authority. Every state can be reconstructed from its moves.
/// No network, clock, random source, database, or Flutter dependency is used.
final class GameState {
  GameState._(List<Move> moves, List<Stone?> cells, this.result)
    : moves = UnmodifiableListView(moves),
      _cells = UnmodifiableListView(cells);

  factory GameState.newGame() =>
      GameState._([], List.filled(boardSize * boardSize, null), null);

  factory GameState.fromMoves(Iterable<Move> moves) {
    var state = GameState.newGame();
    for (final move in moves) {
      state = state.play(move.row, move.col, player: move.stone);
    }
    return state;
  }

  final List<Move> moves;
  final List<Stone?> _cells;
  final GameResult? result;
  Stone get turn => moves.length.isEven ? Stone.black : Stone.white;
  bool get isOver => result != null;
  bool get canUndo => !isOver && moves.isNotEmpty;
  Move? get lastMove => moves.isEmpty ? null : moves.last;

  Stone? at(int row, int col) {
    if (!BoardPoint(row, col).isOnBoard) {
      throw const RuleViolation('out_of_bounds');
    }
    return _cells[row * boardSize + col];
  }

  GameState play(int row, int col, {Stone? player}) {
    if (isOver) throw const RuleViolation('game_over');
    if (player != null && player != turn) {
      throw const RuleViolation('not_your_turn');
    }
    if (!BoardPoint(row, col).isOnBoard) {
      throw const RuleViolation('out_of_bounds');
    }
    if (at(row, col) != null) throw const RuleViolation('occupied');

    final stone = turn;
    final cells = List<Stone?>.of(_cells);
    cells[row * boardSize + col] = stone;
    final nextMoves = [...moves, Move(row: row, col: col, stone: stone)];
    GameResult? outcome;
    for (final (dr, dc) in const [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      final before = <BoardPoint>[];
      final after = <BoardPoint>[];
      for (final direction in [-1, 1]) {
        var r = row + direction * dr;
        var c = col + direction * dc;
        while (BoardPoint(r, c).isOnBoard &&
            cells[r * boardSize + c] == stone) {
          (direction == -1 ? before : after).add(BoardPoint(r, c));
          r += direction * dr;
          c += direction * dc;
        }
      }
      final line = [...before.reversed, BoardPoint(row, col), ...after];
      if (line.length >= 5) {
        outcome = GameResult(
          reason: EndReason.five,
          winner: stone,
          winningLine: line,
        );
        break;
      }
    }
    if (outcome == null && nextMoves.length == boardSize * boardSize) {
      outcome = GameResult(reason: EndReason.boardFull);
    }
    return GameState._(nextMoves, cells, outcome);
  }

  GameState undoLast() {
    if (!canUndo) throw const RuleViolation('undo_not_available');
    return GameState.fromMoves(moves.take(moves.length - 1));
  }

  /// Retract the requester's latest move and any reply after it.
  GameState undoBeforeLastMoveBy(Stone stone) {
    if (!canUndo) throw const RuleViolation('undo_not_available');
    final index = moves.lastIndexWhere((move) => move.stone == stone);
    if (index < 0) throw const RuleViolation('undo_not_available');
    return GameState.fromMoves(moves.take(index));
  }

  GameState resign(Stone player) {
    if (isOver) throw const RuleViolation('game_over');
    return GameState._(
      List.of(moves),
      List.of(_cells),
      GameResult(reason: EndReason.resignation, winner: player.opponent),
    );
  }

  GameState interrupt() {
    if (isOver) return this;
    return GameState._(
      List.of(moves),
      List.of(_cells),
      GameResult(reason: EndReason.interruption),
    );
  }

  GameState positionAt(int ply) {
    if (ply < 0 || ply > moves.length) {
      throw const RuleViolation('invalid_replay_position');
    }
    return ply == moves.length ? this : GameState.fromMoves(moves.take(ply));
  }

  Map<String, dynamic> toJson() => {
    'rulesVersion': rulesVersion,
    'boardSize': boardSize,
    'moves': moves.map((m) => m.toJson()).toList(),
    'result': result?.toJson(),
  };

  /// Replays untrusted records instead of trusting a supplied board or winner.
  factory GameState.fromJson(Map<String, dynamic> json) {
    if (json['rulesVersion'] != rulesVersion ||
        json['boardSize'] != boardSize) {
      throw const RuleViolation('unsupported_rules');
    }
    final rawMoves = json['moves'];
    if (rawMoves is! List || rawMoves.length > boardSize * boardSize) {
      throw const RuleViolation('invalid_record');
    }
    var state = GameState.newGame();
    for (final raw in rawMoves) {
      if (raw is! Map) throw const RuleViolation('invalid_record');
      final move = Move.fromJson(Map<String, dynamic>.from(raw));
      state = state.play(move.row, move.col, player: move.stone);
    }
    final rawResult = json['result'];
    if (rawResult == null) {
      if (state.isOver) throw const RuleViolation('invalid_record');
      return state;
    }
    if (rawResult is! Map) throw const RuleViolation('invalid_record');
    final reason = rawResult['reason'];
    final winner = rawResult['winner'];
    if (!state.isOver && reason == EndReason.resignation.name) {
      state = switch (winner) {
        'black' => state.resign(Stone.white),
        'white' => state.resign(Stone.black),
        _ => throw const RuleViolation('invalid_record'),
      };
    } else if (!state.isOver &&
        reason == EndReason.interruption.name &&
        winner == null) {
      state = state.interrupt();
    }
    if (state.result?.reason.name != reason ||
        state.result?.winner?.name != winner) {
      throw const RuleViolation('invalid_record');
    }
    final rawLine = rawResult['winningLine'];
    if (rawLine is! List ||
        rawLine.length != state.result!.winningLine.length) {
      throw const RuleViolation('invalid_record');
    }
    for (var i = 0; i < rawLine.length; i++) {
      if (rawLine[i] is! Map ||
          BoardPoint.fromJson(Map<String, dynamic>.from(rawLine[i] as Map)) !=
              state.result!.winningLine[i]) {
        throw const RuleViolation('invalid_record');
      }
    }
    return state;
  }
}
