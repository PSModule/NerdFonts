Describe 'Get-NerdFont' {
    It 'Function exists' {
        Get-Command Get-NerdFont | Should -Not -BeNullOrEmpty
    }

    It 'Returns all fonts' {
        $fonts = Get-NerdFont
        Write-Verbose ($fonts | Out-String) -Verbose
        $fonts | Should -Not -BeNullOrEmpty
    }
}
