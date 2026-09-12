# Implementation contract

This repository implements the accepted six-platform Gomoku plan.

## Non-negotiable behavior

- Free-style 15×15, black first, five or more wins; no AI or matchmaking.
- One pure Dart rules authority shared by Flutter and the server.
- Only persisted server decisions advance online games.
- Commands have unique IDs and expected revisions; retries are idempotent.
- PostgreSQL owns room state, records, identities, sessions and the outbox.
- Redis delivers notifications, never the only copy of game state.
- Disconnect grace is 120 seconds; idle waiting rooms expire after 30 minutes.
- Guest claims prove both identities and merge records atomically.
- Native secrets live in OS secure storage; web sessions use HttpOnly cookies.
- Local games work without a backend; cloud failures retain queued records.

## Workstreams

1. Rules and deterministic record validation.
2. Typed Serverpod protocol, persistent rooms, accounts, sync and recovery.
3. Responsive Material 3 Expressive Flutter application and Drift persistence.
4. Real-service integration tests, browser verification and platform builds.
5. Reproducible development/deployment tooling and CI.

Validation results and operational commands are documented in the README and
docs/VALIDATION.md when the corresponding checks have actually run.
