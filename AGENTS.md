# Repository Guidelines

## 工程与约束

当前主线是 Flutter / Serverpod 的 Dart workspace；v0.3.0 及更早的 Tauri / TypeScript 工程保留在 Git 历史与 Release 中。

- `packages/gomoku_core`：纯 Dart 规则，不依赖 UI、数据库或网络。
- `apps/gomoku_app`：Flutter 界面、Riverpod、Drift 和同步。
- `apps/server`：服务端裁定、身份、房间、棋谱与事务事件。
- `packages/gomoku_client`：Serverpod 生成的协议；修改模型后使用匹配版本的生成器更新，不手改生成代码。
- `tool`、`infra`、`.github/workflows`：开发、部署、验收与六端发行。

固定 Flutter 3.47.1、Dart 3.13.1、Serverpod 3.4.13；依赖使用根 workspace lockfile。独立后端镜像另有经过一致性检查的锁文件。

## 开发与验证

- Windows：`./tool/dev.ps1`；macOS / Linux：`bash tool/dev.sh`。
- 检查：`./tool/check.ps1 -WithBackend` 或 `bash tool/check.sh --with-backend`。
- 浏览器：先启动开发服务，在 `tool/browser` 执行 `npm ci`，再执行 `node tool/browser/verify.mjs`。
- 规则和服务端行为变更应增加相应测试；小型文档和打包改动使用针对性的验证即可。
- 保持 Dart format 与静态分析通过。UI 兼顾中英文、键盘、触屏、大字体及深浅色。
- 必须区分编译通过、自动运行验证与真人实机验收，不能把 CI 配置当成已经执行的证据。

## 数据与配置

不提交 `.env`、Serverpod passwords 文件、签名密钥、会话凭证或本机日志。服务端检查每次房间和棋谱操作权限；不要以客户端规则替代事务裁定。数据库迁移只追加，不修改已应用的迁移。

Android 正式发布沿用 `com.xqd922.gomoku`、已有仓库签名证书和递增 versionCode；本地 debug-key 构建不能当成正式签名发行包。

## 提交与发布

遵循 Conventional Commits，例如 `feat(game): ...`、`fix(sync): ...`、`ci: ...`。PR 描述包含行为变化、验证结果及必要截图。保留远端历史，不 force push。`v*` 标签触发六端构建和测试，全部成功后才由 Actions 发布 Release。
