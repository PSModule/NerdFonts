# Download nerd fonts
# https://www.nerdfonts.com/font-downloads

function Get-NerdFonts {
    param ()

    $release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
    $version = $release.tag_name
    $assets = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' }

    foreach ($asset in $assets) {
        [pscustomobject]@{
            Name    = $asset.Split('/')[-1].Split('.')[0]
            Version = $version
            URL     = $asset
        }
    }
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
        $NerdFonts = Get-NerdFonts
        $NerdFontsToInstall = @()
    }

    process {
        if ($All) {
            $NerdFontsToInstall = $NerdFonts
        } else {
            foreach ($FontName in $Name) {
                $NerdFontsToInstall += $NerdFonts | Where-Object Name -EQ $FontName
            }
        }

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

    end{}
}

Export-ModuleMember -Function '*' -Alias '*' -Variable '*' -Cmdlet '*'
