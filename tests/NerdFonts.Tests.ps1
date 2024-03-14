Describe 'NerdFonts' {
    Context 'Module' {
        It 'The module should be available' {
            Get-Module -Name 'NerdFonts' -ListAvailable | Should -Not -BeNullOrEmpty
            Write-Verbose (Get-Module -Name 'NerdFonts' -ListAvailable | Out-String) -Verbose
        }
        It 'The module should be imported' {
            { Import-Module -Name 'NerdFonts' } | Should -Not -Throw
        }
    }
}
