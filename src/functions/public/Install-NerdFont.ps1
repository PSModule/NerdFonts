#Requires -Modules @{ ModuleName = 'Fonts'; RequiredVersion = '1.1.21' }
#Requires -Modules @{ ModuleName = 'Admin'; RequiredVersion = '1.1.6' }

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

        .LINK
        https://psmodule.io/NerdFonts/Functions/Install-NerdFont

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
        $tempPath = Join-Path -Path $HOME -ChildPath "NerdFonts-$guid"
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
        }
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

        $cacheRoot = if ($IsWindows) {
            Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'PSModule/NerdFonts/cache'
        } else {
            Join-Path -Path $HOME -ChildPath '.cache/PSModule/NerdFonts'
        }
        if (-not (Test-Path -LiteralPath $cacheRoot)) {
            $null = New-Item -ItemType Directory -Path $cacheRoot -Force
        }

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
                    if ($family -like "$fontName*") { $alreadyInstalled = $true; break }
                }
                if ($alreadyInstalled) {
                    Write-Verbose "[$fontName] - already installed, skipping"
                    continue
                }
            }
            $toProcess.Add($nerdFont)
        }

        Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue
        $httpClient = [System.Net.Http.HttpClient]::new()
        $httpClient.Timeout = [TimeSpan]::FromMinutes(5)
        $pending = [System.Collections.Generic.List[object]]::new()
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
                    Copy-Item -LiteralPath $cachedFile -Destination $downloadPath -Force
                    $pending.Add([pscustomobject]@{
                            Name         = $fontName
                            URL          = $URL
                            DownloadPath = $downloadPath
                            CachedFile   = $cachedFile
                            CacheTagDir  = $cacheTagDir
                            FromCache    = $true
                        })
                } else {
                    Write-Verbose "[$fontName] - Queue download to [$downloadPath]"
                    $pending.Add([pscustomobject]@{
                            Name         = $fontName
                            URL          = $URL
                            DownloadPath = $downloadPath
                            CachedFile   = $cachedFile
                            CacheTagDir  = $cacheTagDir
                            FromCache    = $false
                        })
                }
            }

            $toDownload = @($pending | Where-Object { -not $_.FromCache })
            for ($i = 0; $i -lt $toDownload.Count; $i += $throttle) {
                $end = [Math]::Min($i + $throttle - 1, $toDownload.Count - 1)
                $chunk = $toDownload[$i..$end]
                $tasks = @()
                foreach ($q in $chunk) {
                    $tasks += [pscustomobject]@{ Q = $q; Task = $httpClient.GetByteArrayAsync($q.URL) }
                }
                foreach ($t in $tasks) {
                    $bytes = $t.Task.GetAwaiter().GetResult()
                    [System.IO.File]::WriteAllBytes($t.Q.DownloadPath, $bytes)
                    if (-not (Test-Path -LiteralPath $t.Q.CacheTagDir)) {
                        $null = New-Item -ItemType Directory -Path $t.Q.CacheTagDir -Force
                    }
                    [System.IO.File]::WriteAllBytes($t.Q.CachedFile, $bytes)
                }
            }
        } finally {
            $httpClient.Dispose()
        }

        foreach ($p in $pending) {
            $fontName = $p.Name
            $downloadPath = $p.DownloadPath
            $extractPath = Join-Path -Path $tempPath -ChildPath $fontName
            Write-Verbose "[$fontName] - Extract to [$extractPath]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$extractPath]", 'Extract')) {
                if (-not (Test-Path -LiteralPath $extractPath)) {
                    $null = New-Item -ItemType Directory -Path $extractPath
                }
                [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath, $true)
                Remove-Item -Path $downloadPath -Force
            }

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
                foreach ($f in $allFiles) {
                    if (-not $keepSet.Contains($f.FullName)) {
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                        $removed++
                    }
                }
                Write-Verbose "[$fontName] - Variant '$Variant' kept $($keep.Count) files, removed $removed"
            }

            Write-Verbose "[$fontName] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$Scope]", 'Install font')) {
                Install-Font -Path $extractPath -Scope $Scope -Force:$Force
                Remove-Item -Path $extractPath -Force -Recurse
            }
        }

        Write-Verbose "Remove folder [$tempPath]"
    }

    clean {
        Remove-Item -Path $tempPath -Force
    }
}
