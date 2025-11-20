**概览**
- 目标：使用 Electron + Bun + Vite + TypeScript 实现桌面五子棋（本地双人）。
- v1 范围：15×15 自由五子（不含禁手）、本地双人、悔棋/重做、胜负判定、Canvas 轻量 UI。
- 后续（可选）：入门 AI、存档/读档（含 SGF）、主题音效、联机对战。

**技术栈**
- Electron 31+（主进程窗口管理、预加载与安全 IPC）
- Vite 5 + TypeScript 5（渲染进程打包与 HMR）
- Bun（包管理与脚本）
- Canvas 2D（棋盘与棋子渲染）

**环境要求**
- 安装 Bun（Windows 可用 PowerShell 安装器，详见 bun.sh）：`curl -fsSL https://bun.sh/install | bash`
- Node.js 可选（Bun 提供 Node 兼容，Electron 工具链可正常运行）
- Git（推荐）

**快速开始（推荐脚手架）**
- 官方模板：
  - `bunx create-electron-vite@latest gomoku-app -t vanilla-ts`
  - `cd gomoku-app`
  - `bun i`
  - `bun run dev`（同时启动 Vite 与 Electron，支持热更新）
- 若无法使用模板，参考文末“手动接线”。

**项目结构（模板生成后大致如下）**
- `electron/main.ts` — 主进程：创建 `BrowserWindow`、应用生命周期、单例锁等。
- `electron/preload.ts` — 预加载：通过 `contextBridge` 暴露安全 API 给渲染进程。
- `src/index.html` — 渲染进程 HTML 入口。
- `src/main.ts` — 渲染入口（挂载 UI、Canvas 与事件）。
- `src/gomoku/engine.ts` — 规则引擎：棋盘状态、落子、胜负判定、悔棋/重做。
- `src/gomoku/types.ts` — 类型：`Cell`、`Player`、`Point`、`GameState`。
- `src/gomoku/render.ts` — Canvas 渲染工具函数。
- `vite.config.ts` — Vite 配置与 `vite-plugin-electron` 集成。
- `tsconfig.json` — TypeScript 配置。
- `bunfig.toml` — Bun 配置（可选）。

**架构与安全**
- 进程职责
  - Main：创建窗口，控制生命周期，后续可加文件对话框与持久化。
  - Preload：白名单 IPC，向 `window.api` 暴露受限方法（带类型）。
  - Renderer：游戏 UI 与逻辑，不直接使用 Node API，通过 preload 通信。
- 安全设置
  - `contextIsolation: true`、`nodeIntegration: false`、`enableRemoteModule: false`。
  - 生产环境建议配置 CSP（内容安全策略）。
- IPC 约定（v1 最小化）
  - v1 完全本地，无磁盘需求，预加载保持最小。
  - 预留通道：`gomoku:save`、`gomoku:load`、`app:getVersion`（后续实现）。

**规则引擎设计**
- 棋盘表示
  - `board: number[][]`，大小 `N=15`。0=空，1=黑，2=白。
  - `lastMove: { r: number; c: number; player: Player } | null` 记录最后一步。
- 走子与历史
  - `history: Move[]` 与 `redo: Move[]`（重做栈），便于悔棋/重做。
  - `placeStone(r, c, player)`：判边界与空位，成功则入栈并清空 `redo`。
- 胜负判定（相对常数时间）
  - 每步后仅从“最后一步”向四个方向检查：`(1,0)`、`(0,1)`、`(1,1)`、`(1,-1)`，两侧累计同色数量，`>=5` 判胜。
- 类型建议
  - `type Player = 1 | 2`
  - `interface Move { r: number; c: number; p: Player }`
  - `interface GameState { board: number[][]; turn: Player; winner?: Player; last?: Move; history: Move[]; redo: Move[] }`

**渲染与交互（Canvas）**
- 画布：例如 600×600，对应 15×15 网格，留内边距。
- 网格计算：`cell = (canvasSize - 2*pad) / (N - 1)`；像素与网格索引互转采用四舍五入到最近交点。
- 交互
  - 点击：映射至最近交点；若空且未分出胜负 → 落子 → 重绘 → 判胜。
  - 控件：新局、悔棋、重做、当前手方显示。
