import { useState } from "react";
import "./App.css";
import Board from "./components/Board";
import Controls from "./components/Controls";
import GameStatus from "./components/GameStatus";
import useGameState from "./hooks/useGameState";

function App() {
  const BOARD_SIZE = 15;
  const { gameState, placeStone, resetGame, undoMove } = useGameState(BOARD_SIZE);
  const [title] = useState("五子棋");

  return (
    <main className="container">
      <h1>{title}</h1>
      
      <div className="game-container">
        <GameStatus gameState={gameState} />
        
        <div className="board-container">
          <Board 
            board={gameState.board} 
            onCellClick={placeStone}
            lastPlaced={gameState.history.length > 0 ? gameState.history[gameState.history.length - 1] : null}
            disabled={gameState.status !== 'playing'}
          />
        </div>
        
        <Controls 
          onReset={resetGame}
          onUndo={undoMove}
          canUndo={gameState.history.length > 0}
          gameStatus={gameState.status}
        />
      </div>

      <div className="game-info">
        <h3>游戏规则</h3>
        <ul>
          <li>黑方先行，双方轮流落子</li>
          <li>先在横、竖或斜方向形成连续五子的一方获胜</li>
          <li>棋盘大小: {BOARD_SIZE}×{BOARD_SIZE}</li>
        </ul>
      </div>
    </main>
  );
}

export default App;
