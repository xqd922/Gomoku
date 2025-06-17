import { BoardState, Position, StoneType } from '../types/game';

// 创建空棋盘
export const createEmptyBoard = (size: number = 15): BoardState => {
  return Array(size).fill(null).map(() => Array(size).fill(null));
};

// 检查是否获胜
export const checkWin = (board: BoardState, position: Position, stoneType: StoneType): boolean => {
  if (!position || !stoneType) return false;
  
  const { row, col } = position;
  const directions = [
    [0, 1],   // 横向
    [1, 0],   // 纵向
    [1, 1],   // 左上到右下
    [1, -1],  // 右上到左下
  ];
  
  return directions.some(([dr, dc]) => {
    let count = 1;  // 当前位置已有一个棋子
    
    // 正向检查
    for (let i = 1; i < 5; i++) {
      const r = row + dr * i;
      const c = col + dc * i;
      
      if (r < 0 || r >= board.length || c < 0 || c >= board[0].length || board[r][c] !== stoneType) {
        break;
      }
      count++;
    }
    
    // 反向检查
    for (let i = 1; i < 5; i++) {
      const r = row - dr * i;
      const c = col - dc * i;
      
      if (r < 0 || r >= board.length || c < 0 || c >= board[0].length || board[r][c] !== stoneType) {
        break;
      }
      count++;
    }
    
    return count >= 5;
  });
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