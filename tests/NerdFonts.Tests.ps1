[CmdletBinding()]
Param(
    # Path to the module to test.
    [Parameter()]
    [string] $Path
)

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
}
