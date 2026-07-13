import { createGame, playMove, type GameState, type Player } from '../src/game'

type ClientData = { room?: string; player?: Player }
type ClientMessage = { type: 'join'; room: string } | { type: 'move'; row: number; col: number } | { type: 'reset' }
type Socket = import('bun').ServerWebSocket<ClientData>
type Room = { game: GameState; players: Array<Socket | null> }

const port = Number(Bun.env.PORT || 8787)
const rooms = new Map<string, Room>()

function send(socket: Socket, message: unknown) {
  socket.send(JSON.stringify(message))
}

function broadcast(room: Room) {
  const message = JSON.stringify({
    type: 'state',
    state: room.game,
    players: room.players.filter(Boolean).length,
  })
  for (const socket of room.players) socket?.send(message)
}

function parseMessage(raw: string | Buffer): ClientMessage | undefined {
  try {
    const value: unknown = JSON.parse(String(raw))
    if (!value || typeof value !== 'object' || !('type' in value)) return
    const message = value as Record<string, unknown>
    if (message.type === 'join' && typeof message.room === 'string') return { type: 'join', room: message.room }
    if (message.type === 'reset') return { type: 'reset' }
    if (message.type === 'move' && Number.isInteger(message.row) && Number.isInteger(message.col)) {
      return { type: 'move', row: Number(message.row), col: Number(message.col) }
    }
  } catch {
    return
  }
}

function leave(socket: Socket) {
  const { room: roomCode, player } = socket.data
  if (!roomCode || !player) return
  const room = rooms.get(roomCode)
  if (!room) return
  if (room.players[player - 1] === socket) room.players[player - 1] = null
  if (room.players.every(value => !value)) rooms.delete(roomCode)
  else broadcast(room)
}

Bun.serve<ClientData>({
  port,
  fetch(request, server) {
    if (server.upgrade(request, { data: {} })) return
    return new Response('Gomoku WebSocket server')
  },
  websocket: {
    open() {},
    message(socket, raw) {
      const message = parseMessage(raw)
      if (!message) return send(socket, { type: 'error', message: '无效请求' })

      if (message.type === 'join') {
        if (socket.data.room) return send(socket, { type: 'error', message: '已经加入房间' })
        const roomCode = message.room.trim().toUpperCase()
        if (!/^[A-Z0-9_-]{2,20}$/.test(roomCode)) return send(socket, { type: 'error', message: '房间号格式错误' })
        const room = rooms.get(roomCode) ?? { game: createGame(), players: [null, null] }
        const slot = room.players.findIndex(value => !value)
        if (slot === -1) return send(socket, { type: 'error', message: '房间已满' })
        const player = (slot + 1) as Player
        room.players[slot] = socket
        rooms.set(roomCode, room)
        socket.data.room = roomCode
        socket.data.player = player
        send(socket, { type: 'welcome', player })
        broadcast(room)
        return
      }

      const room = socket.data.room ? rooms.get(socket.data.room) : undefined
      if (!room || !socket.data.player) return send(socket, { type: 'error', message: '请先加入房间' })
      if (message.type === 'reset') {
        room.game = createGame()
        broadcast(room)
        return
      }
      if (room.players.filter(Boolean).length < 2) return send(socket, { type: 'error', message: '等待另一位玩家加入' })
      const result = playMove(room.game, message.row, message.col, socket.data.player)
      if (!result.ok) return send(socket, { type: 'error', message: '这一步无效' })
      broadcast(room)
    },
    close(socket) {
      leave(socket)
    },
  },
})

console.log(`Gomoku server listening on ws://0.0.0.0:${port}`)
