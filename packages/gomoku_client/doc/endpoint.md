# Callable endpoints

`client.room` creates and joins rooms, submits revisioned commands,
refreshes snapshots, sends heartbeats and opens a snapshot stream.
`client.profile` reads or changes a profile and exchanges record sync pages.

Set `authKeyProvider` before making protected calls. Native apps use a
Serverpod session bearer credential. Web uses the same-origin HttpOnly
cookie adapter implemented by this application's API layer.

Protocol definitions are generated from `apps/server/lib/src/models` and
`apps/server/lib/src/endpoints`. See the [architecture guide](../../../docs/ARCHITECTURE.md).
