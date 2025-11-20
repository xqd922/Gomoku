export type NetMessage =
  | { type: 'join'; room: string; name?: string }
  | { type: 'welcome'; player: 1 | 2; id: number }
  | { type: 'ready' }
  | { type: 'peer_join'; id: number; player: 1 | 2; name?: string }
  | { type: 'peer_leave'; id: number }
  | { type: 'error'; message: string }
  | { type: 'move'; r: number; c: number; p: 1 | 2 }
  | { type: 'reset' }
  | { type: 'state'; snapshot: unknown }
  | { type: 'request_state' }

export interface ConnectOptions {
  url: string
  room: string
  name?: string
}

export class NetClient extends EventTarget {
  ws: WebSocket | null = null
  url = ''
  room = ''
  name?: string

  connect(opts: ConnectOptions) {
    this.url = opts.url
    this.room = opts.room
    this.name = opts.name
    this.ws = new WebSocket(this.url)
    this.ws.addEventListener('open', () => {
      this.send({ type: 'join', room: this.room, name: this.name })
      this.dispatchEvent(new Event('open'))
    })
    this.ws.addEventListener('message', (ev) => {
      try {
        const data = JSON.parse(String(ev.data)) as NetMessage
        this.dispatchEvent(new MessageEvent<NetMessage>('message', { data }))
      } catch {}
    })
    this.ws.addEventListener('close', () => {
      this.dispatchEvent(new Event('close'))
      this.ws = null
    })
    this.ws.addEventListener('error', () => {
      this.dispatchEvent(new Event('error'))
    })
  }

  send(msg: NetMessage) {
    if (!this.ws || this.ws.readyState !== WebSocket.OPEN) return
    this.ws.send(JSON.stringify(msg))
  }

  disconnect() {
    if (this.ws) this.ws.close()
    this.ws = null
  }
}

