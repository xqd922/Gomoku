import { createIcons, Globe2, Redo2, RotateCcw, Undo2, UsersRound } from 'lucide'
import './styles.css'
import {
  BOARD_SIZE,
  createGame,
  isGameState,
  playMove,
  redoMove,
  undoMove,
  type GameState,
  type Player,
  type Point,
} from './game'

type ServerMessage =
  | { type: 'welcome'; player: Player }
  | { type: 'state'; state: GameState; players: number }
  | { type: 'error'; message: string }

type Mode = 'local' | 'online'
type BoardGeometry = { size: number; padding: number; cell: number }

const ALPHABET = 'ABCDEFGHIJKLMNO'
const ROOM_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
const canvas = document.querySelector<HTMLCanvasElement>('#board')!
const context = canvas.getContext('2d')!
const status = document.querySelector<HTMLElement>('#status')!
const identity = document.querySelector<HTMLElement>('#identity')!
const statusStone = document.querySelector<HTMLElement>('#status-stone')!
const blackPlayer = document.querySelector<HTMLElement>('#black-player')!
const whitePlayer = document.querySelector<HTMLElement>('#white-player')!
const moveCount = document.querySelector<HTMLElement>('#move-count')!
const lastMoveLabel = document.querySelector<HTMLElement>('#last-move-label')!
const localModeButton = document.querySelector<HTMLButtonElement>('#local-mode')!
const onlineModeButton = document.querySelector<HTMLButtonElement>('#online-mode')!
const onlinePanel = document.querySelector<HTMLElement>('#online-panel')!
const serverInput = document.querySelector<HTMLInputElement>('#server-url')!
const roomInput = document.querySelector<HTMLInputElement>('#room-code')!
const connectButton = document.querySelector<HTMLButtonElement>('#connect')!
const disconnectButton = document.querySelector<HTMLButtonElement>('#disconnect')!
const undoButton = document.querySelector<HTMLButtonElement>('#undo')!
const redoButton = document.querySelector<HTMLButtonElement>('#redo')!
const resetButton = document.querySelector<HTMLButtonElement>('#reset')!
const dialog = document.querySelector<HTMLDialogElement>('#new-game-dialog')!
const cancelNewGameButton = document.querySelector<HTMLButtonElement>('#cancel-new-game')!
const confirmNewGameButton = document.querySelector<HTMLButtonElement>('#confirm-new-game')!
const connectionMark = document.querySelector<HTMLElement>('.connection-mark')!

let game = createGame()
let mode: Mode = 'local'
let socket: WebSocket | null = null
let myPlayer: Player | null = null
let playerCount = 2
let cursor: Point = { row: 7, col: 7 }
let preview: Point | undefined
let activePointerId: number | undefined
let resizeFrame = 0
let notice: string | undefined
let noticeTimer = 0
let keyboardNavigation = false

createIcons({ icons: { Globe2, Redo2, RotateCcw, Undo2, UsersRound } })

function randomRoomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6))
  return Array.from(bytes, value => ROOM_ALPHABET[value & 31]).join('')
}

roomInput.value = randomRoomCode()
if (/Android/i.test(navigator.userAgent)) serverInput.value = 'ws://10.0.2.2:8787'

function playerName(player: Player) {
  return player === 1 ? '黑方' : '白方'
}

function coordinateName(point: Point) {
  return `${ALPHABET[point.col]}${BOARD_SIZE - point.row}`
}

function currentCellDescription() {
  const cell = game.board[cursor.row][cursor.col]
  if (cell) return `${coordinateName(cursor)}，${playerName(cell)}已有棋子`
  if (game.winner || game.draw) return `${coordinateName(cursor)}，空位，本局已结束`
  return `${coordinateName(cursor)}，空位，可落${playerName(game.turn)}棋`
}

function setNotice(message: string) {
  notice = message
  window.clearTimeout(noticeTimer)
  noticeTimer = window.setTimeout(() => {
    notice = undefined
    updateStatus()
  }, 2_800)
  updateStatus()
}

function clearNotice() {
  notice = undefined
  window.clearTimeout(noticeTimer)
  noticeTimer = 0
}

