function Invoke-NativeCommand {
    <#
        .SYNOPSIS
        Executes a native command with arguments.
    #>
    [Alias('Exec', 'Run')]
    [CmdletBinding()]
    param (
        # The command to execute
        [Parameter(Mandatory, Position = 0)]
        [string]$Command,

        # The arguments to pass to the command
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    Write-Debug "Command: $Command"
    Write-Debug "Arguments: $($Arguments -join ', ')"
    $fullCommand = "$Command $($Arguments -join ' ')"

    try {
        Write-Verbose "Executing: $fullCommand"
        & $Command @Arguments
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
            Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
        }
    } catch {
        throw
    }
}

# Get the current branch and default branch information
$currentBranch = (Invoke-NativeCommand git rev-parse --abbrev-ref HEAD).Trim()
$defaultBranch = (Invoke-NativeCommand git remote show origin | Select-String 'HEAD branch:' | ForEach-Object { $_.ToString().Split(':')[1].Trim() })

Write-Output "Current branch: $currentBranch"
Write-Output "Default branch: $defaultBranch"

# Fetch latest changes from remote
Invoke-NativeCommand git fetch origin

# Get the head branch (latest default branch)
Invoke-NativeCommand git checkout $defaultBranch
Invoke-NativeCommand git pull origin $defaultBranch

$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Determine target branch based on current context
if ($currentBranch -eq $defaultBranch) {
    # Running on main/default branch - create new branch
    $targetBranch = "auto-font-update-$timeStamp"
    Write-Output "Running on default branch. Creating new branch: $targetBranch"
    Invoke-NativeCommand git checkout -b $targetBranch
} else {
    # Running on another branch (e.g., workflow_dispatch) - use current branch
    $targetBranch = $currentBranch
    Write-Output "Running on feature branch. Using existing branch: $targetBranch"
    Invoke-NativeCommand git checkout $targetBranch
    # Merge latest changes from default branch
    Invoke-NativeCommand git merge origin/$defaultBranch
}

$release = Get-GitHubRelease -Owner ryanoasis -Repository nerd-fonts
$fonts = @()
$fontAssets = $release | Get-GitHubReleaseAsset | Where-Object { $_.Name -like '*.zip' }

foreach ($fontArchive in $fontAssets) {
    $fonts += [PSCustomObject]@{
        Name = $fontArchive.Name.Split('.')[0]
        URL  = $fontArchive.Url
    }
}

LogGroup 'Latest Fonts' {
    $fonts | Sort-Object Name | Format-Table -AutoSize | Out-String
}

$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path $filePath -Force

$changes = Invoke-NativeCommand git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
    Invoke-NativeCommand git add .
    Invoke-NativeCommand git commit -m "Update-FontsData via script on $timeStamp"

    # Push behavior depends on branch type
    if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
        # Push to existing branch
        Invoke-NativeCommand git push origin $targetBranch
        Write-Output "Changes committed and pushed to existing branch: $targetBranch"
    } else {
        # Push new branch and create PR
        Invoke-NativeCommand git push --set-upstream origin $targetBranch

        Invoke-NativeCommand gh pr create `
            --base $defaultBranch `
            --head $targetBranch `
            --title "Auto-Update: NerdFonts Data ($timeStamp)" `
            --body 'This PR updates FontsData.json with the latest NerdFonts metadata.'

        Write-Output "Changes detected and PR opened for branch: $targetBranch"
    }
} else {
    Write-Output 'No changes to commit.'
}
