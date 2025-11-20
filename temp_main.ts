import { createState, tryPlaceStone, undo, redo } from './gomoku/engine'
import type { GameState } from './gomoku/types'
import { renderAll, pixelToGrid } from './gomoku/render'
import { NetClient, type NetMessage } from '@/net/ws'

const canvas = document.getElementById('board') as HTMLCanvasElement
const ctx = canvas.getContext('2d')!
const turnDot = document.getElementById('turnDot') as HTMLSpanElement
const turnText = document.getElementById('turnText') as HTMLSpanElement
const statusEl = document.getElementById('status') as HTMLDivElement
const logEl = document.getElementById('log') as HTMLDivElement

const newBtn = document.getElementById('newBtn') as HTMLButtonElement
const undoBtn = document.getElementById('undoBtn') as HTMLButtonElement
const redoBtn = document.getElementById('redoBtn') as HTMLButtonElement
const connectBtn = document.getElementById('connectBtn') as HTMLButtonElement
const disconnectBtn = document.getElementById('disconnectBtn') as HTMLButtonElement
const netStatus = document.getElementById('netStatus') as HTMLDivElement
const roomInput = document.getElementById('roomInput') as HTMLInputElement
const nameInput = document.getElementById('nameInput') as HTMLInputElement
const urlInput = document.getElementById('urlInput') as HTMLInputElement

let state: GameState = createState(15)
let online: NetClient | null = null
let mePlayer: 1 | 2 = 1
let isOnline = false

function updateUI() {
  renderAll(ctx, state)
  const p = state.turn
  turnDot.className = 'dot ' + (p === 1 ? 'black' : 'white')
  turnText.textContent = p === 1 ? '黑子' : '白子'
  statusEl.textContent = state.winner
    ? (state.winner === 1 ? '黑子' : '白子') + ' 获胜'
    : '进行中'
  netStatus.textContent = isOnline ? `在线 - 玩家${mePlayer}` : '离线'
}

let rafPending = false
function requestUpdate() {
  if (rafPending) return
  rafPending = true
  requestAnimationFrame(() => {
    rafPending = false
    updateUI()
  })
}

function log(msg: string) {
  const d = document.createElement('div')
  d.textContent = msg
  logEl.appendChild(d)
  logEl.scrollTop = logEl.scrollHeight
}

canvas.addEventListener('click', (e) => {
  if (state.winner) return
  if (isOnline && state.turn !== mePlayer) return
  const rect = canvas.getBoundingClientRect()
  const scaleX = canvas.width / rect.width
  const scaleY = canvas.height / rect.height
  const x = (e.clientX - rect.left) * scaleX
  const y = (e.clientY - rect.top) * scaleY
  const { r, c } = pixelToGrid(canvas, state.n, 32, x, y)
  const res = tryPlaceStone(state, r, c)
  if (!res.ok) {
    if (res.error === 'out_of_bounds') showToast('越界：请点击有效交点')
    else if (res.error === 'occupied') showToast('该位置已有棋子')
    else if (res.error === 'game_over') showToast('当前对局已结束')
    return
  }
  const m = res.value
  log(`${m.p === 1 ? '黑' : '白'} 落子: (${m.r + 1}, ${m.c + 1})`)
  if (isOnline && online) online.send({ type: 'move', r: m.r, c: m.c, p: m.p } as any)
  if (state.winner) {
    const msg = `${state.winner === 1 ? '黑子' : '白子'} 获胜！`
    log(msg)
    showToast(msg)
  }
  requestUpdate()
})

newBtn.addEventListener('click', () => {
  state = createState(15)
  log('— 新局 —')
  if (isOnline && online) online.send({ type: 'reset' } as any)
  requestUpdate()
})

// 悔棋/重做：离线直接执行，在线发出请求
undoBtn.addEventListener('click', () => {
  if (!isOnline) {
    if (undo(state)) { log('悔棋'); requestUpdate() }
  } else if (online) {
    online.send({ type: 'undo_request' } as any)
    showToast('已发送悔棋请求')
  }
})
redoBtn.addEventListener('click', () => {
  if (!isOnline) {
    if (redo(state)) { log('重做'); requestUpdate() }
  } else if (online) {
    online.send({ type: 'redo_request' } as any)
    showToast('已发送重做请求')
  }
})

function fitCanvasToDPR() {
  const ratio = Math.max(1, Math.floor(window.devicePixelRatio || 1))
  const rect = canvas.getBoundingClientRect()
  const cssW = Math.max(320, Math.floor(rect.width))
  const cssH = Math.max(320, Math.floor(rect.height))
  canvas.width = Math.round(cssW * ratio)
  canvas.height = Math.round(cssH * ratio)
  requestUpdate()
}

fitCanvasToDPR()
requestUpdate()
window.addEventListener('resize', fitCanvasToDPR)

