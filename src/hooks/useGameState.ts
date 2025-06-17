import { useState, useCallback, useEffect } from 'react';
import { BoardState, GameState, Position, StoneType } from '../types/game';
import { checkDraw, checkWin, createEmptyBoard } from '../utils/gameLogic';
import { invoke } from '@tauri-apps/api/core';

const useGameState = (boardSize: number = 15) => {
  const [gameState, setGameState] = useState<GameState>({
    board: createEmptyBoard(boardSize),
    currentPlayer: 'black',
    status: 'playing',
    winner: null,
    history: [],
  });

  // 检查是否使用Tauri环境
  const [isTauri, setIsTauri] = useState(false);

  useEffect(() => {
    // 检测是否在Tauri环境中运行
    const checkTauri = async () => {
      try {
        // 尝试调用Tauri的API
        await invoke('greet', { name: 'Gomoku' });
        setIsTauri(true);
      } catch (e) {
        console.log('Not running in Tauri environment, using client-side logic');
        setIsTauri(false);
      }
    };
    
    checkTauri();
  }, []);

  // 重置游戏
  const resetGame = useCallback(() => {
    setGameState({
      board: createEmptyBoard(boardSize),
      currentPlayer: 'black',
      status: 'playing',
      winner: null,
      history: [],
    });
  }, [boardSize]);

  // 放置棋子
  const placeStone = useCallback(async (position: Position) => {
    const { row, col } = position;
    
    setGameState(prev => {
      // 如果游戏已结束或该位置已有棋子，不执行任何操作
      if (prev.status !== 'playing' || prev.board[row][col] !== null) {
        return prev;
      }

      // 创建新的棋盘状态
      const newBoard: BoardState = prev.board.map(r => [...r]);
      const currentStone = prev.currentPlayer;
      newBoard[row][col] = currentStone;

      // 检查胜负
      const checkGameStatus = async () => {
        let hasWon = false;
        let isDraw = false;

        if (isTauri) {
          try {
            // 将棋盘状态转换为后端期望的格式
            const boardForBackend = newBoard.map(row => 
              row.map(cell => 
                cell === 'black' ? { Black: {} } : 
                cell === 'white' ? { White: {} } : 
                null
              )
            );

            // 调用Rust后端来检查胜负
            hasWon = await invoke('check_win', { 
              board: boardForBackend, 
              row, 
              col, 
              stone: currentStone === 'black' ? { Black: {} } : { White: {} } 
            }) as boolean;

            // 如果没有赢，检查是否平局
            if (!hasWon) {
              isDraw = await invoke('check_draw', { board: boardForBackend }) as boolean;
            }
          } catch (e) {
            console.error('Error calling Rust backend:', e);
            // 降级到前端逻辑
            hasWon = checkWin(newBoard, position, currentStone);
            isDraw = !hasWon && checkDraw(newBoard);
          }
        } else {
          // 使用前端逻辑
          hasWon = checkWin(newBoard, position, currentStone);
          isDraw = !hasWon && checkDraw(newBoard);
        }

        // 更新游戏状态
        const newStatus = hasWon 
          ? (currentStone === 'black' ? 'black-win' : 'white-win')
          : isDraw 
            ? 'draw' 
            : 'playing';

        setGameState(current => ({
          ...current,
          status: newStatus,
          winner: hasWon ? currentStone : null,
        }));
      };

      // 异步检查游戏状态
      checkGameStatus();

      // 记录历史
      const newHistory = [...prev.history, position];

      return {
        board: newBoard,
        currentPlayer: currentStone === 'black' ? 'white' : 'black',
        status: 'playing', // 临时状态，异步结果会更新
        winner: null,      // 临时状态，异步结果会更新
        history: newHistory,
      };
    });
  }, [isTauri, boardSize]);

  // 悔棋
  const undoMove = useCallback(() => {
    setGameState(prev => {
      // 如果没有历史记录，不执行任何操作
      if (prev.history.length === 0) {
        return prev;
      }

      // 复制历史记录，并移除最后一步
      const newHistory = [...prev.history];
      newHistory.pop();

      // 创建新的棋盘状态
      const newBoard = createEmptyBoard(boardSize);
      
      // 根据历史记录重建棋盘
      let player: StoneType = 'black';
      newHistory.forEach(({ row, col }) => {
        newBoard[row][col] = player;
        player = player === 'black' ? 'white' : 'black';
      });

      return {
        board: newBoard,
        currentPlayer: prev.currentPlayer === 'black' ? 'white' : 'black',
        status: 'playing',
        winner: null,
        history: newHistory,
      };
    });
  }, [boardSize]);

  return {
    gameState,
    placeStone,
    resetGame,
    undoMove,
  };
};

export default useGameState; 