import { BoardState, Position, StoneType } from '../types/game';

// 创建空棋盘
export const createEmptyBoard = (size: number = 15): BoardState => {
  return Array(size).fill(null).map(() => Array(size).fill(null));
};

// 检查是否获胜
export const checkWin = (board: BoardState, position: Position, stoneType: StoneType): boolean => {
  const directions = [
    [1, 0],   // 水平
    [0, 1],   // 垂直
    [1, 1],   // 对角线
    [1, -1],  // 反对角线
  ];

  for (const [dx, dy] of directions) {
    let count = 1;  // 包含当前位置

    // 正向检查
    for (let i = 1; i < 5; i++) {
      const newRow = position.row + dx * i;
      const newCol = position.col + dy * i;
      if (
        newRow < 0 || newRow >= board.length ||
        newCol < 0 || newCol >= board[0].length ||
        board[newRow][newCol] !== stoneType
      ) {
        break;
      }
      count++;
    }

    // 反向检查
    for (let i = 1; i < 5; i++) {
      const newRow = position.row - dx * i;
      const newCol = position.col - dy * i;
      if (
        newRow < 0 || newRow >= board.length ||
        newCol < 0 || newCol >= board[0].length ||
        board[newRow][newCol] !== stoneType
      ) {
        break;
      }
      count++;
    }

    if (count >= 5) {
      return true;
    }
  }

  return false;
};

// 检查是否平局
export const checkDraw = (board: BoardState): boolean => {
  return board.every(row => row.every(cell => cell !== null));
};

// 将当前棋盘状态转换为可以序列化的格式（用于历史记录）
export const serializeBoard = (board: BoardState): string => {
  return JSON.stringify(board);
};

// 从序列化格式恢复棋盘状态
export const deserializeBoard = (serialized: string): BoardState => {
  return JSON.parse(serialized);
}; 