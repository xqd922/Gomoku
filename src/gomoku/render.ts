import type { GameState } from './types'

export interface RenderOptions {
  padding?: number
  lineColor?: string
  starColor?: string
  blackColor?: string
  whiteColor?: string
}

const gridCache = new WeakMap<HTMLCanvasElement, { key: string; canvas: HTMLCanvasElement }>()

function getGridLayer(
  canvas: HTMLCanvasElement,
  n: number,
  pad: number,
  lineColor: string,
  starColor: string,
) {
  const width = canvas.width
  const height = canvas.height
  const key = `${width}x${height}:${n}:${pad}:${lineColor}:${starColor}`
  const cached = gridCache.get(canvas)
  if (cached && cached.key === key) return cached.canvas

  const off = document.createElement('canvas')
  off.width = width
  off.height = height
  const g = off.getContext('2d')!
  const cell = (width - pad * 2) / (n - 1)

  // 网格
  g.strokeStyle = lineColor
  g.lineWidth = 1
  for (let i = 0; i < n; i++) {
    const y = pad + i * cell
    g.beginPath()
    g.moveTo(pad, y)
    g.lineTo(width - pad, y)
    g.stroke()
  }
  for (let j = 0; j < n; j++) {
    const x = pad + j * cell
    g.beginPath()
    g.moveTo(x, pad)
    g.lineTo(x, height - pad)
    g.stroke()
  }

  // 星位（15×15）
  if (n === 15) {
    const stars = [
      [3, 3], [3, 11], [7, 7], [11, 3], [11, 11],
    ]
    g.fillStyle = starColor
    for (const [r, c] of stars) {
      const x = pad + c * cell
      const y = pad + r * cell
      g.beginPath()
      g.arc(x, y, 3, 0, Math.PI * 2)
      g.fill()
    }
  }

  gridCache.set(canvas, { key, canvas: off })
  return off
}

export function renderAll(ctx: CanvasRenderingContext2D, s: GameState, opts: RenderOptions = {}) {
  const { width, height } = ctx.canvas
  ctx.clearRect(0, 0, width, height)
  const pad = opts.padding ?? 32
  const n = s.n
  const cell = (width - pad * 2) / (n - 1)

  // 棋盘格
  ctx.strokeStyle = opts.lineColor ?? '#6b4f2d'
  ctx.lineWidth = 1
  for (let i = 0; i < n; i++) {
    const y = pad + i * cell
    ctx.beginPath()
    ctx.moveTo(pad, y)
    ctx.lineTo(width - pad, y)
    ctx.stroke()
  }
  for (let j = 0; j < n; j++) {
    const x = pad + j * cell
    ctx.beginPath()
    ctx.moveTo(x, pad)
    ctx.lineTo(x, height - pad)
    ctx.stroke()
  }

  // 星位（15×15 常见位置）
  if (n === 15) {
    const stars = [
      [3, 3], [3, 11], [7, 7], [11, 3], [11, 11],
    ]
    ctx.fillStyle = opts.starColor ?? '#333'
    for (const [r, c] of stars) {
      const x = pad + c * cell
      const y = pad + r * cell
      ctx.beginPath()
      ctx.arc(x, y, 3, 0, Math.PI * 2)
      ctx.fill()
    }
  }

  // 棋子
  const black = opts.blackColor ?? '#222'
  const white = opts.whiteColor ?? '#fff'
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      const v = s.board[r][c]
      if (!v) continue
      const x = pad + c * cell
      const y = pad + r * cell
      const radius = Math.floor(cell * 0.42)
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      const grad = ctx.createRadialGradient(x - radius/3, y - radius/3, radius/4, x, y, radius)
      if (v === 1) {
        grad.addColorStop(0, '#666')
        grad.addColorStop(1, black)
      } else {
        grad.addColorStop(0, '#fff')
        grad.addColorStop(1, '#ddd')
      }
      ctx.fillStyle = grad
      ctx.fill()
      if (s.last && s.last.r === r && s.last.c === c) {
        ctx.strokeStyle = '#ff5252'
        ctx.lineWidth = 2
        ctx.beginPath()
        ctx.arc(x, y, radius * 0.5, 0, Math.PI * 2)
        ctx.stroke()
      }
    }
  }

  // 胜利连线覆盖
  if (s.winner && s.winLine) {
    const { start, end } = s.winLine
    const x1 = pad + start.c * cell
    const y1 = pad + start.r * cell
    const x2 = pad + end.c * cell
    const y2 = pad + end.r * cell
    ctx.strokeStyle = '#e53935'
    ctx.lineWidth = 4
    ctx.beginPath()
    ctx.moveTo(x1, y1)
    ctx.lineTo(x2, y2)
    ctx.stroke()
  }
}

export function pixelToGrid(canvas: HTMLCanvasElement, n: number, pad = 32, x: number, y: number) {
  const cell = (canvas.width - pad * 2) / (n - 1)
  const cx = Math.round((x - pad) / cell)
  const cy = Math.round((y - pad) / cell)
  return { r: cy, c: cx }
}
