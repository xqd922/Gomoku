export type StoneType = 'black' | 'white' | null;

export type BoardState = StoneType[][];

export interface Position {
  row: number;
  col: number;
}

export type GameStatus = 'playing' | 'black-win' | 'white-win' | 'draw';

export interface GameState {
  board: BoardState;
  currentPlayer: 'black' | 'white';
  status: GameStatus;
  winner: StoneType;
  history: Position[];
} 