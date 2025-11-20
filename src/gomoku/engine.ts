import type { GameState, Move, Player, PlaceError, Result } from './types'

export function createState(n = 15): GameState {
  const board = Array.from({ length: n }, () => Array(n).fill(0))
  return { n, board, turn: 1, history: [], redo: [] }
}

export function inBounds(s: GameState, r: number, c: number) {
  return r >= 0 && r < s.n && c >= 0 && c < s.n
}

export function tryPlaceStone(s: GameState, r: number, c: number): Result<Move, PlaceError> {
  if (s.winner) return { ok: false, error: 'game_over' }
  if (!inBounds(s, r, c)) return { ok: false, error: 'out_of_bounds' }
  if (s.board[r][c] !== 0) return { ok: false, error: 'occupied' }
  const p = s.turn
  s.board[r][c] = p
  const m: Move = { r, c, p }
  s.last = m
  s.history.push(m)
  s.redo.length = 0
  const line = checkWinLine(s.board, r, c, p)
  if (line) {
    s.winner = p
    s.winLine = line
  } else {
    s.turn = p === 1 ? 2 : 1
  }
  return { ok: true, value: m }
}

export function placeStone(s: GameState, r: number, c: number): boolean {
  const res = tryPlaceStone(s, r, c)
  return res.ok
}

export function undo(s: GameState): boolean {
  const m = s.history.pop()
  if (!m) return false
  s.board[m.r][m.c] = 0
  s.redo.push(m)
  s.winner = undefined
  s.last = s.history[s.history.length - 1]
  s.turn = m.p // 轮到刚悔棋的玩家落子
  return true
}

export function redo(s: GameState): boolean {
  const m = s.redo.pop()
  if (!m) return false
  if (s.board[m.r][m.c] !== 0) return false
  s.board[m.r][m.c] = m.p
  s.history.push(m)
  s.last = m
  const line = checkWinLine(s.board, m.r, m.c, m.p)
  if (line) {
    s.winner = m.p
    s.winLine = line
  } else {
    s.turn = m.p === 1 ? 2 : 1
  }
  return true
}

export function checkWin(board: number[][], r: number, c: number, p: Player): boolean {
  return !!checkWinLine(board, r, c, p)
}

export function checkWinLine(
  board: number[][],
  r: number,
  c: number,
  p: Player,
): { start: { r: number; c: number }; end: { r: number; c: number } } | null {
  const dirs = [
    [1, 0],
    [0, 1],
    [1, 1],
    [1, -1],
  ] as const
  const n = board.length
  for (const [dr, dc] of dirs) {
    let count = 1
    let rMin = r, cMin = c, rMax = r, cMax = c
    // 正向
    let rr = r + dr
    let cc = c + dc
    while (rr >= 0 && rr < n && cc >= 0 && cc < n && board[rr][cc] === p) {
      count++
      rMax = rr
      cMax = cc
      rr += dr
      cc += dc
    }
    // 反向
    rr = r - dr
    cc = c - dc
    while (rr >= 0 && rr < n && cc >= 0 && cc < n && board[rr][cc] === p) {
      count++
      rMin = rr
      cMin = cc
      rr -= dr
      cc -= dc
    }
    if (count >= 5) {
      return { start: { r: rMin, c: cMin }, end: { r: rMax, c: cMax } }
    }
  }
  return null
}
