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
  serverAddress?: string;
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
  serverAddress,
}) => {
  const [joinRoomId, setJoinRoomId] = useState('');
  const [showJoinInput, setShowJoinInput] = useState(false);
  const [connecting, setConnecting] = useState(false);
  const [showHelp, setShowHelp] = useState(false);

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

  // 复制房间码到剪贴板
  const copyRoomCode = () => {
    if (roomCode) {
      navigator.clipboard.writeText(roomCode)
        .then(() => {
          alert('房间码已复制到剪贴板！');
        })
        .catch(err => {
          console.error('复制失败:', err);
          alert('复制失败，请手动复制房间码。');
        });
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
      {roomCode && (
        <button 
          style={{...networkButtonStyle, backgroundColor: '#3498db'}} 
          onClick={copyRoomCode}
        >
          复制房间码
        </button>
      )}
    </>
  );

  // 渲染连接帮助
  const renderConnectionHelp = () => {
    if (!showHelp) return null;
    
    return (
      <div style={{ 
        marginTop: '10px', 
        padding: '10px', 
        backgroundColor: '#f8f9fa', 
        borderRadius: '4px',
        border: '1px solid #dee2e6',
        fontSize: '0.9rem',
        lineHeight: '1.4'
      }}>
        <h4 style={{ margin: '0 0 8px 0' }}>联机对战帮助</h4>
        <p><strong>步骤1:</strong> 双方都需要点击"检查连接"确保状态变为"已连接"</p>
        <p><strong>步骤2:</strong> 一方创建房间（点击"创建房间"）</p>
        <p><strong>步骤3:</strong> 创建者点击"复制房间码"，分享给另一方</p>
        <p><strong>步骤4:</strong> 另一方粘贴房间码，点击"加入"</p>
        
        <hr style={{ margin: '10px 0', borderTop: '1px solid #dee2e6' }} />
        
        <h4 style={{ margin: '8px 0' }}>跨网络联机指南</h4>
        <p>对于不同网络下的连接，游戏会自动尝试以下方法：</p>
        <ol style={{ margin: '5px 0', paddingLeft: '20px' }}>
          <li><strong>WebRTC直连</strong> - 通过STUN服务器进行NAT穿透</li>
          <li><strong>中继服务器</strong> - 如果直连失败，通过TURN服务器中继</li>
          <li><strong>公共WebSocket服务器</strong> - 使用云服务器中转连接</li>
        </ol>
        <p>这些技术可以绕过大多数网络限制，不需要手动设置端口转发。</p>
        
        <h4 style={{ margin: '8px 0' }}>常见问题解决</h4>
        <p><strong>无法连接/房间不存在错误:</strong></p>
        <ul style={{ margin: '5px 0', paddingLeft: '20px' }}>
          <li>确保双方都已更新到最新版本的游戏</li>
          <li>检查您的网络连接是否稳定</li>
          <li>确保房间码输入正确（避免多余空格）</li>
          <li>某些极端的网络环境（如学校、企业网络）可能会阻止所有连接</li>
          <li>尝试使用手机热点连接，许多移动网络对P2P连接更友好</li>
          <li>如果通过代理或VPN连接，尝试临时关闭它们</li>
        </ul>
        
        <button 
          style={{ 
            padding: '5px 10px', 
            marginTop: '5px',
            backgroundColor: '#6c757d',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '0.8rem'
          }}
          onClick={() => setShowHelp(false)}
        >
          关闭帮助
        </button>
      </div>
    );
  };

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
          {serverAddress && (
            <p style={{ margin: '5px 0 0 0', fontSize: '0.9rem' }}>
              服务器: <span style={{ fontFamily: 'monospace' }}>{serverAddress}</span>
            </p>
          )}
          {roomCode && (
            <p style={{ margin: '5px 0 0 0' }}>
              房间码: <span style={{ fontWeight: 'bold', fontFamily: 'monospace' }}>{roomCode}</span>
              <button 
                style={{ 
                  marginLeft: '5px',
                  padding: '2px 5px',
                  backgroundColor: '#3498db',
                  color: 'white',
                  border: 'none',
                  borderRadius: '3px',
                  cursor: 'pointer',
                  fontSize: '0.7rem'
                }}
                onClick={copyRoomCode}
              >
                复制
              </button>
            </p>
          )}
          {isHost !== undefined && (
            <p style={{ margin: '5px 0 0 0' }}>
              角色: <span style={{ fontWeight: 'bold' }}>{isHost ? '房主(黑棋)' : '访客(白棋)'}</span>
            </p>
          )}
          {playerName && (
            <p style={{ margin: '5px 0 0 0' }}>
              玩家ID: <span style={{ fontWeight: 'bold', fontSize: '0.9rem', fontFamily: 'monospace' }}>{playerName}</span>
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
            console.log('服务器地址:', serverAddress);
            alert(`模式: ${gameMode}, 状态: ${networkStatus || '无'}, 房间: ${roomCode || '无'}, 服务器: ${serverAddress || '无'}`);
          }}
        >
          调试信息
        </button>
        
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
          onClick={() => setShowHelp(!showHelp)}
        >
          {showHelp ? '隐藏帮助' : '联机帮助'}
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
      
      {renderConnectionHelp()}
      {renderNetworkStatus()}
      {renderDebugButtons()}
    </div>
  );
};

export default Controls; 