function Get-NerdFontCacheRoot {
    <#
        .SYNOPSIS
        Gets the platform-standard archive cache location.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param()

    if ($IsWindows) {
        return Join-Path -Path ([Environment]::GetFolderPath('LocalApplicationData')) -ChildPath 'PSModule/NerdFonts/cache'
    }

    if ($IsMacOS) {
        return Join-Path -Path $HOME -ChildPath 'Library/Caches/PSModule/NerdFonts'
    }

    if (-not [string]::IsNullOrWhiteSpace($env:XDG_CACHE_HOME)) {
        return Join-Path -Path $env:XDG_CACHE_HOME -ChildPath 'PSModule/NerdFonts'
    }

    return Join-Path -Path $HOME -ChildPath '.cache/PSModule/NerdFonts'
}
