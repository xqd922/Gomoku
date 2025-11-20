# Repository Guidelines

## 项目结构与模块
- `src/` — UI 与游戏逻辑
  - `src/gomoku/engine.ts` — 规则/轮转/悔棋重做/胜负判断
  - `src/gomoku/render.ts` — Canvas 渲染工具
  - `src/gomoku/types.ts` — 共享类型
  - `src/main.ts` — 应用事件与 DOM 交互
- `electron/` — 主进程与预加载（`main.ts`, `preload.ts`）
- `index.html` — 渲染进程入口
- `vite.config.ts` — Vite + `vite-plugin-electron` 配置（别名 `@ -> src`）
- 构建产物：`dist/`（渲染）、`dist-electron/`（主/预加载）

## 构建、测试与本地开发
- 安装依赖：`bun i`
- 开发（Vite+Electron）：`bun run dev`
- 备用端口 5174：`bun run dev:5174`
- 构建（渲染+Electron）：`bun run build`
- 预览（Electron 载入构建）：`bun run start`
- 仅 Vite/仅 Electron（少用）：`bun run dev:vite`、`bun run dev:electron`

## 编码风格与命名
- TypeScript（ESM）；缩进 2 空格；单引号；无分号。
- 命名：类型/接口用 `PascalCase`，变量/函数用 `camelCase`。
- 导入：优先使用 `@/` 别名；引擎逻辑保持与渲染解耦、偏向纯函数。
- 渲染进程仅用 DOM/Canvas，避免直接使用 Node API。

## 测试指南
- 目前未集成测试。新增测试建议：Vitest。
- 放置位置：与源文件同层的 `*.test.ts`（例：`src/gomoku/engine.test.ts`）。
- 关注点：`engine.ts` 的纯函数（胜负连线、悔棋/重做、越界判断）。

## 提交与 Pull Request
- 遵循 Conventional Commits：`feat(ui): ...`、`fix(engine): ...`、`docs: ...`。
- PR 需包含：变更说明、UI 截图（如有）、验证步骤（dev/build）、关联 issue。
- 基本校验：`bun run dev` 可启动且无报错。

## 安全与配置
- Electron：`contextIsolation: true`、`nodeIntegration: false`、`sandbox: true`。
- 仅通过 `preload.ts` 的 `contextBridge` 暴露受控 API，避免泄露 Node 对象。
