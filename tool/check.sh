#!/usr/bin/env bash
set -euo pipefail
export PUB_HOSTED_URL=https://pub.dev
cd "$(dirname "$0")/.."
flutter pub get --enforce-lockfile
dart tool/check_server_lock.dart
dart format --output=none --set-exit-if-changed apps/gomoku_app/lib apps/gomoku_app/test apps/server/bin apps/server/lib/server.dart apps/server/lib/src/auth apps/server/lib/src/endpoints apps/server/lib/src/services apps/server/lib/src/web apps/server/test/system packages/gomoku_core tool
dart analyze --fatal-infos
(cd packages/gomoku_core && dart test)
(cd apps/gomoku_app && flutter test --no-pub)
if [[ "${1:-}" == "--with-backend" ]]; then
  (cd apps/server && dart test test/system --reporter expanded)
fi
