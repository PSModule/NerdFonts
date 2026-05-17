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

        $installedFamilies = $null
        if (-not $Force) {
            $installedFamilies = [System.Collections.Generic.HashSet[string]]::new(
                [string[]]((Get-Font -Scope $Scope -ErrorAction SilentlyContinue).Name),
                [System.StringComparer]::OrdinalIgnoreCase
            )
        }

        foreach ($nerdFont in $nerdFontsToInstall) {
            $URL = $nerdFont.URL
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

            $downloadFileName = Split-Path -Path $URL -Leaf
            $downloadPath = Join-Path -Path $tempPath -ChildPath $downloadFileName

            Write-Verbose "[$fontName] - Downloading to [$downloadPath]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$downloadPath]", 'Download')) {
                $previousProgress = $ProgressPreference
                $ProgressPreference = 'SilentlyContinue'
                try {
                    Invoke-WebRequest -Uri $URL -OutFile $downloadPath -RetryIntervalSec 5 -MaximumRetryCount 5
                } finally {
                    $ProgressPreference = $previousProgress
                }
            }

            $extractPath = Join-Path -Path $tempPath -ChildPath $fontName
            Write-Verbose "[$fontName] - Extract to [$extractPath]"
            if ($PSCmdlet.ShouldProcess("[$fontName] to [$extractPath]", 'Extract')) {
                Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
                Remove-Item -Path $downloadPath -Force
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
