function Get-NerdFont {
    <#
        .SYNOPSIS
        Get NerdFonts list

        .DESCRIPTION
        Get NerdFonts list, filtered by name, from the latest release.

        .EXAMPLE
        Get-NerdFonts

        Get all the NerdFonts.

        .EXAMPLE
        Get-NerdFonts -Name 'FiraCode'

        Get the NerdFont with the name 'FiraCode'.

        .EXAMPLE
        Get-NerdFonts -Name '*Code'

        Get the NerdFont with the name ending with 'Code'.
    #>
    [Alias('Get-NerdFonts')]
    [OutputType([System.Object[]])]
    [CmdletBinding()]
    param (
        # Name of the NerdFont to get
        [Parameter()]
        [SupportsWildcards()]
        [string] $Name = '*'
    )

    Write-Verbose 'Selecting assets by:'
    Write-Verbose "Name:    [$Name]"
    $script:NerdFonts | Where-Object { $_.Name -like $Name }
}
