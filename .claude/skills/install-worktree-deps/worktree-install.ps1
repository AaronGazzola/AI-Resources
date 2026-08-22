<#
.SYNOPSIS
Installs dependencies for a git worktree without stacking retries, reaching
into the main checkout, or taking the machine.

.DESCRIPTION
Started by the install-worktree-deps skill. SKILL.md explains why each guard
exists. Returns as soon as the install is launched; the install itself runs
detached and capped, writing to a log file.

.PARAMETER Root
The worktree to install into. Defaults to the git worktree containing the
current directory.

.PARAMETER Status
Report on the last install started for this worktree instead of starting one.

.PARAMETER Force
Stop an install that is already running and start over.

.PARAMETER Cores
How many processor cores the install may use. Clamped to leave two free.
#>
[CmdletBinding()]
param(
  [string]$Root,
  [switch]$Status,
  [switch]$Force,
  [int]$Cores = 6,
  [int]$TailLines = 40
)

$ErrorActionPreference = 'Stop'

function Fail($message) {
  Write-Host "worktree-install: $message" -ForegroundColor Red
  exit 1
}

if ($Root) {
  if (-not (Test-Path -LiteralPath $Root)) { Fail "$Root does not exist." }
  $root = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\')
}
else {
  $top = & git rev-parse --show-toplevel 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $top) {
    Fail "the current directory is not inside a git repository. Run this from the worktree, or pass -Root."
  }
  $root = (Resolve-Path -LiteralPath $top).Path.TrimEnd('\')
}
Set-Location -LiteralPath $root

