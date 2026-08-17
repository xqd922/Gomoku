import { afterAll, beforeAll, describe, expect, test } from 'bun:test'
import { dirname } from 'node:path'

type ServerMessage =
  | { type: 'welcome'; player: 1 | 2 }
  | { type: 'state'; players: number; state: { turn: 1 | 2; board: number[][] } }
  | { type: 'error'; message: string }

const port = 18_000 + Math.floor(Math.random() * 1_000)
let serverProcess: ReturnType<typeof Bun.spawn>

class TestClient {
  readonly socket: WebSocket
  private messages: ServerMessage[] = []
  private waiters: Array<{
    predicate: (message: ServerMessage) => boolean
    resolve: (message: ServerMessage) => void
  }> = []

  private constructor(socket: WebSocket) {
    this.socket = socket
    socket.addEventListener('message', event => {
      const message = JSON.parse(String(event.data)) as ServerMessage
      const waiterIndex = this.waiters.findIndex(waiter => waiter.predicate(message))
      if (waiterIndex >= 0) this.waiters.splice(waiterIndex, 1)[0].resolve(message)
      else this.messages.push(message)
    })
  }

  static async connect() {
    const socket = new WebSocket(`ws://127.0.0.1:${port}`)
    await new Promise<void>((resolve, reject) => {
      socket.addEventListener('open', () => resolve(), { once: true })
      socket.addEventListener('error', () => reject(new Error('WebSocket connection failed')), { once: true })
    })
    return new TestClient(socket)
  }

  send(message: unknown) {
    this.socket.send(JSON.stringify(message))
  }

  next(predicate: (message: ServerMessage) => boolean, timeoutMs = 3_000) {
    const queuedIndex = this.messages.findIndex(predicate)
    if (queuedIndex >= 0) return Promise.resolve(this.messages.splice(queuedIndex, 1)[0])

    return new Promise<ServerMessage>((resolve, reject) => {
      const waiter = { predicate, resolve }
      this.waiters.push(waiter)
      setTimeout(() => {
        const index = this.waiters.indexOf(waiter)
        if (index >= 0) this.waiters.splice(index, 1)
        reject(new Error('Timed out waiting for server message'))
      }, timeoutMs)
    })
  }

  close() {
    this.socket.close()
  }
}

beforeAll(async () => {
  serverProcess = Bun.spawn(['bun', 'run', 'server/index.ts'], {
    cwd: dirname(import.meta.dir),
    env: { ...Bun.env, PORT: String(port) },
    stdout: 'pipe',
    stderr: 'pipe',
  })

  const deadline = Date.now() + 10_000
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${port}`)
      if (response.ok) return
    } catch {
      await Bun.sleep(50)
    }
  }
  throw new Error('Gomoku server did not start')
}, 15_000)

afterAll(async () => {
  serverProcess.kill()
  await serverProcess.exited
})

describe('online game server', () => {
  test('assigns both players and synchronizes legal moves', async () => {
    const black = await TestClient.connect()
    const white = await TestClient.connect()

    black.send({ type: 'join', room: 'SYNC_ROOM' })
    expect(await black.next(message => message.type === 'welcome')).toEqual({ type: 'welcome', player: 1 })
    white.send({ type: 'join', room: 'SYNC_ROOM' })
    expect(await white.next(message => message.type === 'welcome')).toEqual({ type: 'welcome', player: 2 })
    await black.next(message => message.type === 'state' && message.players === 2)
    await white.next(message => message.type === 'state' && message.players === 2)

    black.send({ type: 'move', row: 7, col: 7 })
    const blackState = await black.next(message => message.type === 'state' && message.state.board[7][7] === 1)
    const whiteState = await white.next(message => message.type === 'state' && message.state.board[7][7] === 1)
    expect(blackState).toEqual(whiteState)

    black.close()
    white.close()
  })

  test('rejects a move from the wrong player', async () => {
    const black = await TestClient.connect()
    const white = await TestClient.connect()
    black.send({ type: 'join', room: 'TURN_ROOM' })
    white.send({ type: 'join', room: 'TURN_ROOM' })
    await black.next(message => message.type === 'state' && message.players === 2)
    await white.next(message => message.type === 'state' && message.players === 2)

    white.send({ type: 'move', row: 3, col: 3 })
    const response = await white.next(message => message.type === 'error')
    expect(response).toEqual({ type: 'error', message: '这一步无效' })

    black.close()
    white.close()
  })
})
