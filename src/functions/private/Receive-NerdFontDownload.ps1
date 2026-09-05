function Receive-NerdFontDownload {
    <#
        .SYNOPSIS
        Completes an asynchronous archive download and surfaces its errors.
    #>
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject] $Operation
    )

    try {
        $null = $Operation.PowerShell.EndInvoke($Operation.AsyncResult)
        if ($Operation.PowerShell.HadErrors) {
            $errorMessage = ($Operation.PowerShell.Streams.Error | ForEach-Object ToString) -join [Environment]::NewLine
            throw $errorMessage
        }
    } finally {
        $Operation.PowerShell.Dispose()
    }
}
