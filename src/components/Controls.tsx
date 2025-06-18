import React, { useState } from 'react';
import { GameStatus } from '../types/game';
import { GameMode } from '../hooks/useGame';

interface ControlsProps {
  onReset: () => void;
  onUndo: (() => void) | undefined;
  canUndo: boolean;
  gameStatus: GameStatus;
  gameMode: GameMode;
  onCreateRoom?: () => void;
  onJoinRoom?: (roomId: string) => void;
  onExitNetworkGame?: () => void;
  onConnect?: () => Promise<boolean>;
  onDisconnect?: () => void;
  networkStatus?: string;
  roomCode?: string;
  networkError?: string | null;
  isHost?: boolean;
  playerName?: string | null;
}

const Controls: React.FC<ControlsProps> = ({ 
  onReset, 
  onUndo, 
  canUndo,
  gameStatus,
  gameMode,
  onCreateRoom,
  onJoinRoom,
  onExitNetworkGame,
  onConnect,
  onDisconnect,
  networkStatus = '未连接',
  roomCode,
  networkError,
  isHost,
  playerName,
}) => {
  const [joinRoomId, setJoinRoomId] = useState('');
  const [showJoinInput, setShowJoinInput] = useState(false);
  const [connecting, setConnecting] = useState(false);

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
    backgroundColor: canUndo && onUndo ? '#3498db' : '#ccc',
    color: 'white',
    cursor: canUndo && onUndo ? 'pointer' : 'not-allowed',
    opacity: canUndo && onUndo ? 1 : 0.7,
  };

  const networkButtonStyle: React.CSSProperties = {
    ...buttonStyle,
    backgroundColor: '#27ae60',
    color: 'white',
  };

  const inputStyle: React.CSSProperties = {
    padding: '10px',
    fontSize: '1rem',
    borderRadius: '4px',
    border: '1px solid #ccc',
    marginRight: '8px',
    width: '200px',
  };

  // 处理连接按钮点击
  const handleConnectClick = async () => {
    if (!onConnect) return;
    
    setConnecting(true);
    try {
      await onConnect();
    } catch (err) {
      console.error('连接出错:', err);
    } finally {
      setConnecting(false);
    }
  };

  // 渲染本地游戏控制
  const renderLocalControls = () => (
    <>
      <button style={resetButtonStyle} onClick={onReset}>
        {gameStatus !== 'playing' ? '新游戏' : '重新开始'}
      </button>
      <button 
        style={undoButtonStyle} 
        onClick={onUndo}
        disabled={!canUndo || !onUndo}
      >
        悔棋
      </button>
      {onCreateRoom && onJoinRoom && (
        <button style={networkButtonStyle} onClick={() => setShowJoinInput(!showJoinInput)}>
          联机对战
        </button>
      )}
    </>
  );

  // 渲染网络游戏控制
  const renderNetworkControls = () => (
    <>
      <button style={resetButtonStyle} onClick={onReset}>
        {gameStatus !== 'playing' ? '新游戏' : '重新开始'}
      </button>
      {onExitNetworkGame && (
        <button 
          style={{...networkButtonStyle, backgroundColor: '#e67e22'}} 
          onClick={onExitNetworkGame}
        >
          退出联机
        </button>
      )}
    </>
  );

  // 渲染网络状态信息
  const renderNetworkStatus = () => {
    // 显示网络状态即使在本地模式下，方便调试
    const showStatus = networkStatus || (gameMode === 'local' ? '未连接' : '');
    
    if (showStatus) {
      return (
        <div style={{ 
          marginTop: '10px', 
          padding: '10px', 
          backgroundColor: '#f8f9fa', 
          borderRadius: '4px',
          border: '1px solid #dee2e6'
        }}>
          <p style={{ margin: 0, fontWeight: 'bold' }}>状态: {showStatus}</p>
          {roomCode && (
            <p style={{ margin: '5px 0 0 0' }}>
              房间码: <span style={{ fontWeight: 'bold' }}>{roomCode}</span>
            </p>
          )}
          {isHost !== undefined && (
            <p style={{ margin: '5px 0 0 0' }}>
              角色: <span style={{ fontWeight: 'bold' }}>{isHost ? '房主(黑棋)' : '访客(白棋)'}</span>
            </p>
          )}
          {playerName && (
            <p style={{ margin: '5px 0 0 0' }}>
              玩家ID: <span style={{ fontWeight: 'bold' }}>{playerName}</span>
            </p>
          )}
          {networkError && (
            <p style={{ 
              margin: '5px 0 0 0', 
              color: '#e74c3c', 
              fontWeight: 'bold' 
            }}>
              错误: {networkError}
            </p>
          )}
        </div>
      );
    }
    return null;
  };

  // 渲染调试按钮
  const renderDebugButtons = () => {
    return (
      <div style={{ marginTop: '10px', textAlign: 'center' }}>
        <button
          style={{ 
            padding: '5px 10px', 
            backgroundColor: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            margin: '0 5px',
            cursor: 'pointer',
            fontSize: '0.8rem'
          }}
          onClick={() => {
            console.log('游戏模式:', gameMode);
            console.log('房间码:', roomCode);
            console.log('网络状态:', networkStatus);
            console.log('错误:', networkError);
            alert(`模式: ${gameMode}, 状态: ${networkStatus || '无'}, 房间: ${roomCode || '无'}`);
          }}
        >
          调试信息
        </button>
        
        {/* 连接/断开服务器按钮 */}
        {networkStatus === '未连接' || !networkStatus ? (
          <button
            style={{ 
              padding: '5px 10px', 
              backgroundColor: '#28a745',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              margin: '0 5px',
              cursor: 'pointer',
              fontSize: '0.8rem'
            }}
            onClick={handleConnectClick}
            disabled={connecting}
          >
            {connecting ? '连接中...' : '检查连接'}
          </button>
        ) : (
          <>
            <button
              style={{ 
                padding: '5px 10px', 
                backgroundColor: '#e74c3c',
                color: 'white',
                border: 'none',
                borderRadius: '4px',
                margin: '0 5px',
                cursor: 'pointer',
                fontSize: '0.8rem'
              }}
              onClick={onDisconnect}
            >
              断开连接
            </button>
            
            {networkStatus === '已连接' && (
              <>
                <button 
                  style={{ 
                    padding: '5px 10px', 
                    backgroundColor: '#17a2b8',
                    color: 'white',
                    border: 'none',
                    borderRadius: '4px',
                    margin: '0 5px',
                    cursor: 'pointer',
                    fontSize: '0.8rem'
                  }}
                  onClick={onCreateRoom}
                >
                  创建房间
                </button>
                
                <button 
                  style={{ 
                    padding: '5px 10px', 
                    backgroundColor: '#fd7e14',
                    color: 'white',
                    border: 'none',
                    borderRadius: '4px',
                    margin: '0 5px',
                    cursor: 'pointer',
                    fontSize: '0.8rem'
                  }}
                  onClick={() => setShowJoinInput(!showJoinInput)}
                >
                  {showJoinInput ? '取消' : '加入房间'}
                </button>
              </>
            )}
          </>
        )}
      </div>
    );
  };

  return (
    <div style={{ padding: '15px' }}>
      <div style={{ 
        display: 'flex', 
        justifyContent: 'center', 
        marginTop: '10px',
      }}>
        {gameMode === 'local' ? renderLocalControls() : renderNetworkControls()}
      </div>
      
      {showJoinInput && (
        <div style={{ marginTop: '10px', display: 'flex', justifyContent: 'center' }}>
          <input
            type="text"
            style={inputStyle}
            value={joinRoomId}
            onChange={(e) => setJoinRoomId(e.target.value)}
            placeholder="输入房间码"
          />
          <button 
            style={{ 
              padding: '10px 15px', 
              backgroundColor: '#007bff',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              cursor: 'pointer',
            }}
            onClick={() => {
              if (onJoinRoom && joinRoomId) {
                onJoinRoom(joinRoomId);
                setShowJoinInput(false);
              }
            }}
            disabled={!joinRoomId}
          >
            加入
          </button>
        </div>
      )}
      
      {renderNetworkStatus()}
      
      {renderDebugButtons()}
    </div>
  );
};

export default Controls; 