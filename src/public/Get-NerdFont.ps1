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

    Write-Verbose "Selecting assets by name: '$Name'"
    $script:NerdFonts | Where-Object { $_.Name -like $Name }
}
