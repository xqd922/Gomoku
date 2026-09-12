# 开发、构建与部署

## 开发依赖

Flutter 3.47.1 带 Dart 3.13.1；应用与 Serverpod 3.4.13 通过 workspace 共用规则与锁定依赖。根目录执行 `flutter pub get --enforce-lockfile`，不要分别升级子项目。指定镜像源会改变 lockfile 中的来源 URL，项目检查脚本固定使用 `https://pub.dev`。

开发容器采用 PostgreSQL 17（含 Serverpod 所需 pgvector 扩展）、Redis 7.4 和 Mailpit。`dart tool/bootstrap.dart` 只在首次运行生成随机开发密钥；之后沿用现有 `.env`。`compose.yaml` 仅绑定本机地址，PostgreSQL 初始化同时创建 `gomoku` 与 `gomoku_test`。

Windows 启动脚本优先使用正在运行的 Docker Desktop；不可用时使用 WSL Ubuntu-22.04 中的 Docker Engine 和 Compose。WSL 安装可参考 [Docker 的 Ubuntu 文档](https://docs.docker.com/engine/install/ubuntu/)。`-WslDistribution` 可修改发行版。脚本启动 WSL 保活和 Windows 回环转发，避免 WSL 地址变化或空闲退出影响连接。

不要直接把已有开发数据库的密码换掉后只重跑 Compose：PostgreSQL 初始化密码只在数据卷首次创建时生效。需要改密时在数据库中执行密码轮换，并同步更新应用配置。

## 生产部署

需要一台支持 Docker Compose 的主机、指向主机的域名、80/443 入站端口和可用 SMTP。部署文件使用 Caddy 自动申请 HTTPS，数据库和 Redis 不开放宿主机端口。

1. 复制 `.env.production.example` 为 `.env.production`，填写 `GOMOKU_DOMAIN`（不含 scheme），生成四个独立的至少 32 字节随机密钥。
2. 配置 SMTP。587 通常使用 STARTTLS，即 `SMTP_SSL=false`；465 的隐式 TLS 使用 `SMTP_SSL=true`。填写发件人、用户名和密码，配置邮件服务商要求的 SPF/DKIM。
3. 在匹配版本的 Flutter 环境构建 Web，并从根目录生成离线资源清单。

```bash
flutter pub get --enforce-lockfile
cd apps/gomoku_app
flutter build web --release --no-web-resources-cdn --no-pub
cd ../..
dart tool/prepare_web.dart
docker compose --env-file .env.production -f compose.production.yaml config --quiet
docker compose --env-file .env.production -f compose.production.yaml up -d --build --wait
```

默认仅部署一个模块化单体实例。服务镜像以非 root 用户运行，启动时检查 Serverpod 和应用 SQL 迁移；失败会退出，避免带着不一致结构提供服务。健康检查 `GET /health` 检查数据库、Redis，并返回待发送事件数。不要把包含真实密钥的 Compose 展开配置输出到公共日志。

生产会话强制 `Secure`、`HttpOnly`、`SameSite=Lax`，允许来源限定为 `https://<GOMOKU_DOMAIN>`。应用数据由服务端鉴权，静态站点不能单独提供账号和联机能力。

生产 Compose 启用 `TRUST_PROXY=true`；Caddy 覆盖 `X-Real-IP` 后传给认证服务，频率限制按客户端地址计算。此设置仅适用于服务端口不直接对外暴露、代理可信的拓扑；直接运行后端时保持默认关闭。

### 同源路由

| 外部地址 | 上游 |
| --- | --- |
| `/api/*` | `server:8080`，移除 `/api` |
| `/v1/websocket` | `server:8080`，保留路径 |
| `/auth/*`、`/health` | `server:8082` |
| 其他页面和资源 | Flutter Web，SPA 路由回退到 index.html |

Serverpod 的 WebSocket 路径从 origin 根目录生成，不继承 RPC 的 `/api/` 前缀。代理必须保留 Cookie、Origin、WebSocket 升级和长连接。

Drift Web 的 `sqlite3.wasm` 和 `drift_worker.js` 随应用交付。静态响应设置 `Cross-Origin-Opener-Policy: same-origin`、`Cross-Origin-Embedder-Policy: require-corp`、`Cross-Origin-Resource-Policy: same-origin`；Wasm 由服务器返回 `application/wasm`。浏览器中 `crossOriginIsolated` 应为 true。

离线 worker 只预缓存公开资源，排除账号、RPC 和健康检查。每次 Web 构建后都要运行 `tool/prepare_web.dart`，同批发布全部资源；更新时新 worker 安装完整缓存后切换。Web 部署在域名根目录，当前路由与 worker 路径未配置子目录托管。

### 原生客户端地址

原生构建必须使用实际 HTTPS 后端地址，例如：

```bash
flutter build apk --release --no-pub \
  --dart-define=GOMOKU_API_URL=https://gomoku.example.com/api/ \
  --dart-define=GOMOKU_AUTH_URL=https://gomoku.example.com/auth/ \
  --dart-define=GOMOKU_WEB_URL=https://gomoku.example.com
```

同样的 dart-define 用于 Windows、Linux、macOS 和 iOS。API 与 auth URL 保留末尾斜杠。默认地址仅用于本机开发；Android 模拟器需使用 `10.0.2.2`。真机使用可达的 HTTPS 域名，不能把手机的 localhost 当成开发电脑。

Android 本地签名用于内部构建验证；GitHub Actions 使用仓库已有正式证书重新签名，沿用 `com.xqd922.gomoku`。iOS CI 是无签名构建，安装真机仍需 Apple 签名与配置文件；macOS 对外分发尚未配置开发者签名和公证，Windows 打包需保留运行目录的 DLL 与数据。首版不执行商店发布。

Windows 目标电脑需安装 [Microsoft Visual C++ v14 x64 运行库](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)；本次交付便携 ZIP，没有制作运行库引导安装器。

## 后端依赖锁

Flutter workspace 的根锁文件包括 Flutter SDK 包，独立 Dart 镜像使用 `infra/server.pubspec.lock`。默认构建执行 `dart pub get --enforce-lockfile`；`dart tool/check_server_lock.dart` 核对两个锁文件共有包的版本、来源和内容哈希。

需要有意更新依赖时，先审查根锁文件，再从它生成后端锁：

```bash
docker build --target dependencies \
  --build-arg LOCKFILE=pubspec.lock --build-arg ENFORCE_LOCKFILE=false \
  -f infra/server.Dockerfile -t gomoku-server-lock .
task_container=$(docker create gomoku-server-lock)
docker cp "$task_container:/workspace/pubspec.lock" infra/server.pubspec.lock
docker rm "$task_container"
dart tool/check_server_lock.dart
docker build -f infra/server.Dockerfile -t gomoku-server .
```

Windows WSL 模式在这些 Docker 命令前加 `wsl -d Ubuntu-22.04 -u root --`，复制的目标使用对应的 `/mnt/d/...` 路径。

## 迁移、备份与更新

PostgreSQL 是身份、会话、房间和棋谱的权威存储。备份数据库和环境密钥；Redis 用于通知与缓存，不能替代数据库备份。下面是在部署主机上创建备份的示例：

```bash
mkdir -p backups
docker compose --env-file .env.production -f compose.production.yaml \
  exec -T postgres pg_dump -U postgres -d gomoku -Fc > backups/gomoku.dump
```

将备份复制到独立位置并设置保留策略，定期在隔离数据库中用 pg_restore 验证恢复。避免 `docker compose down -v` 误删生产命名卷。

升级时先备份，再检查待应用迁移，在测试环境验证旧数据库启动和双实例联机。SQL 迁移只能追加，不能修改已经应用的文件；回滚应用前确认旧程序兼容新表结构。发布时对局状态不会因重启丢失，但客户端将短暂进入重连流程。

多实例时共享 PostgreSQL、Redis、认证 peppers 和允许来源，并为每个 Serverpod 进程设置唯一 `--server-id`。路由将 WebSocket 升级请求发送到任一实例即可，通知通过 Redis 扩散，10 秒快照兜底；跨实例行为有真实集成测试。Compose 默认拓扑用于单主机，生产扩容需另行配置负载均衡和数据库连接总量。

## CI

`.github/workflows/ci.yml` 提供：

- Linux 上的静态检查、规则与 Flutter 测试、真实服务集成测试、Web 与 Playwright 验收。
- Windows、Android、Linux、macOS 和 iOS 对应主机的发布构建，iOS 无签名。
- 源码依赖缓存、浏览器截图与验证日志、各平台构建产物、后端 Docker 镜像构建检查。
- `v*` 标签发布：核对 pubspec 版本、等待所有平台通过、收集六端包、生成校验和与构建来源，再公开 GitHub Release。

v1.1.0 的六端构建与完整验收已在 [GitHub Actions](https://github.com/xqd922/Gomoku/actions/runs/34678707537) 实际通过。源码编译、自动化运行与真人实机验收的边界分别记录在 [VALIDATION.md](VALIDATION.md)。

### Android 签名与客户端地址

仓库 Secrets 使用 `ANDROID_KEYSTORE_BASE64`、`ANDROID_KEYSTORE_PASSWORD`、`ANDROID_KEY_ALIAS`、`ANDROID_KEY_PASSWORD`。密钥只在 Android 签名步骤写入 runner 临时目录，步骤结束清理；不会进入源码和发行包。`tool/sign_android.sh` 校验原有证书 SHA-256 指纹、包名、版本和 16 KB 对齐。PR 验证包使用测试签名，正式标签发布必须具备全部签名 Secrets。

v1.1.0 的 Android versionCode 为 10100，高于 v1.0.0 的 10000 和 v0.3.0 的 3000；后续发布继续递增。v1.1.0 沿用 v1.0.0 的数据格式与服务端协议。旧版 Tauri 数据和 WebSocket 协议未迁移到新架构，覆盖安装能力不代表旧棋谱已自动迁移。

发行构建默认使用 `https://gomoku.xqd.pp.ua`，也可通过 Actions Variables：`GOMOKU_API_URL`、`GOMOKU_AUTH_URL`、`GOMOKU_WEB_URL` 覆盖。三项必须使用同一 HTTPS 域名，API 和认证路径分别为 `/api/`、`/auth/`。工作流拒绝缺失或 localhost 配置，并为 Web 及所有原生客户端编入公开地址。请勿把密码或会话凭证放入这些变量。512 MiB 服务器的部署、固定账号及备份方案见 [原生部署说明](NATIVE_DEPLOYMENT.md)。

### 发布步骤

1. 更新 `apps/gomoku_app/pubspec.yaml` 中的版本与 build number，并添加对应的 `docs/releases/vX.Y.Z.md`。
2. 推送主线，等待 Gomoku 工作流完成。必要时从 Actions 手动重新运行。
3. 推送 `vX.Y.Z` 标签。标签流程会重新验收，收齐 Windows ZIP、Android APK、Linux tar.gz、macOS 通用 ZIP、iOS 无签名 ZIP 和 Web ZIP 后发布。

Release 附带 `SHA256SUMS.txt`、`build-info.json` 和 Android 公开签名验证记录。发布先创建草稿，全部资产上传成功才公开；已公开版本不会被工作流覆盖，修复应使用新版本。`workflow_dispatch` 在分支上只执行构建，在版本标签上运行时仍受相同发布门槛约束。
