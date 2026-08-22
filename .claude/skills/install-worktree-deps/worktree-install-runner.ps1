<#
.SYNOPSIS
The capped child process that actually runs the package manager. Started only
by worktree-install.ps1 — never run this by hand.

.DESCRIPTION
Priority and processor affinity are set before the package manager is launched,
because a Windows process inherits both from its parent at creation time.
Setting them here rather than in the launcher closes the gap where the install
could start at normal priority across every core.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Root,
  [Parameter(Mandatory = $true)][string]$ExitFile,
  [Parameter(Mandatory = $true)][int64]$Affinity,
  [ValidateSet('npm', 'pnpm', 'yarn', 'bun')][string]$Manager = 'npm'
)

$ErrorActionPreference = 'Continue'

$self = [System.Diagnostics.Process]::GetCurrentProcess()
$self.PriorityClass = [System.Diagnostics.ProcessPriorityClass]::Idle
$self.ProcessorAffinity = [IntPtr]$Affinity

Set-Location -LiteralPath $Root

$env:npm_config_progress = 'false'
$env:npm_config_audit = 'false'
$env:npm_config_fund = 'false'
$env:npm_config_update_notifier = 'false'
$env:CI = 'true'

switch ($Manager) {
  'npm' { $exe = 'npm.cmd'; $arguments = @('install', '--prefer-offline', '--no-audit', '--no-fund') }
  'pnpm' { $exe = 'pnpm.cmd'; $arguments = @('install', '--prefer-offline') }
  'yarn' { $exe = 'yarn.cmd'; $arguments = @('install') }
  'bun' { $exe = 'bun.exe'; $arguments = @('install') }
}

$started = Get-Date
Write-Output "worktree-install: $Manager $($arguments -join ' ') starting in $Root"
Write-Output "worktree-install: priority $($self.PriorityClass), affinity 0x$([Convert]::ToString($Affinity, 16))"

$resolved = (Get-Command $exe -ErrorAction SilentlyContinue).Source
if (-not $resolved) {
  Write-Output "worktree-install: $exe is not on PATH"
  Set-Content -LiteralPath $ExitFile -Value 127
  exit 127
}

& $resolved @arguments
$code = $LASTEXITCODE

$elapsed = [math]::Round(((Get-Date) - $started).TotalSeconds, 1)
$modules = Join-Path $Root 'node_modules'
$installed = @(Get-ChildItem -LiteralPath $modules -Force -ErrorAction SilentlyContinue).Count
if ($code -eq 0 -and $installed -lt 1) {
  Write-Output "worktree-install: $Manager reported success but nothing was installed into $modules"
  $code = 1
}

Write-Output "worktree-install: finished in ${elapsed}s, exit $code, $installed entries installed"
Set-Content -LiteralPath $ExitFile -Value $code
exit $code
