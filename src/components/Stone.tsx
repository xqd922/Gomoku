import React from 'react';
import { StoneType } from '../types/game';

interface StoneProps {
  type: StoneType;
  isLastPlaced?: boolean;
}

const Stone: React.FC<StoneProps> = ({ type, isLastPlaced = false }) => {
  if (!type) return null;

  const stoneStyle: React.CSSProperties = {
    width: '80%',
    height: '80%',
    borderRadius: '50%',
    backgroundColor: type === 'black' ? '#000' : '#fff',
    boxShadow: type === 'black' 
      ? '0 2px 4px rgba(0, 0, 0, 0.5)' 
      : '0 2px 4px rgba(0, 0, 0, 0.3), inset 0 0 8px rgba(0, 0, 0, 0.1)',
    display: 'flex',
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 2,
  };

  const markerStyle: React.CSSProperties = {
    width: '25%',
    height: '25%',
    borderRadius: '50%',
    backgroundColor: type === 'black' ? '#FFF' : '#000',
    opacity: isLastPlaced ? 1 : 0,
  };

  return (
    <div style={stoneStyle}>
      {isLastPlaced && <div style={markerStyle} />}
    </div>
  );
};

export default Stone; 