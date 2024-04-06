#Requires -Modules Admin, Fonts, DynamicParams

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
        Install-NerdFont -Name 'Fira Code' -Scope AllUsers

        Installs the font 'Fira Code' to all users. This requires to be run as administrator.

        .EXAMPLE
        Install-NerdFont -All

        Installs all Nerd Fonts to the current user.
    #>
    [CmdletBinding(
        DefaultParameterSetName = 'Name',
        SupportsShouldProcess
    )]
    [Alias('Install-NerdFonts')]
    param(
        # Specify to install all Nerd Font(s).
        [Parameter(ParameterSetName = 'All', Mandatory)]
        [switch] $All,

        # Specify the scope of where to install the font(s).
        [Parameter()]
        [Scope] $Scope = 'CurrentUser'
    )

    DynamicParam {
        $DynamicParamDictionary = New-DynamicParamDictionary

        $dynPath = @{
            Name                            = 'Name'
            Type                            = [string[]]
            Mandatory                       = $true
            ParameterSetName                = 'Name'
            HelpMessage                     = 'Name of the font to install.'
            ValueFromPipeline               = $true
            ValueFromPipelineByPropertyName = $true
            ValidateSet                     = Get-NerdFonts | Select-Object -ExpandProperty Name
            DynamicParamDictionary          = $DynamicParamDictionary
        }
        New-DynamicParam @dynPath

        return $DynamicParamDictionary
    }

    begin {
        if ($Scope -eq 'AllUsers' -and -not (IsAdmin)) {
            $errorMessage = @'
Administrator rights are required to install fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
'@
            throw $errorMessage
        }
        $nerdFontsToInstall = @()

        $tempPath = Join-Path -Path $HOME -ChildPath '.temp'
        if (-not (Test-Path -Path $tempPath -PathType Container)) {
            Write-Verbose "Create folder [$tempPath]"
            $null = New-Item -Path $tempPath -ItemType Directory
            $tempFolderCreated = $true
        }

        $Name = $PSBoundParameters.Name
    }

    process {
        if ($All) {
            $nerdFontsToInstall = $script:NerdFonts
        } else {
            foreach ($fontName in $Name) {
                $nerdFontsToInstall += $script:NerdFonts | Where-Object Name -EQ $fontName
            }
        }

        Write-Verbose "[$Scope] - Installing [$($nerdFontsToInstall.count)] fonts"

        foreach ($NerdFont in $nerdFontsToInstall) {
            $URL = $NerdFont.URL
            $fontName = $NerdFont.Name
            $downloadPath = Join-Path -Path $tempPath -ChildPath "$FontName$script:ArchiveExtension"
            $extractPath = Join-Path -Path $tempPath -ChildPath "$fontName"

            Write-Verbose "[$fontName] - Downloading to [$downloadPath]"
            $storedProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue' # Suppress progress bar
            if ($PSCmdlet.ShouldProcess($fontName, "Download $fontName")) {
                Invoke-WebRequest -Uri $URL -OutFile $downloadPath -Verbose:$false
            }
            $ProgressPreference = $storedProgressPreference

            Write-Verbose "[$fontName] - Unpack to [$extractPath]"
            if ($PSCmdlet.ShouldProcess($fontName, 'Extract archive')) {
                Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
                Remove-Item -Path $downloadPath -Force
            }

            Write-Verbose "[$fontName] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess($fontName, 'Install font')) {
                Install-Font -Path $extractPath -Scope $Scope
                Remove-Item -Path $extractPath -Force -Recurse
            }
        }
    }

    end {
        if ($tempFolderCreated) {
            Write-Verbose "Remove folder [$tempPath]"
            Remove-Item -Path $tempPath -Force
        }
    }
}
