#Requires -Modules @{ ModuleName = 'Fonts'; ModuleVersion = '1.1.0'; MaximumVersion = '1.999.999' }
#Requires -Modules @{ ModuleName = 'Admin'; ModuleVersion = '1.1.0'; MaximumVersion = '1.999.999' }

function Install-NerdFont {
    <#
        .SYNOPSIS
        Installs Nerd Fonts to the system.

        .DESCRIPTION
        Installs Nerd Fonts to the system.

        .EXAMPLE
        Install-NerdFont -Name 'Fira Code'

        Installs the font 'Fira Code' to the current user.

        .EXAMPLE
        Install-NerdFont -Name 'Ubuntu*'

        Installs all fonts that match the pattern 'Ubuntu*' to the current user.

        .EXAMPLE
        Install-NerdFont -Name 'Fira Code' -Scope AllUsers

        Installs the font 'Fira Code' to all users. This requires to be run as administrator.

        .EXAMPLE
        Install-NerdFont -All

        Installs all Nerd Fonts to the current user.

        .EXAMPLE
        Install-NerdFont -Name 'FiraCode' -Variant Mono

        Installs only the monospace variant of the font 'FiraCode' to the current user.

        .EXAMPLE
        Install-NerdFont -All -Variant Mono

        Installs only the monospace variant of all Nerd Fonts to the current user.

        .LINK
        https://psmodule.io/NerdFonts/Functions/Install-NerdFont/

        .NOTES
        More information about the NerdFonts can be found at:
        [NerdFonts](https://www.nerdfonts.com/) | [GitHub](https://github.com/ryanoasis/nerd-fonts)
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'ByName',
        SupportsShouldProcess
    )]
    [Alias('Install-NerdFonts')]
    param(
        # Specify the name of the NerdFont(s) to install.
        [Parameter(
            ParameterSetName = 'ByName',
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [SupportsWildcards()]
        [string[]] $Name,

        # Specify to install all NerdFont(s).
        [Parameter(
            ParameterSetName = 'All',
            Mandatory
        )]
        [switch] $All,

        [Parameter()]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser',

        # Select which variant(s) to install from each archive. Default 'All' preserves current behavior.
        [Parameter()]
        [ValidateSet('All', 'Standard', 'Mono', 'Propo')]
        [string] $Variant = 'All',

        # Force will overwrite existing fonts
        [Parameter()]
        [switch] $Force
    )

    begin {
        if ($Scope -eq 'AllUsers' -and -not (IsAdmin)) {
            $errorMessage = @'
Administrator rights are required to install fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
'@
            throw $errorMessage
        }
        $nerdFontsToInstall = [System.Collections.Generic.List[object]]::new()
        $seenNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

        $guid = (New-Guid).Guid
        $tempPath = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "NerdFonts-$guid"
    }

    process {
        if ($All) {
            foreach ($font in $script:NerdFonts) {
                if ($seenNames.Add($font.Name)) { $nerdFontsToInstall.Add($font) }
            }
        } else {
            foreach ($fontName in $Name) {
                foreach ($font in $script:NerdFonts) {
                    if ($font.Name -like $fontName -and $seenNames.Add($font.Name)) {
                        $nerdFontsToInstall.Add($font)
                    }
                }
            }
        }
    }

    end {
        Write-Verbose "[$Scope] - Installing [$($nerdFontsToInstall.Count)] fonts"

        $cacheRoot = Get-NerdFontCacheRoot

        $installedFamilies = $null
        if (-not $Force) {
            $installedNames = @(Get-Font -Scope $Scope -ErrorAction SilentlyContinue | ForEach-Object { $_.Name } | Where-Object { $_ })
            $installedFamilies = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]$installedNames,
                [System.StringComparer]::OrdinalIgnoreCase
            )
        }

        $toProcess = [System.Collections.Generic.List[object]]::new()
        foreach ($nerdFont in $nerdFontsToInstall) {
            $fontName = $nerdFont.Name
            if (-not $Force -and $installedFamilies) {
                $alreadyInstalled = $false
                foreach ($family in $installedFamilies) {
                    $normalizedFamily = $family -replace '[\s_-]', ''
                    $normalizedFontName = $fontName -replace '[\s_-]', ''
                    if ($normalizedFamily -notlike "${normalizedFontName}NerdFont*") {
                        continue
                    }

                    $matchesVariant = switch ($Variant) {
                        'All' {
                            $true
                        }
                        'Mono' {
                            $normalizedFamily -like '*NerdFontMono*'
                        }
                        'Propo' {
                            $normalizedFamily -like '*NerdFontPropo*'
                        }
                        'Standard' {
                            $normalizedFamily -notlike '*NerdFontMono*' -and
                            $normalizedFamily -notlike '*NerdFontPropo*'
                        }
                    }

                    if ($matchesVariant) {
                        $alreadyInstalled = $true
                        break
                    }
                }
                if ($alreadyInstalled) {
                    Write-Verbose "[$fontName] - requested variant [$Variant] already installed, skipping"
                    continue
                }
            }
            $toProcess.Add($nerdFont)
        }

        $pendingDownloads = [System.Collections.Generic.List[object]]::new()
        $readyToInstall = [System.Collections.Generic.List[object]]::new()
        $downloadErrors = [System.Collections.Generic.List[string]]::new()
        $activeDownloadJobs = [System.Collections.Generic.List[object]]::new()
        $throttle = 8

        try {
            foreach ($nerdFont in $toProcess) {
                $URL = $nerdFont.URL
                $fontName = $nerdFont.Name
                $downloadFileName = Split-Path -Path $URL -Leaf
                $downloadPath = Join-Path -Path $tempPath -ChildPath $downloadFileName

                $cacheTag = if ($URL -match '/releases/download/([^/]+)/') {
                    $Matches[1]
                } else {
                    'unknown'
                }
                $cacheTagDir = Join-Path -Path $cacheRoot -ChildPath $cacheTag
                $cachedFile = Join-Path -Path $cacheTagDir -ChildPath $downloadFileName

                if ((Test-Path -LiteralPath $cachedFile) -and -not $Force) {
                    Write-Verbose "[$fontName] - Cache hit at [$cachedFile]"
                    $cacheCopyTarget = "[$fontName] cache archive to [$downloadPath]"
                    if ($PSCmdlet.ShouldProcess($cacheCopyTarget, 'Copy cached archive')) {
                        if (-not (Test-Path -LiteralPath $tempPath)) {
                            Write-Verbose "Create folder [$tempPath]"
                            $null = New-Item -Path $tempPath -ItemType Directory -ErrorAction Stop
                        }

                        try {
                            Copy-Item -LiteralPath $cachedFile -Destination $downloadPath -Force -ErrorAction Stop
                            $cachedDownload = [pscustomobject]@{
                                Name         = $fontName
                                URL          = $URL
                                DownloadPath = $downloadPath
                                CachedFile   = $cachedFile
                                CacheTagDir  = $cacheTagDir
                                FromCache    = $true
                            }
                            $readyToInstall.Add($cachedDownload)
                            continue
                        } catch {
                            Write-Warning "[$fontName] - Cache read failed, falling back to download: $($_.Exception.Message)"
                        }
                    } else {
                        continue
                    }

                }

                if ($PSCmdlet.ShouldProcess("[$fontName] from [$URL]", 'Download archive')) {
                    if (-not (Test-Path -LiteralPath $tempPath)) {
                        Write-Verbose "Create folder [$tempPath]"
                        $null = New-Item -Path $tempPath -ItemType Directory -ErrorAction Stop
                    }

                    Write-Verbose "[$fontName] - Queue download to [$downloadPath]"
                    $queuedDownload = [pscustomobject]@{
                        Name         = $fontName
                        URL          = $URL
                        DownloadPath = $downloadPath
                        CachedFile   = $cachedFile
                        CacheTagDir  = $cacheTagDir
                        FromCache    = $false
                    }
                    $pendingDownloads.Add($queuedDownload)
                }
            }

            $toDownload = @($pendingDownloads)
            for ($i = 0; $i -lt $toDownload.Count; $i += $throttle) {
                $end = [Math]::Min($i + $throttle - 1, $toDownload.Count - 1)
                $chunk = $toDownload[$i..$end]
                $tasks = foreach ($queuedDownload in $chunk) {
                    $downloadParams = @{
                        Uri             = $queuedDownload.URL
                        DestinationPath = $queuedDownload.DownloadPath
                    }
                    $downloadJob = Start-NerdFontDownload @downloadParams
                    $activeDownloadJobs.Add($downloadJob)
                    [pscustomobject]@{
                        QueuedDownload = $queuedDownload
                        Job            = $downloadJob
                    }
                }

                foreach ($task in $tasks) {
                    try {
                        $null = Receive-Job -Job $task.Job -Wait -AutoRemoveJob -ErrorAction Stop
                        $readyToInstall.Add($task.QueuedDownload)
                    } catch {
                        $downloadErrors.Add("[$($task.QueuedDownload.Name)] - Download failed: $($_.Exception.Message)")
                    } finally {
                        $null = $activeDownloadJobs.Remove($task.Job)
                    }
                }
            }
        } finally {
            foreach ($downloadJob in $activeDownloadJobs) {
                Remove-Job -Job $downloadJob -Force -ErrorAction SilentlyContinue
            }
        }

        foreach ($p in $readyToInstall) {
            $fontName = $p.Name
            $downloadPath = $p.DownloadPath
            $extractPath = Join-Path -Path $tempPath -ChildPath $fontName
            Write-Verbose "[$fontName] - Extract to [$extractPath]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$extractPath]", 'Extract')) {
                try {
                    if (-not (Test-Path -LiteralPath $extractPath)) {
                        $null = New-Item -ItemType Directory -Path $extractPath -ErrorAction Stop
                    }
                    [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath, $true)
                } catch {
                    Remove-Item -LiteralPath $extractPath -Force -Recurse -ErrorAction SilentlyContinue
                    Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue
                    Write-Error "[$fontName] - Extract failed: $($_.Exception.Message)"
                    continue
                }

                if (-not $p.FromCache -and (Test-Path -LiteralPath $downloadPath)) {
                    $tempCachePath = $null
                    try {
                        if (-not (Test-Path -LiteralPath $p.CacheTagDir)) {
                            $null = New-Item -ItemType Directory -Path $p.CacheTagDir -Force -ErrorAction Stop
                        }
                        $tempCachePath = "$($p.CachedFile).$PID.tmp"
                        Copy-Item -LiteralPath $downloadPath -Destination $tempCachePath -Force -ErrorAction Stop
                        Move-Item -LiteralPath $tempCachePath -Destination $p.CachedFile -Force -ErrorAction Stop
                    } catch {
                        Write-Warning "[$fontName] - Download succeeded but cache write failed: $($_.Exception.Message)"
                        if ($tempCachePath -and (Test-Path -LiteralPath $tempCachePath)) {
                            Remove-Item -LiteralPath $tempCachePath -Force -ErrorAction SilentlyContinue
                        }
                    }
                }

                Remove-Item -LiteralPath $downloadPath -Force -ErrorAction SilentlyContinue

                if ($Variant -ne 'All') {
                    $allFiles = Get-ChildItem -Path $extractPath -Recurse -File -Include '*.ttf', '*.otf'
                    $keep = switch ($Variant) {
                        'Mono' {
                            $allFiles | Where-Object { $_.Name -like '*NerdFontMono*' }
                        }
                        'Propo' {
                            $allFiles | Where-Object { $_.Name -like '*NerdFontPropo*' }
                        }
                        'Standard' {
                            $allFiles | Where-Object {
                                $_.Name -like '*NerdFont*' -and
                                $_.Name -notlike '*NerdFontMono*' -and
                                $_.Name -notlike '*NerdFontPropo*'
                            }
                        }
                    }
                    $keepNames = [string[]]@($keep.FullName)
                    $keepSet = [System.Collections.Generic.HashSet[string]]::new(
                        $keepNames,
                        [System.StringComparer]::OrdinalIgnoreCase
                    )
                    $removed = 0
                    foreach ($file in $allFiles) {
                        if (-not $keepSet.Contains($file.FullName)) {
                            Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                            $removed++
                        }
                    }
                    Write-Verbose "[$fontName] - Variant '$Variant': kept $($keep.Count), removed $removed"
                }

                # Nerd Fonts archives sometimes contain duplicate matching files in
                # compatibility subfolders. Keep a single file per filename.
                $remaining = @(Get-ChildItem -Path $extractPath -Recurse -File -Include '*.ttf', '*.otf')
                $preferred = $remaining | Sort-Object -Property @(
                    @{ Expression = { if ($_.FullName -match '(?i)[\\/]Windows Compatible[\\/]') { 1 } else { 0 } } }
                    @{ Expression = { $_.FullName.Length } }
                )
                $seenFileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                $duplicateRemoved = 0
                foreach ($file in $preferred) {
                    if ($seenFileNames.Add($file.Name)) {
                        continue
                    }
                    Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
                    $duplicateRemoved++
                }
                if ($duplicateRemoved -gt 0) {
                    Write-Verbose "[$fontName] - Deduplicated $duplicateRemoved file(s)"
                }

                Write-Verbose "[$fontName] - Install to [$Scope]"
                if ($PSCmdlet.ShouldProcess("[$fontName] to [$Scope]", 'Install font')) {
                    Install-Font -Path $extractPath -Scope $Scope -Force:$Force
                    Remove-Item -LiteralPath $extractPath -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
        }

        foreach ($err in $downloadErrors) {
            Write-Error $err
        }

        Write-Verbose "Remove folder [$tempPath]"
    }

    clean {
        if ($tempPath -and (Test-Path -LiteralPath $tempPath)) {
            Remove-Item -LiteralPath $tempPath -Force -Recurse -ErrorAction SilentlyContinue
        }
    }
}
