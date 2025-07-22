function Invoke-NativeCommand {
    <#
        .SYNOPSIS
        Executes a native command with arguments.
    #>
    [Alias('Exec', 'Run')]
    [CmdletBinding()]
    param (
        # The command to execute
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$Command
    )
    $cmd = $Command[0]
    $arguments = $Command[1..$Command.Length]
    Write-Debug "Command: $cmd"
    Write-Debug "Arguments: $($arguments -join ', ')"
    $fullCommand = "$cmd $($arguments -join ' ')"

    try {
        Write-Verbose "Executing: $fullCommand"
        & $cmd @arguments
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
            Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
        }
    } catch {
        throw
    }
}

$currentBranch = (Run git rev-parse --abbrev-ref HEAD).Trim()
$defaultBranch = (Run git remote show origin | Select-String 'HEAD branch:' | ForEach-Object { $_.ToString().Split(':')[1].Trim() })
Write-Output "Current branch: $currentBranch"
Write-Output "Default branch: $defaultBranch"

Run git fetch origin
Run git checkout $defaultBranch
Run git pull origin $defaultBranch

$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if ($currentBranch -eq $defaultBranch) {
    # Running on main/default branch - create new branch
    $targetBranch = "auto-update-font-$timeStamp"
    Write-Output "Running on default branch. Creating new branch: $targetBranch"
    Run git checkout -b $targetBranch
} else {
    # Running on another branch (e.g., workflow_dispatch) - use current branch
    $targetBranch = $currentBranch
    Write-Output "Running on feature branch. Using existing branch: $targetBranch"
    Run git checkout $targetBranch
    # Merge latest changes from default branch
    Run git merge origin/$defaultBranch
}

LogGroup 'Latest Fonts' {
    $release = Get-GitHubRelease -Owner ryanoasis -Repository nerd-fonts
    $fonts = @()
    $fontAssets = $release | Get-GitHubReleaseAsset | Where-Object { $_.Name -like '*.zip' }

    foreach ($fontArchive in $fontAssets) {
        $fonts += [PSCustomObject]@{
            Name = $fontArchive.Name.Split('.')[0]
            URL  = $fontArchive.Url
        }
    }

    $fonts | Sort-Object Name | Format-Table -AutoSize | Out-String
}

$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path $filePath -Force

$changes = Run git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Output 'No changes detected.'
    return
}

Write-Output 'Changes detected:'
Write-Output $changes

Write-Output 'Diff of changes to be committed:'
Run git diff HEAD -- src/FontsData.json

Run git add .
Run git commit -m "Update-FontsData via script on $timeStamp"
Write-Output 'Changes in this commit:'
Run git diff HEAD~1 HEAD -- src/FontsData.json

# Push behavior depends on branch type
if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
    # Push to existing branch
    Run git push origin $targetBranch
    Write-Output "Changes committed and pushed to existing branch: $targetBranch"
} else {
    # Push new branch and create PR
    Run git push --set-upstream origin $targetBranch

    Run gh pr create `
        --base $defaultBranch `
        --head $targetBranch `
        --title "Auto-Update: NerdFonts Data ($timeStamp)" `
        --body 'This PR updates FontsData.json with the latest NerdFonts metadata.'

    Write-Output "Changes detected and PR opened for branch: $targetBranch"
}
