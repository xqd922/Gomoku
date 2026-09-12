# 架构与协议

## 模块边界

项目是一个 Dart workspace，采用模块化单体服务。客户端与服务端都调用 `gomoku_core`，规则中没有 UI、网络或数据库代码。Flutter 使用 Riverpod 管理状态、go_router 路由、Drift 持久化。服务端通过 Serverpod 类型化 Endpoint 与 Streaming Method 对外提供能力。

`GameState` 不可变，保存按顺序排列的 `Move`、轮到的棋色和 `GameResult`。所有导入棋谱都重新执行落子序列，核验胜负、落点、次序、终局限制与时间字段。15×15 棋盘，黑棋先行，任意方向连续五颗或更多获胜，无禁手；满盘无人获胜为和棋。

## 服务端数据

| 表 | 作用 |
| --- | --- |
| `gm_players` | 独立玩家 ID、认证用户映射、昵称、游客归并目标 |
| `gm_rooms` | 房间快照、版本、状态、座位、截止时间 |
| `gm_active_seats` | 每名玩家至多一个进行中的房间 |
| `gm_presence` | 每设备连接租约；多标签页任一有效连接即在线 |
| `gm_commands` | 命令请求摘要、持久化返回快照、幂等回执 |
| `gm_records / gm_record_owners` | 不可变终局记录与各玩家所有权 |
| `gm_sync_clocks` | 按玩家串行分配、随事务提交的同步版本 |
| `gm_outbox` | 与房间版本一同提交的待发送事件 |
| `gm_rate_limits` | 跨实例共享的频率限制 |
| Serverpod 认证表 | 已验证邮箱、密码哈希、验证请求与服务端会话 |

## 房间状态与命令

`waiting → playing → finished`；掉线时 `playing → paused`，重连后恢复 `playing`，120 秒超时生成 `interrupted` 记录。房主首局黑棋，双方确认再来一局后交换黑白、创建新 gameId。等待房间空闲 30 分钟后关闭。首版无棋钟。

| Endpoint | 调用 |
| --- | --- |
| `room` | `createRoom`、`joinRoom`、`activeRoom`、`snapshot`、`command`、`heartbeat`、`watch` |
| `profile` | `me`、`rename`、`syncRecords` |
| `POST /auth/*` | `guest`、`session`、`register-start`、`register-finish`、`login`、`reset-start`、`reset-finish`、`logout` |

每个房间命令携带 `commandId` 和 `expectedRevision`。服务端验证已认证玩家、座位、状态、轮次、合法落点，锁定相关行后在同一事务中保存快照、回执、终局记录及 outbox，再向调用者返回。

- 相同玩家、相同命令 ID、相同请求返回原有结果；相同 ID 的不同内容返回 `command_conflict`。
- 过期版本返回 `stale_revision`，客户端重新取快照。准备和再来一局可以在同一局、同一阶段有限重试，重试使用新命令 ID；落子、悔棋和认输不自动套用到变化后的局面。
- 悔棋须对方同意，回退到申请者最近一次落子之前；协商中暂停新的落子。
- 对局中切换身份、退出账号、重命名都被服务端拒绝，避免座位和记录归属改变。

在线连接以 8 秒心跳续期 25 秒租约，服务端每 2 秒维护房间。明确断开订阅会立即释放相应连接；异常断网最多等待租约到期才被识别，此后开始 120 秒保留期。首版允许同一玩家多设备查看同一房间，命令版本仍由服务器校验。

Outbox 每 250 毫秒尝试派发，通过 Redis 通知各个服务实例，发布失败保留事件供下次重试。客户端只接受不倒退的房间版本。Streaming Method 每 10 秒也发送数据库快照，弥补通知丢失；重连与服务重启都从 PostgreSQL 恢复，Redis 不保存唯一的对局状态。

## 身份与凭证

游客创建独立认证用户和 `gm_players` 玩家；邮箱登录使用 Serverpod 稳定的 Email IDP 和 ServerSideSessions，不依赖实验性的匿名绑定功能。会话绝对有效期 30 天，连续不活跃 7 天过期。

归并前验证当前游客凭证和目标邮箱账号凭证，在一个数据库事务中检查活跃座位、转移记录、更新玩家映射并撤销游客会话。注册新账号保留游客玩家 ID 并使用注册昵称；登录已有账号保留原账号 ID、昵称与资料，只合并游客记录。客户端也在 Drift 事务中转移该游客命名空间的数据，其他账号的本地缓存保持隔离。

原生平台凭证使用 `flutter_secure_storage`，存储键包含后端地址。浏览器认证 JSON 不返回会话秘密；生产使用 `__Host-gomoku_session`、`Secure`、`HttpOnly`、`SameSite=Lax` 和根路径 Cookie。浏览器认证和 Cookie 模式的 RPC、WebSocket 请求验证 Origin。公开生成的客户端标记 `Bearer web-session` 仅选择 Cookie 适配，不是凭证。

密码找回完成后撤销旧会话。客户端定期和恢复前台时重新验证会话，失效后清除认证状态；离线时保留本地账号数据供恢复连接后继续同步。

## 棋谱与同步

Drift schema v1 包含 `GameEntries` 和 `SyncCursors`。每条记录以 `(recordId, ownerKey)` 为主键；游客和正式账号使用不同命名空间。本地每次落子先执行原子比较写入，旧页面得到冲突提示并加载最新棋局。通过 Drift worker 的数据库通知更新其他标签页。

只有已结束的本地棋局进入上传队列；未结束的棋局留在本设备自动保存。完成同步后在一个本地事务中提交上传确认、下载记录和游标。失败保留队列，在恢复网络、前台和周期刷新时重试。联机终局始终以服务端记录为准，客户端不能覆盖。

服务端按 UUID 去重，拒绝伪造的胜负、非法棋序和不属于当前玩家的记录。同步游标格式为 `r1:<revision>`；`gm_record_owners` 插入触发器锁定玩家同步时钟，避免一个较早开始但较晚提交的事务被游标跳过。旧时间戳游标迁移后进行一次全量扫描。

## 数据库迁移

`apps/server/migrations` 由 Serverpod 管理认证模块结构，启动参数 `--apply-migrations` 应用迁移。`apps/server/db/001_initial.sql` 创建业务表，`002_sync_revisions.sql` 升级同步游标。

应用迁移在 PostgreSQL advisory lock 下顺序运行，记录版本与 SHA-256。禁止修改已应用的 SQL；变更必须追加连续编号文件。校验和统一 LF 行尾，避免 Windows 检出导致误判。Drift 未来升级须增加 schemaVersion、提供显式 onUpgrade，并验证旧文件迁移。

## 代码生成

从根目录运行 `flutter pub get --enforce-lockfile` 后：

```bash
dart pub global activate serverpod_cli 3.4.13
cd apps/server
dart pub global run serverpod_cli:serverpod_cli generate
cd ../gomoku_app
dart run build_runner build
```

生成的协议和 Drift Dart 文件随源码交付。升级依赖、协议或数据库后运行单元测试、真实服务测试和浏览器验收；不要编辑生成的客户端方法签名。
