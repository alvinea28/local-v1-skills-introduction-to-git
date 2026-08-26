[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('git-config-changed', 'post-commit', 'post-checkout', 'post-merge')]
    [string]$Event,

    # post-checkout
    [string]$PreviousHead,
    [string]$NewHead,

    # git-config-changed
    [ValidateSet('global', 'repository')]
    [string]$ConfigType = 'global'
)

$ErrorActionPreference = 'Stop'

function Get-RepoSlug {
    $url = (git remote get-url origin 2>$null)
    if (-not $url) { throw "No 'origin' remote found. Run this from inside the exercise repository." }
    if ($url -match '[:/]([^/:]+)/([^/]+?)(\.git)?$') { return "$($Matches[1])/$($Matches[2])" }
    throw "Could not parse repository slug from origin URL: $url"
}

function Get-BranchCommits {
    $branch = (git branch --show-current).Trim()

    # %x1f is an ASCII unit separator, which cannot appear in a commit subject.
    # Split with IndexOf rather than -split: the "`u{...}" escape only exists in
    # PowerShell 6+, and the git hooks run under Windows PowerShell 5.1, where it
    # silently fails to match and every message would be sent as null.
    $separator = [char]0x1F
    $lines = @(git log --pretty=format:"%h$separator%s")
    $messages = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $index = $line.IndexOf($separator)
        if ($index -lt 0) {
            $messages += [ordered]@{ id = $line; message = $line }
        }
        else {
            $messages += [ordered]@{
                id      = $line.Substring(0, $index)
                message = $line.Substring($index + 1)
            }
        }
    }
    return @{
        branch_name            = $branch
        branch_commit_count    = $messages.Count
        branch_commit_messages = $messages
    }
}

$slug = Get-RepoSlug
$repoName = Split-Path -Leaf (git rev-parse --show-toplevel)
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')

switch ($Event) {
    'git-config-changed' {
        $payload = [ordered]@{
            config_type     = $ConfigType
            repository_name = $repoName
            timestamp       = $timestamp
        }
    }
    'post-checkout' {
        $payload = [ordered]@{
            previous_head   = $PreviousHead
            new_head        = $NewHead
            branch_name     = (git branch --show-current).Trim()
            repository_name = $repoName
            timestamp       = $timestamp
        }
    }
    'post-commit' {
        $info = Get-BranchCommits
        $payload = [ordered]@{
            commit_hash            = (git rev-parse HEAD).Trim()
            commit_message         = (git log -1 --pretty=%B) -join "`n"
            commit_author          = (git log -1 --pretty='%an <%ae>').Trim()
            branch_name            = $info.branch_name
            branch_commit_count    = $info.branch_commit_count
            branch_commit_messages = $info.branch_commit_messages
            modified_files         = @(git show --pretty=format: --name-only HEAD | Where-Object { $_ })
            repository_name        = $repoName
            timestamp              = $timestamp
        }
    }
    'post-merge' {
        $info = Get-BranchCommits
        $payload = [ordered]@{
            current_head           = (git rev-parse HEAD).Trim()
            branch_name            = $info.branch_name
            branch_commit_count    = $info.branch_commit_count
            branch_commit_messages = $info.branch_commit_messages
            last_commit_message    = (git log -1 --pretty=%B) -join "`n"
            merge_author           = (git log -1 --pretty='%an <%ae>').Trim()
            repository_name        = $repoName
            timestamp              = $timestamp
        }
    }
}

$body = [ordered]@{
    event_type     = $Event
    client_payload = $payload
} | ConvertTo-Json -Depth 10 -Compress

Write-Host "Exercise Monitor: sending '$Event' to $slug" -ForegroundColor Cyan

$response = $body | gh api "repos/$slug/dispatches" --input - 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Exercise Monitor: event sent. Watch the exercise issue for Mona's reply." -ForegroundColor Green
}
else {
    Write-Warning "Exercise Monitor: failed to send '$Event'."
    Write-Warning ($response | Out-String).Trim()
    Write-Warning "Check that the GitHub CLI is installed and authenticated with the 'repo' scope ('gh auth login')."
}