function updateStatus() {
  let message = notice
  if (!message) {
    if (game.winner) message = `${playerName(game.winner)}获胜`
    else if (game.draw) message = '棋盘已满，和棋'
    else if (mode === 'online' && playerCount < 2) message = '等待另一位玩家加入'
    else if (mode === 'online' && myPlayer && game.turn !== myPlayer) message = '等待对方落子'
    else message = `轮到${playerName(game.turn)}`
  }

  status.textContent = message
  identity.textContent = mode === 'local'
    ? '同机双人'
    : myPlayer
      ? `你执${playerName(myPlayer)}`
      : '未连接房间'
  moveCount.textContent = game.moveCount ? `第 ${game.moveCount} 手` : '尚未落子'
  lastMoveLabel.textContent = game.lastMove
    ? `最后一手：${coordinateName(game.lastMove)}`
    : '最后一手：暂无'

  const activePlayer = game.winner ?? (!game.draw ? game.turn : undefined)
  blackPlayer.classList.toggle('active', activePlayer === 1)
  whitePlayer.classList.toggle('active', activePlayer === 2)
  if (activePlayer === 1) blackPlayer.setAttribute('aria-current', 'true')
  else blackPlayer.removeAttribute('aria-current')
  if (activePlayer === 2) whitePlayer.setAttribute('aria-current', 'true')
  else whitePlayer.removeAttribute('aria-current')

  const stonePlayer = game.winner ?? game.turn
  statusStone.className = `status-stone ${stonePlayer === 1 ? 'black' : 'white'}`
  canvas.setAttribute('aria-label', `${message}，${currentCellDescription()}`)
  undoButton.disabled = mode !== 'local' || game.moves.length === 0
  redoButton.disabled = mode !== 'local' || game.redoMoves.length === 0
  connectButton.disabled = socket?.readyState === WebSocket.CONNECTING
    || (socket?.readyState === WebSocket.OPEN && myPlayer !== null)
  disconnectButton.disabled = socket?.readyState !== WebSocket.OPEN
  connectionMark.classList.toggle('connected', socket?.readyState === WebSocket.OPEN)
  connectionMark.classList.toggle('waiting', mode === 'online' && socket?.readyState === WebSocket.OPEN && playerCount < 2)
}

function boardGeometry(size: number): BoardGeometry {
  const padding = Math.max(18, Math.min(36, size * 0.075))
  return { size, padding, cell: (size - padding * 2) / (BOARD_SIZE - 1) }
}

function resizeCanvas() {
  cancelAnimationFrame(resizeFrame)
  resizeFrame = requestAnimationFrame(() => {
    const size = Math.max(1, Math.floor(canvas.getBoundingClientRect().width))
    const ratio = Math.min(window.devicePixelRatio || 1, 3)
    const pixelSize = Math.max(1, Math.round(size * ratio))
    if (canvas.width !== pixelSize || canvas.height !== pixelSize) {
      canvas.width = pixelSize
      canvas.height = pixelSize
    }
    context.setTransform(ratio, 0, 0, ratio, 0, 0)
    render(size)
  })
}

function drawWoodGrain(size: number) {
  context.save()
  context.globalAlpha = 0.12
  context.strokeStyle = '#7a4e27'
  context.lineWidth = 0.7
  for (let line = 0; line < 11; line++) {
    const baseline = (size / 10) * line
    context.beginPath()
    for (let x = -20; x <= size + 20; x += 18) {
      const y = baseline + Math.sin(x * 0.018 + line * 1.7) * (1.5 + (line % 3))
      if (x === -20) context.moveTo(x, y)
      else context.lineTo(x, y)
    }
    context.stroke()
  }
  context.restore()
}

function drawStone(point: Point, player: Player, geometry: BoardGeometry, alpha = 1) {
  const x = geometry.padding + point.col * geometry.cell
  const y = geometry.padding + point.row * geometry.cell
  const radius = geometry.cell * 0.42
  const gradient = context.createRadialGradient(
    x - geometry.cell * 0.13,
    y - geometry.cell * 0.17,
    geometry.cell * 0.05,
    x,
    y,
    radius,
  )
  if (player === 1) {
    gradient.addColorStop(0, '#59645e')
    gradient.addColorStop(0.42, '#1d2521')
    gradient.addColorStop(1, '#080a09')
  } else {
    gradient.addColorStop(0, '#ffffff')
    gradient.addColorStop(0.54, '#f0f3f0')
    gradient.addColorStop(1, '#c7cfca')
  }
  context.save()
  context.globalAlpha = alpha
  context.fillStyle = gradient
  context.shadowColor = 'rgba(25, 34, 29, 0.25)'
  context.shadowBlur = geometry.cell * 0.13
  context.shadowOffsetY = geometry.cell * 0.08
  context.beginPath()
  context.arc(x, y, radius, 0, Math.PI * 2)
  context.fill()
  context.restore()
}

