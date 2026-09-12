param([switch]$WithBackend)
$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $taskRoot
& flutter pub get --enforce-lockfile
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& dart tool/check_server_lock.dart
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& dart format --output=none --set-exit-if-changed apps/gomoku_app/lib apps/gomoku_app/test apps/server/bin apps/server/lib/server.dart apps/server/lib/src/auth apps/server/lib/src/endpoints apps/server/lib/src/services apps/server/lib/src/web apps/server/test/system packages/gomoku_core tool
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
& dart analyze --fatal-infos
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Push-Location packages/gomoku_core
try { & dart test } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Push-Location apps/gomoku_app
try { & flutter test --no-pub } finally { Pop-Location }
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
if ($WithBackend) {
  Push-Location apps/server
  try { & dart test test/system --reporter expanded } finally { Pop-Location }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
