export const BOARD_SIZE = 15

const MAX_MOVES = BOARD_SIZE * BOARD_SIZE

export type Player = 1 | 2
export type Cell = 0 | Player
export type Point = { row: number; col: number }
export type WinLine = { start: Point; end: Point }
export type Move = Point & { player: Player }

export interface GameState {
  board: Cell[][]
  turn: Player
  winner?: Player
  winLine?: WinLine
  draw: boolean
  moves: Move[]
  redoMoves: Move[]
  moveCount: number
  lastMove?: Move
}

export type MoveError =
  | 'occupied'
  | 'game_over'
  | 'out_of_bounds'
  | 'wrong_turn'
  | 'nothing_to_undo'
  | 'nothing_to_redo'

export type MoveResult =
  | { ok: true }
  | { ok: false; error: MoveError }

type DerivedState = {
  board: Cell[][]
  turn: Player
  winner?: Player
  winLine?: WinLine
  draw: boolean
  lastMove?: Move
}

function isPlayer(value: unknown): value is Player {
  return value === 1 || value === 2
}

function isPoint(value: unknown): value is Point {
  if (!value || typeof value !== 'object') return false
  const point = value as Partial<Point>
  const row = point.row
  const col = point.col
  return typeof row === 'number'
    && typeof col === 'number'
    && Number.isInteger(row)
    && Number.isInteger(col)
    && row >= 0
    && row < BOARD_SIZE
    && col >= 0
    && col < BOARD_SIZE
}

function isMove(value: unknown): value is Move {
  return isPoint(value)
    && isPlayer((value as Partial<Move>).player)
}

function cloneMove(move: Move): Move {
  return { row: move.row, col: move.col, player: move.player }
}

function otherPlayer(player: Player): Player {
  return player === 1 ? 2 : 1
}

function emptyBoard(): Cell[][] {
  return Array.from({ length: BOARD_SIZE }, () => Array<Cell>(BOARD_SIZE).fill(0))
}

function sameMove(left: Move | undefined, right: Move | undefined): boolean {
  return left?.row === right?.row
    && left?.col === right?.col
    && left?.player === right?.player
}

function samePoint(left: Point | undefined, right: Point | undefined): boolean {
  return left?.row === right?.row && left?.col === right?.col
}

function sameWinLine(left: WinLine | undefined, right: WinLine | undefined): boolean {
  return samePoint(left?.start, right?.start) && samePoint(left?.end, right?.end)
}

function isBoard(value: unknown): value is Cell[][] {
  return Array.isArray(value)
    && value.length === BOARD_SIZE
    && value.every(row => Array.isArray(row)
      && row.length === BOARD_SIZE
      && row.every(cell => cell === 0 || cell === 1 || cell === 2))
}

function deriveState(moves: readonly Move[]): DerivedState | undefined {
  if (moves.length > MAX_MOVES) return

  const board = emptyBoard()
  const occupied = new Set<string>()
  let turn: Player = 1
  let winner: Player | undefined
  let winLine: WinLine | undefined
  let draw = false
  let lastMove: Move | undefined

  for (const move of moves) {
    if (!isMove(move) || move.player !== turn || winner || draw) return
    const key = `${move.row}:${move.col}`
    if (occupied.has(key) || board[move.row][move.col] !== 0) return

    board[move.row][move.col] = move.player
    occupied.add(key)
    lastMove = cloneMove(move)
    winLine = findWinLine(board, move.row, move.col, move.player)
    if (winLine) {
      winner = move.player
      continue
    }

    turn = otherPlayer(move.player)
    if (occupied.size === MAX_MOVES) draw = true
  }

  return { board, turn, winner, winLine, draw, lastMove }
}

function assignDerivedState(game: GameState, moves: readonly Move[], derived: DerivedState) {
  game.board = derived.board
  game.turn = derived.turn
  game.draw = derived.draw
  game.moves = moves.map(cloneMove)
  game.moveCount = game.moves.length

  if (derived.lastMove === undefined) delete game.lastMove
  else game.lastMove = cloneMove(derived.lastMove)
  if (derived.winner === undefined) delete game.winner
  else game.winner = derived.winner
  if (derived.winLine === undefined) delete game.winLine
  else game.winLine = {
    start: { ...derived.winLine.start },
    end: { ...derived.winLine.end },
  }
}

