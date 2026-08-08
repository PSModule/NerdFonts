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
        [string] $DestinationPath
    )

    $downloadScript = {
        param(
            [uri] $DownloadUri,

            [string] $DownloadPath
        )

        $downloadParams = @{
            Uri               = $DownloadUri
            OutFile           = $DownloadPath
            MaximumRetryCount = 5
            RetryIntervalSec  = 5
            ErrorAction       = 'Stop'
        }
        Invoke-WebRequest @downloadParams
    }

    return Start-ThreadJob -ScriptBlock $downloadScript -ArgumentList $Uri, $DestinationPath
}
