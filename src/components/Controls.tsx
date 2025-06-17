import React from 'react';
import { GameStatus } from '../types/game';

interface ControlsProps {
  onReset: () => void;
  onUndo: () => void;
  canUndo: boolean;
  gameStatus: GameStatus;
}

const Controls: React.FC<ControlsProps> = ({ 
  onReset, 
  onUndo, 
  canUndo,
  gameStatus,
}) => {
  const buttonStyle: React.CSSProperties = {
    padding: '10px 20px',
    fontSize: '1rem',
    borderRadius: '4px',
    border: 'none',
    margin: '0 8px',
    cursor: 'pointer',
    fontWeight: 'bold',
    transition: 'all 0.2s ease',
    boxShadow: '0 2px 4px rgba(0, 0, 0, 0.2)',
  };

  const resetButtonStyle: React.CSSProperties = {
    ...buttonStyle,
    backgroundColor: '#e74c3c',
    color: 'white',
  };

  const undoButtonStyle: React.CSSProperties = {
    ...buttonStyle,
    backgroundColor: canUndo ? '#3498db' : '#ccc',
    color: 'white',
    cursor: canUndo ? 'pointer' : 'not-allowed',
    opacity: canUndo ? 1 : 0.7,
  };

  return (
    <div style={{ 
      display: 'flex', 
      justifyContent: 'center', 
      padding: '15px',
      marginTop: '10px',
    }}>
      <button 
        style={resetButtonStyle} 
        onClick={onReset}
      >
        {gameStatus !== 'playing' ? '新游戏' : '重新开始'}
      </button>
      <button 
        style={undoButtonStyle} 
        onClick={onUndo}
        disabled={!canUndo}
      >
        悔棋
      </button>
    </div>
  );
};

export default Controls; 