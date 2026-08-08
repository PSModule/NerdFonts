function Start-NerdFontDownload {
    <#
        .SYNOPSIS
        Starts a streaming archive download with retries.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Install-NerdFont confirms the download operation before starting a job.'
    )]
    [OutputType([pscustomobject])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter()]
        [System.Net.Http.HttpClient] $HttpClient,

        [Parameter()]
        [System.Management.Automation.Runspaces.RunspacePool] $RunspacePool,

        [Parameter()]
        [switch] $Wait
    )

    if ($Wait) {
        Invoke-NerdFontDownload -Uri $Uri -DestinationPath $DestinationPath -HttpClient $HttpClient
        return
    }

    if ($null -eq $HttpClient -or $null -eq $RunspacePool) {
        throw 'HttpClient and RunspacePool are required for asynchronous downloads.'
    }

    $powerShell = [PowerShell]::Create()
    $powerShell.RunspacePool = $RunspacePool
    try {
        $command = $powerShell.AddCommand('Invoke-NerdFontDownload')
        $null = $command.AddParameter('Uri', $Uri)
        $null = $command.AddParameter('DestinationPath', $DestinationPath)
        $null = $command.AddParameter('HttpClient', $HttpClient)
        $asyncResult = $powerShell.BeginInvoke()
        return [pscustomobject]@{
            AsyncResult = $asyncResult
            PowerShell  = $powerShell
        }
    } catch {
        $powerShell.Dispose()
        throw
    }
}
