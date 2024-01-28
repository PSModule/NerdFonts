#Requires -Modules Fonts
#Requires -Modules Utilities

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
        DefaultParameterSetName = 'Name'
    )]
    param(
        [Parameter(
            Mandatory,
            Position = 0,
            ParameterSetName = 'All'
        )]
        [switch] $All,

        [Parameter(
            Position = 1,
            ParameterSetName = '__AllParameterSets'
        )]
        [ValidateSet('CurrentUser', 'AllUsers')]
        [string] $Scope = 'CurrentUser'
    )

    DynamicParam {
        $runtimeDefinedParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary
        $attributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        $parameterName = 'Name'
        $parameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $parameterAttribute.Mandatory = $true
        $parameterAttribute.ParameterSetName = 'Name'
        $parameterAttribute.Position = 0
        $parameterAttribute.HelpMessage = 'Name of the font to uninstall.'
        $parameterAttribute.ValueFromPipeline = $true
        $parameterAttribute.ValueFromPipelineByPropertyName = $true
        $attributeCollection.Add($parameterAttribute)

        $parameterValidateSet = (Get-NerdFonts).Name
        $validateSetAttribute = New-Object System.Management.Automation.ValidateSetAttribute($parameterValidateSet)
        $attributeCollection.Add($validateSetAttribute)

        $runtimeDefinedParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($parameterName, [string[]], $attributeCollection)
        $runtimeDefinedParameterDictionary.Add($parameterName, $runtimeDefinedParameter)
        return $runtimeDefinedParameterDictionary
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
            Invoke-WebRequest -Uri $URL -OutFile $downloadPath -Verbose:$false
            $ProgressPreference = $storedProgressPreference

            Write-Verbose "[$FontName] - Unpack to [$extractPath]"
            Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
            Remove-Item -Path $downloadPath -Force

            Write-Verbose "[$FontName] - Install to [$Scope]"
            Install-Font -Path $extractPath -Scope $Scope
            Remove-Item -Path $extractPath -Force -Recurse
        }
    }

    end {}
}
