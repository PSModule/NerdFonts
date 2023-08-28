$script:NerdFontsReleaseURL = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases'

function Get-NerdFontsVersionList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param()

    $versionPattern = [regex]'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

    $release = Invoke-RestMethod $script:NerdFontsReleaseURL -Verbose:$false
    $versions = $release.tag_name | Where-Object { $_ -match $versionPattern } | Sort-Object

    return $versions
}

function Get-NerdFontsRelease {
    [CmdletBinding()]
    param(
        [Parameter(
            ParameterSetName = 'Latest',
            Mandatory
        )]
        [switch] $Latest,

        [Parameter(
            ParameterSetName = 'Latest'
        )]
        [switch] $AllowPrerelease,

        [Parameter(
            ParameterSetName = 'Version'
        )]
        [ValidateSet({ Get-NerdFontsVersionList })]
        [string] $Version
    )

    begin {
        $versionPattern = [regex]'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

    }

    process {
        foreach ($TerraformPath in $Path) {
            $terraformVersionOutput = & $TerraformPath --version
            $version = $versionPattern.Match($terraformVersionOutput).Value
            [pscustomobject]@{
                Path    = $TerraformPath
                Version = $version
            }
        }
    }

    end {
        return $versions
    }
}

function Get-NerdFonts {
    param (
        [Parameter()]
        [SupportsWildcards()]
        [string] $Name
    )

    $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest' -Verbose:$false
    $version = $release.tag_name
    $assets = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' -and $_ -like "*$Name*" } | Sort-Object
    $nerdFonts = @()
    foreach ($asset in $assets) {
        $nerdFonts += [pscustomobject]@{
            Name    = $asset.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $asset
        }
    }
    return $nerdFonts
}

function Download-NerdFonts {
    [CmdletBinding()]
    param(
        $Path = "$env:TEMP\NerdFonts"
    )

}

function Install-NerdFont {
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
            throw "Administrator rights are required to uninstall fonts. Please run the command again with elevated rights (Run as Administrator) or provide '-Scope CurrentUser' to your command."
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

Export-ModuleMember -Function '*' -Alias '*' -Variable '*' -Cmdlet '*'
