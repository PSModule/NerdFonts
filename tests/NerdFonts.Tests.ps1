Describe 'Module' {
    Context 'Function: Get-NerdFont' {
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

    Context 'Function: Install-NerdFont' {
        It '[Install-NerdFont] - Exists' {
            Get-Command -Name Install-NerdFont | Should -Not -BeNullOrEmpty
        }

        It '[Install-NerdFont] - Installs a font' {
            { Install-NerdFont -Name 'Tinos' } | Should -Not -Throw
            Get-Font -Name 'Tinos*' | Should -Not -BeNullOrEmpty
        }

        It '[Install-NerdFont] - Installs all fonts' {
            { Install-NerdFont -All -Verbose } | Should -Not -Throw
            Get-Font -Name 'VictorMono*' | Should -Not -BeNullOrEmpty
        }
    }
}