function render(size = Math.max(1, Math.floor(canvas.getBoundingClientRect().width))) {
  const geometry = boardGeometry(size)
  context.clearRect(0, 0, size, size)
  context.fillStyle = '#d7a662'
  context.fillRect(0, 0, size, size)
  drawWoodGrain(size)

  context.strokeStyle = 'rgba(55, 39, 24, 0.68)'
  context.lineWidth = Math.max(0.75, Math.min(1.35, geometry.cell * 0.035))
  for (let index = 0; index < BOARD_SIZE; index++) {
    const point = geometry.padding + index * geometry.cell
    context.beginPath()
    context.moveTo(geometry.padding, point)
    context.lineTo(size - geometry.padding, point)
    context.moveTo(point, geometry.padding)
    context.lineTo(point, size - geometry.padding)
    context.stroke()
  }

  context.fillStyle = '#50331d'
  for (const row of [3, 7, 11]) {
    for (const col of [3, 7, 11]) {
      context.beginPath()
      context.arc(
        geometry.padding + col * geometry.cell,
        geometry.padding + row * geometry.cell,
        Math.max(2.2, geometry.cell * 0.075),
        0,
        Math.PI * 2,
      )
      context.fill()
    }
  }

  const labelSize = Math.max(7, Math.min(11, geometry.cell * 0.28))
  context.fillStyle = 'rgba(62, 44, 27, 0.8)'
  context.font = `650 ${labelSize}px ui-sans-serif, system-ui, sans-serif`
  context.textAlign = 'center'
  context.textBaseline = 'middle'
  for (let col = 0; col < BOARD_SIZE; col++) {
    context.fillText(ALPHABET[col], geometry.padding + col * geometry.cell, size - geometry.padding * 0.38)
  }
  context.textAlign = 'right'
  for (let row = 0; row < BOARD_SIZE; row++) {
    context.fillText(String(BOARD_SIZE - row), geometry.padding * 0.42, geometry.padding + row * geometry.cell)
  }

  if (game.winLine) {
    context.save()
    context.strokeStyle = 'rgba(239, 106, 75, 0.72)'
    context.lineWidth = Math.max(3, geometry.cell * 0.11)
    context.lineCap = 'round'
    context.beginPath()
    context.moveTo(
      geometry.padding + game.winLine.start.col * geometry.cell,
      geometry.padding + game.winLine.start.row * geometry.cell,
    )
    context.lineTo(
      geometry.padding + game.winLine.end.col * geometry.cell,
      geometry.padding + game.winLine.end.row * geometry.cell,
    )
    context.stroke()
    context.restore()
  }

  for (let row = 0; row < BOARD_SIZE; row++) {
    for (let col = 0; col < BOARD_SIZE; col++) {
      const player = game.board[row][col]
      if (player) drawStone({ row, col }, player, geometry)
    }
  }

  if (preview && !game.board[preview.row][preview.col] && !game.winner && !game.draw) {
    drawStone(preview, game.turn, geometry, 0.38)
  }

  if (game.lastMove) {
    const x = geometry.padding + game.lastMove.col * geometry.cell
    const y = geometry.padding + game.lastMove.row * geometry.cell
    context.save()
    context.strokeStyle = game.lastMove.player === 1 ? '#f2f5f1' : '#173d36'
    context.lineWidth = Math.max(1.5, geometry.cell * 0.045)
    context.beginPath()
    context.arc(x, y, geometry.cell * 0.16, 0, Math.PI * 2)
    context.stroke()
    context.restore()
  }

  if (document.activeElement === canvas && keyboardNavigation) {
    const x = geometry.padding + cursor.col * geometry.cell
    const y = geometry.padding + cursor.row * geometry.cell
    const side = geometry.cell * 0.82
    context.save()
    context.strokeStyle = '#246348'
    context.lineWidth = Math.max(1.5, geometry.cell * 0.055)
    context.strokeRect(x - side / 2, y - side / 2, side, side)
    context.restore()
  }
}

