import React, { useMemo } from 'react';
import { BoardState, Position } from '../types/game';
import Stone from './Stone';

interface BoardProps {
  board: BoardState;
  onCellClick: (position: Position) => void;
  lastPlaced?: Position | null;
  disabled?: boolean;
}

const Board: React.FC<BoardProps> = ({ 
  board, 
  onCellClick, 
  lastPlaced = null,
  disabled = false 
}) => {
  const boardSize = board.length;

  const boardStyle: React.CSSProperties = {
    display: 'grid',
    gridTemplateColumns: `repeat(${boardSize}, 1fr)`,
    gridTemplateRows: `repeat(${boardSize}, 1fr)`,
    gap: 0,
    width: '100%',
    height: '100%',
    backgroundColor: '#DEB887', // 棋盘的木色背景
    border: '2px solid #8B4513',
    borderRadius: '4px',
    padding: '2px',
    boxShadow: '0 4px 8px rgba(0, 0, 0, 0.2)',
    position: 'relative',
    aspectRatio: '1 / 1', // 保持棋盘为正方形
  };

  // 创建棋盘网格线
  const gridLines = useMemo(() => {
    const lines: React.ReactNode[] = [];
    
    // 横线
    for (let i = 0; i < boardSize; i++) {
      lines.push(
        <div
          key={`h-${i}`}
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            top: `${(i * 100) / (boardSize - 1)}%`,
            height: '1px',
            backgroundColor: 'rgba(0, 0, 0, 0.7)',
            pointerEvents: 'none',
          }}
        />
      );
    }
    
    // 竖线
    for (let i = 0; i < boardSize; i++) {
      lines.push(
        <div
          key={`v-${i}`}
          style={{
            position: 'absolute',
            top: 0,
            bottom: 0,
            left: `${(i * 100) / (boardSize - 1)}%`,
            width: '1px',
            backgroundColor: 'rgba(0, 0, 0, 0.7)',
            pointerEvents: 'none',
          }}
        />
      );
    }
    
    return lines;
  }, [boardSize]);

  // 绘制棋盘上的星位点
  const starPoints = useMemo(() => {
    const stars: React.ReactNode[] = [];
    // 只对15x15以上的棋盘添加星位点
    if (boardSize >= 15) {
      const positions = [3, Math.floor(boardSize / 2), boardSize - 4];
      
      positions.forEach(row => {
        positions.forEach(col => {
          stars.push(
            <div
              key={`star-${row}-${col}`}
              style={{
                position: 'absolute',
                top: `${(row * 100) / (boardSize - 1)}%`,
                left: `${(col * 100) / (boardSize - 1)}%`,
                width: '8px',
                height: '8px',
                backgroundColor: '#000',
                borderRadius: '50%',
                transform: 'translate(-50%, -50%)',
                pointerEvents: 'none',
              }}
            />
          );
        });
      });
    }
    
    return stars;
  }, [boardSize]);

  return (
    <div style={{ position: 'relative', width: '100%', maxWidth: '600px' }}>
      <div style={boardStyle}>
        {/* 绘制网格线 */}
        {gridLines}
        
        {/* 绘制星位点 */}
        {starPoints}
        
        {/* 绘制棋子 */}
        {board.map((row, rowIndex) => 
          row.map((cell, colIndex) => (
            <div
              key={`cell-${rowIndex}-${colIndex}`}
              style={{
                position: 'relative',
                width: '100%',
                height: '100%',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                cursor: disabled || cell !== null ? 'default' : 'pointer',
                zIndex: 1,
              }}
              onClick={() => {
                if (!disabled && cell === null) {
                  onCellClick({ row: rowIndex, col: colIndex });
                }
              }}
            >
              <Stone 
                type={cell} 
                isLastPlaced={!!(lastPlaced && lastPlaced.row === rowIndex && lastPlaced.col === colIndex)}
              />
            </div>
          ))
        )}
      </div>
    </div>
  );
};

export default Board; 