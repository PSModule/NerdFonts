function Get-NerdFont {
    <#
        .SYNOPSIS
        Get NerdFonts asset list

        .DESCRIPTION
        Get NerdFonts asset list, filtered by name, from the latest release.

        .EXAMPLE
        Get-NerdFonts -Name 'FiraCode'

        .EXAMPLE
        Get-NerdFonts -Name '*Code'
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'Name', Justification = 'PSScriptAnalyzer false positive')]
    [Alias('Get-NerdFonts')]
    [CmdletBinding()]
    param (
        # Name of the NerdFont to get
        [Parameter()]
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    $release = Invoke-RestMethod "$script:NerdFontsReleaseURL/latest" -Verbose:$false
    $version = $release.tag_name
    $assets = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' -and $_ -like "$Name" } | Sort-Object
    foreach ($asset in $assets) {
        [pscustomobject]@{
            Name    = $asset.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $asset
        }
    }
}