function hitTest(clientX: number, clientY: number): Point | undefined {
  const bounds = canvas.getBoundingClientRect()
  const size = bounds.width
  const geometry = boardGeometry(size)
  const col = Math.round((clientX - bounds.left - geometry.padding) / geometry.cell)
  const row = Math.round((clientY - bounds.top - geometry.padding) / geometry.cell)
  if (row < 0 || row >= BOARD_SIZE || col < 0 || col >= BOARD_SIZE) return
  const x = bounds.left + geometry.padding + col * geometry.cell
  const y = bounds.top + geometry.padding + row * geometry.cell
  const distance = Math.hypot(clientX - x, clientY - y)
  if (distance > geometry.cell * 0.7) return
  return { row, col }
}

function canPlace() {
  if (game.winner || game.draw) return false
  if (mode === 'local') return true
  return Boolean(socket && socket.readyState === WebSocket.OPEN && myPlayer && playerCount >= 2 && game.turn === myPlayer)
}

function resultMessage(error: string) {
  switch (error) {
    case 'occupied': return '这个位置已有棋子'
    case 'wrong_turn': return '现在是对方回合'
    case 'game_over': return '本局已经结束'
    case 'out_of_bounds': return '请选择棋盘内的交点'
    default: return '这一步无效'
  }
}

function placeSelectedStone(point = preview ?? cursor) {
  cursor = { ...point }
  if (!canPlace()) {
    setNotice(mode === 'online' && !socket ? '请先连接房间' : mode === 'online' && playerCount < 2 ? '等待另一位玩家加入' : '现在是对方回合')
    render()
    return
  }

  if (mode === 'online') {
    socket?.send(JSON.stringify({ type: 'move', row: point.row, col: point.col }))
    return
  }

  const result = playMove(game, point.row, point.col)
  if (!result.ok) setNotice(resultMessage(result.error))
  else {
    preview = undefined
    if ('vibrate' in navigator) navigator.vibrate(12)
    updateStatus()
  }
  render()
}

function updatePointerPreview(event: PointerEvent) {
  const next = hitTest(event.clientX, event.clientY)
  preview = next && !game.board[next.row][next.col] ? next : undefined
  if (next) cursor = { ...next }
  updateStatus()
  render()
}

function closeSocket(announce = false) {
  const previous = socket
  socket = null
  myPlayer = null
  playerCount = mode === 'local' ? 2 : 0
  if (previous && previous.readyState < WebSocket.CLOSING) previous.close()
  if (announce) setNotice('连接已断开')
  else updateStatus()
}

function isServerMessage(value: unknown): value is ServerMessage {
  if (!value || typeof value !== 'object' || !('type' in value)) return false
  const message = value as Record<string, unknown>
  if (message.type === 'welcome') return message.player === 1 || message.player === 2
  if (message.type === 'error') return typeof message.message === 'string'
  return message.type === 'state'
    && typeof message.players === 'number'
    && Number.isInteger(message.players)
    && message.players >= 0
    && message.players <= 2
    && isGameState(message.state)
}

function connect() {
  if (socket?.readyState === WebSocket.CONNECTING
    || (socket?.readyState === WebSocket.OPEN && myPlayer !== null)) return
  clearNotice()
  closeSocket()
  let url: URL
  try {
    url = new URL(serverInput.value.trim())
    if (url.protocol !== 'ws:' && url.protocol !== 'wss:') throw new Error()
  } catch {
    setNotice('服务器地址必须以 ws:// 或 wss:// 开头')
    return
  }

  const room = roomInput.value.trim().toUpperCase()
  if (!/^[A-Z0-9_-]{2,20}$/.test(room)) {
    setNotice('房间号需要 2–20 位字母或数字')
    return
  }

  const connection = new WebSocket(url)
  socket = connection
  updateStatus()
  connection.addEventListener('open', () => {
    if (socket !== connection) return
    connection.send(JSON.stringify({ type: 'join', room }))
    updateStatus()
  })
  connection.addEventListener('message', event => {
    if (socket !== connection) return
    try {
      const message: unknown = JSON.parse(String(event.data))
      if (!isServerMessage(message)) return
      if (message.type === 'welcome') myPlayer = message.player
      if (message.type === 'state') {
        game = message.state
        playerCount = message.players
        preview = undefined
        clearNotice()
      }
      if (message.type === 'error') setNotice(message.message)
      else updateStatus()
      render()
    } catch {
      setNotice('服务器返回了无效数据')
    }
  })
  connection.addEventListener('close', () => {
    if (socket !== connection) return
    const wasJoined = myPlayer !== null
    const hadNotice = notice !== undefined
    closeSocket(false)
    if (wasJoined || !hadNotice) setNotice('连接已断开')
    render()
  })
  connection.addEventListener('error', () => {
    if (socket === connection) setNotice('无法连接服务器')
  })
}

