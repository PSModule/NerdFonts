#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.1.0'; MaximumVersion = '6.*' }

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

BeforeAll {
    function Use-TestFontData {
        <#
            .SYNOPSIS
            Runs a test body against a replaced module-internal font catalog.

            .DESCRIPTION
            Swaps $script:NerdFonts inside the NerdFonts module for the supplied font objects, runs the
            body, and restores the original catalog afterwards even when the body fails.

            .EXAMPLE
            Use-TestFontData -Fonts $testFonts -Body { Install-NerdFont -Name 'Test' }

            Installs against the test catalog and restores the real catalog when finished.
        #>
        param(
            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [object[]] $Fonts,

            [Parameter(Mandatory)]
            [scriptblock] $Body
        )

        $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
        InModuleScope NerdFonts -Parameters @{ fonts = $Fonts } {
            param($fonts)
            $script:NerdFonts = $fonts
        }
        try {
            & $Body
        } finally {
            InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }
        }
    }

    function Get-TestFont {
        <#
            .SYNOPSIS
            Gets a single font entry from the repository's FontsData.json.

            .DESCRIPTION
            Reads the source FontsData.json and returns the first entry whose name matches exactly, so
            tests can build catalogs from real font metadata instead of hard-coded URLs.

            .EXAMPLE
            Get-TestFont -Name 'Tinos'

            Returns the Tinos font entry.
        #>
        param(
            [Parameter(Mandatory)]
            [string] $Name
        )

        $fontsDataPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/FontsData.json'
        Get-Content -Path $fontsDataPath | ConvertFrom-Json | Where-Object Name -EQ $Name | Select-Object -First 1
    }

    function Get-TestCacheRoot {
        <#
            .SYNOPSIS
            Gets the platform-specific NerdFonts download cache root.

            .DESCRIPTION
            Mirrors the cache root that Install-NerdFont computes, so tests can seed and clean up cache
            entries on the same path the function uses.

            .EXAMPLE
            Get-TestCacheRoot

            Returns the cache root path for the current platform.
        #>
        if ($IsWindows) {
            Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'PSModule/NerdFonts/cache'
        } else {
            Join-Path -Path $HOME -ChildPath '.cache/PSModule/NerdFonts'
        }
    }
}

