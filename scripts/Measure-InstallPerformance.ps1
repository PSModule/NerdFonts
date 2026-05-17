<#
    .SYNOPSIS
        Measures Install-NerdFont performance across known scenarios.

    .DESCRIPTION
        Runs a set of timed scenarios against the currently loaded NerdFonts module
        and emits a structured result object per scenario. Each scenario uninstalls
        the fonts it will measure before timing, so measurements are comparable
        across iterations.

    .EXAMPLE
        ./Measure-InstallPerformance.ps1 -Iteration 'baseline' -Subset 'Hack','FiraCode','JetBrainsMono'

    .NOTES
        Per-iteration result JSON is appended to scripts/perf-results.jsonl
        so a full report can be produced at the end of the improvement cycle.
#>
[CmdletBinding()]
param(
    # Free-form label for the iteration (module version, commit short SHA, etc).
    [Parameter(Mandatory)]
    [string] $Iteration,

    # Named fonts used for the small subset scenarios. Should be small/medium
    # archives to keep iteration time bounded.
    [Parameter()]
    [string[]] $Subset = @('Hack', 'FiraCode', 'JetBrainsMono'),

    # When set, also runs a full Install-NerdFont -All measurement. Slow.
    [Parameter()]
    [switch] $IncludeAll,

    # File where per-scenario JSON lines are appended.
    [Parameter()]
    [string] $ResultsPath = (Join-Path $PSScriptRoot 'perf-results.jsonl')
)

$ErrorActionPreference = 'Stop'

function Invoke-Uninstall {
    param([string[]]$Names)
    foreach ($n in $Names) {
        # Nerd Fonts archives expand to multiple family names that all start
        # with the archive's base name (e.g. "Hack Nerd Font", "Hack Nerd Font Mono").
        $families = Get-Font -Scope CurrentUser | Where-Object { $_.Name -like "$n*" }
        foreach ($f in $families) {
            try {
                Uninstall-Font -Name $f.Name -Scope CurrentUser -ErrorAction Stop
            } catch {
                Write-Verbose "Uninstall failed for $($f.Name): $_"
            }
        }
    }
}

function Invoke-UninstallAll {
    $names = (Get-NerdFont).Name
    Invoke-Uninstall -Names $names
}

function Measure-Scenario {
    param(
        [string]$Name,
        [scriptblock]$Setup,
        [scriptblock]$Action
    )
    Write-Host "[$Iteration] Setup    : $Name" -ForegroundColor DarkGray
    & $Setup | Out-Null
    [System.GC]::Collect()
    [System.GC]::WaitForPendingFinalizers()
    Write-Host "[$Iteration] Measure  : $Name" -ForegroundColor Cyan
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        & $Action | Out-Null
        $err = $null
    } catch {
        $err = $_.ToString()
    }
    $sw.Stop()
    $result = [pscustomobject]@{
        Iteration  = $Iteration
        Scenario   = $Name
        DurationMs = [int]$sw.Elapsed.TotalMilliseconds
        DurationS  = [math]::Round($sw.Elapsed.TotalSeconds, 2)
        Timestamp  = (Get-Date).ToString('o')
        Error      = $err
        Module     = (Get-Module NerdFonts).Version.ToString()
    }
    Write-Host ("[$Iteration] Result   : {0} -> {1}s" -f $Name, $result.DurationS) -ForegroundColor Green
    $result | ConvertTo-Json -Compress | Add-Content -Path $ResultsPath
    return $result
}

$results = [System.Collections.Generic.List[object]]::new()

# --- Scenario 1: single small/medium font ---
$results.Add((Measure-Scenario -Name 'Single-Hack' `
    -Setup { Invoke-Uninstall -Names 'Hack' } `
    -Action { Install-NerdFont -Name 'Hack' -Scope CurrentUser -Force }))

# --- Scenario 2: subset of named fonts ---
$results.Add((Measure-Scenario -Name "Subset-$($Subset -join '+')" `
    -Setup { Invoke-Uninstall -Names $Subset } `
    -Action { Install-NerdFont -Name $Subset -Scope CurrentUser -Force }))

# --- Scenario 3: re-install when already present (no-op path) ---
$results.Add((Measure-Scenario -Name 'Subset-AlreadyInstalled' `
    -Setup { } `
    -Action { Install-NerdFont -Name $Subset -Scope CurrentUser }))

# --- Scenario 4: full -All (only when explicitly requested) ---
if ($IncludeAll) {
    $results.Add((Measure-Scenario -Name 'All' `
        -Setup { Invoke-UninstallAll } `
        -Action { Install-NerdFont -All -Scope CurrentUser -Force }))
}

Write-Host ""
Write-Host "Summary for iteration '$Iteration':" -ForegroundColor Yellow
$results | Format-Table Iteration, Scenario, DurationS, Module -AutoSize
