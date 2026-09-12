# Gomoku Flutter

Six-platform Material 3 Gomoku client. Uses Riverpod, go_router, Drift and
the shared `gomoku_core` rules package. Local games work without a server;
friend rooms and email accounts use the typed Serverpod client.

Resolve dependencies from the workspace root, then run `flutter run` here.
Web requires the same-origin development gateway for cookies, WebSockets
and database isolation headers.

See the [root README](../../README.md) for startup and platform builds,
[architecture](../../docs/ARCHITECTURE.md) for module boundaries, and
[validation results](../../docs/VALIDATION.md) for checks actually performed.