Describe 'Module' {
    Context 'Function: Get-NerdFont' {
        It 'Returns all fonts' {
            $fonts = Get-NerdFont
            Write-Verbose ($fonts | Out-String) -Verbose
            $fonts | Should-NotBeNull
        }

        It 'Returns a specific font' {
            $font = Get-NerdFont -Name 'Tinos'
            Write-Verbose ($font | Out-String) -Verbose
            $font | Should-NotBeNull
            $font.Name | Should-Be 'Tinos'
        }
    }

    Context 'Function: Install-NerdFont' {
        It 'Install-NerdFont - Installs a font' {
            Install-NerdFont -Name 'Tinos'
            Get-Font -Name 'Tinos*' | Should-NotBeNull
        }

        It 'Install-NerdFont - Continues when one queued download fails' {
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'BrokenDownloadTest'
                    URL  = 'https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/does-not-exist.zip'
                }
                Get-TestFont -Name 'Tinos'
            )

            Use-TestFontData -Fonts $testFonts -Body {
                Mock -ModuleName NerdFonts Install-Font {}

                Install-NerdFont -Name @('BrokenDownloadTest', 'Tinos') -Force -ErrorAction SilentlyContinue

                Should-Invoke -CommandName Install-Font -ModuleName NerdFonts -Times 1 -Exactly
            }
        }

        It 'Install-NerdFont - Skips already installed fonts without downloading' {
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'AlreadyInstalledTest'
                    URL  = 'https://example.invalid/already-installed.zip'
                }
            )

            Use-TestFontData -Fonts $testFonts -Body {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'AlreadyInstalledTest Nerd Font' }
                }
                Mock -ModuleName NerdFonts Install-Font {}

                Install-NerdFont -Name 'AlreadyInstalledTest' -ErrorAction Stop

                Should-NotInvoke -CommandName Install-Font -ModuleName NerdFonts
            }
        }

        It 'Install-NerdFont - Installs a font with -Variant <Variant>' -ForEach @(
            @{ Variant = 'Mono'; Expected = '*NerdFontMono*'; NotExpected = @() }
            @{ Variant = 'Propo'; Expected = '*NerdFontPropo*'; NotExpected = @() }
            @{ Variant = 'Standard'; Expected = '*NerdFont*'; NotExpected = @('*NerdFontMono*', '*NerdFontPropo*') }
        ) {
            $testFonts = @(Get-TestFont -Name 'Hack')

            Use-TestFontData -Fonts $testFonts -Body {
                Mock -ModuleName NerdFonts Get-Font { @() }
                $script:TestCapturedFiles = $null
                Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                    $script:TestCapturedFiles = @(
                        Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                            Select-Object -ExpandProperty Name
                    )
                    $true
                }

                Install-NerdFont -Name 'Hack' -Variant $Variant -ErrorAction Stop

                Should-Invoke -CommandName Install-Font -ModuleName NerdFonts -Times 1 -Exactly
                $script:TestCapturedFiles | Should-NotBeNull
                $script:TestCapturedFiles | Should-All { $_ -like $Expected }
                foreach ($pattern in $NotExpected) {
                    $script:TestCapturedFiles | Should-All { $_ -notlike $pattern }
                }
            }
        }

        It 'Install-NerdFont - Handles -All without downloading already installed fonts' {
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'AllPathSmokeTest'
                    URL  = 'https://example.invalid/all-path-smoke.zip'
                }
            )

            Use-TestFontData -Fonts $testFonts -Body {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'AllPathSmokeTest Nerd Font' }
                }
                Mock -ModuleName NerdFonts Install-Font {}

                Install-NerdFont -All -Verbose -ErrorAction Stop

                Should-NotInvoke -CommandName Install-Font -ModuleName NerdFonts
            }
        }

        It 'Install-NerdFont - Throws when -Scope AllUsers without admin rights' {
            Mock -ModuleName NerdFonts IsAdmin { $false }
            { Install-NerdFont -Name 'Tinos' -Scope AllUsers -ErrorAction Stop } |
                Should-Throw -ExceptionMessage '*Administrator*'
        }

        It 'Install-NerdFont - Falls back to download when cache read fails' {
            $goodFont = Get-TestFont -Name 'Tinos'
            $fontName = $goodFont.Name
            $cacheRoot = Get-TestCacheRoot
            $cacheTag = if ($goodFont.URL -match '/releases/download/([^/]+)/') { $Matches[1] } else { 'unknown' }
            $cacheTagDir = Join-Path -Path $cacheRoot -ChildPath $cacheTag
            $downloadFileName = Split-Path -Path $goodFont.URL -Leaf
            $cachedFile = Join-Path -Path $cacheTagDir -ChildPath $downloadFileName

            # Backup any existing real cache entry to restore after the test
            $backupPath = "$cachedFile.test-bak"
            $hadExistingCacheRoot = Test-Path -LiteralPath $cacheRoot
            $hadExistingCache = Test-Path -LiteralPath $cachedFile
            $hadExistingTagDir = Test-Path -LiteralPath $cacheTagDir
            if ($hadExistingCache) {
                Copy-Item -LiteralPath $cachedFile -Destination $backupPath -Force
            }

            $fileLock = $null
            try {
                Use-TestFontData -Fonts @($goodFont) -Body {
                    # Lock the cached file with an exclusive share so Copy-Item fails, forcing the
                    # function to fall back to a real download using live test data.
                    if (-not (Test-Path -LiteralPath $cacheTagDir)) {
                        $null = New-Item -ItemType Directory -Path $cacheTagDir -Force
                    }
                    if (Test-Path -LiteralPath $cachedFile) {
                        Remove-Item -LiteralPath $cachedFile -Recurse -Force -ErrorAction SilentlyContinue
                    }
                    Set-Content -LiteralPath $cachedFile -Value 'locked-cache-entry' -Force
                    $fileLock = [System.IO.File]::Open(
                        $cachedFile,
                        [System.IO.FileMode]::Open,
                        [System.IO.FileAccess]::Read,
                        [System.IO.FileShare]::None
                    )

                    Mock -ModuleName NerdFonts Get-Font { @() }
                    Mock -ModuleName NerdFonts Install-Font {}

                    # Falls back to a real download instead of failing on the unreadable cache entry.
                    Install-NerdFont -Name $fontName -Force:$false -ErrorAction Stop

                    Should-Invoke -CommandName Install-Font -ModuleName NerdFonts -Times 1 -Exactly
                }
            } finally {
                # Release the lock before restoring cache state.
                if ($fileLock) {
                    $fileLock.Dispose()
                    $fileLock = $null
                }
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
            }
        }

        It 'Install-NerdFont - Deduplicates variant files from cached archives' {
            $fontName = 'DuplicateMonoTest'
            $cacheRoot = Get-TestCacheRoot
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

                Use-TestFontData -Fonts $testFonts -Body {
                    Mock -ModuleName NerdFonts Get-Font { @() }
                    $script:TestCapturedFiles = $null
                    Mock -ModuleName NerdFonts Install-Font {} -ParameterFilter {
                        $script:TestCapturedFiles = @(
                            Get-ChildItem -Path $Path -Recurse -File -Include '*.ttf', '*.otf' |
                                Select-Object -ExpandProperty Name
                        )
                        $true
                    }

                    Install-NerdFont -Name $fontName -Variant Mono -ErrorAction Stop

                    Should-Invoke -CommandName Install-Font -ModuleName NerdFonts -Times 1 -Exactly
                    $script:TestCapturedFiles | Should-BeCollection -Count 1
                    ($script:TestCapturedFiles | Select-Object -Unique).Count | Should-Be 1
                }
            } finally {
                if (Test-Path -LiteralPath $cacheTagDir) {
                    Remove-Item -LiteralPath $cacheTagDir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if (-not $hadExistingCacheRoot -and (Test-Path -LiteralPath $cacheRoot)) {
                    Remove-Item -LiteralPath $cacheRoot -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
}