- 视觉细节
  - 高亮最后一步；胜利时覆盖连线；禁手暂不实现。

**实现计划（MVP）**
- 引擎
  - `createState(N=15)`、`placeStone(s, r, c)`、`checkWin(board, r, c, p)`、`undo(s)`、`redo(s)`。
- 渲染
  - `renderBoard(ctx, state)`、`renderStones(ctx, state)`、`renderOverlay(ctx, state)`。
  - 事件：`onCanvasClick(e)` → 坐标转换 → `placeStone`。
- 预加载/主进程
  - 维持最小接线，后续再扩展存档/设置。

**手动接线（不使用模板时）**
1) 初始化
- `mkdir gomoku-app && cd gomoku-app`
- `bun init -y`
- `bun add -d electron vite vite-plugin-electron typescript @types/node`
- `bunx tsc --init`

2) 脚本（`package.json`）
- `"dev": "vite"`
- `"build": "vite build"`
- `"start": "electron ."`

3) Vite 配置（`vite.config.ts`）
- 集成 `vite-plugin-electron`：
  - 入口包含 `electron/main.ts` 与 `electron/preload.ts`
  - 渲染由 Vite Dev Server 提供

4) 主进程（`electron/main.ts`）
- 创建 `BrowserWindow`，指定 `preload` 路径，设置安全选项；开发加载 Vite URL，生产加载打包后 `index.html`。

5) 预加载（`electron/preload.ts`）
- `contextBridge.exposeInMainWorld('api', { /* 预留 */ })`

6) 渲染（`src/index.html`, `src/main.ts`）
- 挂载 Canvas 与按钮；实现绘制与点击；引入引擎。

**测试建议**
- 可用 Vitest 为引擎做单测。
- 覆盖：四个方向成五、边缘场景、非胜场景。
- 手测清单：
  - 轮流落子与回合切换正确。
  - 占用点不可落子；胜负已分后不可继续落子；悔棋/重做正确。

**格式与质量**
- Prettier 统一格式。
- ESLint + TS 基础规则，避免 `any` 与隐式 `any`。
- 建议脚本：`bun run lint`、`bun run format`。

**构建与打包**
- 开发：`bun run dev`（Vite + Electron HMR）。
- 生产：`bun run build`（打包渲染与主/预加载）；制作安装包可后续接入 `electron-builder` 或 `electron-forge`。

**性能提示**
- 每步全量重绘可接受；若需要再做脏矩形优化。
- 动态覆盖使用 `requestAnimationFrame`。

**后续扩展**
- AI：先规则/启发式（堵四、活三），再做 minimax + alpha‑beta 与迭代加深。
- 存档：JSON 或 SGF；通过 IPC 调用主进程文件对话框；主进程校验内容。
- 联机：渲染进程 WebSocket 客户端；服务端权威裁决。

**目录约定**
- `src/gomoku` 仅放纯逻辑（不依赖 DOM/Electron），便于单测。
- 渲染/UI 放在 `src/` 或 `src/ui`，与引擎解耦。
- IPC 类型（将来）集中在 `src/shared/ipc.ts`，三进程共享强类型。

**最小类型与函数签名**
- `export type Player = 1 | 2`
- `export interface Move { r: number; c: number; p: Player }`
- `export interface GameState { board: number[][]; turn: Player; winner?: Player; last?: Move; history: Move[]; redo: Move[] }`
- `export function createState(n?: number): GameState`
- `export function placeStone(s: GameState, r: number, c: number): boolean`
- `export function checkWin(board: number[][], r: number, c: number, p: Player): boolean`
- `export function undo(s: GameState): boolean`
- `export function redo(s: GameState): boolean`

**v1 验收标准**
- 可新开一局；轮流落子；UI 正确显示当前手方。
- 四个方向的胜负判定正确，边缘情况无误。
- 悔棋/重做行为正确；胜负已分后禁止继续落子，重新开局恢复。

**协作方式**
- 以里程碑为单位建分支。
- 先实现纯逻辑（引擎），再接渲染，最后做 UI 打磨与打包。
- 预加载与 IPC 表面保持最小且可审计。