window.addEventListener('keydown', (e) => {
  const k = e.key.toLowerCase()
  if (e.ctrlKey && k === 'n') {
    e.preventDefault()
    state = createState(15)
    log('— 新局 —')
    if (isOnline && online) online.send({ type: 'reset' } as any)
    requestUpdate()
    return
  }
  if (k === 'z') {
    if (!isOnline) {
      if (undo(state)) { log('悔棋'); requestUpdate() }
    } else if (online) {
      online.send({ type: 'undo_request' } as any)
      showToast('已发送悔棋请求')
    }
  } else if (k === 'y') {
    if (!isOnline) {
      if (redo(state)) { log('重做'); requestUpdate() }
    } else if (online) {
      online.send({ type: 'redo_request' } as any)
      showToast('已发送重做请求')
    }
  } else if (k === 'r') {
    state = createState(15)
    log('— 新局 —')
    if (isOnline && online) online.send({ type: 'reset' } as any)
    requestUpdate()
  }
})

declare global {
  interface Window { api: unknown }
}

// 简易 Toast 提示（非阻塞）
let toastTimer: number | null = null
function showToast(text: string) {
  const el = document.getElementById('toast') as HTMLDivElement | null
  if (!el) return
  el.textContent = text
  el.classList.add('show')
  if (toastTimer) {
    window.clearTimeout(toastTimer)
    toastTimer = null
  }
  toastTimer = window.setTimeout(() => {
    el.classList.remove('show')
  }, 2200)
}

// 在线联机
connectBtn.addEventListener('click', () => {
  if (isOnline) return
  const url = urlInput.value || 'ws://localhost:8787'
  const room = roomInput.value || 'test'
  const name = nameInput.value || ''
  const client = new NetClient()
  client.connect({ url, room, name, autoReconnect: true })
  client.addEventListener('message', (ev: MessageEvent<NetMessage>) => {
    const msg = ev.data
    if (msg.type === 'welcome') {
      mePlayer = msg.player
      isOnline = true
      connectBtn.disabled = true
      disconnectBtn.disabled = false
      // 联机下允许通过按钮发起协商
      undoBtn.disabled = false
      redoBtn.disabled = false
      requestUpdate()
    } else if (msg.type === 'ready') {
      if (mePlayer === 1) {
        client.send({ type: 'state', snapshot: state } as any)
      } else {
        client.send({ type: 'request_state' } as any)
      }
    } else if (msg.type === 'state') {
      try {
        const snap = msg.snapshot as GameState
        state = snap
        requestUpdate()
      } catch {}
    } else if (msg.type === 'request_state') {
      if (mePlayer === 1) client.send({ type: 'state', snapshot: state } as any)
    } else if (msg.type === 'move') {
      if (state.turn === msg.p) {
        tryPlaceStone(state, msg.r, msg.c)
        requestUpdate()
      }
    } else if ((msg as any).type === 'undo_request') {
      const ok = window.confirm('对方请求悔棋，是否同意？')
      if (ok) {
        if (undo(state)) requestUpdate()
        client.send({ type: 'undo_reply', accepted: true } as any)
      } else {
        client.send({ type: 'undo_reply', accepted: false } as any)
      }
    } else if ((msg as any).type === 'undo_reply') {
      const { accepted } = msg as any
      if (accepted) {
        if (undo(state)) requestUpdate()
      } else {
        showToast('对方拒绝了悔棋')
      }
    } else if ((msg as any).type === 'redo_request') {
      const ok = window.confirm('对方请求重做，是否同意？')
      if (ok) {
        if (redo(state)) requestUpdate()
        client.send({ type: 'redo_reply', accepted: true } as any)
      } else {
        client.send({ type: 'redo_reply', accepted: false } as any)
      }
    } else if ((msg as any).type === 'redo_reply') {
      const { accepted } = msg as any
      if (accepted) {
        if (redo(state)) requestUpdate()
      } else {
        showToast('对方拒绝了重做')
      }
    } else if (msg.type === 'reset') {
      state = createState(15)
      requestUpdate()
    } else if (msg.type === 'peer_leave') {
      showToast('对方已离开房间')
    } else if (msg.type === 'error') {
      showToast('连接错误: ' + (msg as any).message)
    }
  })
  client.addEventListener('close', () => {
    isOnline = false
    connectBtn.disabled = false
    disconnectBtn.disabled = true
    undoBtn.disabled = false
    redoBtn.disabled = false
    requestUpdate()
  })
  client.addEventListener('reconnecting', (e: any) => {
    netStatus.textContent = `重连中... ${e.detail?.delay ?? ''}ms`
  })
  client.addEventListener('reconnected', () => {
    netStatus.textContent = '已尝试重连'
  })
  online = client
})

disconnectBtn.addEventListener('click', () => {
  if (online) online.disconnect()
})
