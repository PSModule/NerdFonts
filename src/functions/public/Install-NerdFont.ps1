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

        # Max concurrent downloads.
        [Parameter()]
        [ValidateRange(1, 32)]
        [int] $ThrottleLimit = 8,

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

        $extracted = $toProcess | ForEach-Object -ThrottleLimit $ThrottleLimit -Parallel {
            $nerdFont = $_
            $tempPath = $using:tempPath
            $cacheRoot = $using:cacheRoot
            $Variant = $using:Variant
            $Force = $using:Force

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
                Copy-Item -LiteralPath $cachedFile -Destination $downloadPath -Force
            } else {
                $previousProgress = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                try {
                    Invoke-WebRequest -Uri $URL -OutFile $downloadPath -RetryIntervalSec 5 -MaximumRetryCount 5
                } finally {
                    $ProgressPreference = $previousProgress
                }
                if (-not (Test-Path -LiteralPath $cacheTagDir)) {
                    $null = New-Item -ItemType Directory -Path $cacheTagDir -Force
                }
                Copy-Item -LiteralPath $downloadPath -Destination $cachedFile -Force -ErrorAction SilentlyContinue
            }

            $extractPath = Join-Path -Path $tempPath -ChildPath $fontName
            if (-not (Test-Path -LiteralPath $extractPath)) {
                $null = New-Item -ItemType Directory -Path $extractPath
            }
            Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
            [System.IO.Compression.ZipFile]::ExtractToDirectory($downloadPath, $extractPath, $true)
            Remove-Item -Path $downloadPath -Force

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
                foreach ($f in $allFiles) {
                    if (-not $keepSet.Contains($f.FullName)) {
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                    }
                }
            }

            [pscustomobject]@{ Name = $fontName; ExtractPath = $extractPath }
        }

        foreach ($e in $extracted) {
            Write-Verbose "[$($e.Name)] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess("[$($e.Name)] to [$Scope]", 'Install font')) {
                Install-Font -Path $e.ExtractPath -Scope $Scope -Force:$Force
                Remove-Item -Path $e.ExtractPath -Force -Recurse
            }
        }

        Write-Verbose "Remove folder [$tempPath]"
    }

    clean {
        Remove-Item -Path $tempPath -Force
    }
}
