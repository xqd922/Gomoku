param(
  [ValidatePattern('^[A-Za-z0-9._-]+$')][string]$WslDistribution = 'Ubuntu-22.04',
  [switch]$SkipWebBuild,
  [switch]$CheckStartup
)
$ErrorActionPreference = 'Stop'
$env:PUB_HOSTED_URL = 'https://pub.dev'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $taskRoot
$taskProcesses = [System.Collections.Generic.List[System.Diagnostics.Process]]::new()
$taskDartCommand = (Get-Command dart).Source
$taskDart = if ($taskDartCommand.EndsWith('.bat')) {
  Join-Path (Split-Path $taskDartCommand) 'cache/dart-sdk/bin/dart.exe'
} else { $taskDartCommand }
New-Item -ItemType Directory -Force -Path (Join-Path $taskRoot '.local') | Out-Null
function Start-GomokuProcess([string]$Name, [string[]]$Arguments, [string]$WorkingDirectory) {
  $taskStart = @{
    FilePath = $taskDart
    ArgumentList = $Arguments
    WorkingDirectory = $WorkingDirectory
    WindowStyle = 'Hidden'
    PassThru = $true
    RedirectStandardOutput = (Join-Path $taskRoot ".local/$Name.log")
    RedirectStandardError = (Join-Path $taskRoot ".local/$Name.error.log")
  }
  $taskChild = Start-Process @taskStart
  $taskProcesses.Add($taskChild)
  return $taskChild
}
try {
  & $taskDart tool/bootstrap.dart
  if ($LASTEXITCODE -ne 0) { throw 'Configuration failed.' }
  $taskNativeDocker = Get-Command docker -ErrorAction SilentlyContinue
  if ($taskNativeDocker) {
    & docker info --format '{{.ServerVersion}}' 2>$null | Out-Null
    $taskNativeDocker = $LASTEXITCODE -eq 0
  }
  if ($taskNativeDocker) {
    & docker compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'Docker services failed to start.' }
  } else {
    # System services alone do not keep a WSL distribution alive.
    $taskKeepAlive = Start-Process -FilePath wsl.exe -WindowStyle Hidden -PassThru -ArgumentList @(
      '-d', $WslDistribution, '--exec', 'sleep', 'infinity'
    )
    $taskProcesses.Add($taskKeepAlive)
    $taskWslIp = ((& wsl -d $WslDistribution -- hostname -I).Trim() -split '\s+')[0]
    if (!$taskWslIp) { throw 'WSL did not return an address.' }
    & wsl -d $WslDistribution -u root -- env "GOMOKU_BIND_ADDRESS=$taskWslIp" docker compose up -d --wait
    if ($LASTEXITCODE -ne 0) { throw 'Install Docker Engine and Compose in WSL, then retry.' }
    Start-GomokuProcess 'bridge' @('tool/wsl_bridge.dart', $taskWslIp) $taskRoot | Out-Null
  }
  & flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  if (!$SkipWebBuild) {
    Push-Location (Join-Path $taskRoot 'apps/gomoku_app')
    try { & flutter build web --release --no-web-resources-cdn --no-pub }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw 'Web build failed.' }
  }
  & $taskDart tool/prepare_web.dart
  if ($LASTEXITCODE -ne 0) { throw 'Web assets could not be prepared.' }
  Start-GomokuProcess 'server' @('bin/main.dart', '--apply-migrations', '--server-id', 'gomoku-dev') (Join-Path $taskRoot 'apps/server') | Out-Null
  Start-GomokuProcess 'gateway' @('tool/dev_gateway.dart') $taskRoot | Out-Null
  $taskDeadline = (Get-Date).AddSeconds(60)
  Add-Type -AssemblyName System.Net.Http
  $taskProbeHandler = [System.Net.Http.HttpClientHandler]::new()
  $taskProbeHandler.UseProxy = $false
  $taskProbe = [System.Net.Http.HttpClient]::new($taskProbeHandler)
  $taskProbe.Timeout = [TimeSpan]::FromSeconds(2)
  $taskProbeError = 'No response'
  try {
    while ($true) {
      foreach ($taskChild in $taskProcesses) {
        if ($taskChild.HasExited) { throw 'A development process exited during startup. Check .local/*.error.log.' }
      }
      try {
        $taskHealth = $taskProbe.GetAsync('http://127.0.0.1:4280/health').GetAwaiter().GetResult()
        $taskReady = $taskHealth.IsSuccessStatusCode
        $taskProbeError = "HTTP $([int]$taskHealth.StatusCode)"
        $taskHealth.Dispose()
        if ($taskReady) { break }
      } catch { $taskProbeError = $_.Exception.Message }
      if ((Get-Date) -gt $taskDeadline) { throw "The application did not become healthy: $taskProbeError" }
      Start-Sleep -Milliseconds 200
    }
  } finally {
    $taskProbe.Dispose()
    $taskProbeHandler.Dispose()
  }
  Write-Host 'Gomoku: http://localhost:4280'
  Write-Host 'Development email: http://localhost:8025'
  Write-Host 'Logs: .local/   Press Ctrl+C to stop the processes started here.'
  if ($CheckStartup) {
    Write-Host 'Development startup verified; stopping the processes started here.'
    return
  }
  while ($true) {
    Start-Sleep -Seconds 1
    foreach ($taskChild in $taskProcesses) {
      if ($taskChild.HasExited) { throw 'A development process exited. Check .local/*.error.log.' }
    }
  }
} finally {
  foreach ($taskChild in $taskProcesses) {
    if (!$taskChild.HasExited) {
      # The Dart launcher can own a child VM; stop the complete owned tree.
      & taskkill.exe /PID $taskChild.Id /T /F *> $null
    }
  }
}
