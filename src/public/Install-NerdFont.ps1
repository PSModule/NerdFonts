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
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser'
    )

    DynamicParam {
        $DynamicParamDictionary = New-DynamicParamDictionary

        $dynPath = @{
            Name                            = 'Name'
            Type                            = [string[]]
            Mandatory                       = $true
            ParameterSetName                = 'Name'
            HelpMessage                     = 'Name of the font to uninstall.'
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
Administrator rights are required to uninstall fonts.
Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
'@
            throw $errorMessage
        }
        $NerdFonts = Get-NerdFonts
        $NerdFontsToInstall = @()
        $Name = $PSBoundParameters.Name
    }

    process {
        if ($All) {
            $NerdFontsToInstall = $NerdFonts
        } else {
            foreach ($FontName in $Name) {
                $NerdFontsToInstall += $NerdFonts | Where-Object Name -EQ $FontName
            }
        }

        Write-Verbose "[$Scope] - Installing [$($NerdFontsToInstall.count)] fonts"

        foreach ($NerdFont in $NerdFontsToInstall) {
            $URL = $NerdFont.URL
            $FontName = $NerdFont.Name
            $downloadPath = "$env:TEMP\$FontName.zip"
            $extractPath = "$env:TEMP\$FontName"

            Write-Verbose "[$FontName] - Downloading to [$downloadPath]"
            $storedProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue' # Suppress progress bar
            if ($PSCmdlet.ShouldProcess($FontName, "Download $FontName")) {
                Invoke-WebRequest -Uri $URL -OutFile $downloadPath -Verbose:$false
            }
            $ProgressPreference = $storedProgressPreference

            Write-Verbose "[$FontName] - Unpack to [$extractPath]"
            if ($PSCmdlet.ShouldProcess($FontName, 'Extract archive')) {
                Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
                Remove-Item -Path $downloadPath -Force
            }

            Write-Verbose "[$FontName] - Install to [$Scope]"
            if ($PSCmdlet.ShouldProcess($FontName, 'Install font')) {
                Install-Font -Path $extractPath -Scope $Scope
                Remove-Item -Path $extractPath -Force -Recurse
            }
        }
    }

    end {}
}
