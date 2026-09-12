# Gomoku / 五子棋

使用 Flutter 和 Serverpod 构建的六端五子棋。界面采用 [Material 3 Expressive](https://m3.material.io/blog/building-with-m3-expressive) 的配色、形状、字体层级和动效理念，默认紫色主题，支持浅色、深色及 Android 动态配色。

## 功能

- **本地双人**：15×15 无禁手五子棋，黑先，五颗或更多连成一线获胜；自动保存、悔棋、重新开局、终局复盘。
- **好友联机**：六位房间码和网页邀请链接、双方准备、服务端裁定、认输、协商悔棋、换色再来一局。
- **断线恢复**：暂停对局并保留座位 120 秒，重连恢复快照；等待房间空闲 30 分钟过期。
- **身份与同步**：游客直接游玩；邮箱注册、验证码、密码找回、事务式游客归并；正式账号同步已结束棋谱。
- **多种输入**：触屏预选与确认、鼠标预览、方向键与 Enter/空格落子、屏幕阅读器逐交叉点操作。
- **适配**：各端统一“对弈／棋谱”顶部标签，账户与设置从头像进入；手机对局使用固定落子操作区，横屏与大屏采用棋盘＋信息栏。支持中英文、系统语言回退、大字体、减少动画、声音和触感开关。
- **离线 Web**：本地字体、CanvasKit、数据库 Wasm/worker 和离线静态缓存；同一浏览器的多标签页共享棋局并检查写入冲突。

首版范围不包含 AI、在线匹配、排行榜和商店上架。平台构建与实机验收情况见 [验证记录](docs/VALIDATION.md)。

主线界面改版的导航、交互、前后截图和验收范围见 [Material 3 Expressive 改版记录](docs/UI_REDESIGN.md)。

## 下载

[GitHub Releases](https://github.com/xqd922/Gomoku/releases) 提供由 Actions 构建的六端发行文件、SHA-256 校验和及源码版本记录。v1.0.0 是 Flutter / Serverpod 架构的首个版本；旧版 Tauri 源码仍可通过 v0.3.0 等标签查看。

本地双人无需后端。发布包未接入公共服务器，账号、联机和云端同步需按 [部署说明](docs/DEPLOYMENT.md) 自建服务并配置客户端地址。iOS 文件为无签名构建，不能直接安装；其余使用条件见 [发行说明](docs/releases/v1.0.0.md)。

## 本机启动

固定使用 **Flutter 3.47.1 / Dart 3.13.1**，Serverpod **3.4.13**。Flutter 版本也记录在 `.fvmrc`。依赖通过根 `pubspec.lock` 锁定，包源使用 `https://pub.dev`。

需要 Flutter 对应的平台工具链，以及 Docker Compose。Windows 可使用 Docker Desktop，或在 Ubuntu-22.04 WSL 中安装 Docker Engine 与 Compose；当前开发环境采用后者。脚本会生成本地随机密钥，并启动 PostgreSQL、Redis 和 Mailpit。

PowerShell：

```powershell
cd D:\Seven_code\Gomoku
.\tool\dev.ps1
```

macOS / Linux：

```bash
bash tool/dev.sh
```

打开 [本地游戏](http://localhost:4280)；开发验证码在 [Mailpit](http://localhost:8025) 查看。第一次构建需要下载依赖。已有 Web 构建时可使用 `.\tool\dev.ps1 -SkipWebBuild` 或 `bash tool/dev.sh --skip-web-build`。

Ctrl+C 停止脚本启动的应用进程。数据库容器和命名卷保留，便于下次继续开发。运行日志位于 `.local/`；`.env` 和 `apps/server/config/passwords.yaml` 含本地密钥，已经加入忽略列表。

Windows 可使用 `.\tool\dev.ps1 -SkipWebBuild -CheckStartup` 验证启动后自动退出，检查脚本会释放自己创建的进程与端口。

| 用途 | 本机端口 |
| --- | --- |
| 同源 Web 网关 | 4280 |
| Serverpod API / WebSocket | 8080 |
| 认证与健康检查 | 8082 |
| PostgreSQL / Redis | 8090 / 8091 |
| Mailpit 网页 / SMTP | 8025 / 1025 |

WSL Docker 模式由脚本启动保活进程和 Windows 回环转发；不用手动填写每次启动变化的 WSL 地址。

## 客户端开发

从根目录获取依赖后，在 `apps/gomoku_app` 执行：

```powershell
flutter run -d windows
```

Android 模拟器使用宿主机地址：

```powershell
flutter run -d <device-id> --dart-define=GOMOKU_API_URL=http://10.0.2.2:8080/ --dart-define=GOMOKU_AUTH_URL=http://10.0.2.2:8082/auth/ --dart-define=GOMOKU_WEB_URL=http://localhost:4280
```

无后端时可以直接玩本地双人。Web 开发需保留同源网关和隔离响应头，常规验收使用 `tool/dev` 生成的发布构建。

## 工程结构

| 目录 | 职责 |
| --- | --- |
| `packages/gomoku_core` | 无 Flutter / 网络 / 数据库依赖的规则与棋谱验证 |
| `packages/gomoku_client` | Serverpod 生成的类型化协议与客户端 |
| `apps/gomoku_app` | Flutter UI、Riverpod 状态、Drift、本地与云端同步 |
| `apps/server` | 房间、身份、记录、持久化事件、认证适配 |
| `apps/server/db` | 应用 SQL 迁移，带版本连续性与校验和检查 |
| `apps/server/migrations` | Serverpod 认证与会话表迁移 |
| `tool` | 启动、检查、离线资源、浏览器验收与资产生成脚本 |
| `infra` | 生产镜像、反向代理、独立后端依赖锁 |
| `.github/workflows` | 六端构建和自动验收 CI |

## 检查与构建

```powershell
.\tool\check.ps1 -WithBackend
node tool/browser/verify.mjs
```

浏览器验收前需启动开发服务，并在 `tool/browser` 执行一次 `npm ci`。Windows 默认使用本机 Chrome；其他系统执行 `npx playwright install --with-deps chromium`。可通过 `GOMOKU_CHROME_PATH` 和 `GOMOKU_WEB_URL` 指定浏览器与网关。

```bash
bash tool/check.sh --with-backend
```

服务端集成测试使用真实 PostgreSQL、Redis、Mailpit，专用数据库 `gomoku_test` 会被测试重置；不可将测试配置指向需要保留的数据库。

发布构建（在 `apps/gomoku_app`）：

```bash
flutter build web --release --no-web-resources-cdn --no-pub
flutter build windows --release --no-pub
flutter build apk --release --no-pub
```

Web 构建后从根目录执行 `dart tool/prepare_web.dart`。Windows 分发必须保留整个 `build/windows/x64/runner/Release` 目录中的 DLL 和 `data`。本地 Android 构建使用 debug key，Actions 发布前使用仓库已有正式证书重新签名并验证；包名沿用 `com.xqd922.gomoku`，v1.0.0 的 versionCode 为 10000。

本次界面改版的六端构建和完整自动验收已在 [GitHub Actions](https://github.com/xqd922/Gomoku/actions/runs/34677414905) 实际通过，构建产物可在该运行的 Artifacts 下载；其中 iOS 使用 `--no-codesign`，macOS 为 Intel / Apple Silicon 通用构建。生产地址、SMTP、HTTPS、备份及升级步骤见 [部署说明](docs/DEPLOYMENT.md)；一致性协议见 [架构说明](docs/ARCHITECTURE.md)。

推送 `main` 或打开 PR 执行验收和六端构建；推送与 pubspec.yaml 匹配的 `v*` 标签会在所有检查通过后自动发布 Release。发行文件通过 `tool/package_release.py` 归档，macOS 保留 app 内符号链接，Linux 保留可执行权限。发布工作流不会覆盖已经公开的 Release。
