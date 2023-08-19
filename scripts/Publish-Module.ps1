[CmdletBinding()]
param (
    [Parameter()]
    [string] $ModuleName,

    [Parameter()]
    [string] $APIKey
)

$SRCPath = Get-Item -Path .\src\ | Select-Object -ExpandProperty FullName
$env:PSModulePath += ":$SRCPath"
$env:PSModulePath -Split ':'

.\scripts\Set-ModuleVersion.ps1 -ModuleName $ModuleName -Verbose
Publish-Module -Path "src/$ModuleName" -NuGetApiKey $APIKey -Verbose
