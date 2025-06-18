import React from 'react';
import { GameState } from '../types/game';
import { GameMode } from '../hooks/useGame';

interface GameStatusProps {
  gameState: GameState & {
    gameMode?: GameMode;
    isMyTurn?: boolean;
    isWaitingForOpponent?: boolean;
  };
}

const GameStatus: React.FC<GameStatusProps> = ({ gameState }) => {
  const { 
    status, 
    currentPlayer, 
    winner, 
    gameMode = 'local', 
    isMyTurn = true,
    isWaitingForOpponent = false 
  } = gameState;

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
    if (gameMode === 'network') {
      if (isWaitingForOpponent) {
        statusMessage = '等待对手加入...';
        statusStyle = {
          ...statusStyle,
          backgroundColor: '#fff3cd',
          color: '#856404',
          border: '2px solid #ffeeba',
        };
      } else {
        statusMessage = isMyTurn 
          ? `轮到你落子 (${currentPlayer === 'black' ? '黑方' : '白方'})`
          : `等待对手落子 (${currentPlayer === 'black' ? '黑方' : '白方'})`;
        
        statusStyle = {
          ...statusStyle,
          backgroundColor: isMyTurn ? '#d4edda' : '#f8f9fa',
          color: isMyTurn ? '#155724' : '#6c757d',
          border: `2px solid ${isMyTurn ? '#c3e6cb' : '#dae0e5'}`,
        };
      }
    } else {
      statusMessage = `当前回合: ${currentPlayer === 'black' ? '黑方' : '白方'}`;
      statusStyle = {
        ...statusStyle,
        backgroundColor: currentPlayer === 'black' ? '#333' : '#f5f5f5',
        color: currentPlayer === 'black' ? '#fff' : '#333',
        border: `2px solid ${currentPlayer === 'black' ? '#000' : '#ddd'}`,
      };
    }
  } else if (status === 'draw') {
    statusMessage = '游戏结束: 平局';
    statusStyle = {
      ...statusStyle,
      backgroundColor: '#f0f0f0',
      color: '#666',
      border: '2px solid #999',
    };
  } else {
    const winnerText = winner === 'black' ? '黑方' : '白方';
    
    if (gameMode === 'network') {
      statusMessage = `游戏结束: ${
        (winner === 'black' && isMyTurn) || (winner === 'white' && !isMyTurn) 
          ? '你获胜了' 
          : '对手获胜'
      } (${winnerText})`;
    } else {
      statusMessage = `游戏结束: ${winnerText}获胜`;
    }
    
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