function rebuildFromMoves(game: GameState, moves: readonly Move[]): boolean {
  const derived = deriveState(moves)
  if (!derived) return false
  assignDerivedState(game, moves, derived)
  return true
}

export function createGame(): GameState {
  return {
    board: emptyBoard(),
    turn: 1,
    draw: false,
    moves: [],
    redoMoves: [],
    moveCount: 0,
  }
}

export function playMove(game: GameState, row: number, col: number, player = game.turn): MoveResult {
  if (!Number.isInteger(row) || !Number.isInteger(col) || row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) {
    return { ok: false, error: 'out_of_bounds' }
  }
  if (game.winner || game.draw) return { ok: false, error: 'game_over' }
  if (player !== game.turn) return { ok: false, error: 'wrong_turn' }
  if (game.board[row]?.[col]) return { ok: false, error: 'occupied' }

  const nextMoves = [...game.moves, { row, col, player }]
  if (!rebuildFromMoves(game, nextMoves)) return { ok: false, error: 'game_over' }
  game.redoMoves = []
  return { ok: true }
}

export function undoMove(game: GameState): MoveResult {
  if (!game.moves.length) return { ok: false, error: 'nothing_to_undo' }

  const undone = game.moves[game.moves.length - 1]
  const nextMoves = game.moves.slice(0, -1)
  const nextRedoMoves = [...(Array.isArray(game.redoMoves) ? game.redoMoves : []), cloneMove(undone)]
  if (!rebuildFromMoves(game, nextMoves)) return { ok: false, error: 'nothing_to_undo' }
  game.redoMoves = nextRedoMoves
  return { ok: true }
}

export function redoMove(game: GameState): MoveResult {
  if (!Array.isArray(game.redoMoves) || !game.redoMoves.length) {
    return { ok: false, error: 'nothing_to_redo' }
  }
  if (game.winner || game.draw) return { ok: false, error: 'game_over' }

  const redone = game.redoMoves[game.redoMoves.length - 1]
  const nextMoves = [...game.moves, cloneMove(redone)]
  if (!rebuildFromMoves(game, nextMoves)) return { ok: false, error: 'nothing_to_redo' }
  game.redoMoves = game.redoMoves.slice(0, -1)
  return { ok: true }
}

export function findWinLine(board: Cell[][], row: number, col: number, player: Player): WinLine | undefined {
  if (!isPlayer(player) || !isPoint({ row, col }) || !Array.isArray(board) || board[row]?.[col] !== player) return

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

function isValidWinLine(value: unknown): value is WinLine {
  if (!value || typeof value !== 'object') return false
  const line = value as Partial<WinLine>
  return isPoint(line.start) && isPoint(line.end)
}

export function isGameState(value: unknown): value is GameState {
  if (!value || typeof value !== 'object') return false
  const state = value as Partial<GameState>
  if (!isBoard(state.board) || !isPlayer(state.turn) || typeof state.draw !== 'boolean') return false
  if (state.winner !== undefined && !isPlayer(state.winner)) return false
  if (state.winLine !== undefined && !isValidWinLine(state.winLine)) return false
  if (!Array.isArray(state.moves) || !state.moves.every(isMove)) return false
  if (!Array.isArray(state.redoMoves) || !state.redoMoves.every(isMove)) return false
  if (typeof state.moveCount !== 'number'
    || !Number.isInteger(state.moveCount)
    || state.moveCount < 0
    || state.moveCount !== state.moves.length) return false
  if (state.lastMove !== undefined && !isMove(state.lastMove)) return false
  if (!sameMove(state.lastMove, state.moves[state.moves.length - 1])) return false

  const derived = deriveState(state.moves)
  if (!derived) return false
  if (state.turn !== derived.turn || state.draw !== derived.draw || state.winner !== derived.winner) return false
  if (!sameWinLine(state.winLine, derived.winLine)) return false
  for (let row = 0; row < BOARD_SIZE; row++) {
    for (let col = 0; col < BOARD_SIZE; col++) {
      if (state.board[row][col] !== derived.board[row][col]) return false
    }
  }

  if (state.redoMoves.length > 0 && (state.winner !== undefined || state.draw)) return false
  const continuation = [...state.moves, ...[...state.redoMoves].reverse()]
  if (!deriveState(continuation)) return false
  return true
}
