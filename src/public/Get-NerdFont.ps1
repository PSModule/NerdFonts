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
    Write-Verbose "Latest release: $version"
    Write-Verbose "Selecting assets by name: '$Name'"
    $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' } | ForEach-Object {
        [pscustomobject]@{
            Name    = $_.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $_
        }
    } | Where-Object { $_.Name -like "$Name" }
}
