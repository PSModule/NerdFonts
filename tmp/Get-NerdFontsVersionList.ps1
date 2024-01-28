function Get-NerdFontsVersionList {
    [OutputType([string[]])]
    [CmdletBinding()]
    param()

    $versionPattern = [regex]'(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'

    $release = Invoke-RestMethod $script:NerdFontsReleaseURL -Verbose:$false
    $versions = $release.tag_name | Where-Object { $_ -match $versionPattern } | Sort-Object

    return $versions
}
