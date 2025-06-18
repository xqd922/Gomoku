import { useState, useCallback } from 'react';
import { StoneType } from '../types/game';
import { checkWin } from '../utils/gameLogic';

export const useGame = (boardSize: number = 15) => {
  const [board, setBoard] = useState<(StoneType | null)[][]>(
    Array(boardSize).fill(null).map(() => Array(boardSize).fill(null))
  );
  const [currentPlayer, setCurrentPlayer] = useState<StoneType>('black');
  const [lastPlaced, setLastPlaced] = useState<{ row: number; col: number } | null>(null);
  const [winner, setWinner] = useState<StoneType | null>(null);

  const handleCellClick = useCallback(({ row, col }: { row: number; col: number }) => {
    if (board[row][col] !== null || winner) return;

    const newBoard = board.map(r => [...r]);
    newBoard[row][col] = currentPlayer;
    setBoard(newBoard);
    setLastPlaced({ row, col });

    // 检查是否有赢家
    if (checkWin(newBoard, { row, col }, currentPlayer)) {
      setWinner(currentPlayer);
    } else {
      setCurrentPlayer(currentPlayer === 'black' ? 'white' : 'black');
    }
  }, [board, currentPlayer, winner]);

  const resetGame = useCallback(() => {
    setBoard(Array(boardSize).fill(null).map(() => Array(boardSize).fill(null)));
    setCurrentPlayer('black');
    setLastPlaced(null);
    setWinner(null);
  }, [boardSize]);

  return {
    board,
    currentPlayer,
    lastPlaced,
    winner,
    handleCellClick,
    resetGame,
  };
}; 