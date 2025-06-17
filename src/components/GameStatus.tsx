import React from 'react';
import { GameState } from '../types/game';

interface GameStatusProps {
  gameState: GameState;
}

const GameStatus: React.FC<GameStatusProps> = ({ gameState }) => {
  const { status, currentPlayer, winner } = gameState;

  // 确定状态信息
  let statusMessage = '';
  let statusStyle: React.CSSProperties = {
    fontSize: '1.2rem',
    fontWeight: 'bold',
    padding: '10px',
    borderRadius: '4px',
    textAlign: 'center',
    margin: '10px 0',
  };

  if (status === 'playing') {
    statusMessage = `当前回合: ${currentPlayer === 'black' ? '黑方' : '白方'}`;
    statusStyle = {
      ...statusStyle,
      backgroundColor: currentPlayer === 'black' ? '#333' : '#f5f5f5',
      color: currentPlayer === 'black' ? '#fff' : '#333',
      border: `2px solid ${currentPlayer === 'black' ? '#000' : '#ddd'}`,
    };
  } else if (status === 'draw') {
    statusMessage = '游戏结束: 平局';
    statusStyle = {
      ...statusStyle,
      backgroundColor: '#f0f0f0',
      color: '#666',
      border: '2px solid #999',
    };
  } else {
    statusMessage = `游戏结束: ${winner === 'black' ? '黑方' : '白方'}获胜`;
    statusStyle = {
      ...statusStyle,
      backgroundColor: winner === 'black' ? '#333' : '#f5f5f5',
      color: winner === 'black' ? '#fff' : '#333',
      border: `2px solid ${winner === 'black' ? '#000' : '#ddd'}`,
    };
  }

  return (
    <div style={statusStyle}>
      {statusMessage}
    </div>
  );
};

export default GameStatus; 