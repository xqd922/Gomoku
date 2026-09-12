# Gomoku rules

Pure Dart immutable game state and record validation, shared by the server
and all Flutter platforms. No UI, networking or storage dependency.

Rules: 15 by 15, black first, five or more consecutive stones in any of four
directions wins, no forbidden moves, full board without a winner is a draw.
The package also defines undo, replay, resignation and interruption results.

Run `dart test` in this directory after workspace dependency resolution.
See [architecture](../../docs/ARCHITECTURE.md) for import validation and
the online authority boundary.
