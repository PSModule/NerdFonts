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
        $output = & $cmd @arguments
        if ($LASTEXITCODE -ne 0) {
            $errorMessage = "Command failed with exit code $LASTEXITCODE`: $fullCommand"
            Write-Error $errorMessage -ErrorId 'NativeCommandFailed' -Category OperationStopped -TargetObject $fullCommand
        }
        if ($output -is [array] -and $output.Count -gt 1) {
            return $output -join "`n"
        } else {
            return $output
        }
    } catch {
        throw
    }
}

Install-PSResource -Repository PSGallery -TrustRepository -Name 'Json'

Connect-GitHubApp -Organization 'PSModule' -Default
$repo = Get-GitHubRepository -Owner 'PSModule' -Name 'NerdFonts'

# Constants for PR management
$AUTO_UPDATE_PR_PREFIX = 'Auto-Update'

LogGroup 'Checkout' {
    $currentBranch = (Run git rev-parse --abbrev-ref HEAD).Trim()
    $defaultBranch = $repo.DefaultBranch

    Write-Output "Current branch: $currentBranch"
    Write-Output "Default branch: $defaultBranch"
    Run git fetch origin
    Run git checkout $defaultBranch
    Run git pull origin $defaultBranch

    $timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    if ($currentBranch -eq $defaultBranch) {
        # Running on main/default branch - create new branch
        $targetBranch = "auto-update-$timeStamp"
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
}

LogGroup 'Getting latest fonts' {
    $fonts = @()
    $release = Get-GitHubRelease -Owner ryanoasis -Repository nerd-fonts
    $fontAssets = $release | Get-GitHubReleaseAsset | Where-Object { $_.Name -like '*.zip' }

    foreach ($fontArchive in $fontAssets) {
        $fonts += [PSCustomObject]@{
            Name = $fontArchive.Name.Split('.')[0]
            URL  = $fontArchive.Url
        }
    }

    $fonts | Sort-Object Name | Format-Table -AutoSize | Out-String
    $parentFolder = Split-Path -Path $PSScriptRoot -Parent
    $filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
    $null = New-Item -Path $filePath -ItemType File -Force
    $fonts | ConvertTo-Json | Format-Json -IndentationType Spaces -IndentationSize 4 | Set-Content -Path $filePath -Force
}

$changes = Run git status --porcelain
if ([string]::IsNullOrWhiteSpace($changes)) {
    Write-Output 'No updates available.'
    Write-GitHubNotice 'No updates available.'
    return
}
LogGroup 'Get changes' {
    Run git add .
    Run git commit -m 'Update FontsData.json'
    Write-Output 'Changes in this commit:'
    $changes = Run git diff HEAD~1 HEAD -- src/FontsData.json
    Write-Output $changes
    Set-GitHubStepSummary @"
## Changes available

<details><summary>Details</summary>
<p>

``````diff
$changes
``````

</p>
</details>
"@

}

LogGroup 'Close superseded PRs' {
    Write-Output 'Checking for existing open font data update PRs...'
    
    # Get all open PRs with the auto-update prefix in the title
    $openPRsJson = Run gh pr list --state open --json number,title,headRefName --search "$AUTO_UPDATE_PR_PREFIX in:title"
    
    if (-not [string]::IsNullOrWhiteSpace($openPRsJson)) {
        $openPRs = $openPRsJson | ConvertFrom-Json
        
        if ($openPRs.Count -gt 0) {
            Write-Output "Found $($openPRs.Count) existing open font data update PR(s)"
            
            foreach ($pr in $openPRs) {
                # Skip the current branch if we're updating an existing PR
                if ($pr.headRefName -eq $targetBranch) {
                    Write-Output "Skipping PR #$($pr.number) as it's the current branch: $targetBranch"
                    continue
                }
                
                Write-Output "Closing superseded PR #$($pr.number): $($pr.title)"
                
                $supersedenceMessage = if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
                    "This PR has been superseded by updates to branch ``$targetBranch``."
                } else {
                    "This PR has been superseded by a newer font data update."
                }
                
                # Close the PR with a comment
                Run gh pr close $($pr.number) --comment $supersedenceMessage
                Write-Output "Closed PR #$($pr.number)"
            }
        } else {
            Write-Output 'No existing open font data update PRs found.'
        }
    } else {
        Write-Output 'No existing open font data update PRs found.'
    }
}

LogGroup 'Process changes' {
    if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
        Run git push origin $targetBranch
        Write-Output "Changes committed and pushed to existing branch: $targetBranch"
    } else {
        Run git push --set-upstream origin $targetBranch

        Run gh pr create `
            --base $defaultBranch `
            --head $targetBranch `
            --title "$AUTO_UPDATE_PR_PREFIX $timeStamp" `
            --body 'This PR updates FontsData.json with the latest metadata.'

        Write-Output "Changes detected and PR opened for branch: $targetBranch"
    }
}