function resetLocal() {
  clearNotice()
  game = createGame()
  cursor = { row: 7, col: 7 }
  preview = undefined
  updateStatus()
  render()
}

function resetGame() {
  if (mode === 'online') {
    if (socket?.readyState === WebSocket.OPEN) {
      clearNotice()
      socket.send(JSON.stringify({ type: 'reset' }))
    }
    else setNotice('请先连接房间')
  } else resetLocal()
}

function setMode(nextMode: Mode) {
  if (mode === nextMode) {
    updateStatus()
    render()
    return
  }
  if (mode === 'online') closeSocket()
  clearNotice()
  mode = nextMode
  onlineModeButton.classList.toggle('active', mode === 'online')
  localModeButton.classList.toggle('active', mode === 'local')
  localModeButton.setAttribute('aria-pressed', String(mode === 'local'))
  onlineModeButton.setAttribute('aria-pressed', String(mode === 'online'))
  onlinePanel.hidden = mode !== 'online'
  game = createGame()
  cursor = { row: 7, col: 7 }
  preview = undefined
  playerCount = mode === 'local' ? 2 : 0
  updateStatus()
  render()
}

function openNewGameDialog() {
  if (!game.moveCount) {
    resetGame()
    return
  }
  if (typeof dialog.showModal === 'function') dialog.showModal()
  else if (window.confirm('确认重新开局？')) resetGame()
}

canvas.addEventListener('pointerdown', event => {
  if (event.button !== 0) return
  keyboardNavigation = false
  activePointerId = event.pointerId
  canvas.setPointerCapture(event.pointerId)
  updatePointerPreview(event)
})
canvas.addEventListener('pointermove', event => {
  if (activePointerId === undefined && event.pointerType !== 'mouse') return
  updatePointerPreview(event)
})
canvas.addEventListener('pointerup', event => {
  if (activePointerId !== event.pointerId) return
  updatePointerPreview(event)
  const selected = preview
  activePointerId = undefined
  canvas.releasePointerCapture(event.pointerId)
  if (selected) placeSelectedStone(selected)
  else render()
})
canvas.addEventListener('pointercancel', () => {
  activePointerId = undefined
  preview = undefined
  render()
})
canvas.addEventListener('pointerleave', () => {
  if (activePointerId === undefined) {
    preview = undefined
    render()
  }
})
canvas.addEventListener('focus', () => render())
canvas.addEventListener('blur', () => render())
canvas.addEventListener('keydown', event => {
  keyboardNavigation = true
  const movement: Record<string, [number, number]> = {
    ArrowUp: [-1, 0],
    ArrowDown: [1, 0],
    ArrowLeft: [0, -1],
    ArrowRight: [0, 1],
  }
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault()
    placeSelectedStone(cursor)
    return
  }
  const delta = movement[event.key]
  if (!delta) return
  event.preventDefault()
  cursor.row = Math.max(0, Math.min(BOARD_SIZE - 1, cursor.row + delta[0]))
  cursor.col = Math.max(0, Math.min(BOARD_SIZE - 1, cursor.col + delta[1]))
  preview = undefined
  updateStatus()
  render()
})

localModeButton.addEventListener('click', () => setMode('local'))
onlineModeButton.addEventListener('click', () => setMode('online'))
connectButton.addEventListener('click', connect)
disconnectButton.addEventListener('click', () => closeSocket(true))
undoButton.addEventListener('click', () => {
  if (mode !== 'local') return
  if (undoMove(game).ok) {
    preview = undefined
    updateStatus()
    render()
  }
})
redoButton.addEventListener('click', () => {
  if (mode !== 'local') return
  if (redoMove(game).ok) {
    preview = undefined
    updateStatus()
    render()
  }
})
resetButton.addEventListener('click', openNewGameDialog)
cancelNewGameButton.addEventListener('click', () => dialog.close('cancel'))
confirmNewGameButton.addEventListener('click', () => {
  dialog.close('confirm')
  resetGame()
})
dialog.addEventListener('click', event => {
  if (event.target === dialog) dialog.close('cancel')
})
roomInput.addEventListener('keydown', event => {
  if (event.key === 'Enter') {
    event.preventDefault()
    connect()
  }
})

new ResizeObserver(resizeCanvas).observe(canvas)
setMode('local')
