import { describe, expect, test } from 'bun:test'
import { createGame, playMove } from './game'

describe('gomoku rules', () => {
  test('detects five stones in a row', () => {
    const game = createGame()
    for (let col = 0; col < 4; col++) {
      expect(playMove(game, 7, col).ok).toBe(true)
      expect(playMove(game, 8, col).ok).toBe(true)
    }
    expect(playMove(game, 7, 4).ok).toBe(true)
    expect(game.winner).toBe(1)
  })

  test('rejects occupied intersections', () => {
    const game = createGame()
    playMove(game, 7, 7)
    expect(playMove(game, 7, 7)).toEqual({ ok: false, error: 'occupied' })
  })
})
