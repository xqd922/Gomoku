# Gomoku server

Serverpod 3.4.13 authoritative rooms, email authentication, stable guest
identities, immutable records and incremental synchronization.

Start PostgreSQL, Redis and Mailpit with the development script in the
[root README](../../README.md). To run the server separately, execute
`dart bin/main.dart --apply-migrations` in this directory after bootstrapping
the root configuration and resolving workspace dependencies.

Framework migrations live in `migrations`; checksummed business migrations
live in `db`. All room decisions and outbound events commit in one database
transaction. Redis distributes persisted snapshots across instances.

`dart test test/system` uses two actual server processes and the dedicated
`gomoku_test` database. See [architecture](../../docs/ARCHITECTURE.md) and
[deployment](../../docs/DEPLOYMENT.md) for protocol and operations details.
