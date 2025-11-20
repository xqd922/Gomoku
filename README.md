# 五子棋（Electron + Bun + Vite + TypeScript）

一个本地双人对战的桌面端五子棋小游戏。采用 Electron 驱动桌面窗口，Vite 打包渲染进程，TypeScript 编写核心逻辑与 Canvas 渲染。

## 功能
- 15×15 自由五子，本地双人对战
- 悔棋 / 重做、重新开局
- 落子高亮、胜利连线与顶部 Toast 提示（非弹窗）

## 技术栈
- Electron 31+（主进程、预加载）
- Vite 5 + TypeScript 5（渲染打包/HMR）
- Bun（包管理与脚本）
- Canvas 2D（棋盘与棋子渲染）

## 快速开始
前提：已安装 Bun（https://bun.sh）。

开发（推荐）：
- 固定端口 5173：`bun run dev`
- 如 5173 被占用：`bun run dev:5174`

生产构建与预览：
- 构建：`bun run build`
- 预览（Electron 加载打包产物）：`bun run start`

首次安装依赖：
```
bun i
```

## 目录结构
- `index.html`：渲染进程入口
- `src/main.ts`：事件与 UI 逻辑、Canvas 渲染入口
- `src/gomoku/engine.ts`：规则引擎（落子/胜负/悔棋/重做）
- `src/gomoku/render.ts`：棋盘与棋子渲染、胜利连线
- `src/gomoku/types.ts`：类型定义
- `electron/main.ts`：主进程创建窗口、开发/生产加载
- `electron/preload.ts`：预加载（后续可扩展存档/读档 IPC）
- `vite.config.ts`：Vite + `vite-plugin-electron` 配置
- `tsconfig.json`：TypeScript 配置

## 操作
- 在棋盘上点击交点落子（黑白交替）
- 右侧按钮：新局、悔棋、重做
- 获胜后：顶部 Toast 显示“黑子/白子 获胜”，并绘制红色胜利连线

## 常见问题
- 开发端口占用：`bun run dev` 报 5173 被占用时，使用 `bun run dev:5174`。
- Windows 杀端口（5173）：
  - 查询：`netstat -ano | findstr :5173`
  - 结束：`taskkill /PID <PID> /F`

## 后续计划（可选）
- 简单 AI（堵四成五 + 活三优先）
- 存档/读档（JSON/SGF）与文件对话框
- 主题、音效、禁手规则

