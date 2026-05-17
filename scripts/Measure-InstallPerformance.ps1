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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Console output for an interactive perf script.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'ResultsPath',
    Justification = 'Used inside Measure-Scenario via closure on the enclosing scope.'
)]
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
    <#
        .SYNOPSIS
            Removes matching Nerd Font families for the current user.
    #>
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
    <#
        .SYNOPSIS
            Removes all Nerd Fonts known to the current module.
    #>
    $names = (Get-NerdFont).Name
    Invoke-Uninstall -Names $names
}

function Measure-Scenario {
    <#
        .SYNOPSIS
            Runs one setup/action performance scenario and records the result.
    #>
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
$single = @{
    Name   = 'Single-Hack'
    Setup  = { Invoke-Uninstall -Names 'Hack' }
    Action = { Install-NerdFont -Name 'Hack' -Scope CurrentUser -Force }
}
$results.Add((Measure-Scenario @single))

# --- Scenario 2: subset of named fonts ---
$subsetArgs = @{
    Name   = "Subset-$($Subset -join '+')"
    Setup  = { Invoke-Uninstall -Names $Subset }
    Action = { Install-NerdFont -Name $Subset -Scope CurrentUser -Force }
}
$results.Add((Measure-Scenario @subsetArgs))

# --- Scenario 3: re-install when already present (no-op path) ---
$noop = @{
    Name   = 'Subset-AlreadyInstalled'
    Setup  = { }
    Action = { Install-NerdFont -Name $Subset -Scope CurrentUser }
}
$results.Add((Measure-Scenario @noop))

# --- Scenario 4: full -All (only when explicitly requested) ---
if ($IncludeAll) {
    $allArgs = @{
        Name   = 'All'
        Setup  = { Invoke-UninstallAll }
        Action = { Install-NerdFont -All -Scope CurrentUser -Force }
    }
    $results.Add((Measure-Scenario @allArgs))
}

Write-Host ""
Write-Host "Summary for iteration '$Iteration':" -ForegroundColor Yellow
$results | Format-Table Iteration, Scenario, DurationS, Module -AutoSize
