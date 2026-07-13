import './styles.css'
import {
  BOARD_SIZE,
  createGame,
  isGameState,
  playMove,
  type GameState,
  type Player,
} from './game'

type ServerMessage =
  | { type: 'welcome'; player: Player }
  | { type: 'state'; state: GameState; players: number }
  | { type: 'error'; message: string }

const canvas = document.querySelector<HTMLCanvasElement>('#board')!
const context = canvas.getContext('2d')!
const status = document.querySelector<HTMLElement>('#status')!
const identity = document.querySelector<HTMLElement>('#identity')!
const localModeButton = document.querySelector<HTMLButtonElement>('#local-mode')!
const onlineModeButton = document.querySelector<HTMLButtonElement>('#online-mode')!
const onlinePanel = document.querySelector<HTMLElement>('#online-panel')!
const serverInput = document.querySelector<HTMLInputElement>('#server-url')!
const roomInput = document.querySelector<HTMLInputElement>('#room-code')!
const connectButton = document.querySelector<HTMLButtonElement>('#connect')!
const disconnectButton = document.querySelector<HTMLButtonElement>('#disconnect')!
const resetButton = document.querySelector<HTMLButtonElement>('#reset')!

let game = createGame()
let mode: 'local' | 'online' = 'local'
let socket: WebSocket | null = null
let myPlayer: Player | null = null
let playerCount = 0
let cursor = { row: 7, col: 7 }

function playerName(player: Player) {
  return player === 1 ? '黑方' : '白方'
}

function updateStatus(message?: string) {
  if (message) status.textContent = message
  else if (game.winner) status.textContent = `${playerName(game.winner)}获胜`
  else if (mode === 'online' && playerCount < 2) status.textContent = '等待另一位玩家加入'
  else status.textContent = `轮到${playerName(game.turn)}`

  identity.textContent = mode === 'local'
    ? '同机双人'
    : myPlayer
      ? `你是${playerName(myPlayer)}`
      : '尚未连接'
  canvas.setAttribute('aria-label', `${status.textContent}，当前选择第 ${cursor.row + 1} 行第 ${cursor.col + 1} 列`)
}

function resizeCanvas() {
  const size = Math.floor(canvas.getBoundingClientRect().width)
  const ratio = window.devicePixelRatio || 1
  canvas.width = size * ratio
  canvas.height = size * ratio
  context.setTransform(ratio, 0, 0, ratio, 0, 0)
  render(size)
}

function render(size = canvas.getBoundingClientRect().width) {
  const padding = Math.max(20, size * 0.055)
  const cell = (size - padding * 2) / (BOARD_SIZE - 1)
  context.clearRect(0, 0, size, size)
  context.fillStyle = '#d8a85f'
  context.fillRect(0, 0, size, size)
  context.strokeStyle = 'rgba(62, 36, 18, 0.74)'
  context.lineWidth = 1

  for (let index = 0; index < BOARD_SIZE; index++) {
    const point = padding + index * cell
    context.beginPath()
    context.moveTo(padding, point)
    context.lineTo(size - padding, point)
    context.moveTo(point, padding)
    context.lineTo(point, size - padding)
    context.stroke()
  }

  context.fillStyle = '#4a2c17'
  for (const row of [3, 7, 11]) {
    for (const col of [3, 7, 11]) {
      context.beginPath()
      context.arc(padding + col * cell, padding + row * cell, Math.max(2.4, cell * 0.08), 0, Math.PI * 2)
      context.fill()
    }
  }

  for (let row = 0; row < BOARD_SIZE; row++) {
    for (let col = 0; col < BOARD_SIZE; col++) {
      const player = game.board[row][col]
      if (!player) continue
      const x = padding + col * cell
      const y = padding + row * cell
      const gradient = context.createRadialGradient(x - cell * 0.12, y - cell * 0.15, cell * 0.04, x, y, cell * 0.44)
      if (player === 1) {
        gradient.addColorStop(0, '#555')
        gradient.addColorStop(1, '#080808')
      } else {
        gradient.addColorStop(0, '#fff')
        gradient.addColorStop(1, '#cfcfcf')
      }
      context.fillStyle = gradient
      context.beginPath()
      context.arc(x, y, cell * 0.42, 0, Math.PI * 2)
      context.fill()
    }
  }

  if (game.winLine) {
    context.strokeStyle = '#ef4444'
    context.lineWidth = Math.max(3, cell * 0.1)
    context.lineCap = 'round'
    context.beginPath()
    context.moveTo(padding + game.winLine.start.col * cell, padding + game.winLine.start.row * cell)
    context.lineTo(padding + game.winLine.end.col * cell, padding + game.winLine.end.row * cell)
    context.stroke()
  }

  if (document.activeElement === canvas && !game.winner) {
    context.strokeStyle = '#2563eb'
    context.lineWidth = 2
    context.strokeRect(
      padding + cursor.col * cell - cell * 0.45,
      padding + cursor.row * cell - cell * 0.45,
      cell * 0.9,
      cell * 0.9,
    )
  }
}

