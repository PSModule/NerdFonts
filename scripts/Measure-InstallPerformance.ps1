<#
    .SYNOPSIS
    Measures Install-NerdFont performance across known scenarios.

    .DESCRIPTION
    Runs timed installation scenarios and appends structured results to a JSON Lines file.
    Each fresh-install scenario removes its target fonts during setup. The already-installed
    scenario explicitly installs its subset before measuring the skip path.

    .EXAMPLE
    ./Measure-InstallPerformance.ps1 -Iteration 'baseline' -Subset 'Hack', 'FiraCode', 'JetBrainsMono'
#>
[CmdletBinding()]
param(
    # Free-form label for the iteration, such as a module version or commit SHA.
    [Parameter(Mandatory)]
    [string] $Iteration,

    # Named fonts used for the small subset scenarios.
    [Parameter()]
    [string[]] $Subset = @('Hack', 'FiraCode', 'JetBrainsMono'),

    # Runs a full Install-NerdFont -All measurement.
    [Parameter()]
    [switch] $IncludeAll,

    # File to receive one JSON result object per scenario.
    [Parameter()]
    [string] $ResultsPath = (Join-Path -Path $PSScriptRoot -ChildPath 'perf-results.jsonl')
)

$ErrorActionPreference = 'Stop'

function Remove-NerdFont {
    <#
        .SYNOPSIS
        Removes the installed families associated with the supplied archive names.
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string[]] $Names
    )

    foreach ($name in $Names) {
        $normalizedName = $name -replace '[\s_-]', ''
        $families = Get-Font -Scope CurrentUser | Where-Object {
            $normalizedFamily = $_.Name -replace '[\s_-]', ''
            $normalizedFamily -like "${normalizedName}*NerdFont*"
        }
        foreach ($family in $families) {
            if ($PSCmdlet.ShouldProcess($family.Name, 'Uninstall font')) {
                Uninstall-Font -Name $family.Name -Scope CurrentUser -ErrorAction Stop
            }
        }
    }
}

function Remove-AllNerdFont {
    <#
        .SYNOPSIS
        Removes all installed Nerd Font families.
    #>
    [OutputType([void])]
    [CmdletBinding(SupportsShouldProcess)]
    param()

    $removeParams = @{
        Names   = (Get-NerdFont).Name
        WhatIf  = $WhatIfPreference
        Confirm = $false
    }
    Remove-NerdFont @removeParams
}

function Measure-InstallScenario {
    <#
        .SYNOPSIS
        Measures one setup and action pair.
    #>
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [scriptblock] $Setup,

        [Parameter(Mandatory)]
        [scriptblock] $Action,

        [Parameter(Mandatory)]
        [string] $ResultsPath
    )

    Write-Verbose "[$Iteration] Setup    : $Name"
    $null = & $Setup
    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()

    Write-Verbose "[$Iteration] Measure  : $Name"
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $errorMessage = $null
    try {
        $null = & $Action
    } catch {
        $errorMessage = $_.ToString()
    }
    $stopwatch.Stop()

    $result = [pscustomobject]@{
        Iteration  = $Iteration
        Scenario   = $Name
        DurationMs = [int] $stopwatch.Elapsed.TotalMilliseconds
        DurationS  = [Math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
        Timestamp  = (Get-Date).ToString('o')
        Error      = $errorMessage
        Module     = (Get-Module -Name NerdFonts).Version.ToString()
    }

    Write-Verbose "[$Iteration] Result   : $Name -> $($result.DurationS)s"
    $result | ConvertTo-Json -Compress | Add-Content -Path $ResultsPath
    return $result
}

$results = [System.Collections.Generic.List[object]]::new()

$singleFontScenario = @{
    Name        = 'Single-Hack'
    Setup       = { Remove-NerdFont -Names 'Hack' -Confirm:$false }
    Action      = { Install-NerdFont -Name 'Hack' -Scope CurrentUser -Force }
    ResultsPath = $ResultsPath
}
$results.Add((Measure-InstallScenario @singleFontScenario))

$subsetScenario = @{
    Name        = "Subset-$($Subset -join '+')"
    Setup       = { Remove-NerdFont -Names $Subset -Confirm:$false }
    Action      = { Install-NerdFont -Name $Subset -Scope CurrentUser -Force }
    ResultsPath = $ResultsPath
}
$results.Add((Measure-InstallScenario @subsetScenario))

$alreadyInstalledScenario = @{
    Name        = 'Subset-AlreadyInstalled'
    Setup       = { Install-NerdFont -Name $Subset -Scope CurrentUser -Force }
    Action      = { Install-NerdFont -Name $Subset -Scope CurrentUser }
    ResultsPath = $ResultsPath
}
$results.Add((Measure-InstallScenario @alreadyInstalledScenario))

if ($IncludeAll) {
    $allScenario = @{
        Name        = 'All'
        Setup       = { Remove-AllNerdFont -Confirm:$false }
        Action      = { Install-NerdFont -All -Scope CurrentUser -Force }
        ResultsPath = $ResultsPath
    }
    $results.Add((Measure-InstallScenario @allScenario))
}

Write-Verbose "Summary for iteration '$Iteration':"
$results | Format-Table Iteration, Scenario, DurationS, Module -AutoSize
