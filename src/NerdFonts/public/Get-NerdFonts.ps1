function Get-NerdFonts {
    param (
        [Parameter()]
        [SupportsWildcards()]
        [string] $Name
    )

    $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -Verbose:$false
    $version = $release.tag_name
    $assets = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' -and $_ -like "*$Name*" } | Sort-Object
    $nerdFonts = @()
    foreach ($asset in $assets) {
        $nerdFonts += [pscustomobject]@{
            Name    = $asset.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $asset
        }
    }
    return $nerdFonts
}
