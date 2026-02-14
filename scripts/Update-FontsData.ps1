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

$repoName = $env:GITHUB_REPOSITORY

Install-PSResource -Repository PSGallery -TrustRepository -Name 'Json'

Connect-GitHubApp -Organization 'PSModule' -Default
$repo = Get-GitHubRepository -Owner 'PSModule' -Name 'NerdFonts'

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

LogGroup 'Process changes' {
    if ($targetBranch -eq $currentBranch -and $currentBranch -ne $defaultBranch) {
        Run git push origin $targetBranch
        Write-Output "Changes committed and pushed to existing branch: $targetBranch"
    } else {
        Run git push --set-upstream origin $targetBranch

        Run gh pr create `
            --base $defaultBranch `
            --head $targetBranch `
            --title "Auto-Update $timeStamp" `
            --body 'This PR updates FontsData.json with the latest metadata.'

        Write-Output "Changes detected and PR opened for branch: $targetBranch"

        # Close any existing open Auto-Update PRs after creating the new one
        LogGroup 'Close superseded PRs' {
            Write-Output 'Checking for existing open Auto-Update PRs to supersede...'

            # Get the newly created PR with retry logic
            $newPRJson = $null
            $retryCount = 0
            $maxRetries = 3
            $retryDelays = @(1, 2, 3)  # Progressive delays in seconds
            while ($null -eq $newPRJson -and $retryCount -lt $maxRetries) {
                if ($retryCount -gt 0) {
                    Start-Sleep -Seconds $retryDelays[$retryCount - 1]
                }
                $newPRJson = Run gh pr list --repo $repoName --head $targetBranch --state open --json 'number,title' --limit 1
                $newPR = $newPRJson | ConvertFrom-Json | Select-Object -First 1
                if ($null -eq $newPR -or $null -eq $newPR.number) {
                    $newPR = $null
                    $newPRJson = $null
                }
                $retryCount++
                if ($null -eq $newPR -and $retryCount -lt $maxRetries) {
                    Write-Output "PR not found yet, retrying in $($retryDelays[$retryCount - 1]) seconds... (attempt $retryCount/$maxRetries)"
                }
            }

            if ($null -ne $newPR) {
                Write-Output "Found new PR #$($newPR.number): $($newPR.title)"

                # Find existing open Auto-Update PRs (excluding the one we just created)
                $existingPRsJson = Run gh pr list --repo $repoName --state open --search 'Auto-Update in:title' --json 'number,title,headRefName'
                $existingPRs = $existingPRsJson | ConvertFrom-Json | Where-Object { $_.number -ne $newPR.number }

                if ($existingPRs) {
                    Write-Output "Found $(@($existingPRs).Count) existing Auto-Update PR(s) to close."
                    foreach ($pr in $existingPRs) {
                        Write-Output "Closing PR #$($pr.number): $($pr.title)"

                        # Add a comment explaining the supersedence
                        $comment = @"
This PR has been superseded by #$($newPR.number) and will be closed automatically.

The font data has been updated in the newer PR. Please refer to #$($newPR.number) for the most current changes.
"@
                        Run gh pr comment $pr.number --repo $repoName --body $comment

                        # Close the PR
                        Run gh pr close $pr.number --repo $repoName

                        Write-Output "Successfully closed PR #$($pr.number)"

                        # Delete the branch associated with the closed PR
                        $branchName = $pr.headRefName
                        if ($branchName) {
                            Write-Output "Deleting branch: $branchName"
                            $null = Run gh api -X DELETE "repos/$repoName/git/refs/heads/$branchName"
                            if ($LASTEXITCODE -eq 0) {
                                Write-Output "Successfully deleted branch: $branchName"
                            } else {
                                Write-Warning "Failed to delete branch $branchName (exit code $LASTEXITCODE)"
                            }
                        } else {
                            Write-Warning "Could not determine branch name for PR #$($pr.number)"
                        }
                    }
                } else {
                    Write-Output 'No existing open Auto-Update PRs to close.'
                }
            } else {
                Write-Warning "Could not retrieve the newly created PR after $maxRetries attempts. Skipping supersedence logic."
            }
        }
    }
}
