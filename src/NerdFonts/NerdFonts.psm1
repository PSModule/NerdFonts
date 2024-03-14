[Cmdletbinding()]
param()

Write-Verbose 'Importing subcomponents'
$Folders = 'classes', 'private', 'public'
# Import everything in these folders
Foreach ($Folder in $Folders) {
    $Root = Join-Path -Path $PSScriptRoot -ChildPath $Folder
    Write-Verbose "Processing folder: $Root"
    if (Test-Path -Path $Root) {
        Write-Verbose "Getting all files in $Root"
        $Files = $null
        $Files = Get-ChildItem -Path $Root -Include '*.ps1', '*.psm1' -Recurse
        # dot source each file
        foreach ($File in $Files) {
            Write-Verbose "Importing $($File)"
            Import-Module $File
            Write-Verbose "Importing $($File): Done"
        }
    }
}

$Param = @{
    Function = (Get-ChildItem -Path "$PSScriptRoot\public" -Include '*.ps1' -Recurse).BaseName
    Variable = '*'
    Cmdlet   = '*'
    Alias    = '*'
}

Write-Verbose 'Exporting module members'

Export-ModuleMember @Param -Verbose
