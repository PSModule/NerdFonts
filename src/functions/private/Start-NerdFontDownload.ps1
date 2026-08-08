function Start-NerdFontDownload {
    <#
        .SYNOPSIS
        Starts a streaming archive download with retries.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Install-NerdFont confirms the download operation before starting a job.'
    )]
    [OutputType([System.Management.Automation.Job])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter()]
        [switch] $Wait
    )

    if ($Wait) {
        Invoke-NerdFontDownload -Uri $Uri -DestinationPath $DestinationPath
        return
    }

    $downloadFunctionBody = ${function:Invoke-NerdFontDownload}.ToString()
    $downloadScript = {
        param(
            [string] $FunctionBody,

            [uri] $DownloadUri,

            [string] $DownloadPath
        )

        $functionDefinition = "function Invoke-NerdFontDownload {`n$FunctionBody`n}"
        . ([scriptblock]::Create($functionDefinition))
        Invoke-NerdFontDownload -Uri $DownloadUri -DestinationPath $DownloadPath
    }

    return Start-ThreadJob -ScriptBlock $downloadScript -ArgumentList $downloadFunctionBody, $Uri, $DestinationPath
}
