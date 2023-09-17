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
