# Download nerd fonts
# https://www.nerdfonts.com/font-downloads

function Get-NerdFonts {
    param ()

    $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    $version = $release.tag_name
    $assets = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' }

    foreach ($asset in $assets) {
        [pscustomobject]@{
            Name    = $asset.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $asset
        }
    }
}

function Install-NerdFont {
    [CmdletBinding(
        DefaultParameterSetName = 'Name'
    )]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'Name'
        )]
        [ValidateNotNullOrEmpty()]
        [ValidateSet({ Get-NerdFonts })]
        [string] $Name,

        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'All'
        )]
        [switch] $All,

        [Parameter(
            Position = 1,
            ParameterSetName = '__AllParameterSets'
        )]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser'
    )

    if ($All) {
        $NerdFonts = $script:NerdFonts
    } else {
        $NerdFonts = $script:NerdFonts | Where-Object Name -EQ $Name
    }

    foreach ($NerdFont in $NerdFonts) {
        $URL = $NerdFont.URL
        $FontName = $NerdFont.Name
        $downloadPath = "$env:TEMP\$FontName.zip"
        $extractPath = "$env:TEMP\$FontName"

        Write-Verbose "[$FontName] - Downloading to [$downloadPath]"
        $storedProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue' # Suppress progress bar
        Invoke-WebRequest -Uri $URL -OutFile $downloadPath -Verbose:$false
        $ProgressPreference = $storedProgressPreference

        Write-Verbose "[$FontName] - Unpack to [$extractPath]"
        Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
        Remove-Item -Path $downloadPath -Force

        Write-Verbose "[$FontName] - Install to [$Scope]"
        Install-Font -Path $extractPath -Scope $Scope
        Remove-Item -Path $extractPath -Force -Recurse
    }
}

Export-ModuleMember -Function '*' -Alias '*' -Variable '*' -Cmdlet '*'
