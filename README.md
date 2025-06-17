# 五子棋 (Gomoku) - 基于 Tauri + React + TypeScript

一个使用Tauri、React和TypeScript开发的五子棋桌面应用程序。

![五子棋游戏](/screenshots/game.png)

## 功能特点

- 标准15×15棋盘
- 黑白棋子交替落子
- 胜负判断（横、竖、斜向连成五子）
- 悔棋功能
- 重新开始/新游戏
- 游戏状态显示
- 前后端结合（React前端 + Rust后端）

## 技术栈

- **前端**: React 18, TypeScript
- **后端/桌面**: Tauri 2, Rust
- **构建工具**: Vite, Bun

## 开发环境设置

### 推荐的IDE设置

- [VS Code](https://code.visualstudio.com/) + [Tauri](https://marketplace.visualstudio.com/items?itemName=tauri-apps.tauri-vscode) + [rust-analyzer](https://marketplace.visualstudio.com/items?itemName=rust-lang.rust-analyzer)

### 安装依赖

```bash
# 安装依赖
bun install
```

### 开发模式

```bash
# 启动开发服务器
bun run dev

# 启动Tauri应用
bun run tauri dev
```

## 打包应用

可以使用以下命令打包应用：

```bash
# 打包为可执行文件和安装包
bun run tauri build
```

打包过程会完成以下工作：

1. 编译前端代码 (`bun run build`)
2. 编译Rust后端代码（Release模式）
3. 生成单文件可执行程序 (EXE)
   - 位置: `src-tauri/target/release/gomoku.exe`
4. 生成Windows安装包 (MSI)
   - 位置: `src-tauri/target/release/bundle/msi/gomoku_0.1.0_x64_en-US.msi`

### 手动复制可执行文件

如果需要快速分发可执行文件，可以将其复制到更方便的位置：

```bash
# 复制可执行文件到项目根目录
cp .\src-tauri\target\release\gomoku.exe .\gomoku.exe
```

## 分发应用

有两种方式分发此应用：

1. **安装包方式**：分享MSI文件，用户通过安装向导进行安装
2. **便携方式**：直接分享EXE文件，用户无需安装即可运行

## 项目结构

```
src/
  components/       - UI组件
    Board.tsx       - 棋盘组件
    Stone.tsx       - 棋子组件
    GameStatus.tsx  - 游戏状态组件
    Controls.tsx    - 游戏控制组件
  hooks/
    useGameState.ts - 游戏状态管理
  types/
    game.ts         - 类型定义
  utils/
    gameLogic.ts    - 游戏逻辑
  App.tsx           - 主应用
  App.css           - 应用样式

src-tauri/
  src/              - Rust后端代码
  Cargo.toml        - Rust项目配置
  tauri.conf.json   - Tauri配置
```

## 许可证

[MIT](LICENSE)
