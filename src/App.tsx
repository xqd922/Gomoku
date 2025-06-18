import { useState, useEffect } from "react";
import "./App.css";
import Board from "./components/Board";
import Controls from "./components/Controls";
import GameStatus from "./components/GameStatus";
import useGame from "./hooks/useGame";

function App() {
  const BOARD_SIZE = 15;
  const { 
    gameState, 
    placeStone, 
    resetGame, 
    undoMove,
    createNetworkGame,
    joinNetworkGame,
    exitNetworkGame,
    connectToServer,
    disconnectFromServer
  } = useGame(BOARD_SIZE);
  const [title] = useState("五子棋");
  const [debug, setDebug] = useState(false);

  // 添加键盘快捷键来切换调试模式
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      // Ctrl+Shift+D 切换调试模式
      if (e.ctrlKey && e.shiftKey && e.key === 'D') {
        setDebug(prev => !prev);
        console.log('调试模式:', !debug);
      }
    };

    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [debug]);

  // 调试状态显示
  const renderDebugInfo = () => {
    if (!debug) return null;

    return (
      <div className="debug-panel">
        <h3>调试信息</h3>
        <pre>
          {JSON.stringify({
            gameMode: gameState.gameMode,
            status: gameState.status,
            networkStatus: gameState.networkStatus,
            roomCode: gameState.roomCode,
            error: gameState.networkError,
            isMyTurn: gameState.isMyTurn,
            isWaiting: gameState.isWaitingForOpponent,
            currentPlayer: gameState.currentPlayer,
            isHost: gameState.isHost,
            playerName: gameState.playerName
          }, null, 2)}
        </pre>
      </div>
    );
  };

  return (
    <main className="container">
      <h1>{title} {debug && <span className="debug-badge">调试模式</span>}</h1>
      
      <div className="game-container">
        <GameStatus gameState={gameState} />
        
        <div className="board-container">
          <Board 
            board={gameState.board} 
            onCellClick={placeStone}
            lastPlaced={gameState.history.length > 0 ? gameState.history[gameState.history.length - 1] : null}
            disabled={
              gameState.status !== 'playing' || 
              (gameState.gameMode === 'network' && !gameState.isMyTurn) ||
              (gameState.gameMode === 'network' && gameState.isWaitingForOpponent)
            }
          />
        </div>
        
        <Controls 
          onReset={resetGame}
          onUndo={undoMove}
          canUndo={gameState.history.length > 0}
          gameStatus={gameState.status}
          gameMode={gameState.gameMode}
          onCreateRoom={createNetworkGame}
          onJoinRoom={joinNetworkGame}
          onExitNetworkGame={exitNetworkGame}
          onConnect={connectToServer}
          onDisconnect={disconnectFromServer}
          networkStatus={gameState.networkStatus}
          roomCode={gameState.roomCode}
          networkError={gameState.networkError}
          isHost={gameState.isHost}
          playerName={gameState.playerName}
        />

        {renderDebugInfo()}
      </div>

      <div className="game-info">
        <h3>游戏规则</h3>
        <ul>
          <li>黑方先行，双方轮流落子</li>
          <li>先在横、竖或斜方向形成连续五子的一方获胜</li>
          <li>棋盘大小: {BOARD_SIZE}×{BOARD_SIZE}</li>
          {gameState.gameMode === 'network' && (
            <>
              <li><strong>网络对战模式:</strong> {gameState.isMyTurn ? '轮到你落子' : '等待对手落子'}</li>
              {gameState.isWaitingForOpponent && <li className="waiting">等待对手加入...</li>}
            </>
          )}
        </ul>
      </div>

      <div className="debug-hint">
        按 Ctrl+Shift+D 切换调试模式
      </div>
    </main>
  );
}

export default App;
