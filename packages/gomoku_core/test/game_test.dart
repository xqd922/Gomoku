import 'dart:convert';

import 'package:gomoku_core/gomoku_core.dart';
import 'package:test/test.dart';

Matcher violates(String code) =>
    throwsA(isA<RuleViolation>().having((e) => e.code, 'code', code));

void main() {
  group('free-style Gomoku', () {
    for (final (dr, dc) in [(0, 1), (1, 0), (1, 1), (1, -1)]) {
      test('wins along direction ${(dr, dc)}', () {
        var game = GameState.newGame();
        for (var n = 0; n < 5; n++) {
          game = game.play(7 + n * dr, 7 + n * dc);
          if (n < 4) game = game.play(0, n * 2);
        }
        expect(game.result?.winner, Stone.black);
        expect(game.result?.winningLine.length, 5);
        expect(() => game.play(14, 14), violates('game_over'));
        expect(GameState.fromJson(game.toJson()).toJson(), game.toJson());
      });
    }

    test('a six-stone line formed by filling a gap wins', () {
      var game = GameState.newGame();
      for (final col in [0, 1, 2, 4, 5]) {
        game = game.play(14, col);
        game = game.play(0, col * 2);
      }
      game = game.play(14, 3);
      expect(game.result?.winningLine.length, 6);
    });

    test('white can win and edges never wrap', () {
      var game = GameState.newGame();
      for (var n = 0; n < 5; n++) {
        game = game.play(0, n * 2);
        game = game.play(n, 14);
      }
      expect(game.result?.winner, Stone.white);
    });

    test('moves are immutable and reject wrong turn and illegal positions', () {
      final empty = GameState.newGame();
      final first = empty.play(7, 7);
      expect(empty.at(7, 7), isNull);
      expect(() => first.moves.clear(), throwsUnsupportedError);
      expect(() => first.play(7, 7), violates('occupied'));
      expect(() => first.play(-1, 0), violates('out_of_bounds'));
      expect(() => first.play(15, 0), violates('out_of_bounds'));
      expect(
        () => first.play(8, 8, player: Stone.black),
        violates('not_your_turn'),
      );
    });

    test('full board without five is a draw', () {
      final blacks = <BoardPoint>[];
      final whites = <BoardPoint>[];
      for (var r = 0; r < boardSize; r++) {
        for (var c = 0; c < boardSize; c++) {
          ((r + 2 * c) % 4 < 2 ? blacks : whites).add(BoardPoint(r, c));
        }
      }
      expect(blacks.length, 113);
      var game = GameState.newGame();
      for (var i = 0; i < 113; i++) {
        game = game.play(blacks[i].row, blacks[i].col);
        if (i < whites.length) game = game.play(whites[i].row, whites[i].col);
      }
      expect(game.result?.isDraw, isTrue);
      expect(game.result?.winner, isNull);
    });
  });

  group('history and validation', () {
    test(
      'agreed undo restores requesters turn, removing a reply if needed',
      () {
        final game = GameState.newGame().play(7, 7).play(7, 8).play(8, 8);
        final blackUndo = game.undoBeforeLastMoveBy(Stone.black);
        expect(blackUndo.moves.length, 2);
        expect(blackUndo.turn, Stone.black);
        final whiteUndo = game.undoBeforeLastMoveBy(Stone.white);
        expect(whiteUndo.moves.length, 1);
        expect(whiteUndo.turn, Stone.white);
        expect(game.undoLast().moves.length, 2);
        expect(game.positionAt(0).moves, isEmpty);
        expect(game.positionAt(2).toJson(), blackUndo.toJson());
      },
    );

    test('resignation and interruption round trip', () {
      final game = GameState.newGame().play(7, 7);
      for (final ended in [game.resign(Stone.white), game.interrupt()]) {
        final restored = GameState.fromJson(
          jsonDecode(jsonEncode(ended.toJson())) as Map<String, dynamic>,
        );
        expect(restored.toJson(), ended.toJson());
        expect(() => ended.undoLast(), violates('undo_not_available'));
      }
    });

    test('a fabricated winner or unordered moves cannot be imported', () {
      final game = GameState.newGame().play(7, 7);
      final forged = game.toJson();
      forged['result'] = {
        'reason': 'five',
        'winner': 'black',
        'winningLine': [],
      };
      expect(() => GameState.fromJson(forged), violates('invalid_record'));
      final wrongTurn = game.toJson();
      (wrongTurn['moves'] as List).first['stone'] = 'white';
      expect(() => GameState.fromJson(wrongTurn), violates('not_your_turn'));
    });

    test('record import validates its id, dates, and full move sequence', () {
      final record = GameRecord(
        id: 'efddfeaa-c807-4694-9c46-f09a319efb16',
        game: GameState.newGame().play(7, 7).resign(Stone.white),
        source: RecordSource.local,
        startedAt: DateTime.utc(2026, 9, 12),
        updatedAt: DateTime.utc(2026, 9, 12, 0, 1),
      );
      expect(GameRecord.fromJson(record.toJson()).toJson(), record.toJson());
      final forged = record.toJson()..['updatedAt'] = '2025-01-01T00:00:00Z';
      expect(() => GameRecord.fromJson(forged), violates('invalid_record'));
    });
  });
}
