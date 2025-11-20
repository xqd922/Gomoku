import { createState, placeStone, undo, redo } from './gomoku/engine'
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

function log(msg: string) {
  const d = document.createElement('div')
  d.textContent = msg
  logEl.appendChild(d)
  logEl.scrollTop = logEl.scrollHeight
}

canvas.addEventListener('click', (e) => {
  if (state.winner) return
  const rect = canvas.getBoundingClientRect()
  const x = e.clientX - rect.left
  const y = e.clientY - rect.top
  const { r, c } = pixelToGrid(canvas, state.n, 32, x, y)
  const ok = placeStone(state, r, c)
  if (ok) {
    log(`${state.last?.p === 1 ? '黑' : '白'} 落子: (${r + 1}, ${c + 1})`)
    if (state.winner) {
      const msg = `${state.winner === 1 ? '黑子' : '白子'} 获胜！`
      log(msg)
      showToast(msg)
    }
    updateUI()
  }
})

newBtn.addEventListener('click', () => {
  state = createState(15)
  log('—— 新局 ——')
  updateUI()
})
undoBtn.addEventListener('click', () => {
  if (undo(state)) {
    log('悔棋')
    updateUI()
  }
})
redoBtn.addEventListener('click', () => {
  if (redo(state)) {
    log('重做')
    updateUI()
  }
})

updateUI()

declare global {
  interface Window { api: unknown }
}

// 简单 Toast 提示（非阻塞，无弹窗）
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
