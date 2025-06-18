import { useState } from 'react';
import { Position } from '../types/game';

// 网络游戏相关状态类型
export type NetworkGameStatus = 'disconnected' | 'connecting' | 'connected' | 'waiting' | 'playing';

interface UseNetworkGameProps {
  onReceiveMove: (position: Position) => void;
  onGameStart: () => void;
  onOpponentDisconnect: () => void;
  onReconnect: () => void;
}

/**
 * 此钩子已被弃用，仅保留为了兼容性。
 * 请使用useCloudflareConnection代替。
 */
const useNetworkGame = (props: UseNetworkGameProps) => {
  const [status] = useState<NetworkGameStatus>('disconnected');
  const [error] = useState<string | null>('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');

  // 返回最小化的接口，所有方法返回false并提示错误
  return {
    status,
    error,
    playerId: null,
    roomId: null,
    isHost: false,
    opponentId: null,
    serverAddress: '',
    connect: async () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
      return false;
    },
    createRoom: async () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
      return false;
    },
    joinRoom: async () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
      return false;
    },
    sendMove: () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
      return false;
    },
    disconnect: () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
    },
    reconnect: async () => {
      console.error('本地WebSocket服务器已禁用，请使用Cloudflare Worker中继服务器');
      return false;
    },
    checkConnection: () => false
  };
};

export default useNetworkGame; 