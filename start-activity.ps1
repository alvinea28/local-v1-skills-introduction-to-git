# Start Activity - the only command you need after cloning this exercise.
#
#   .\start-activity.ps1
#
# It is also run automatically the first time you open this folder in
# Visual Studio Code (see .vscode/tasks.json).
#
# What it does:
#   1. Verifies Git and the GitHub CLI are ready.
#   2. Delivers the sample game into ./src as *untracked* files, so Step 2's
#      "git add" / "Initial commit" behaves like a brand new project.
#   3. Points Git at this repository's hooks so commits, checkouts, and merges
#      notify the exercise workflows (Steps 2-5).
#   4. Starts the git-config watcher in the background (Step 1).

$ErrorActionPreference = 'Stop'

function Write-Step($message) { Write-Host "  $message" -ForegroundColor Gray }
function Write-Ok($message) { Write-Host "  $([char]0x2713) $message" -ForegroundColor Green }

Write-Host ""
Write-Host "Introduction to Git - starting the activity" -ForegroundColor Cyan
Write-Host "-------------------------------------------" -ForegroundColor Cyan

# --- 1. Prerequisites -------------------------------------------------------

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git not found. Install it from https://git-scm.com then re-run .\start-activity.ps1"
}

$root = (git rev-parse --show-toplevel 2>$null)
if (-not $root) { throw "Not inside a git repository. Open the cloned exercise folder and try again." }
$root = $root.Trim()
Write-Ok "Git repository: $root"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "  GitHub CLI is required so Mona can see your work." -ForegroundColor Yellow
    Write-Host "  Install it from https://cli.github.com, then re-run .\start-activity.ps1" -ForegroundColor Yellow
    Write-Host ""
    throw "GitHub CLI (gh) not found."
}

gh auth status 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "  You are not signed in to the GitHub CLI." -ForegroundColor Yellow
    Write-Host "  Run the following, then re-run .\start-activity.ps1" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "      gh auth login" -ForegroundColor White
    Write-Host ""
    throw "GitHub CLI is not authenticated."
}
Write-Ok "GitHub CLI signed in"

# --- 2. Deliver the sample game as untracked files (Step 2) -----------------
#
# This repository is a clone, so Git already tracks everything in it. That
# would make Step 2 ("git init", "git add src/*", "Initial commit") a no-op.
# The pristine game lives in .exercise-assets/game/src and is copied to ./src,
# which is deliberately NOT tracked and NOT ignored. The learner therefore sees
# real untracked files and creates a real first commit for them.

$assets = Join-Path $root '.exercise-assets/game/src'
$target = Join-Path $root 'src'

if (-not (Test-Path -LiteralPath $assets)) {
    throw "Missing exercise assets at $assets"
}

$tracked = @(git -C $root ls-files -- src)
if ($tracked.Count -gt 0) {
    Write-Ok "Game files already committed - leaving ./src untouched"
}
elseif (Test-Path -LiteralPath $target) {
    Write-Ok "Game files already present in ./src"
}
else {
    New-Item -ItemType Directory -Path $target | Out-Null
    Copy-Item -Path (Join-Path $assets '*') -Destination $target -Recurse -Force
    Write-Ok "Sample game copied to ./src (untracked - you'll commit it in Step 2)"
}

# --- 3. Enable the git hooks (Steps 2-5) ------------------------------------

git -C $root config core.hooksPath .githooks
Write-Ok "Git hooks enabled (post-commit, post-checkout, post-merge)"

# --- 4. Start the config watcher in the background (Step 1) -----------------

$pidFile = Join-Path $root '.git/exercise-monitor.pid'
$watcher = Join-Path $root '.exercise-monitor/watch-git-config.ps1'

# Stop a watcher left over from a previous session.
if (Test-Path -LiteralPath $pidFile) {
    $oldPid = (Get-Content -LiteralPath $pidFile -Raw).Trim()
    $existing = Get-Process -Id $oldPid -ErrorAction SilentlyContinue
    if ($existing) { Stop-Process -Id $oldPid -Force -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $pidFile -ErrorAction SilentlyContinue
}

$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
$process = Start-Process -FilePath $shell `
    -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$watcher`"" `
    -WorkingDirectory $root `
    -WindowStyle Hidden `
    -PassThru

$process.Id | Set-Content -LiteralPath $pidFile -Encoding ascii
Write-Ok "Progress watcher running in the background (PID $($process.Id))"

# --- Done -------------------------------------------------------------------

Write-Host ""
Write-Host "You're all set. Mona is watching your work." -ForegroundColor Green
Write-Host "Open the exercise issue on GitHub and follow Step 1." -ForegroundColor Green
Write-Host ""
Write-Host "  Stop the watcher later with: .\stop-activity.ps1" -ForegroundColor DarkGray
Write-Host ""
