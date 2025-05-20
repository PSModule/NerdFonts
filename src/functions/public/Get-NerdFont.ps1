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

        .LINK
        https://psmodule.io/NerdFonts/Functions/Get-NerdFont

        .NOTES
        More information about the NerdFonts can be found at:
        - [NerdFonts | Website](https://www.nerdfonts.com/)
        - [NerdFonts | GitHub](https://github.com/ryanoasis/nerd-fonts)
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
