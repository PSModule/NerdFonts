[CmdletBinding()]
param (
    [Parameter()]
    [string] $ModuleName = "GitHub"
)

[Version]$NewVersion = "0.0.0"

$OnlineVersion = [Version](Find-Module $ModuleName).Version
Write-Warning "Online: $($OnlineVersion.ToString())"
$ManifestVersion = [Version](Test-ModuleManifest ".\src\$ModuleName\$ModuleName.psd1").Version
Write-Warning "Manifest: $($ManifestVersion.ToString())"

if($ManifestVersion.Major -gt $OnlineVersion.Major) {
    $NewVersionMajor = $ManifestVersion.Major
    $NewVersionMinor = 0
    $NewVersionBuild = 0
} else {
    $NewVersionMajor = $OnlineVersion.Major
    if($ManifestVersion.Minor -gt $OnlineVersion.Minor) {
        $NewVersionMinor = $ManifestVersion.Minor
        $NewVersionBuild = 0
    } else {
        $NewVersionMinor = $OnlineVersion.Minor
        $NewVersionBuild = $OnlineVersion.Build + 1
    }
}
[Version]$NewVersion = [version]::new($NewVersionMajor,$NewVersionMinor,$NewVersionBuild)
Write-Warning "NewVersion: $($NewVersion.ToString())"

Update-ModuleManifest -Path ".\src\$ModuleName\$ModuleName.psd1" -ModuleVersion $NewVersion -ErrorAction Continue
