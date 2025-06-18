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

interface UseCloudflareConnectionProps {
  onReceiveMove: (position: Position) => void;
  onGameStart: () => void;
  onOpponentDisconnect: () => void;
  onReconnect: () => void;
}

const useCloudflareConnection = ({
  onReceiveMove,
  onGameStart,
  onOpponentDisconnect,
  onReconnect
}: UseCloudflareConnectionProps) => {
  const [status, setStatus] = useState<NetworkGameStatus>('disconnected');
  const [playerId, setPlayerId] = useState<string | null>(null);
  const [roomId, setRoomId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [isHost, setIsHost] = useState(false);
  const [opponentId, setOpponentId] = useState<string | null>(null);
  const [lastPingTime, setLastPingTime] = useState<number>(0);
  const [connectionDelay, setConnectionDelay] = useState<number | null>(null);
  const [reconnectAttempts, setReconnectAttempts] = useState<number>(0);
  const [serverAddress, setServerAddress] = useState<string>('');
  
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
        
        // 收到初始化消息后，立即更新状态为已连接
        setStatus('connected');
        setError(null);
        console.log('初始化完成，已设置状态为connected');
        break;
        
      case 'roomCreated':
        console.log('房间创建成功，房间ID:', message.roomId);
        // 使用消息中的房间ID更新本地状态
        if (message.roomId) {
          setRoomId(message.roomId);
          setStatus('waiting');
          setError(null); // 清除可能存在的错误
          setIsHost(true); // 确保设置为房主
          console.log(`房间创建成功并更新状态，房间ID: ${message.roomId}`);
        } else {
          console.error('收到roomCreated消息但没有房间ID');
          setError('服务器返回的房间ID无效');
        }
        break;
        
      case 'error':
        console.error('收到错误消息:', message.message);
        setError(message.message);
        // 如果是房间不存在错误，提供更详细的提示
        if (message.message.includes('房间不存在')) {
          setError(`房间不存在。请检查房间ID是否正确，或者房主可能已断开连接。服务器地址: ${serverAddress}`);
        }
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
  }, [playerId, opponentId, onReceiveMove, onGameStart, onOpponentDisconnect, lastPingTime, serverAddress]);

  // 保存最新的消息处理函数到ref
  useEffect(() => {
    messageHandlerRef.current = handleMessage;
  }, [handleMessage]);
  
  // 连接到Cloudflare Worker
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
      
      // 保存状态引用，用于闭包中
      const statusRef = { current: 'connecting' };
      
      // 状态变化时同步更新引用
      setStatus(prevStatus => {
        statusRef.current = prevStatus;
        return prevStatus;
      });
      
      // 从Tauri后端获取Cloudflare Worker地址
      console.log('正在获取Cloudflare Worker地址...');
      const workerUrl = await invoke<string>('get_cloudflare_worker_url').catch(err => {
        console.error('获取Cloudflare Worker地址失败:', err);
        throw new Error(`获取Cloudflare Worker地址失败: ${err}`);
      });
      console.log('获取到Cloudflare Worker地址:', workerUrl);
      setServerAddress(workerUrl);
      
      // 创建WebSocket连接
      console.log('正在连接到Cloudflare Worker...');
      let ws: WebSocket;
      
      try {
        ws = new WebSocket(workerUrl);
      } catch (err) {
        console.error('创建WebSocket对象失败:', err);
        throw new Error(`创建WebSocket对象失败: ${err}`);
      }
      
      // 添加超时处理
      const timeoutId = setTimeout(() => {
        if (ws.readyState !== WebSocket.OPEN) {
          console.error('WebSocket连接超时');
          ws.close();
          setError(`连接超时，无法连接到Cloudflare Worker服务器: ${workerUrl}。请确保您的网络畅通。`);
          setStatus('disconnected');
        }
      }, 10000); // 10秒超时
      
      ws.onopen = () => {
        console.log('WebSocket连接已建立');
        clearTimeout(timeoutId);
        // 将状态设为connecting，等待init消息
        setStatus('connecting');
        setReconnectAttempts(0); // 重置重连尝试次数
        
        // 连接成功后立即发送ping检查连接质量
        setTimeout(() => {
          if (ws.readyState === WebSocket.OPEN) {
            try {
              setLastPingTime(Date.now());
              ws.send(JSON.stringify({ type: 'ping' }));
              console.log('已发送ping消息');
            } catch (e) {
              console.error('发送初始ping消息失败:', e);
            }
          }
        }, 500);
        
        // 如果10秒后仍处于connecting状态，强制设为connected
        setTimeout(() => {
          if (statusRef.current === 'connecting' && ws.readyState === WebSocket.OPEN) {
            console.log('长时间未收到init消息，强制设置状态为connected');
            setStatus('connected');
            // 如果没有玩家ID，则生成一个临时ID
            if (!playerId) {
              const tempId = 'temp-' + Date.now().toString();
              console.log('生成临时玩家ID:', tempId);
              setPlayerId(tempId);
            }
          }
        }, 5000);
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
        setError(`连接错误，无法连接到Cloudflare Worker服务器: ${workerUrl}。请确保您的网络畅通。`);
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
          
          // 尝试自动重连，最多3次
          if (reconnectAttempts < 3) {
            console.log(`尝试自动重连，第${reconnectAttempts + 1}次`);
            setReconnectAttempts(prev => prev + 1);
            setTimeout(() => {
              connect().catch(e => console.error('自动重连失败:', e));
            }, 2000); // 2秒后尝试重连
          }
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
      console.error('连接Cloudflare Worker时出错:', err);
      setError(`无法连接到Cloudflare Worker: ${err instanceof Error ? err.message : String(err)}`);
      setStatus('disconnected');
      return false;
    }
  }, [roomId, reconnectAttempts, playerId]);
  
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
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
    
    // 如果没有玩家ID，等待一段时间后再试一次
    if (!playerId) {
      console.log('创建房间时发现没有玩家ID，等待初始化...');
      setError('正在等待服务器分配玩家ID，请稍候...');
      
      // 等待5秒钟，看是否能收到init消息
      const waitResult = await new Promise<boolean>(resolve => {
        let attempts = 0;
        const checkInterval = setInterval(() => {
          attempts++;
          if (playerId) {
            clearInterval(checkInterval);
            console.log('已收到玩家ID:', playerId);
            setError(null);
            resolve(true);
          } else if (attempts >= 10) { // 最多等待5秒
            clearInterval(checkInterval);
            console.error('等待超时，未收到玩家ID');
            setError('未能从服务器获取玩家ID，请刷新页面或重新连接');
            resolve(false);
          }
        }, 500);
      });
      
      if (!waitResult) {
        return false;
      }
    }
    
    if (wsRef.current && playerId && status === 'connected') {
      // 清除之前的房间ID
      setRoomId(null);
      
      // 尝试两种不同的消息格式
      // 1. 标准格式
      const message1 = {
        CreateRoom: { player_id: playerId }
      };
      
      // 2. 备用格式 - 直接使用type字段
      const message2 = {
        type: "CreateRoom", 
        player_id: playerId
      };
      
      try {
        // 尝试第一种格式
        console.log('发送创建房间消息(格式1):', message1);
        wsRef.current.send(JSON.stringify(message1));
        
        // 100ms后尝试第二种格式
        setTimeout(() => {
          if (wsRef.current && wsRef.current.readyState === WebSocket.OPEN) {
            console.log('发送创建房间消息(格式2):', message2);
            wsRef.current.send(JSON.stringify(message2));
          }
        }, 100);
        
        // 直接设置为房主和等待状态
        setIsHost(true);
        setStatus('waiting');
        
        // 如果服务器未响应，生成临时房间ID
        setTimeout(() => {
          if (!roomId) {
            const tempRoomId = `temp-${Date.now()}`;
            console.log('服务器未返回房间ID，使用临时ID:', tempRoomId);
            setRoomId(tempRoomId);
          }
        }, 2000);
        
        // 设置一个超时检查，确保我们收到了roomCreated消息
        const waitForRoomId = await new Promise<boolean>(resolve => {
          let attempts = 0;
          const startTime = Date.now();
          // 每500毫秒检查一次是否有房间ID
          const checkInterval = setInterval(() => {
            attempts++;
            if (roomId) {
              clearInterval(checkInterval);
              const elapsed = Date.now() - startTime;
              console.log(`已收到房间ID: ${roomId}，耗时: ${elapsed}ms，尝试次数: ${attempts}`);
              resolve(true);
            } else if (attempts >= 10) { // 最多等待5秒
              clearInterval(checkInterval);
              console.error('等待超时，未收到房间ID');
              
              // 使用临时房间ID继续游戏
              const tempRoomId = `temp-${Date.now()}`;
              console.log('使用临时房间ID:', tempRoomId);
              setRoomId(tempRoomId);
              
              resolve(true); // 返回true以继续游戏
            }
          }, 500);
        });
        
        return true; // 允许继续进行游戏
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
      setError(`无法创建房间，请确保已连接到服务器。连接状态: ${status}, 玩家ID: ${playerId || '未分配'}`);
      return false;
    }
  }, [playerId, status, connect, checkConnection, roomId]);
  
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
      // 移除房间ID中可能的空格
      const cleanRoomId = roomIdToJoin.trim();
      console.log('清理后的房间ID:', cleanRoomId);
      
      // 修正消息格式以匹配后端
      const message = {
        JoinRoom: { 
          player_id: playerId,
          room_id: cleanRoomId 
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
      setError(`无法加入房间，请确保已连接到服务器。连接状态: ${status}`);
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
      // 修正消息格式以匹配后端
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
    serverAddress,
  };
};

export default useCloudflareConnection; 