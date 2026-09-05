function New-NerdFontHttpClient {
    <#
        .SYNOPSIS
        Creates a reusable HTTP client for an installation operation.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Creating an in-memory HTTP client has no external side effects.'
    )]
    [OutputType([System.Net.Http.HttpClient])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $MaximumConnections
    )

    $handler = [System.Net.Http.SocketsHttpHandler]::new()
    $handler.MaxConnectionsPerServer = $MaximumConnections
    $handler.PooledConnectionLifetime = [TimeSpan]::FromMinutes(15)

    $httpClient = [System.Net.Http.HttpClient]::new($handler, $true)
    $httpClient.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
    return $httpClient
}
