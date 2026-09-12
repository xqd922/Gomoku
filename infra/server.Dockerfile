FROM dart:3.13.1-sdk AS dependencies
WORKDIR /workspace
ARG LOCKFILE=infra/server.pubspec.lock
ARG ENFORCE_LOCKFILE=true
COPY ${LOCKFILE} ./pubspec.lock
COPY infra/server-workspace.yaml ./pubspec.yaml
COPY packages/gomoku_core packages/gomoku_core
COPY packages/gomoku_client packages/gomoku_client
COPY apps/server apps/server
# Regeneration may seed this workspace with the reviewed root lockfile.
RUN if [ "$ENFORCE_LOCKFILE" = "true" ]; then dart pub get --enforce-lockfile; else dart pub get; fi

FROM dependencies AS build
WORKDIR /workspace/apps/server
RUN mkdir -p /app && dart compile exe bin/main.dart -o /app/gomoku-server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl libssl3 \
    && rm -rf /var/lib/apt/lists/* && useradd --uid 10001 --create-home gomoku
WORKDIR /app
COPY --from=build /app/gomoku-server ./gomoku-server
COPY apps/server/config/production.yaml ./config/production.yaml
COPY apps/server/migrations ./migrations
COPY apps/server/db ./db
USER gomoku
EXPOSE 8080 8082
HEALTHCHECK --interval=10s --start-period=45s --timeout=5s CMD curl -fsS http://127.0.0.1:8082/health || exit 1
ENTRYPOINT ["./gomoku-server", "--mode", "production", "--apply-migrations"]
