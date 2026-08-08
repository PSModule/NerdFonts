#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '6.0.0'; MaximumVersion = '6.*' }

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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', '',
    Justification = 'Pester mock parameters mirror the invoked command signature.'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSProvideCommentHelp', '',
    Justification = 'Test-only archive helper is not part of the module interface.'
)]
[CmdletBinding()]
param()

Describe 'Module' {
    BeforeAll {
        function script:New-TestFontArchive {
            param(
                [Parameter(Mandatory)]
                [string] $ArchivePath,

                [Parameter(Mandatory)]
                [string[]] $FileNames
            )

            $archiveRoot = Join-Path -Path $TestDrive -ChildPath ([Guid]::NewGuid().ToString('N'))
            $null = New-Item -ItemType Directory -Path $archiveRoot -Force
            foreach ($fileName in $FileNames) {
                Set-Content -Path (Join-Path -Path $archiveRoot -ChildPath $fileName) -Value 'test-font'
            }

            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
            [System.IO.Compression.ZipFile]::CreateFromDirectory($archiveRoot, $ArchivePath)
        }
    }

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

        It 'Install-NerdFont - Continues when one downloaded archive cannot be extracted' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $validArchivePath = Join-Path -Path $TestDrive -ChildPath 'valid-archive.zip'
            New-TestFontArchive -ArchivePath $validArchivePath -FileNames 'ValidArchiveTestNerdFont-Regular.ttf'
            $testFonts = @(
                [pscustomobject]@{
                    Name = 'BrokenArchiveTest'
                    URL  = 'https://example.invalid/BrokenArchiveTest.zip'
                },
                [pscustomobject]@{
                    Name = 'ValidArchiveTest'
                    URL  = 'https://example.invalid/ValidArchiveTest.zip'
                }
            )

            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                Mock -ModuleName NerdFonts Get-NerdFontCacheRoot {
                    Join-Path -Path $TestDrive -ChildPath 'cache'
                }
                Mock -ModuleName NerdFonts Start-NerdFontDownload {
                    param($Uri, $DestinationPath)
                    if ($Uri.AbsoluteUri -like '*BrokenArchiveTest.zip') {
                        Set-Content -Path $DestinationPath -Value 'invalid archive'
                    } else {
                        Copy-Item -LiteralPath $validArchivePath -Destination $DestinationPath -Force
                    }
                    Start-ThreadJob -ScriptBlock {}
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name @('BrokenArchiveTest', 'ValidArchiveTest') -Force -ErrorAction SilentlyContinue } |
                    Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 2 -Exactly
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
                    [pscustomobject]@{ Name = 'AlreadyInstalledTestNerdFont-Regular' }
                }
                Mock -ModuleName NerdFonts Start-NerdFontDownload {}
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name 'AlreadyInstalledTest' -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 0 -Exactly
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 0 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Downloads with -Force when the family is installed' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'ForceDownloadTest'
            $testFonts = @(
                [pscustomobject]@{
                    Name = $fontName
                    URL  = 'https://example.invalid/force-download.zip'
                }
            )
            $script:TestArchivePath = Join-Path -Path $TestDrive -ChildPath 'force-download.zip'
            New-TestFontArchive -ArchivePath $script:TestArchivePath -FileNames 'ForceDownloadTestNerdFont-Regular.ttf'

            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'ForceDownloadTestNerdFont-Regular' }
                }
                Mock -ModuleName NerdFonts Get-NerdFontCacheRoot {
                    Join-Path -Path $TestDrive -ChildPath 'cache'
                }
                Mock -ModuleName NerdFonts Start-NerdFontDownload {
                    param($Uri, $DestinationPath)
                    Copy-Item -LiteralPath $script:TestArchivePath -Destination $DestinationPath -Force
                    Start-ThreadJob -ScriptBlock {}
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name $fontName -Force -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 1 -Exactly
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Downloads when the requested variant is missing' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'VariantSkipTest'
            $testFonts = @(
                [pscustomobject]@{
                    Name = $fontName
                    URL  = 'https://example.invalid/variant-skip.zip'
                }
            )
            $script:TestArchivePath = Join-Path -Path $TestDrive -ChildPath 'variant-skip.zip'
            New-TestFontArchive -ArchivePath $script:TestArchivePath -FileNames 'VariantSkipTestNerdFontMono-Regular.ttf'

            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font {
                    [pscustomobject]@{ Name = 'VariantSkipTestNerdFont-Regular' }
                }
                Mock -ModuleName NerdFonts Get-NerdFontCacheRoot {
                    Join-Path -Path $TestDrive -ChildPath 'cache'
                }
                Mock -ModuleName NerdFonts Start-NerdFontDownload {
                    param($Uri, $DestinationPath)
                    Copy-Item -LiteralPath $script:TestArchivePath -Destination $DestinationPath -Force
                    Start-ThreadJob -ScriptBlock {}
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name $fontName -Variant Mono -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 1 -Exactly
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Downloads each overlapping name match once' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'OverlappingNameTest'
            $testFonts = @(
                [pscustomobject]@{
                    Name = $fontName
                    URL  = 'https://example.invalid/overlapping-name.zip'
                }
            )
            $script:TestArchivePath = Join-Path -Path $TestDrive -ChildPath 'overlapping-name.zip'
            New-TestFontArchive -ArchivePath $script:TestArchivePath -FileNames 'OverlappingNameTestNerdFont-Regular.ttf'

            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                Mock -ModuleName NerdFonts Get-NerdFontCacheRoot {
                    Join-Path -Path $TestDrive -ChildPath 'cache'
                }
                Mock -ModuleName NerdFonts Start-NerdFontDownload {
                    param($Uri, $DestinationPath)
                    Copy-Item -LiteralPath $script:TestArchivePath -Destination $DestinationPath -Force
                    Start-ThreadJob -ScriptBlock {}
                }
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name "$fontName*", $fontName -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 1 -Exactly
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
            } finally {
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Does not copy or download archives with -WhatIf' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'WhatIfCacheTest'
            $testFonts = @(
                [pscustomobject]@{
                    Name = $fontName
                    URL  = 'https://github.com/ryanoasis/nerd-fonts/releases/download/test-whatif/WhatIfCacheTest.zip'
                }
            )
            $cacheRoot = Join-Path -Path $TestDrive -ChildPath 'cache'
            $cacheTagDir = Join-Path -Path $cacheRoot -ChildPath 'test-whatif'
            $cachedFile = Join-Path -Path $cacheTagDir -ChildPath 'WhatIfCacheTest.zip'
            $null = New-Item -ItemType Directory -Path $cacheTagDir -Force
            Set-Content -Path $cachedFile -Value 'cached archive'

            InModuleScope NerdFonts -Parameters @{ fonts = $testFonts } {
                param($fonts)
                $script:NerdFonts = $fonts
            }

            try {
                Mock -ModuleName NerdFonts Get-Font { @() }
                Mock -ModuleName NerdFonts Get-NerdFontCacheRoot { $cacheRoot }
                Mock -ModuleName NerdFonts Copy-Item {}
                Mock -ModuleName NerdFonts Start-NerdFontDownload {}
                Mock -ModuleName NerdFonts Install-Font {}

                { Install-NerdFont -Name $fontName -WhatIf -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Copy-Item -Times 0 -Exactly
                Should -Invoke -ModuleName NerdFonts Start-NerdFontDownload -Times 0 -Exactly
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
                $script:TestCapturedFiles | ForEach-Object {
                    $_ | Should -BeLike '*NerdFontMono*'
                    $_ | Should -Not -BeLike '*NerdFontPropo*'
                    $_ | Should -Not -BeLike '*NerdFont-*'
                }
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
            $cacheRoot = InModuleScope NerdFonts { Get-NerdFontCacheRoot }
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

            $fileLock = $null
            try {
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

                # Should not throw — falls back to download
                { Install-NerdFont -Name $fontName -Force:$false -ErrorAction Stop } | Should -Not -Throw
                Should -Invoke -ModuleName NerdFonts Install-Font -Times 1 -Exactly
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
                InModuleScope NerdFonts -Parameters @{ fonts = $originalFonts } {
                    param($fonts)
                    $script:NerdFonts = $fonts
                }
            }
        }

        It 'Install-NerdFont - Deduplicates variant files from cached archives' {
            $originalFonts = InModuleScope NerdFonts { $script:NerdFonts }
            $fontName = 'DuplicateMonoTest'
            $cacheRoot = InModuleScope NerdFonts { Get-NerdFontCacheRoot }
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
