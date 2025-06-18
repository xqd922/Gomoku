# 五子棋游戏 Cloudflare Worker 服务器

这是五子棋游戏的Cloudflare Worker服务器组件，用于实现跨网络的多人对战功能。

## 功能特点

- 基于WebSocket的实时通信
- 支持创建和加入游戏房间
- 自动生成房间ID
- 处理游戏状态同步
- 处理玩家断开连接
- 心跳检测

## 部署步骤

### 准备工作

1. 确保您已有Cloudflare账户，并已登录
2. 安装Node.js和npm（如果尚未安装）

### 安装依赖

```bash
npm install
# 或者使用bun
bun install
```

### 配置Wrangler

1. 全局安装Wrangler（如果尚未安装）
   ```bash
   npm install -g wrangler
   # 或者使用bun
   bun install -g wrangler
   ```

2. 登录到您的Cloudflare账户
   ```bash
   wrangler login
   ```

3. 修改`wrangler.toml`文件中的配置
   - 如果您有自己的域名，可以修改routes部分
   - 如果没有，可以删除routes部分，使用Cloudflare提供的workers.dev域名

### 本地测试

```bash
npm run dev
# 或者
wrangler dev
```

### 部署到Cloudflare

```bash
npm run deploy
# 或者
wrangler deploy
```

## 部署后配置

1. 部署完成后，您会获得一个类似 `https://gomoku-server.YOUR-ACCOUNT.workers.dev` 的URL
2. 将这个URL配置到游戏客户端中:
   - 打开 `src-tauri/src/lib.rs` 文件
   - 找到 `get_cloudflare_worker_url` 函数
   - 将URL更新为您的Worker URL（记得将http替换为ws或https替换为wss）
   ```rust
   fn get_cloudflare_worker_url() -> String {
       "wss://gomoku-server.YOUR-ACCOUNT.workers.dev".to_string()
   }
   ```

3. 重新编译Tauri应用以应用更改

## 注意事项

- Cloudflare Workers有每日请求限制，免费账户每天有100,000次请求限制
- WebSocket连接在Cloudflare Workers上有时间限制，单个连接最长维持30分钟
- 确保正确处理断线重连和错误情况 