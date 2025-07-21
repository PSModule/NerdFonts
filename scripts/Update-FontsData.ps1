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

Run git checkout main
Run git pull

# 2. Retrieve the date-time to create a unique branch name.
$timeStamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$branchName = "auto-font-update-$timeStamp"

# 3. Create a new branch for the changes.
Run git checkout -b $branchName

# 4. Retrieve the latest font data from Nerd Fonts.
$release = Get-GitHubRelease -Owner ryanoasis -Repository nerd-fonts
$fonts = @()
$fontAssets = $release | Get-GitHubReleaseAsset | Where-Object { $_.Name -like '*.zip' }

foreach ($fontArchive in $fontAssets) {
    $fonts += [PSCustomObject]@{
        Name = $fontArchive.Name.Split('.')[0]
        URL  = $fontArchive.Url
    }
}

# 5. Write results to FontsData.json.
$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'

# Make sure file exists (or overwrite).
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path $filePath -Force

# 6. Check if anything actually changed.
#    If git status --porcelain is empty, there are no new changes to commit.
$changes = Run git status --porcelain


if (-not [string]::IsNullOrWhiteSpace($changes)) {
    # 7. Commit and push changes.
    Run git add .
    Run git commit -m "Update-FontsData via script on $timeStamp"
    Run git push --set-upstream origin $branchName

    # 8. Create a PR via GitHub CLI.
    Run gh pr create `
        --base main `
        --head $branchName `
        --title "Auto-Update: NerdFonts Data ($timeStamp)" `
        --body 'This PR updates FontsData.json with the latest NerdFonts metadata.'

    Write-Output 'Changes detected and PR opened.'
} else {
    Write-Output 'No changes to commit.'
}
