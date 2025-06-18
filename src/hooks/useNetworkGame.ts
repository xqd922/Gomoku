import { useState, useEffect, useCallback, useRef } from 'react';
import { invoke } from '@tauri-apps/api/core';
import { Position, StoneType } from '../types/game';

// 网络游戏相关状态类型
export type NetworkGameStatus = 'disconnected' | 'connecting' | 'connected' | 'waiting' | 'playing';

// 网络游戏相关消息类型
type MessageType = 
  | { type: 'init', playerId: string }
  | { type: 'roomCreated', roomId: string }
  | { type: 'error', message: string }
  | { type: 'gameStart', roomId: string, hostId: string, guestId: string | null }
  | { type: 'placeStone', playerId: string, row: number, col: number }
  | { type: 'gameOver', winner: StoneType | null, isDraw: boolean }
  | { type: 'playerDisconnected', playerId: string }
  | { type: 'pong', time: number };

interface UseNetworkGameProps {
  onReceiveMove: (position: Position) => void;
  onGameStart: () => void;
  onOpponentDisconnect: () => void;
  onReconnect: () => void;
}

const useNetworkGame = ({
  onReceiveMove,
  onGameStart,
  onOpponentDisconnect,
  onReconnect
}: UseNetworkGameProps) => {
  const [status, setStatus] = useState<NetworkGameStatus>('disconnected');
  const [playerId, setPlayerId] = useState<string | null>(null);
  const [roomId, setRoomId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isHost, setIsHost] = useState(false);
  const [opponentId, setOpponentId] = useState<string | null>(null);
  const [lastPingTime, setLastPingTime] = useState<number>(0);
  const [connectionDelay, setConnectionDelay] = useState<number | null>(null);
  
  const wsRef = useRef<WebSocket | null>(null);
  const messageHandlerRef = useRef<((message: MessageType) => void) | null>(null);
  
  // 检查连接状态
  const checkConnection = useCallback(() => {
    if (!wsRef.current || wsRef.current.readyState !== WebSocket.OPEN) {
      setStatus('disconnected');
      return false;
    }
    return true;
  }, []);
  
  // 处理接收到的消息
  const handleMessage = useCallback((message: MessageType) => {
    console.log('收到消息:', message);
    
    switch (message.type) {
      case 'init':
        console.log('设置玩家ID:', message.playerId);
        setPlayerId(message.playerId);
        break;
        
      case 'roomCreated':
        console.log('房间创建成功，房间ID:', message.roomId);
        setRoomId(message.roomId);
        setStatus('waiting');
        setError(null); // 清除可能存在的错误
        break;
        
      case 'error':
        console.error('收到错误消息:', message.message);
        setError(message.message);
        break;
        
      case 'gameStart':
        console.log('游戏开始，房间:', message.roomId, '主机:', message.hostId, '访客:', message.guestId);
        setRoomId(message.roomId);
        setStatus('playing');
        setError(null); // 清除可能存在的错误
        
        // 确定玩家角色（房主或访客）
        if (playerId === message.hostId) {
          setIsHost(true);
          setOpponentId(message.guestId);
        } else {
          setIsHost(false);
          setOpponentId(message.hostId);
        }
        
        onGameStart();
        break;
        
      case 'placeStone':
        console.log('收到落子消息:', message);
        // 如果是对手的落子，通知游戏逻辑
        if (message.playerId !== playerId) {
          onReceiveMove({
            row: message.row,
            col: message.col
          });
        }
        break;
        
      case 'playerDisconnected':
        console.log('玩家断开连接:', message.playerId);
        if (message.playerId === opponentId) {
          setOpponentId(null);
          onOpponentDisconnect();
        }
        break;
        
      case 'gameOver':
        console.log('游戏结束:', message);
        // 游戏结束逻辑在游戏组件中处理
        break;
      
      case 'pong':
        // 计算网络延迟
        const now = Date.now();
        const delay = now - lastPingTime;
        setConnectionDelay(delay);
        console.log(`收到pong响应，延迟: ${delay}ms`);
        break;
        
      default:
        console.warn('收到未知类型的消息:', message);
    }
  }, [playerId, opponentId, onReceiveMove, onGameStart, onOpponentDisconnect, lastPingTime]);

  // 保存最新的消息处理函数到ref
  useEffect(() => {
    messageHandlerRef.current = handleMessage;
  }, [handleMessage]);
  
  // 连接到WebSocket服务器
  const connect = useCallback(async () => {
    try {
      // 如果已经连接，直接返回成功
      if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
        console.log('WebSocket已经连接，无需重复连接');
        setStatus('connected');
        setError(null);
        return true;
      }
      
      setStatus('connecting');
      setError(null);
      
      // 从Tauri后端获取WebSocket服务器地址
      console.log('正在获取WebSocket服务器地址...');
      const serverUrl = await invoke<string>('get_ws_server_address').catch(err => {
        console.error('获取WebSocket地址失败:', err);
        throw new Error(`获取WebSocket地址失败: ${err}`);
      });
      console.log('获取到WebSocket服务器地址:', serverUrl);
      
      // 创建WebSocket连接
      console.log('正在连接到WebSocket服务器...');
      let ws: WebSocket;
      
      try {
        ws = new WebSocket(serverUrl);
      } catch (err) {
        console.error('创建WebSocket对象失败:', err);
        throw new Error(`创建WebSocket对象失败: ${err}`);
      }
      
      // 添加超时处理
      const timeoutId = setTimeout(() => {
        if (ws.readyState !== WebSocket.OPEN) {
          console.error('WebSocket连接超时');
          ws.close();
          setError('连接超时，请确保服务器已启动');
          setStatus('disconnected');
        }
      }, 5000); // 5秒超时
      
      ws.onopen = () => {
        console.log('WebSocket连接已建立');
        clearTimeout(timeoutId);
        setStatus('connected');
        
        // 连接成功后立即发送ping检查连接质量
        setTimeout(() => {
          if (ws.readyState === WebSocket.OPEN) {
            try {
              setLastPingTime(Date.now());
              ws.send(JSON.stringify({ type: 'ping' }));
            } catch (e) {
              console.error('发送初始ping消息失败:', e);
            }
          }
        }, 500);
      };
      
      ws.onmessage = (event) => {
        try {
          console.log('收到原始消息:', event.data);
          const message = JSON.parse(event.data) as MessageType;
          if (messageHandlerRef.current) {
            messageHandlerRef.current(message);
          }
        } catch (err) {
          console.error('处理消息时出错:', err, '原始消息:', event.data);
        }
      };
      
      ws.onerror = (error) => {
        console.error('WebSocket错误:', error);
        clearTimeout(timeoutId);
        setError('连接错误，请确保服务器已启动并且网络正常');
        setStatus('disconnected');
      };
      
      ws.onclose = (event) => {
        console.log('WebSocket连接已关闭:', event.code, event.reason);
        clearTimeout(timeoutId);
        setStatus('disconnected');
        
        // 如果有房间ID，说明是在游戏过程中断开连接
        if (roomId && event.code !== 1000) {
          console.log('非正常关闭，游戏过程中断开连接');
          setError(`连接已断开 (代码: ${event.code})，请重新连接`);
        } 
        // 如果是正常关闭，不显示错误信息
        else if (event.code === 1000) {
          console.log('正常关闭连接');
        }
        // 其他非正常关闭情况
        else if (event.code !== 1000) {
          setError(`连接已断开 (代码: ${event.code})，请重新连接`);
        }
      };
      
      wsRef.current = ws;
      
      // 设置心跳检测，每30秒发送一次ping消息
      const heartbeatInterval = setInterval(() => {
        if (ws.readyState === WebSocket.OPEN) {
          console.log('发送心跳消息');
          try {
            setLastPingTime(Date.now());
            ws.send(JSON.stringify({ type: 'ping' }));
          } catch (e) {
            console.error('发送心跳消息失败:', e);
          }
        } else {
          clearInterval(heartbeatInterval);
        }
      }, 30000);
      
      // 当WebSocket关闭时，清除心跳定时器
      ws.addEventListener('close', () => {
        clearInterval(heartbeatInterval);
      });
      
      return true;
    } catch (err) {
      console.error('连接WebSocket服务器时出错:', err);
      setError(`无法连接到服务器: ${err instanceof Error ? err.message : String(err)}`);
      setStatus('disconnected');
      return false;
    }
  }, [roomId]);
  
  // 创建游戏房间
  const createRoom = useCallback(async () => {
    console.log('创建房间开始, 状态:', status, '玩家ID:', playerId);
    
    // 确保连接存在
    if (!checkConnection()) {
      console.log('创建房间时发现未连接，正在尝试连接...');
      const connected = await connect();
      if (!connected) {
        setError('无法连接到服务器，请重试');
        return false;
      }
      
      // 连接成功后等待一小段时间确保连接稳定
      await new Promise(resolve => setTimeout(resolve, 500));
    }
    
    if (wsRef.current && playerId && status === 'connected') {
      // 修正消息格式以匹配Rust后端
      const message = {
        CreateRoom: { player_id: playerId }
      };
      
      try {
        console.log('发送创建房间消息:', message);
        wsRef.current.send(JSON.stringify(message));
        setIsHost(true);
        return true;
      } catch (err) {
        console.error('发送创建房间消息失败:', err);
        setError(`发送创建房间消息失败: ${err instanceof Error ? err.message : String(err)}`);
        return false;
      }
    } else {
      console.error('创建房间失败:', {
        wsRef: !!wsRef.current,
        playerId,
        status
      });
      setError('无法创建房间，请确保已连接到服务器');
      return false;
    }
  }, [playerId, status, connect, checkConnection]);
  
  // 加入房间
  const joinRoom = useCallback(async (roomIdToJoin: string) => {
    console.log('加入房间开始, 状态:', status, '玩家ID:', playerId, '房间ID:', roomIdToJoin);
    
    // 确保连接存在
    if (!checkConnection()) {
      console.log('加入房间时发现未连接，正在尝试连接...');
      const connected = await connect();
      if (!connected) {
        setError('无法连接到服务器，请重试');
        return false;
      }
      
      // 连接成功后等待一小段时间确保连接稳定
      await new Promise(resolve => setTimeout(resolve, 500));
    }
    
    if (wsRef.current && playerId && status === 'connected') {
      // 修正消息格式以匹配Rust后端
      const message = {
        JoinRoom: { 
          player_id: playerId,
          room_id: roomIdToJoin 
        }
      };
      
      try {
        console.log('发送加入房间消息:', message);
        wsRef.current.send(JSON.stringify(message));
        setIsHost(false);
        return true;
      } catch (err) {
        console.error('发送加入房间消息失败:', err);
        setError(`发送加入房间消息失败: ${err instanceof Error ? err.message : String(err)}`);
        return false;
      }
    } else {
      console.error('加入房间失败:', {
        wsRef: !!wsRef.current,
        playerId,
        status
      });
      setError('无法加入房间，请确保已连接到服务器');
      return false;
    }
  }, [playerId, status, connect, checkConnection]);
  
  // 发送落子消息
  const sendMove = useCallback((position: Position) => {
    if (!checkConnection()) {
      setError('连接已断开，无法发送落子');
      return false;
    }
    
    if (wsRef.current && playerId && roomId && status === 'playing') {
      // 修正消息格式以匹配Rust后端
      const message = {
        PlaceStone: {
          player_id: playerId,
          row: position.row,
          col: position.col
        }
      };
      
      try {
        console.log('发送落子消息:', message);
        wsRef.current.send(JSON.stringify(message));
        return true;
      } catch (err) {
        console.error('发送落子消息失败:', err);
        setError(`发送落子消息失败: ${err}`);
        return false;
      }
    }
    return false;
  }, [playerId, roomId, status, checkConnection]);
  
  // 断开连接
  const disconnect = useCallback(() => {
    console.log('主动断开WebSocket连接');
    if (wsRef.current) {
      // 发送关闭消息，让服务器知道这是一个正常关闭
      try {
        const closeMsg = JSON.stringify({
          type: 'close',
          playerId: playerId
        });
        wsRef.current.send(closeMsg);
      } catch (e) {
        console.error('发送关闭消息失败:', e);
      }
      
      // 等待100ms再关闭，让消息有时间发送
      setTimeout(() => {
        if (wsRef.current) {
          wsRef.current.close(1000, "正常关闭");
          wsRef.current = null;
        }
        
        setStatus('disconnected');
        setRoomId(null);
        setOpponentId(null);
        setIsHost(false);
      }, 100);
    } else {
      setStatus('disconnected');
      setPlayerId(null);
      setRoomId(null);
      setOpponentId(null);
      setIsHost(false);
    }
  }, [playerId]);
  
  // 重新连接
  const reconnect = useCallback(async () => {
    disconnect();
    const success = await connect();
    if (success) {
      onReconnect();
    }
    return success;
  }, [disconnect, connect, onReconnect]);
  
  // 组件卸载时清理WebSocket连接
  useEffect(() => {
    return () => {
      if (wsRef.current) {
        wsRef.current.close();
      }
    };
  }, []);
  
  return {
    status,
    playerId,
    roomId,
    error,
    isHost,
    opponentId,
    connectionDelay,
    connect,
    createRoom,
    joinRoom,
    sendMove,
    disconnect,
    reconnect,
    checkConnection,
  };
};

export default useNetworkGame; 