import { describe, expect, test } from 'bun:test'
import {
  BOARD_SIZE,
  createGame,
  isGameState,
  playMove,
  redoMove,
  undoMove,
  type GameState,
  type Player,
} from './game'

function playPairs(game: GameState, black: Array<[number, number]>, white: Array<[number, number]>) {
  expect(black.length).toBe(white.length)
  for (let index = 0; index < black.length - 1; index++) {
    expect(playMove(game, black[index][0], black[index][1])).toEqual({ ok: true })
    expect(playMove(game, white[index][0], white[index][1])).toEqual({ ok: true })
  }
  expect(playMove(game, black[black.length - 1][0], black[black.length - 1][1])).toEqual({ ok: true })
}

function copyState<T>(value: T): T {
  return JSON.parse(JSON.stringify(value)) as T
}

describe('gomoku rules', () => {
  test('detects horizontal, vertical, and both diagonal lines', () => {
    const scenarios: Array<{
      name: string
      black: Array<[number, number]>
      expected: { start: { row: number; col: number }; end: { row: number; col: number } }
    }> = [
      {
        name: 'horizontal',
        black: [[0, 10], [0, 11], [0, 12], [0, 13], [0, 14]],
        expected: { start: { row: 0, col: 10 }, end: { row: 0, col: 14 } },
      },
      {
        name: 'vertical',
        black: [[10, 0], [11, 0], [12, 0], [13, 0], [14, 0]],
        expected: { start: { row: 10, col: 0 }, end: { row: 14, col: 0 } },
      },
      {
        name: 'main diagonal',
        black: [[0, 0], [1, 1], [2, 2], [3, 3], [4, 4]],
        expected: { start: { row: 0, col: 0 }, end: { row: 4, col: 4 } },
      },
      {
        name: 'anti diagonal',
        black: [[0, 14], [1, 13], [2, 12], [3, 11], [4, 10]],
        expected: { start: { row: 0, col: 14 }, end: { row: 4, col: 10 } },
      },
    ]

    for (const scenario of scenarios) {
      const game = createGame()
      playPairs(game, scenario.black, [[8, 1], [8, 3], [8, 5], [8, 7], [8, 9]])
      expect(game.winner, scenario.name).toBe(1)
      expect(game.winLine, scenario.name).toEqual(scenario.expected)
    }
  })

  test('returns the full segment for a line longer than five', () => {
    const game = createGame()
    playPairs(game, [[7, 2], [7, 3], [7, 4], [7, 6], [7, 7], [7, 5]], [
      [8, 1], [8, 3], [8, 5], [8, 7], [8, 9], [8, 11],
    ])

    expect(game.winner).toBe(1)
    expect(game.winLine).toEqual({ start: { row: 7, col: 2 }, end: { row: 7, col: 7 } })
    expect(game.moves).toHaveLength(11)
    expect(game.lastMove).toEqual({ row: 7, col: 5, player: 1 })
  })

  test('rejects occupied, out-of-bounds, non-integer, and wrong-turn moves', () => {
    const game = createGame()
    expect(playMove(game, 7, 7)).toEqual({ ok: true })
    expect(playMove(game, 7, 7)).toEqual({ ok: false, error: 'occupied' })
    expect(playMove(game, -1, 0)).toEqual({ ok: false, error: 'out_of_bounds' })
    expect(playMove(game, BOARD_SIZE, 0)).toEqual({ ok: false, error: 'out_of_bounds' })
    expect(playMove(game, 1.5, 0)).toEqual({ ok: false, error: 'out_of_bounds' })
    expect(playMove(game, Number.NaN, 0)).toEqual({ ok: false, error: 'out_of_bounds' })
    expect(playMove(game, 7, 8, 1)).toEqual({ ok: false, error: 'wrong_turn' })
    expect(game.moves).toHaveLength(1)
  })

  test('rejects every move after a winner', () => {
    const game = createGame()
    playPairs(game, [[7, 0], [7, 1], [7, 2], [7, 3], [7, 4]], [
      [8, 1], [8, 3], [8, 5], [8, 7], [8, 9],
    ])

    expect(playMove(game, 8, 8, 1)).toEqual({ ok: false, error: 'game_over' })
    expect(game.moves).toHaveLength(9)
    expect(game.winner).toBe(1)
  })

  test('draws after all 225 cells are filled without five in a row', () => {
    const cellsByPlayer: Record<Player, Array<[number, number]>> = { 1: [], 2: [] }
    for (let row = 0; row < BOARD_SIZE; row++) {
      for (let col = 0; col < BOARD_SIZE; col++) {
        const player = ((row * 2 + col) % 4 < 2 ? 1 : 2) as Player
        cellsByPlayer[player].push([row, col])
      }
    }

    const game = createGame()
    for (let index = 0; index < cellsByPlayer[1].length; index++) {
      expect(playMove(game, cellsByPlayer[1][index][0], cellsByPlayer[1][index][1])).toEqual({ ok: true })
      if (index < cellsByPlayer[2].length) {
        expect(playMove(game, cellsByPlayer[2][index][0], cellsByPlayer[2][index][1])).toEqual({ ok: true })
      }
    }

    expect(game.moves).toHaveLength(BOARD_SIZE * BOARD_SIZE)
    expect(game.moveCount).toBe(BOARD_SIZE * BOARD_SIZE)
    expect(game.lastMove?.player).toBe(1)
    expect(game.winner).toBeUndefined()
    expect(game.draw).toBe(true)
    expect(playMove(game, 0, 0)).toEqual({ ok: false, error: 'game_over' })
    expect(isGameState(game)).toBe(true)
  })

  test('undoes and redoes moves, including a winning move', () => {
    const game = createGame()
    playPairs(game, [[7, 0], [7, 1], [7, 2], [7, 3], [7, 4]], [
      [8, 1], [8, 3], [8, 5], [8, 7], [8, 9],
    ])
    expect(game.winner).toBe(1)

    expect(undoMove(game)).toEqual({ ok: true })
    expect(game.winner).toBeUndefined()
    expect(game.draw).toBe(false)
    expect(game.board[7][4]).toBe(0)
    expect(game.lastMove).toEqual({ row: 8, col: 7, player: 2 })
    expect(game.turn).toBe(1)
    expect(isGameState(game)).toBe(true)

    expect(redoMove(game)).toEqual({ ok: true })
    expect(game.winner).toBe(1)
    expect(game.board[7][4]).toBe(1)
    expect(game.lastMove).toEqual({ row: 7, col: 4, player: 1 })
    expect(game.redoMoves).toHaveLength(0)
    expect(isGameState(game)).toBe(true)
  })

  test('clears the redo branch after a new move', () => {
    const game = createGame()
    expect(playMove(game, 7, 7)).toEqual({ ok: true })
    expect(playMove(game, 7, 8)).toEqual({ ok: true })
    expect(playMove(game, 7, 9)).toEqual({ ok: true })

    expect(undoMove(game)).toEqual({ ok: true })
    expect(game.redoMoves).toEqual([{ row: 7, col: 9, player: 1 }])
    expect(undoMove(game)).toEqual({ ok: true })
    expect(game.redoMoves).toEqual([
      { row: 7, col: 9, player: 1 },
      { row: 7, col: 8, player: 2 },
    ])
    expect(redoMove(game)).toEqual({ ok: true })
    expect(game.lastMove).toEqual({ row: 7, col: 8, player: 2 })
    expect(playMove(game, 8, 8)).toEqual({ ok: true })
    expect(game.redoMoves).toHaveLength(0)
    expect(redoMove(game)).toEqual({ ok: false, error: 'nothing_to_redo' })
    expect(isGameState(game)).toBe(true)
  })

  test('reports empty undo and redo stacks', () => {
    const game = createGame()
    expect(undoMove(game)).toEqual({ ok: false, error: 'nothing_to_undo' })
    expect(redoMove(game)).toEqual({ ok: false, error: 'nothing_to_redo' })
  })

  test('validates derived state, history, and optional structures', () => {
    const game = createGame()
    playMove(game, 7, 7)
    playMove(game, 7, 8)
    expect(isGameState(game)).toBe(true)

    const badBoard = copyState(game)
    badBoard.board[0][0] = 1
    expect(isGameState(badBoard)).toBe(false)

    const badTurn = copyState(game)
    badTurn.turn = 2
    expect(isGameState(badTurn)).toBe(false)

    const badMoveCount = copyState(game)
    badMoveCount.moveCount = 1
    expect(isGameState(badMoveCount)).toBe(false)

    const badLastMove = copyState(game)
    badLastMove.lastMove = { row: 0, col: 0, player: 2 }
    expect(isGameState(badLastMove)).toBe(false)

    const badMoves = copyState(game)
    badMoves.moves[1] = { row: 7, col: 7, player: 2 }
    expect(isGameState(badMoves)).toBe(false)

    const badDraw = copyState(game)
    badDraw.draw = true
    expect(isGameState(badDraw)).toBe(false)

    const badWinLine = copyState(game)
    badWinLine.winLine = { start: { row: 0, col: 0 }, end: { row: 0, col: 4 } }
    expect(isGameState(badWinLine)).toBe(false)

    const badRedo = copyState(game)
    badRedo.redoMoves = [{ row: BOARD_SIZE, col: 0, player: 1 }]
    expect(isGameState(badRedo)).toBe(false)

    const missingFields = { board: game.board, turn: game.turn }
    expect(isGameState(missingFields)).toBe(false)
  })
})
