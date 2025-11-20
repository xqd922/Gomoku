// Minimal WebSocket relay server with simple 2-player rooms
import { WebSocketServer } from 'ws'

const PORT = process.env.PORT ? Number(process.env.PORT) : 8787
const wss = new WebSocketServer({ port: PORT })

/** @type {Map<string, Set<WebSocket & { __meta?: any }>>} */
const rooms = new Map()
let idSeq = 1

function send(ws, data) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(data))
}

function broadcast(room, from, data) {
  const set = rooms.get(room)
  if (!set) return
  for (const client of set) {
    if (client !== from && client.readyState === client.OPEN) {
      client.send(JSON.stringify(data))
    }
  }
}

wss.on('connection', (ws) => {
  ws.__meta = { id: idSeq++ }

  ws.on('message', (raw) => {
    let msg
    try { msg = JSON.parse(String(raw)) } catch { return }
    const meta = ws.__meta
    if (!meta) return

    if (msg.type === 'join') {
      const room = String(msg.room || '')
      if (!room) { send(ws, { type: 'error', message: 'room_required' }); return }
      let set = rooms.get(room)
      if (!set) { set = new Set(); rooms.set(room, set) }
      if (set.size >= 2) { send(ws, { type: 'error', message: 'room_full' }); return }
      meta.room = room
      meta.name = String(msg.name || '')
      meta.player = set.size === 0 ? 1 : 2
      set.add(ws)
      send(ws, { type: 'welcome', player: meta.player, id: meta.id })
      broadcast(room, ws, { type: 'peer_join', id: meta.id, player: meta.player, name: meta.name })
      if (set.size === 2) {
        // notify both ready
        for (const c of set) send(c, { type: 'ready' })
      }
      return
    }

    // pass-through messages within room
    if (meta.room) {
      const data = { ...msg, from: meta.id }
      broadcast(meta.room, ws, data)
    }
  })

  ws.on('close', () => {
    const meta = ws.__meta
    if (!meta || !meta.room) return
    const set = rooms.get(meta.room)
    if (set) {
      set.delete(ws)
      broadcast(meta.room, ws, { type: 'peer_leave', id: meta.id })
      if (set.size === 0) rooms.delete(meta.room)
    }
  })
})

console.log(`[ws-server] listening on ws://localhost:${PORT}`)

