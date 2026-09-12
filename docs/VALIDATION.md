# 验证记录

验证日期：**2026-09-12（Asia/Shanghai）**。本机为 Windows，Flutter **3.47.1**、Dart **3.13.1**、Serverpod **3.4.13**；后端依赖运行于 Ubuntu-22.04 WSL 的 Docker Engine **29.1.3** / Compose **2.40.3**。

## 本次 Material 3 Expressive 改版

本节对应“对弈／棋谱两区＋头像入口”的主线改版；下方 v1.0.0 记录保留为历史依据。设计说明、相同窗口尺寸的前后截图见 [界面改版记录](UI_REDESIGN.md)。

### 本机已执行

| 检查 | 本次结果 |
| --- | --- |
| 格式、静态分析、workspace／后端锁文件一致性 | 通过；95 个共享 hosted 依赖一致 |
| 规则 | 12 / 12 通过 |
| Flutter／SQLite | 39 / 39 通过，包含 22 项布局、9 项导航／对局流程、4 项棋盘、4 项数据库测试 |
| 真实后端 | 11 / 11 通过，使用 PostgreSQL、Redis、Mailpit 与两个服务实例 |
| Chrome 发布模式 Web | 9 组场景通过，运行时异常 0 |
| Web release | 构建通过；55 个公共离线资源已准备 |
| Windows x64 release | 构建通过；新程序启动后持续运行检查通过，约 118 MB 工作集 |
| Android release APK | 本机测试签名构建通过，约 72.5 MB |

浏览器流程实际验证了二级页 URL、前进／后退、房间刷新、邀请链接、HttpOnly 会话、返回续局、双客户端完整棋局、协商悔棋、断线暂停／重连、即时复盘、棋谱持久化后刷新、Mailpit 注册、游客归并、第二设备登录与云端棋谱、Drift 多标签页和离线重载、深色及英文／横屏设置。

本机日志：`.local/ui-checks.log`、`.local/ui-browser.log`、`.local/ui-web-build.log`、`.local/ui-windows-build.log`、`.local/ui-windows-smoke.json`、`.local/ui-android-build.log`；浏览器结果见 `artifacts/browser/results.json`，精选截图随 `docs/images/ui-redesign` 交付。

### 六端构建与实机范围

六端 Actions 运行链接在本次主线推送完成后补录。Windows 已进行本机发布程序启动检查；浏览器已完成桌面和触屏模拟自动运行。Android、Linux、macOS、iOS 尚无本轮真人实机操作结论；iOS 构建使用 `--no-codesign`。Android 本机样本使用测试签名，Actions 使用已有仓库正式证书。

## v1.0.0 历史：GitHub Actions 实际验收

[完整通过的工作流](https://github.com/xqd922/Gomoku/actions/runs/34669116772) 对应源码提交 [62c32eb](https://github.com/xqd922/Gomoku/commit/62c32ebc613351aa759eadbee35a375e2954f74b)，已完成六端构建和全部验收；以下记录之后的发行准备只补充文档，正式发行仍由版本标签上的 Actions 重新构建和验证。

- Ubuntu 上的规则 **12 项**、Flutter / SQLite **12 项**、真实后端 **11 项**全部通过，格式与静态分析无诊断。
- **Google Chrome 152.0.7977.82** 完成 **6 组**浏览器流程，运行时异常 **0**，包括邮箱注册、游客归并、第二设备登录、棋谱同步、离线和多标签页。
- Windows x64、Linux x64、Android 通用 APK、macOS 通用 app、iOS 无签名 app、Web 均成功构建和归档。
- macOS 可执行文件通过 `lipo` 的 arm64 / x86_64 检查；下载归档后确认保留 **12 个** app 框架符号链接。Linux 包保留可执行权限 `0755` 与运行库，Windows 包包含完整 DLL 和 data 目录。
- Android 使用仓库原有正式证书，APK v2 / v3 签名验证通过；校验 `com.xqd922.gomoku`、版本 **1.0.0**、versionCode **10000** 和 16 KB ZIP 对齐，并包含 arm64-v8a、armeabi-v7a、x86_64 三种 ABI。
- 生产后端与 Web Docker 镜像在 Ubuntu runner 上构建成功。

验证截图和日志保存在工作流的 `verification` artifact 中。发行文件的具体源码提交与运行链接由 `build-info.json` 记录，`SHA256SUMS.txt` 用于核验下载。发布门槛要求所有验证与六端构建成功，缺少任一平台不会发布。

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
| Web | 本机与 Actions release 构建通过，离线资源完整性已验收 | 本机与 Ubuntu Chrome 双客户端、触屏模拟、离线/多标签页通过 |
| Windows x64 | 本机与 Actions release 构建通过，完整 DLL/data 目录归档 | 本机发布程序启动并持续运行检查通过；未做完整原生人工操作验收 |
| Android | 本机测试签名构建及 Actions 正式签名 APK 构建通过 | 未连接 Android 真机或模拟器；无实机或覆盖安装结论 |
| Linux x64 | Ubuntu 24.04 Actions 构建及归档检查通过 | 未运行 Linux GUI；无真人操作结论 |
| macOS | macOS Actions 通用构建通过，arm64 / x86_64 均验证 | 未在 Mac 实机运行；未进行签名公证 |
| iOS | macOS Actions 无签名设备构建通过 | 未在模拟器或 iPhone 运行；安装前需要开发者签名 |

本机 Android 样本使用测试签名，公开 Release 的 Android APK 使用原有正式证书。iOS 安装、macOS 公证、Windows 安装器签名、正式 SMTP 和公网部署不在本次已验证结果中。六端构建已经实际通过，编译和自动化结果不能替代真人实机验收。

## 本机构建产物

`artifacts/releases` 保留正式签名流水线之前的本机验收样本：

- `Gomoku-1.0.0-windows-x64.zip`：完整 Windows 运行目录。
- `Gomoku-1.0.0-android.apk`：Android 内部验收包。
- `Gomoku-1.0.0-web.zip`：静态 Web 构建与离线资源。
- `SHA256SUMS.txt`：以上文件的校验和。

本机样本与公开发行包应分别看待；正式下载使用 [GitHub Release](https://github.com/xqd922/Gomoku/releases) 中由 Actions 生成的文件及对应校验和。产物默认使用本地开发地址；原生平台连接正式服务时需要按 [部署说明](DEPLOYMENT.md) 设置 dart-define 并重新构建。源码、迁移、配置示例、脚本和 CI 保留在仓库中，构建缓存、真实密钥和本机日志不纳入版本控制。
