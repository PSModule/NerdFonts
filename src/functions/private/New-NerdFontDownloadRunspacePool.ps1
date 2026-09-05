function New-NerdFontDownloadRunspacePool {
    <#
        .SYNOPSIS
        Creates a bounded pool for concurrent archive downloads.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creating an in-memory runspace pool has no external side effects.'
    )]
    [OutputType([System.Management.Automation.Runspaces.RunspacePool])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaximumRunspaces
    )

    $initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
    $downloadDefinition = ${function:Invoke-NerdFontDownload}.ToString()
    $downloadFunction = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new(
        'Invoke-NerdFontDownload',
        $downloadDefinition
    )
    $initialSessionState.Commands.Add($downloadFunction)

    $runspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(
        1,
        $MaximumRunspaces,
        $initialSessionState,
        $Host
    )
    $runspacePool.Open()
    return $runspacePool
}
