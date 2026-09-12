#!/usr/bin/env bash
set -euo pipefail
export PUB_HOSTED_URL=https://pub.dev
cd "$(dirname "$0")/.."
mkdir -p .local
dart tool/bootstrap.dart
docker compose up -d --wait
flutter pub get --enforce-lockfile
if [[ "${1:-}" != "--skip-web-build" ]]; then
  (cd apps/gomoku_app && flutter build web --release --no-web-resources-cdn --no-pub)
fi
dart tool/prepare_web.dart
(cd apps/server && exec dart bin/main.dart --apply-migrations --server-id gomoku-dev) >.local/server.log 2>&1 &
task_server_pid=$!
dart tool/dev_gateway.dart >.local/gateway.log 2>&1 &
task_gateway_pid=$!
trap 'kill "$task_server_pid" "$task_gateway_pid" 2>/dev/null || true' EXIT INT TERM
echo 'Gomoku: http://localhost:4280'
echo 'Development email: http://localhost:8025'
echo 'Logs: .local/   Press Ctrl+C to stop.'
while kill -0 "$task_server_pid" 2>/dev/null && kill -0 "$task_gateway_pid" 2>/dev/null; do sleep 1; done
