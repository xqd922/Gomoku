# 验证记录

验证日期：**2026-09-12（Asia/Shanghai）**。本机为 Windows，Flutter **3.47.1**、Dart **3.13.1**、Serverpod **3.4.13**；后端依赖运行于 Ubuntu-22.04 WSL 的 Docker Engine **29.1.3** / Compose **2.40.3**。

## 已执行的自动检查

| 检查 | 结果 |
| --- | --- |
| `dart analyze --fatal-infos` | 通过，无诊断 |
| Dart 格式检查 | 通过 |
| 根 workspace 与独立后端 lockfile | 95 个共有 hosted 包的版本、来源和哈希一致 |
| 规则测试 | **12 / 12** 通过 |
| Flutter / Drift 测试 | **12 / 12** 通过 |
| 真实后端集成测试 | **11 / 11** 通过 |
| Chrome 浏览器验收 | **6 组流程**通过，运行时异常 **0** |
| 开发 Compose / 生产 Compose | 启动及配置校验通过 |
| 开发脚本 | 启动健康检查、停止后释放应用与转发端口通过 |
| 生产后端与 Web Docker 镜像 | 构建通过，容器运行与代理检查通过 |

主要入口：`tool/check.ps1 -WithBackend`、`tool/browser/verify.mjs`。本次日志保留在 `.local/checks.log`、`.local/dev-startup-check.log`、`.local/container-smoke.log`；截图和浏览器报告位于 `artifacts/browser`。

### 规则和持久化

- 四方向、边界、白棋获胜、长连、满盘和棋、越界/重复/错方落子、终局限制。
- 同意悔棋后的回合、逐步复盘、认输与中断的往返序列化、伪造胜负和棋序的拒绝。
- 实际 SQLite 文件重新打开后的恢复、离线队列、事务式游客归并、其他账号隔离。
- 同一棋局的旧副本不能覆盖已经保存的新落子。

### 联机与账号

测试启动两个真实 Serverpod 进程，共享 PostgreSQL 专用测试库和 Redis，使用真实类型化客户端调用；不以模拟存储替代服务端。

- 房间权限、满房、活跃座位约束、版本冲突、重复命令和并发落子。
- 完整获胜棋局、协商悔棋、不可变联机记录、再来一局交换黑白。
- 断线暂停、恢复、超时中断、等待房间过期和服务重启。
- 跨实例通知在 10 秒快照兜底前收到。
- Mailpit 邮箱验证、注册昵称、密码找回、旧会话撤销。
- 登录已有账号保留资料、合并游客联机记录、重复上传与账号隔离。
- 较早开始、较晚提交的数据库事务不会被增量同步游标跳过。
- 浏览器认证仅返回 HttpOnly Cookie，拒绝不允许的 Origin。

超时测试通过调整专用测试库的时间字段触发 120 秒与 30 分钟过期分支，并检查状态结果，不以等待完整时长作为测试前提。

### 浏览器与界面

Playwright 使用实际 Chrome 和发布模式的 Flutter Web，覆盖：

1. Web HttpOnly 身份和同源 WebSocket 连接。
2. 桌面与触屏手机两个身份完成一局游戏，协商悔棋、显示胜负。
3. 持久化棋谱、回到开局、前进一手，并断言实际复盘步数。
4. Mailpit 注册、游客归并、第二浏览器设备登录与云端棋谱恢复。
5. 两标签页互相看到落子，断网重载后保持棋局。
6. 深色主题、英文、平板和横屏布局。

Flutter 界面测试覆盖 390×844、844×390、900×1200、1440×1000，以及英文 200% 字体。另验证触屏预选/确认、鼠标、方向键与 Enter、落子失败提示及 225 个交叉点语义标签。浏览器检查了 `crossOriginIsolated == true`。

这些测试验证无障碍语义和输入行为；未进行真人屏幕阅读器体验测试。

### 部署与启动

生产后端镜像使用独立锁文件和 AOT 编译，以非 root 用户运行；曾在全新 `gomoku_image_smoke` 数据库上应用框架迁移和应用 SQL 001、002。验证了数据库/Redis 健康检查、Caddy 路由、SPA 回退、数据库 worker、Wasm MIME 与跨源隔离响应头。

生产配置的 Cookie 验证包含 `__Host-` 名称、`HttpOnly`、`Secure`、`SameSite=Lax`，且认证 JSON 不含 token。容器代理冒烟检查使用内部 HTTP 测试入口和允许的 Origin 来检查响应属性；未申请公网 TLS 证书或部署到公网。

PowerShell 开发脚本的 `-CheckStartup` 检查使用不经过系统代理的回环请求，并在结束后停止自己创建的进程树。生产 SMTP 尚需部署者填写真实服务配置；开发邮箱流程通过 Mailpit 验证。

## 平台构建与实机边界

| 平台 | 构建验证 | 运行 / 实机验证 |
| --- | --- | --- |
| Web | 本机 release 构建通过，离线缓存包含 55 项公开资源 | Chrome 双客户端、触屏模拟、离线/多标签页通过 |
| Windows x64 | 本机 release 构建通过，完整 DLL/data 目录归档 | 发布程序启动并持续运行检查通过；未做完整原生人工操作验收 |
| Android | 本机 release APK 构建通过 | 未连接 Android 真机或模拟器；无实机结论 |
| Linux | 已配置 Ubuntu CI 构建 | 未在本机运行 Linux GUI；远端 CI 未执行 |
| macOS | 已配置 macOS CI 构建 | 未在 Mac 构建或实机运行；远端 CI 未执行 |
| iOS | 已配置 macOS CI 无签名构建 | 未在 Xcode/模拟器/iPhone 运行；远端 CI 未执行 |

Android APK 使用内部测试签名。iOS 安装、macOS 公证、Windows 安装器签名、正式 SMTP 和公网部署不在本次已验证结果中。六端工程和对应构建流程已交付，不能把“已配置 CI”视为“CI 已通过”。

## 本机构建产物

`artifacts/releases` 提供：

- `Gomoku-1.0.0-windows-x64.zip`：完整 Windows 运行目录。
- `Gomoku-1.0.0-android.apk`：Android 内部验收包。
- `Gomoku-1.0.0-web.zip`：静态 Web 构建与离线资源。
- `SHA256SUMS.txt`：以上文件的校验和。

产物使用本地开发地址；原生平台连接正式服务时需要按 [部署说明](DEPLOYMENT.md) 设置 dart-define 并重新构建。源码、迁移、配置示例、脚本和 CI 保留在仓库中，构建缓存、真实密钥和本机日志不纳入版本控制。
