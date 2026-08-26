# Stops the background progress watcher started by .\start-activity.ps1

$ErrorActionPreference = 'Stop'

$root = (git rev-parse --show-toplevel).Trim()
$pidFile = Join-Path $root '.git/exercise-monitor.pid'

if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Host "Exercise Monitor: not running."
    return
}

$watcherPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
Stop-Process -Id $watcherPid -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue

Write-Host "Exercise Monitor: stopped (PID $watcherPid)." -ForegroundColor Green
