[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

Write-Verbose "Path to the module: [$Path]" -Verbose

Describe 'NerdFonts' {
    Context 'Module' {
        It 'The module should be available' {
            Get-Module -Name 'NerdFonts' -ListAvailable | Should -Not -BeNullOrEmpty
            Write-Verbose (Get-Module -Name 'NerdFonts' -ListAvailable | Out-String) -Verbose
        }
        It 'The module should be imported' {
            { Import-Module -Name 'NerdFonts' -Verbose -RequiredVersion 999.0.0 -Force } | Should -Not -Throw
        }
    }

    Context 'Get-NerdFont' {
        It 'Function exists' {
            Get-Command Get-NerdFont | Should -Not -BeNullOrEmpty
        }

        It 'Returns all fonts' {
            $fonts = Get-NerdFont
            Write-Verbose ($fonts | Out-String) -Verbose
            $fonts | Should -Not -BeNullOrEmpty
        }

        It 'Returns a specific font' {
            $font = Get-NerdFont -Name 'Tinos'
            Write-Verbose ($font | Out-String) -Verbose
            $font | Should -Not -BeNullOrEmpty
        }
    }
}
