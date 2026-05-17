#Requires -Modules @{ ModuleName = 'Pester'; RequiredVersion = '5.7.1' }

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester grouping syntax: known issue.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Used to create a secure string for testing.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingWriteHost', '',
    Justification = 'Log outputs to GitHub Actions logs.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidLongLines', '',
    Justification = 'Long test descriptions and skip switches'
)]
[CmdletBinding()]
param()

Describe 'Module' {
    Context 'Function: Get-NerdFont' {
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
        It 'Install-NerdFont - Installs a font' {
            { Install-NerdFont -Name 'Tinos' } | Should -Not -Throw
            Get-Font -Name 'Tinos*' | Should -Not -BeNullOrEmpty
        }

        It 'Install-NerdFont - Continues when one queued download fails' {
            . (Join-Path -Path $PSScriptRoot -ChildPath '..\src\functions\public\Install-NerdFont.ps1')

            $originalFonts = $script:NerdFonts
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\src\FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -eq 'Tinos' | Select-Object -First 1

            $script:NerdFonts = @(
                [pscustomobject]@{
                    Name = 'BrokenDownloadTest'
                    URL  = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/does-not-exist.zip'
                },
                $goodFont
            )

            try {
                Mock Install-Font {}
                { Install-NerdFont -Name @('BrokenDownloadTest', 'Tinos') -Force -ErrorAction SilentlyContinue } | Should -Not -Throw
                Should -Invoke Install-Font -Times 1 -Exactly
            } finally {
                $script:NerdFonts = $originalFonts
            }
        }

        It 'Install-NerdFont - Skips already installed fonts without downloading' {
            . (Join-Path -Path $PSScriptRoot -ChildPath '..\src\functions\public\Install-NerdFont.ps1')

            $originalFonts = $script:NerdFonts
            $script:NerdFonts = @(
                [pscustomobject]@{
                    Name = 'AlreadyInstalledTest'
                    URL  = 'https://example.invalid/already-installed.zip'
                }
            )

            try {
                Mock Get-Font {
                    [pscustomobject]@{ Name = 'AlreadyInstalledTest Nerd Font' }
                }
                Mock Install-Font {}

                { Install-NerdFont -Name 'AlreadyInstalledTest' -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke Install-Font -Times 0 -Exactly
            } finally {
                $script:NerdFonts = $originalFonts
            }
        }

        It 'Install-NerdFont - Installs a font with -Variant Mono' {
            { Install-NerdFont -Name 'Hack' -Variant Mono -Force } | Should -Not -Throw
            Get-Font -Name 'Hack*' | Should -Not -BeNullOrEmpty
        }

        It 'Install-NerdFont - Installs all fonts' {
            { Install-NerdFont -All -Verbose } | Should -Not -Throw
            Get-Font -Name 'VictorMono*' | Should -Not -BeNullOrEmpty
        }
    }
}
