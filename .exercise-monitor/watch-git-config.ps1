# Exercise Monitor - watches your git configuration files for changes.
# Replaces the inotify watcher that the Codespace version used.
#
#   .\.exercise-monitor\watch-git-config.ps1
#
# Leave this running in its own terminal while you work through Step 1.

$ErrorActionPreference = 'Stop'

$root = (git rev-parse --show-toplevel).Trim()
$sender = Join-Path $root '.exercise-monitor/send-event.ps1'

$globalConfig = Join-Path $HOME '.gitconfig'
$localConfig = Join-Path $root '.git/config'

# Snapshot both the content and the last-write time.
#
# Comparing content alone is not enough: if your global identity is already set
# to the same name/email, `git config --global user.name "..."` rewrites the
# file with identical content. The learner ran the command and expects Mona to
# react, so treat a rewrite as a change too.
function Get-Snapshot([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    $content = Get-Content -LiteralPath $path -Raw
    $stamp = (Get-Item -LiteralPath $path).LastWriteTimeUtc.Ticks
    return "$stamp|$content"
}

$state = @{
    $globalConfig = Get-Snapshot $globalConfig
    $localConfig  = Get-Snapshot $localConfig
}

Write-Host "Exercise Monitor: watching git configuration for changes." -ForegroundColor Cyan
Write-Host "  global:     $globalConfig"
Write-Host "  repository: $localConfig"
Write-Host "Press Ctrl+C to stop." -ForegroundColor DarkGray

while ($true) {
    Start-Sleep -Seconds 2

    foreach ($path in @($globalConfig, $localConfig)) {
        $current = Get-Snapshot $path
        if ($current -eq $state[$path]) { continue }

        $state[$path] = $current
        $type = if ($path -eq $globalConfig) { 'global' } else { 'repository' }
        Write-Host "Exercise Monitor: detected $type git config change." -ForegroundColor Yellow
        & $sender -Event 'git-config-changed' -ConfigType $type
    }
}
