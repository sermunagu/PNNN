param(
    [string]$TaskSummary = "",
    [ValidateSet("low", "medium", "high")]
    [string]$RiskLevel = "medium",
    [switch]$NoIntentToAdd,
    [string[]]$ExcludePath = @()
)

$ErrorActionPreference = "Stop"

# Force UTF-8 for Git/PowerShell interaction. This avoids mojibake in diffs and paths
# when the repo contains non-ASCII characters such as "Códigos".
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = $utf8NoBom
$OutputEncoding = $utf8NoBom
$env:LC_ALL = "C.UTF-8"
$env:LANG = "C.UTF-8"

# Resolve the repository root from this script location, not from `git rev-parse`.
# This avoids Windows/Git encoding issues with paths containing non-ASCII characters.
$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $scriptDir "..")).Path

Set-Location -LiteralPath $repoRoot

$handoffDir = Join-Path $repoRoot ".codex_handoff"
New-Item -ItemType Directory -Force -Path $handoffDir | Out-Null

$statusFile = Join-Path $handoffDir "GIT_STATUS.txt"
$filesFile = Join-Path $handoffDir "FILES_CHANGED.txt"
$diffFile = Join-Path $handoffDir "LAST_DIFF.patch"
$responseFile = Join-Path $handoffDir "LAST_RESPONSE.md"

function Normalize-GitPath {
    param([string]$PathValue)
    return ($PathValue -replace "\\", "/").Trim("/")
}

$normalizedExcludePaths = @()
foreach ($exclude in $ExcludePath) {
    if (-not [string]::IsNullOrWhiteSpace($exclude)) {
        $normalizedExcludePaths += Normalize-GitPath $exclude
    }
}

function Test-ExcludedByUser {
    param([string]$GitPath)

    $normalizedPath = Normalize-GitPath $GitPath

    foreach ($exclude in $normalizedExcludePaths) {
        if ($normalizedPath -eq $exclude -or $normalizedPath -like "$exclude/*") {
            return $true
        }
    }

    return $false
}

function Test-ProtectedArtifact {
    param([string]$GitPath)

    $normalized = Normalize-GitPath $GitPath
    $leaf = Split-Path -Leaf $normalized

    return (
        ($normalized -like "measurements/*") -or
        ($normalized -like "results/*") -or
        ($normalized -like "generated_outputs/*") -or
        ($normalized -like ".codex_handoff/*") -or
        ($normalized -like "*.mat") -or
        ($normalized -like "*.fig") -or
        ($leaf -eq "deploy_package.mat")
    )
}

# Add intent-to-add entries for new files so they appear in git diff,
# but never include protected/generated artifacts or user-excluded paths.
if (-not $NoIntentToAdd) {
    $untrackedFiles = & git -c core.quotepath=false ls-files --others --exclude-standard

    foreach ($file in $untrackedFiles) {
        if (-not (Test-ProtectedArtifact $file) -and -not (Test-ExcludedByUser $file)) {
            & git add -N -- $file | Out-Null
        }
    }
}

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

$gitStatus = & git -c core.quotepath=false status --short
$changedFiles = & git -c core.quotepath=false diff --name-status -- .

# Filter status/list outputs by user excludes. Protected paths are still visible in status
# if they are already tracked, but protected generated artifacts should not be included in the patch.
if ($normalizedExcludePaths.Count -gt 0) {
    $gitStatus = $gitStatus | Where-Object {
        $linePath = ($_ -replace "^[ MADRCU?!]{1,2}\s+", "")
        -not (Test-ExcludedByUser $linePath)
    }

    $changedFiles = $changedFiles | Where-Object {
        $parts = $_ -split "`t"
        $candidatePath = $parts[-1]
        -not (Test-ExcludedByUser $candidatePath)
    }
}

Set-Content -LiteralPath $statusFile -Value ($gitStatus -join [Environment]::NewLine) -Encoding UTF8

if ($changedFiles) {
    Set-Content -LiteralPath $filesFile -Value ($changedFiles -join [Environment]::NewLine) -Encoding UTF8
} else {
    Set-Content -LiteralPath $filesFile -Value "No changed files detected." -Encoding UTF8
}

$diffArgs = @(
    "-c", "core.quotepath=false",
    "diff",
    "--binary",
    "--",
    ".",
    ":(exclude)measurements/**",
    ":(exclude)results/**",
    ":(exclude)generated_outputs/**",
    ":(exclude).codex_handoff/**",
    ":(exclude)*.mat",
    ":(exclude)*.fig",
    ":(exclude)deploy_package.mat"
)

foreach ($exclude in $normalizedExcludePaths) {
    $diffArgs += ":(exclude)$exclude/**"
    $diffArgs += ":(exclude)$exclude"
}

$diffText = & git @diffArgs

if ($diffText) {
    Set-Content -LiteralPath $diffFile -Value ($diffText -join [Environment]::NewLine) -Encoding UTF8
} else {
    Set-Content -LiteralPath $diffFile -Value "No diff detected." -Encoding UTF8
}

$response = @"
# Codex handoff

Generated: $timestamp

## Task summary

$TaskSummary

## Risk level

$RiskLevel

## Files modified

See FILES_CHANGED.txt.

## Current git status

See GIT_STATUS.txt.

## Complete diff

See LAST_DIFF.patch.

## Commands run

- tools/make_handoff.ps1

## Commands Sergi should run manually

- Review .codex_handoff/LAST_DIFF.patch.
- Run only the lightweight tests explicitly requested for this task.
- Do not run long MATLAB training unless the task requires it.

## Risks, doubts or assumptions

- This handoff is generated from the current working tree.
- Untracked files are included via git add -N, except protected/generated artifacts and paths passed through -ExcludePath.
- Protected paths excluded from the diff: measurements/, results/, generated_outputs/, .mat, .fig, deploy_package.mat.
- User-excluded paths: $($normalizedExcludePaths -join ", ")

## Project log / results index

- docs/PROJECT_LOG.md: check whether the task changed project state and update if needed.
- docs/RESULTS_INDEX.md: update only when there are important new experimental results.
"@

Set-Content -LiteralPath $responseFile -Value $response -Encoding UTF8

Write-Host "Handoff generated in: $handoffDir"
Write-Host "Files:"
Write-Host " - $responseFile"
Write-Host " - $diffFile"
Write-Host " - $statusFile"
Write-Host " - $filesFile"
