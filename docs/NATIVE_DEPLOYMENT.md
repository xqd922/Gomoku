# Debian 12 小内存服务器部署

正式站点采用 PostgreSQL 17、Redis 7、Caddy 2.10.2、HAProxy 和 systemd。应用以 `gomoku` 用户运行。服务器不安装 Dart、Flutter 或 Docker；Actions 在 Debian 12 构建服务端 AOT，并把迁移和正式 Web 资源一起打包。

## 初始化及升级

域名添加 A 记录，Cloudflare 使用仅 DNS。通过 SSH 将仓库 `infra/native` 复制到 `/opt/gomoku/native`，保持该管理脚本路径稳定。以 root 执行：

```sh
python3 /opt/gomoku/native/manage.py bootstrap gomoku.xqd.pp.ua
python3 /opt/gomoku/native/manage.py install /root/Gomoku-1.2.0-server-debian12-x64.tar.gz
python3 /opt/gomoku/native/manage.py gateway
python3 /opt/gomoku/native/manage.py status
```

`bootstrap` 创建 512 MiB swap 和私有配置 `/etc/gomoku/runtime.env`，生成 `/etc/gomoku/initial-accounts.json` 的两个随机密码；重复执行不会替换既有密码。不要复制这些私有文件到 Release、仓库或公开日志。初次及每次部署先比对发行包 SHA256；升级继续使用 `install`，程序保留当前和上一版。成功部署后可删除上传的压缩包以节省空间。

`gateway` 会先探测既有 REALITY 代理，再在临时端口验证分流。通过后将 Xray 改为 `127.0.0.1:10443`，HAProxy 监听 443，以 SNI 将游戏域名转至 Caddy `127.0.0.1:9443`。保留 Xray 原认证、协议及配置文件权限。Caddy 使用 TLS-ALPN 申请证书，并通过 PROXY protocol 获得真实客户端地址。失败自动恢复原配置。其它现有服务不修改。

## 账户管理

管理员通过 SSH 私下查看 `initial-accounts.json` 并交付给玩家。邮箱仅作为登录标识。需要修改密码时运行：

```sh
python3 /opt/gomoku/native/manage.py reset-password player1@gomoku.xqd.pp.ua
```

密码在终端中不回显，不作为命令参数传入；重置撤销旧会话。初始文件是初次交付记录，重置后不再代表现有密码。私有模式拒绝所有非预置身份的联机、订阅和同步操作。可用 `GOMOKU_AUTH_MODE=email` 保留原自建邮件模式，另行配置 SMTP。

## 备份、恢复和回滚

每天 03:30 运行 `gomoku-backup.timer`，压缩备份在 `/var/backups/gomoku`，只允许 root 访问并保留最近 3 份。每次部署另外下载一份到管理电脑的私有目录，在隔离 PostgreSQL 17 数据库中执行 `pg_restore` 并核对关键表数量。

```sh
python3 /opt/gomoku/native/manage.py backup
python3 /opt/gomoku/native/manage.py rollback
# 灾难恢复会替换当前游戏数据，先确认目标备份：
python3 /opt/gomoku/native/manage.py restore /var/backups/gomoku/SELECTED.dump --confirm-database gomoku
```

程序回滚不会逆向删除迁移；v1.2 迁移保持向后兼容。数据恢复使用单事务，失败时保留原数据库，并在恢复前额外备份。管理命令失败后查看对应 systemd 日志，避免把含凭证的配置复制到公开 issue。

本机已有开发 PostgreSQL 17 容器时，可运行 `python tool/verify_native_backup.py`：它通过固定主机密钥的 SSH 调用服务器备份命令，将备份下载到仅当前用户可读的 `.local/private/backups`，在新建的隔离数据库中恢复，并核对全部表的记录数。对局继续运行时，变化中的表按备份前后计数范围核对；固定账号及其他不变的表须精确一致。完成后只删除该次创建的测试数据库，保留私有备份与不含凭证的验收报告。Windows 默认使用 WSL 的 `Ubuntu-22.04` 和 `gomoku-postgres-1` 容器，可用 `GOMOKU_WSL_DISTRIBUTION`、`GOMOKU_POSTGRES_CONTAINER` 调整。

数据库连接池为 5；PostgreSQL `shared_buffers=16MB`；Redis 限制 16 MiB 且不持久化；权威数据在 PostgreSQL。应用日志限制容量，部署要求剩余空间 ≥500 MiB。GitHub Actions 每 15 分钟检查公网 `/health`，通知遵循仓库已有设置。

## 容量验收

在可信管理电脑的仓库根目录设置 `GOMOKU_ACCOUNTS_FILE` 指向私有账号 JSON，再运行 `dart apps/server/tool/verify_production.dart 60`。脚本使用两个账号的 10 个客户端验证权限、重复／并发命令、悔棋、换色、同步与持续对局；报告写入 `artifacts/production`，不含凭证。验收期间占用两个账号；检测到已有活跃棋局时会退出。脚本会生成测试棋谱，报告记录其房间及本地棋谱标识，便于管理员保留证据或定向清理。

容量测试与客户端一样，对传输失败延迟 500 毫秒重试一次，命令标识及预期版本保持不变。报告单独记录重试次数，P95 包含重试耗时；连接或局面一致性无法恢复时测试失败。可同时在服务器运行 `python3 /opt/gomoku/native/observe.py 3900`，采样服务 PID、重启次数、内存和磁盘，区分网络失败与服务器容量问题。
