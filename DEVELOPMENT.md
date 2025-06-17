# 五子棋应用开发文档

本文档记录了使用Tauri、React和TypeScript开发五子棋桌面应用的完整过程。

## 目录

1. [项目初始化](#项目初始化)
2. [应用架构设计](#应用架构设计)
3. [核心组件开发](#核心组件开发)
4. [游戏逻辑实现](#游戏逻辑实现)
5. [前后端交互](#前后端交互)
6. [应用打包](#应用打包)
7. [GitHub发布](#github发布)
8. [问题与解决方案](#问题与解决方案)

## 项目初始化

我们使用Tauri脚手架初始化了项目，选择React和TypeScript作为前端技术栈。

```bash
# 使用Tauri CLI创建项目
npm create tauri-app@latest gomoku
# 选择React + TypeScript + Vite模板
```

项目初始结构主要包含：
- `src/` - React前端代码
- `src-tauri/` - Rust后端代码
- `public/` - 静态资源

## 应用架构设计

### 文件结构设计

为了更好地组织代码，我们添加了以下目录结构：

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
```

### 类型设计

在`src/types/game.ts`中，我们定义了游戏相关的类型：

```typescript
export type StoneType = 'black' | 'white' | null;
export type BoardState = StoneType[][];
export interface Position {
  row: number;
  col: number;
}
export type GameStatus = 'playing' | 'black-win' | 'white-win' | 'draw';
export interface GameState {
  board: BoardState;
  currentPlayer: 'black' | 'white';
  status: GameStatus;
  winner: StoneType;
  history: Position[];
}
```

## 核心组件开发

### 棋盘和棋子组件

棋盘组件(`Board.tsx`)负责渲染15×15的棋盘网格，处理点击事件，并显示棋子。
棋子组件(`Stone.tsx`)渲染黑白棋子，并支持标记最后落子位置。

关键实现点：
- 使用CSS Grid实现棋盘布局
- 使用绝对定位绘制网格线和星位点
- 棋子使用圆形设计，通过阴影增强立体感

### 游戏状态和控制组件

游戏状态组件(`GameStatus.tsx`)显示当前游戏状态，包括当前回合和胜负情况。
控制组件(`Controls.tsx`)提供重新开始和悔棋功能。

## 游戏逻辑实现

### 前端逻辑

在`src/utils/gameLogic.ts`中实现了核心游戏逻辑：

```typescript
// 创建空棋盘
export const createEmptyBoard = (size: number = 15): BoardState => {
  return Array(size).fill(null).map(() => Array(size).fill(null));
};

// 检查是否获胜
export const checkWin = (board: BoardState, position: Position, stoneType: StoneType): boolean => {
  // 检查横、竖、斜四个方向是否有连续五子
  // ...
};

// 检查是否平局
export const checkDraw = (board: BoardState): boolean => {
  return board.every(row => row.every(cell => cell !== null));
};
```

### 状态管理

使用React Hooks实现游戏状态管理(`useGameState.ts`)：

```typescript
const useGameState = (boardSize: number = 15) => {
  const [gameState, setGameState] = useState<GameState>({
    board: createEmptyBoard(boardSize),
    currentPlayer: 'black',
    status: 'playing',
    winner: null,
    history: [],
  });

  // 实现放置棋子、悔棋、重置游戏等功能
  // ...
  
  return {
    gameState,
    placeStone,
    resetGame,
    undoMove,
  };
};
```

## 前后端交互

### Rust后端逻辑

在`src-tauri/src/lib.rs`中实现了胜负判断逻辑：

```rust
#[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq)]
pub enum StoneType {
    Black,
    White,
}

// 检查游戏胜负的API函数
#[tauri::command]
fn check_win(board: Vec<Vec<Option<StoneType>>>, row: usize, col: usize, stone: StoneType) -> bool {
    // 检查横、竖、斜四个方向是否有连续五子
    // ...
}

// 检查是否平局的API函数
#[tauri::command]
fn check_draw(board: Vec<Vec<Option<StoneType>>>) -> bool {
    // ...
}
```

### 前端调用后端

在`useGameState.ts`中通过Tauri API调用Rust函数：

```typescript
// 检测是否在Tauri环境中运行
const [isTauri, setIsTauri] = useState(false);

useEffect(() => {
  const checkTauri = async () => {
    try {
      await invoke('greet', { name: 'Gomoku' });
      setIsTauri(true);
    } catch (e) {
      setIsTauri(false);
    }
  };
  
  checkTauri();
}, []);

// 使用Rust后端检查胜负
if (isTauri) {
  try {
    hasWon = await invoke('check_win', { 
      board: boardForBackend, 
      row, 
      col, 
      stone: currentStone === 'black' ? { Black: {} } : { White: {} } 
    }) as boolean;
    // ...
  } catch (e) {
    // 降级到前端逻辑
    // ...
  }
}
```

## 应用打包

### 打包过程

使用Tauri的构建功能将应用打包为可执行文件和安装包：

```bash
# 打包应用
bun run tauri build
```

打包过程执行以下步骤：
1. 编译前端代码 (`bun run build`)
2. 编译Rust后端代码（Release模式）
3. 生成单文件可执行程序 (EXE)
4. 生成Windows安装包 (MSI)

### 解决打包问题

在打包过程中，我们遇到并解决了以下问题：

1. TypeScript类型错误
   ```
   src/components/Board.tsx:81:11 - error TS7034: Variable 'stars' implicitly has type 'any[]'
   ```
   解决方案：添加明确的类型声明 `const stars: React.ReactNode[] = [];`

2. Rust `PartialEq` 实现缺失
   ```
   error[E0369]: binary operation `==` cannot be applied to type `StoneType`
   ```
   解决方案：为`StoneType`枚举添加`PartialEq`派生宏：
   ```rust
   #[derive(Debug, Serialize, Deserialize, Clone, Copy, PartialEq)]
   pub enum StoneType {
       Black,
       White,
   }
   ```

### 打包结果

成功生成以下文件：
- 可执行文件: `src-tauri/target/release/gomoku.exe`
- 安装包: `src-tauri/target/release/bundle/msi/gomoku_0.1.0_x64_en-US.msi`

## GitHub发布

### 代码提交

1. 添加`.gitignore`规则，排除构建文件：
   ```
   # 构建文件
   *.exe
   *.msi
   *.dmg
   *.app
   *.deb
   *.rpm
   
   # Tauri构建目录
   src-tauri/target
   ```

2. 提交代码并推送到GitHub：
   ```bash
   git add .
   git commit -m "完成五子棋游戏开发"
   git push origin main
   ```

### 创建Release

1. 创建并推送标签：
   ```bash
   git tag -a v0.1.0 -m "第一个正式版本"
   git push origin v0.1.0
   ```

2. 在GitHub上创建Release，上传MSI安装包：
   - 选择标签: `v0.1.0`
   - 标题: 五子棋应用 v0.1.0
   - 描述: 详细介绍应用功能和下载说明
   - 附件: 上传MSI安装文件

3. 更新项目信息：
   - 添加项目描述
   - 添加标签: `gomoku`, `五子棋`, `tauri`, `react`, `typescript`, `game`, `board-game`

## 问题与解决方案

在开发过程中，我们遇到并解决了以下典型问题：

1. **TypeScript类型问题**
   - 问题: 变量隐式类型和类型不匹配
   - 解决: 添加明确的类型声明和类型转换

2. **Rust类型系统问题**
   - 问题: 缺少`PartialEq`trait实现
   - 解决: 为自定义类型添加派生宏

3. **前后端交互问题**
   - 问题: 数据格式转换和错误处理
   - 解决: 实现格式转换函数和降级策略

4. **打包过程问题**
   - 问题: NSIS下载失败
   - 解决: 使用MSI安装包作为替代方案

## 结论

通过结合Tauri、React和TypeScript的强大功能，我们成功开发了一个高性能、美观的五子棋桌面应用。项目代码组织良好，实现了完整的游戏功能，并成功打包为可分发的应用程序。