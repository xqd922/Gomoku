import { createState, tryPlaceStone, undo, redo } from './gomoku/engine'
import type { GameState } from './gomoku/types'
import { renderAll, pixelToGrid } from './gomoku/render'

const canvas = document.getElementById('board') as HTMLCanvasElement
const ctx = canvas.getContext('2d')!
const turnDot = document.getElementById('turnDot') as HTMLSpanElement
const turnText = document.getElementById('turnText') as HTMLSpanElement
const statusEl = document.getElementById('status') as HTMLDivElement
const logEl = document.getElementById('log') as HTMLDivElement

const newBtn = document.getElementById('newBtn') as HTMLButtonElement
const undoBtn = document.getElementById('undoBtn') as HTMLButtonElement
const redoBtn = document.getElementById('redoBtn') as HTMLButtonElement

let state: GameState = createState(15)

function updateUI() {
  renderAll(ctx, state)
  const p = state.turn
  turnDot.className = 'dot ' + (p === 1 ? 'black' : 'white')
  turnText.textContent = p === 1 ? '黑子' : '白子'
  if (state.winner) {
    statusEl.textContent = (state.winner === 1 ? '黑子' : '白子') + ' 获胜'
  } else {
    statusEl.textContent = '进行中'
  }
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
  requestUpdate()
})
undoBtn.addEventListener('click', () => {
  if (undo(state)) {
    log('悔棋')
    requestUpdate()
  }
})
redoBtn.addEventListener('click', () => {
  if (redo(state)) {
    log('重做')
    requestUpdate()
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
    requestUpdate()
    return
  }
  if (k === 'z') {
    if (undo(state)) { log('悔棋'); requestUpdate() }
  } else if (k === 'y') {
    if (redo(state)) { log('重做'); requestUpdate() }
  } else if (k === 'r') {
    state = createState(15)
    log('— 新局 —')
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

