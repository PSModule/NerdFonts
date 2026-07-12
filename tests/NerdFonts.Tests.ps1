#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

﻿#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

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
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -EQ 'Tinos' | Select-Object -First 1

            $testFonts = @(
                [pscustomobject]@{
                    Name = 'BrokenDownloadTest'
                    URL  = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/does-not-exist.zip'
                },
                $goodFont
            )
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Install-Font {}
                { Install-NerdFont -Name @('BrokenDownloadTest', 'Tinos') -Force -ErrorAction SilentlyContinue } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Skips already installed fonts without downloading' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'AlreadyInstalledTest'
                    URL  = 'https://example.invalid/already-installed.zip'
                }
            )
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'AlreadyInstalledTest Nerd Font' }
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name 'AlreadyInstalledTest' -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 0 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Installs a font with -Variant Mono' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -EQ 'Hack' | Select-Object -First 1
            $testFonts = @($goodFont)
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                $script:TestCapturedFiles = $null
                Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                    $script:TestCapturedFiles = @(
                        Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                            Select-Object -ExpandProperty Name
                    )
                    $true
                }

                { Install-NerdFont -Name 'Hack' -Variant Mono -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
                $script:TestCapturedFiles | Should -Not -BeNullOrEmpty
                $script:TestCapturedFiles | ForEach-Object { $_ | Should -BeLike '*NerdFontMono*' }
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Installs a font with -Variant Standard' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -EQ 'Hack' | Select-Object -First 1
            $testFonts = @($goodFont)
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                $script:TestCapturedFiles = $null
                Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                    $script:TestCapturedFiles = @(
                        Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                            Select-Object -ExpandProperty Name
                    )
                    $true
                }

                { Install-NerdFont -Name 'Hack' -Variant Standard -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
                $script:TestCapturedFiles | Should -Not -BeNullOrEmpty
                $script:TestCapturedFiles | ForEach-Object {
                    $_ | Should -BeLike '*NerdFont*'
                    $_ | Should -Not -BeLike '*NerdFontMono*'
                    $_ | Should -Not -BeLike '*NerdFontPropo*'
                }
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Installs a font with -Variant Propo' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -EQ 'Hack' | Select-Object -First 1
            $testFonts = @($goodFont)
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                $script:TestCapturedFiles = $null
                Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                    $script:TestCapturedFiles = @(
                        Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                            Select-Object -ExpandProperty Name
                    )
                    $true
                }

                { Install-NerdFont -Name 'Hack' -Variant Propo -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
                $script:TestCapturedFiles | Should -Not -BeNullOrEmpty
                $script:TestCapturedFiles | ForEach-Object { $_ | Should -BeLike '*NerdFontPropo*' }
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Handles -All without downloading already installed fonts' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'AllPathSmokeTest'
                    URL  = 'https://example.invalid/all-path-smoke.zip'
                }
            )
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'AllPathSmokeTest Nerd Font' }
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -All -Verbose -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 0 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Throws when -Scope AllUsers without admin rights' {
            Mock -ModuleName NerdFonts IsAdmin { $false }
            { Install-NerdFont -Name 'Tinos' -Scope AllUsers -ErrorAction Stop } | Should -Throw '*Administrator*'
        }

        It 'Install-NerdFont - Falls back to download when cache read fails' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $loadedFonts = Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json') | ConvertFrom-Json
            $goodFont = $loadedFonts | Where-Object Name -EQ 'Tinos' | Select-Object -First 1
            $fontName = $goodFont.Name
            $cacheRoot = if ($IsWindows) {
                Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'PSModule/NerdFonts/cache'
            } else {
                Join-Path $HOME '.cache/PSModule/NerdFonts'
            }
            $cacheTag = if ($goodFont.URL -match '/releases/download/([^/]+)/') { $Matches[1] } else { 'unknown' }
            $cacheTagDir = Join-Path $cacheRoot $cacheTag
            $downloadFileName = Split-Path -Path $goodFont.URL -Leaf
            $cachedFile = Join-Path $cacheTagDir $downloadFileName

            # Backup any existing real cache entry to restore after the test
            $backupPath = "$cachedFile.test-bak"
            $hadExistingCacheRoot = Test-Path -LiteralPath $cacheRoot
            $hadExistingCache = Test-Path -LiteralPath $cachedFile
            $hadExistingTagDir = Test-Path -LiteralPath $cacheTagDir
            if ($hadExistingCache) {
                Copy-Item -LiteralPath $cachedFile -Destination $backupPath -Force
            }

            $testFonts = @($goodFont)
            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                # Place a regular placeholder file so Test-Path returns true for cache-hit detection
                if (-not (Test-Path -LiteralPath $cacheTagDir)) {
                    $null = New-Item -ItemType Directory -Path $cacheTagDir -Force
                }
                Set-Content -LiteralPath $cachedFile -Value 'placeholder'

                Mock -ModuleName NerdFonts Get-Font { @() }
                Mock -ModuleName NerdFonts Install-Font {}
                # Mock Copy-Item to throw only for the cache-read path, simulating
                # a locked/unreadable cached file cross-platform.
                Mock -ModuleName NerdFonts Copy-Item {
                    throw 'Simulated cache read failure'
                } -ParameterFilter { $LiteralPath -and $LiteralPath -eq $cachedFile }

                # Should not throw — falls back to download
                { Install-NerdFont -Name $fontName -Force:$false -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
            } finally {
                # Restore original cache state so no user/CI state is mutated
                if ($hadExistingCache) {
                    Move-Item -LiteralPath $backupPath -Destination $cachedFile -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-Item -LiteralPath $cachedFile -Force -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath $backupPath -Force -ErrorAction SilentlyContinue
                }
                if (-not $hadExistingTagDir -and (Test-Path -LiteralPath $cacheTagDir)) {
                    Remove-Item -LiteralPath $cacheTagDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (-not $hadExistingCacheRoot -and (Test-Path -LiteralPath $cacheRoot)) {
                    Remove-Item -LiteralPath $cacheRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Deduplicates variant files from cached archives' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'DuplicateMonoTest'
            $cacheRoot = if ($IsWindows) {
                Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'PSModule/NerdFonts/cache'
            } else {
                Join-Path -Path $HOME -ChildPath '.cache/PSModule/NerdFonts'
            }
            $cacheTagDir = Join-Path -Path $cacheRoot -ChildPath 'test-dedup-v0'
            $zipPath = Join-Path -Path $cacheTagDir -ChildPath 'DuplicateMonoTest.zip'
            $hadExistingCacheRoot = Test-Path -LiteralPath $cacheRoot

            try {
                if (-not (Test-Path -LiteralPath $cacheTagDir)) {
                    $null = New-Item -ItemType Directory -Path $cacheTagDir -Force
                }

                $zipRoot = Join-Path -Path $TestDrive -ChildPath 'dup-zip'
                $primaryDir = Join-Path -Path $zipRoot -ChildPath 'Primary'
                $compatDir = Join-Path -Path $zipRoot -ChildPath 'Windows Compatible'
                $null = New-Item -ItemType Directory -Path $primaryDir -Force
                $null = New-Item -ItemType Directory -Path $compatDir -Force

                $fileName = 'DuplicateMonoTestNerdFontMono-Regular.ttf'
                Set-Content -Path (Join-Path -Path $primaryDir -ChildPath $fileName) -Value 'primary'
                Set-Content -Path (Join-Path -Path $compatDir -ChildPath $fileName) -Value 'compat'

                Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
                if (Test-Path -LiteralPath $zipPath) {
                    Remove-Item -LiteralPath $zipPath -Force
                }
                [System.IO.Compression.ZipFile]::CreateFromDirectory($zipRoot, $zipPath)

                $testFonts = @(
                    [pscustomobject]@{
                        Name = $fontName
                        URL  = 'https://github.com/ryanoasis/nerd-fonts/releases/download/test-dedup-v0/DuplicateMonoTest.zip'
                    }
                )
                InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }

                Mock -ModuleName NerdFonts Get-Font { @() }
                $script:TestCapturedFiles = $null
                Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                    $script:TestCapturedFiles = @(
                        Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                            Select-Object -ExpandProperty Name
                    )
                    $true
                }

                { Install-NerdFont -Name $fontName -Variant Mono -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
                $script:TestCapturedFiles.Count | Should -Be 1
                ($script:TestCapturedFiles | Select-Object -Unique).Count | Should -Be 1
            } finally {
                if (Test-Path -LiteralPath $cacheTagDir) {
                    Remove-Item -LiteralPath $cacheTagDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (-not $hadExistingCacheRoot -and (Test-Path -LiteralPath $cacheRoot)) {
                    Remove-Item -LiteralPath $cacheRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }
    }
}
