export const BOARD_SIZE = 15

export type Player = 1 | 2
export type Cell = 0 | Player
export type Point = { row: number; col: number }
export type WinLine = { start: Point; end: Point }

export interface GameState {
  board: Cell[][]
  turn: Player
  winner?: Player
  winLine?: WinLine
}

export type MoveResult =
  | { ok: true }
  | { ok: false; error: 'occupied' | 'game_over' | 'out_of_bounds' | 'wrong_turn' }

export function createGame(): GameState {
  return {
    board: Array.from({ length: BOARD_SIZE }, () => Array<Cell>(BOARD_SIZE).fill(0)),
    turn: 1,
  }
}

export function playMove(game: GameState, row: number, col: number, player = game.turn): MoveResult {
  if (!Number.isInteger(row) || !Number.isInteger(col) || row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) {
    return { ok: false, error: 'out_of_bounds' }
  }
  if (game.winner) return { ok: false, error: 'game_over' }
  if (player !== game.turn) return { ok: false, error: 'wrong_turn' }
  if (game.board[row][col]) return { ok: false, error: 'occupied' }

  game.board[row][col] = player
  game.winLine = findWinLine(game.board, row, col, player)
  if (game.winLine) game.winner = player
  else game.turn = player === 1 ? 2 : 1
  return { ok: true }
}

export function findWinLine(board: Cell[][], row: number, col: number, player: Player): WinLine | undefined {
  const directions = [[1, 0], [0, 1], [1, 1], [1, -1]] as const
  for (const [rowStep, colStep] of directions) {
    const points = [{ row, col }]
    for (const sign of [-1, 1] as const) {
      let nextRow = row + rowStep * sign
      let nextCol = col + colStep * sign
      while (board[nextRow]?.[nextCol] === player) {
        points.push({ row: nextRow, col: nextCol })
        nextRow += rowStep * sign
        nextCol += colStep * sign
      }
    }
    if (points.length >= 5) {
      points.sort((a, b) => a.row - b.row || a.col - b.col)
      return { start: points[0], end: points[points.length - 1] }
    }
  }
}

export function isGameState(value: unknown): value is GameState {
  if (!value || typeof value !== 'object') return false
  const state = value as Partial<GameState>
  return (state.turn === 1 || state.turn === 2)
    && (state.winner === undefined || state.winner === 1 || state.winner === 2)
    && Array.isArray(state.board)
    && state.board.length === BOARD_SIZE
    && state.board.every(row => Array.isArray(row)
      && row.length === BOARD_SIZE
      && row.every(cell => cell === 0 || cell === 1 || cell === 2))
}
