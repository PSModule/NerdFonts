# Download nerd fonts
# https://www.nerdfonts.com/font-downloads

function Get-NerdFontsReleases {
    param (
        [switch] $Latest,
        [switch] $AllowPrerelease
    )

    $semverVersionPattern = [regex]'\d+\.\d+\.\d+(-\w+)?'

    $releases = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases'

    $releaseTagNames = $releases.tag_name
    $releaseVersions = $releaseTagNames | ForEach-Object { $semverVersionPattern.Match($_).Value } | Sort-Object

    if (-not $AllowPrerelease) {
        $releaseVersions = $releaseVersions | Where-Object { $_ -notlike '*-*' }
    }

    if ($Latest) {
        return $releaseVersions[-1]
    }

    return $releaseVersions
}

function Get-NerdFontsNames {
    param(
        [switch] $Latest,
        [switch] $AllowPrerelease
    )
    if ($Latest) {
        $latest = Get-NerdFontsReleases -Latest -AllowPrerelease:$AllowPrerelease
    } else {
        $latest = Get-NerdFontsReleases -AllowPrerelease:$AllowPrerelease
    }
    $latest = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    $packages = $latest.assets.browser_download_url | Where-Object { $_ -like '*.zip' }
    $fontNames = $packages | ForEach-Object { $_.Split('/')[-1].Split('.')[0] }
    $fontNames
}

function Get-NerdFonts {
    param(
        [string[]] $Name,
        [string[]] $Version,
        [switch] $Latest,
        [switch] $AllowPrerelease
    )

    begin {
        $versionPattern = [regex]'\d+\.\d+\.\d+(-\w+)?'
    }

    process {
        foreach ($NerdFontsPath in $Path) {
            $NerdFontsVersionOutput = & $NerdFontsPath --version
            $version = $versionPattern.Match($NerdFontsVersionOutput).Value
            [pscustomobject]@{
                Path    = $NerdFontsPath
                Version = $version
            }
        }
    }
}
