# Deprecated - kept so older instructions keep working.
# Use .\start-activity.ps1 instead.

$root = (git rev-parse --show-toplevel).Trim()
& (Join-Path $root 'start-activity.ps1')
