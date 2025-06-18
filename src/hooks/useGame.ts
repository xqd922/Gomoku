import { useState, useCallback, useEffect } from 'react';
import useGameState from './useGameState';
import useNetworkGame from './useNetworkGame';
import { Position } from '../types/game';

// 游戏模式
export type GameMode = 'local' | 'network';

const useGame = (boardSize: number = 15) => {
  const [gameMode, setGameMode] = useState<GameMode>('local');
  const [isMyTurn, setIsMyTurn] = useState<boolean>(true);
  const [isWaitingForOpponent, setIsWaitingForOpponent] = useState<boolean>(false);
  const [roomCode, setRoomCode] = useState<string>('');
  const [networkError, setNetworkError] = useState<string | null>(null);
  const [isHost, setIsHost] = useState<boolean>(false);
  
  // 本地游戏状态管理
  const {
    gameState,
    placeStone,
    resetGame,
    undoMove
  } = useGameState(boardSize);
  
  // 处理对手落子
  const handleOpponentMove = useCallback((position: Position) => {
    placeStone(position);
    setIsMyTurn(true);
  }, [placeStone]);
  
  // 处理游戏开始
  const handleGameStart = useCallback(() => {
    resetGame();
    setIsWaitingForOpponent(false);
    // 作为房主(黑子)先行
    setIsMyTurn(isHost);
  }, [resetGame, isHost]);
  
  // 处理对手断开连接
  const handleOpponentDisconnect = useCallback(() => {
    setIsWaitingForOpponent(true);
    setNetworkError('对手已断开连接');
  }, []);
  
  // 处理重新连接
  const handleReconnect = useCallback(() => {
    setNetworkError(null);
  }, []);
  
  // 网络游戏状态管理
  const networkGame = useNetworkGame({
    onReceiveMove: handleOpponentMove,
    onGameStart: handleGameStart,
    onOpponentDisconnect: handleOpponentDisconnect,
    onReconnect: handleReconnect
  });

  // 同步网络游戏的主机状态
  useEffect(() => {
    setIsHost(networkGame.isHost);
  }, [networkGame.isHost]);
  
  // 处理落子
  const handlePlaceStone = useCallback((position: Position) => {
    if (gameMode === 'local') {
      // 本地模式直接落子
      placeStone(position);
    } else if (gameMode === 'network' && isMyTurn && !isWaitingForOpponent) {
      // 网络模式，如果是我的回合，发送落子消息
      const success = networkGame.sendMove(position);
      if (success) {
        // 本地也执行落子
        placeStone(position);
        setIsMyTurn(false);
      }
    }
  }, [gameMode, isMyTurn, isWaitingForOpponent, networkGame, placeStone]);
  
  // 连接服务器 - 只连接不创建房间
  const connectToServer = useCallback(async () => {
    setNetworkError(null);
    console.log("正在连接到服务器...");
    
    try {
      const connected = await networkGame.connect();
      console.log("连接结果:", connected);
      
      if (!connected) {
        console.error("连接服务器失败");
        setNetworkError('无法连接到服务器，请确保服务器已启动');
        return false;
      }
      
      return true;
    } catch (err) {
      console.error("连接服务器出错:", err);
      setNetworkError(`连接出错: ${err instanceof Error ? err.message : String(err)}`);
      return false;
    }
  }, [networkGame]);
  
  // 断开连接
  const disconnectFromServer = useCallback(() => {
    console.log("断开与服务器的连接");
    networkGame.disconnect();
    
    if (gameMode === 'network') {
      setGameMode('local');
      setIsWaitingForOpponent(false);
      setIsMyTurn(true);
      resetGame();
    }
  }, [networkGame, gameMode, resetGame]);
  
  // 创建房间
  const createNetworkGame = useCallback(async () => {
    setNetworkError(null);
    console.log("创建网络游戏开始");
    
    try {
      // 如果未连接，先连接到服务器
      if (networkGame.status === 'disconnected') {
        console.log("尝试连接到服务器...");
        const connected = await networkGame.connect();
        console.log("连接结果:", connected);
        
        if (!connected) {
          console.error("连接服务器失败");
          setNetworkError('无法连接到服务器，请确保服务器已启动');
          return false;
        }
      }
      
      if (networkGame.status !== 'connected') {
        console.error("服务器状态不是connected，当前状态:", networkGame.status);
        setNetworkError(`服务器状态异常: ${networkGame.status}`);
        return false;
      }
      
      console.log("调用创建房间...");
      // 创建房间
      const roomCreated = await networkGame.createRoom();
      if (!roomCreated) {
        console.error("创建房间失败");
        return false;
      }
      
      setGameMode('network');
      setIsWaitingForOpponent(true);
      resetGame();
      
      return true;
    } catch (err) {
      console.error("创建网络游戏出错:", err);
      setNetworkError(`创建游戏出错: ${err instanceof Error ? err.message : String(err)}`);
      return false;
    }
  }, [networkGame, resetGame]);
  
  // 加入房间
  const joinNetworkGame = useCallback(async (roomId: string) => {
    setNetworkError(null);
    console.log("加入房间开始:", roomId);
    
    try {
      // 如果未连接，先连接到服务器
      if (networkGame.status === 'disconnected') {
        console.log("尝试连接到服务器...");
        const connected = await networkGame.connect();
        
        if (!connected) {
          console.error("连接服务器失败");
          setNetworkError('无法连接到服务器，请确保服务器已启动');
          return false;
        }
      }
      
      if (networkGame.status !== 'connected') {
        console.error("服务器状态不是connected，当前状态:", networkGame.status);
        setNetworkError(`服务器状态异常: ${networkGame.status}`);
        return false;
      }
      
      console.log("调用加入房间...");
      // 加入房间
      const roomJoined = await networkGame.joinRoom(roomId);
      if (!roomJoined) {
        console.error("加入房间失败");
        return false;
      }
      
      setGameMode('network');
      setIsWaitingForOpponent(false);
      resetGame();
      
      return true;
    } catch (err) {
      console.error("加入网络游戏出错:", err);
      setNetworkError(`加入游戏出错: ${err instanceof Error ? err.message : String(err)}`);
      return false;
    }
  }, [networkGame, resetGame]);
  
  // 退出网络游戏
  const exitNetworkGame = useCallback(() => {
    networkGame.disconnect();
    setGameMode('local');
    setIsWaitingForOpponent(false);
    setIsMyTurn(true);
    resetGame();
  }, [networkGame, resetGame]);
  
  // 根据房间ID更新可共享的房间代码
  useEffect(() => {
    if (networkGame.roomId) {
      setRoomCode(networkGame.roomId);
    }
  }, [networkGame.roomId]);
  
  // 同步网络错误
  useEffect(() => {
    if (networkGame.error) {
      setNetworkError(networkGame.error);
    }
  }, [networkGame.error]);
  
  // 显示到界面的网络状态
  const getNetworkStatus = useCallback((): string => {
    switch (networkGame.status) {
      case 'disconnected':
        return '未连接';
      case 'connecting':
        return '正在连接...';
      case 'connected':
        return '已连接';
      case 'waiting':
        return `等待对手加入 (房间码: ${roomCode})`;
      case 'playing':
        return '对战中';
      default:
        return '';
    }
  }, [networkGame.status, roomCode]);
  
  // 附加游戏状态信息
  const enhancedGameState = {
    ...gameState,
    gameMode,
    isMyTurn,
    isWaitingForOpponent,
    networkStatus: getNetworkStatus(),
    roomCode,
    networkError: networkError || networkGame.error,
    isNetworkConnected: networkGame.status !== 'disconnected' && networkGame.status !== 'connecting',
    isNetworkGameActive: networkGame.status === 'playing',
    isHost,
    playerName: networkGame.playerId,
  };

  return {
    gameState: enhancedGameState,
    placeStone: handlePlaceStone,
    resetGame,
    undoMove: gameMode === 'local' ? undoMove : undefined, // 网络模式暂不支持悔棋
    createNetworkGame,
    joinNetworkGame,
    exitNetworkGame,
    connectToServer,       // 新增：仅连接到服务器
    disconnectFromServer,  // 新增：断开服务器连接
  };
};

export default useGame; 