$gitDir = (Resolve-Path (& git rev-parse --absolute-git-dir)).Path.TrimEnd('\')
$commonDir = (Resolve-Path (& git rev-parse --git-common-dir)).Path.TrimEnd('\')
$isMainCheckout = ($gitDir -eq $commonDir)
if ($isMainCheckout -and -not $Force) {
  Fail "$root is the main checkout, not a worktree. Dependencies there are the owner's to install, by hand, at a moment of their choosing. Pass -Force only if the owner asked for it."
}

$mainRoot = (Split-Path $commonDir -Parent).TrimEnd('\')
$mainModules = Join-Path $mainRoot 'node_modules'

# State is kept outside the repository, so no project needs a gitignore entry.
$md5 = [System.Security.Cryptography.MD5]::Create()
$digest = $md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($root.ToLower()))
$hash = [BitConverter]::ToString($digest).Replace('-', '').Substring(0, 8)
$stateDir = Join-Path $env:TEMP ('worktree-install\' + (Split-Path $root -Leaf) + '-' + $hash)
$logFile = Join-Path $stateDir 'install.log'
$errFile = Join-Path $stateDir 'install.err'
$pidFile = Join-Path $stateDir 'install.pid'
$exitFile = Join-Path $stateDir 'install.exit'
$runner = Join-Path $PSScriptRoot 'worktree-install-runner.ps1'

if (-not (Test-Path -LiteralPath $runner)) { Fail "the runner script is missing from $PSScriptRoot." }
if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }

function Get-RunningInstall {
  if (-not (Test-Path -LiteralPath $pidFile)) { return $null }
  $recorded = (Get-Content -LiteralPath $pidFile -Raw).Trim()
  if (-not $recorded) { return $null }
  return Get-Process -Id ([int]$recorded) -ErrorAction SilentlyContinue
}

function Show-Log([switch]$IncludeErrors) {
  if ((Test-Path -LiteralPath $logFile) -and (Get-Item -LiteralPath $logFile).Length -gt 0) {
    Write-Host "--- $logFile ---"
    Get-Content -LiteralPath $logFile -Tail $TailLines
  }
  if (-not $IncludeErrors) { return }
  if ((Test-Path -LiteralPath $errFile) -and (Get-Item -LiteralPath $errFile).Length -gt 0) {
    $lines = @(Get-Content -LiteralPath $errFile | Where-Object { $_ -notmatch 'deprecated' })
    if ($lines.Count -gt 0) {
      Write-Host "--- $errFile (deprecation warnings omitted) ---"
      $lines | Select-Object -Last $TailLines
    }
  }
}

if ($Status) {
  $running = Get-RunningInstall
  if ($running) {
    $cpu = [math]::Round($running.CPU, 1)
    $mask = '0x' + [Convert]::ToString([int64]$running.ProcessorAffinity, 16)
    Write-Host "STATUS: running (pid $($running.Id), cpu ${cpu}s, priority $($running.PriorityClass), affinity $mask)"
    Show-Log
    exit 0
  }
  if (Test-Path -LiteralPath $exitFile) {
    $code = (Get-Content -LiteralPath $exitFile -Raw).Trim()
    if ($code -eq '0') {
      Write-Host "STATUS: finished, exit 0"
      Show-Log
      exit 0
    }
    Write-Host "STATUS: FAILED, exit $code"
    Show-Log -IncludeErrors
    exit 0
  }
  Write-Host "STATUS: no install has been started for $root"
  exit 0
}

$running = Get-RunningInstall
if ($running -and -not $Force) {
  Write-Host "worktree-install: an install is already running (pid $($running.Id)). Wait for it, or pass -Force to start over."
  Show-Log
  exit 0
}
if ($running -and $Force) {
  Write-Host "worktree-install: stopping the running install (pid $($running.Id)) because -Force was given."
  Stop-Process -Id $running.Id -Force -ErrorAction SilentlyContinue
  Start-Sleep -Milliseconds 500
}

$manager = 'npm'
if (Test-Path -LiteralPath (Join-Path $root 'pnpm-lock.yaml')) {
  $manager = 'pnpm'
}
elseif (Test-Path -LiteralPath (Join-Path $root 'yarn.lock')) {
  $manager = 'yarn'
}
elseif ((Test-Path -LiteralPath (Join-Path $root 'bun.lockb')) -or (Test-Path -LiteralPath (Join-Path $root 'bun.lock'))) {
  $manager = 'bun'
}

$logical = [int](Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
$ceiling = [math]::Max(1, $logical - 2)
if ($Cores -lt 1) { $Cores = 1 }
if ($Cores -gt $ceiling) { $Cores = $ceiling }
$affinity = [int64]((1 -shl $Cores) - 1)

# A junction is invisible to the file APIs a package manager uses, so an install
# through one lands in the main checkout. Drop the junction before installing.
$modules = Join-Path $root 'node_modules'
$existing = Get-Item -LiteralPath $modules -Force -ErrorAction SilentlyContinue
if ($existing -and ($existing.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
  Write-Host "worktree-install: removing the node_modules junction so the install cannot reach $mainRoot."
  & cmd.exe /c "rmdir ""$modules""" | Out-Null
  if (Test-Path -LiteralPath $modules) { Fail "could not remove the junction at $modules." }
}

if (-not $isMainCheckout) {
  $mainEntries = @(Get-ChildItem -LiteralPath $mainModules -Force -ErrorAction SilentlyContinue).Count
  if ($mainEntries -gt 0 -and $mainEntries -lt 100) {
    Fail "the main checkout's dependencies at $mainModules look damaged ($mainEntries entries). Stopping rather than installing on top of that."
  }
}

Remove-Item -LiteralPath $exitFile -ErrorAction SilentlyContinue
Set-Content -LiteralPath $logFile -Value '' -Encoding utf8
Set-Content -LiteralPath $errFile -Value '' -Encoding utf8

$arguments = @(
  '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $runner,
  '-Root', $root, '-ExitFile', $exitFile, '-Affinity', $affinity, '-Manager', $manager
)
$process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments `
  -WorkingDirectory $root -WindowStyle Hidden -PassThru `
  -RedirectStandardOutput $logFile -RedirectStandardError $errFile
$process.PriorityClass = 'Idle'
$process.ProcessorAffinity = [IntPtr]$affinity
Set-Content -LiteralPath $pidFile -Value $process.Id

Write-Host "worktree-install: $manager install started (pid $($process.Id)) at idle priority on $Cores of $logical cores."
Write-Host "worktree-install: this returns immediately on purpose; nothing here can time out."
Write-Host "worktree-install: log at $logFile"
Write-Host "worktree-install: check on it by running this script again with -Status"