function selectCell(clientX: number, clientY: number) {
  const bounds = canvas.getBoundingClientRect()
  const size = bounds.width
  const padding = Math.max(20, size * 0.055)
  const cell = (size - padding * 2) / (BOARD_SIZE - 1)
  const col = Math.round((clientX - bounds.left - padding) / cell)
  const row = Math.round((clientY - bounds.top - padding) / cell)
  if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) return
  cursor = { row, col }
  placeSelectedStone()
}

function placeSelectedStone() {
  if (mode === 'online') {
    if (!socket || socket.readyState !== WebSocket.OPEN || !myPlayer) return updateStatus('请先连接房间')
    if (playerCount < 2) return updateStatus('等待另一位玩家加入')
    if (game.turn !== myPlayer) return updateStatus('现在是对方回合')
    socket.send(JSON.stringify({ type: 'move', row: cursor.row, col: cursor.col }))
    return
  }

  const result = playMove(game, cursor.row, cursor.col)
  if (!result.ok) updateStatus(result.error === 'occupied' ? '这个位置已有棋子' : '本局已经结束')
  else updateStatus()
  render()
}

function setMode(nextMode: 'local' | 'online') {
  mode = nextMode
  localModeButton.classList.toggle('active', mode === 'local')
  onlineModeButton.classList.toggle('active', mode === 'online')
  onlinePanel.hidden = mode !== 'online'
  if (mode === 'local') disconnect()
  game = createGame()
  playerCount = mode === 'local' ? 2 : 0
  updateStatus()
  render()
}

function isServerMessage(value: unknown): value is ServerMessage {
  if (!value || typeof value !== 'object' || !('type' in value)) return false
  const message = value as Record<string, unknown>
  if (message.type === 'welcome') return message.player === 1 || message.player === 2
  if (message.type === 'error') return typeof message.message === 'string'
  return message.type === 'state'
    && typeof message.players === 'number'
    && isGameState(message.state)
}

function connect() {
  disconnect()
  let url: URL
  try {
    url = new URL(serverInput.value.trim())
    if (url.protocol !== 'ws:' && url.protocol !== 'wss:') throw new Error()
  } catch {
    updateStatus('服务器地址必须以 ws:// 或 wss:// 开头')
    return
  }

  const room = roomInput.value.trim().toUpperCase()
  if (!/^[A-Z0-9_-]{2,20}$/.test(room)) {
    updateStatus('房间号需要 2–20 位字母或数字')
    return
  }

  socket = new WebSocket(url)
  updateStatus('正在连接服务器…')
  connectButton.disabled = true
  disconnectButton.disabled = false

  socket.addEventListener('open', () => socket?.send(JSON.stringify({ type: 'join', room })))
  socket.addEventListener('message', event => {
    try {
      const message: unknown = JSON.parse(String(event.data))
      if (!isServerMessage(message)) return
      if (message.type === 'welcome') myPlayer = message.player
      if (message.type === 'state') {
        game = message.state
        playerCount = message.players
      }
      if (message.type === 'error') updateStatus(message.message)
      else updateStatus()
      render()
    } catch {
      updateStatus('服务器返回了无效数据')
    }
  })
  socket.addEventListener('close', () => {
    socket = null
    myPlayer = null
    playerCount = 0
    connectButton.disabled = false
    disconnectButton.disabled = true
    updateStatus('连接已断开')
  })
  socket.addEventListener('error', () => updateStatus('无法连接服务器'))
}

function disconnect() {
  socket?.close()
  socket = null
  myPlayer = null
  playerCount = 0
  connectButton.disabled = false
  disconnectButton.disabled = true
}

canvas.addEventListener('pointerdown', event => selectCell(event.clientX, event.clientY))
canvas.addEventListener('focus', () => render())
canvas.addEventListener('blur', () => render())
canvas.addEventListener('keydown', event => {
  const movement: Record<string, [number, number]> = {
    ArrowUp: [-1, 0],
    ArrowDown: [1, 0],
    ArrowLeft: [0, -1],
    ArrowRight: [0, 1],
  }
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    placeSelectedStone()
    return
  }
  const delta = movement[event.key]
  if (!delta) return
  event.preventDefault()
  cursor.row = Math.max(0, Math.min(BOARD_SIZE - 1, cursor.row + delta[0]))
  cursor.col = Math.max(0, Math.min(BOARD_SIZE - 1, cursor.col + delta[1]))
  updateStatus()
  render()
})

localModeButton.addEventListener('click', () => setMode('local'))
onlineModeButton.addEventListener('click', () => setMode('online'))
connectButton.addEventListener('click', connect)
disconnectButton.addEventListener('click', disconnect)
resetButton.addEventListener('click', () => {
  if (mode === 'online') socket?.send(JSON.stringify({ type: 'reset' }))
  else {
    game = createGame()
    updateStatus()
    render()
  }
})

new ResizeObserver(resizeCanvas).observe(canvas)
setMode('local')
