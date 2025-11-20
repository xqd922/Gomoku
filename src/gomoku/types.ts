export type Player = 1 | 2

export interface Move { r: number; c: number; p: Player }

export interface GameState {
  n: number
  board: number[][]
  turn: Player
  winner?: Player
  last?: Move
  winLine?: { start: { r: number; c: number }; end: { r: number; c: number } }
  history: Move[]
  redo: Move[]
}
