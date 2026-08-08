function Invoke-NerdFontDownload {
    <#
        .SYNOPSIS
        Streams a font archive to disk with retries.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Install-NerdFont confirms the download operation before invoking this helper.'
    )]
    [OutputType([void])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $DestinationPath,

        [Parameter()]
        [System.Net.Http.HttpClient] $HttpClient,

        [Parameter()]
        [ValidateRange(1, 3600)]
        [int] $AttemptTimeoutSeconds = 900
    )

    $maximumRetryCount = 5
    $retryIntervalSeconds = 5
    $temporaryPath = "$DestinationPath.$PID.tmp"
    $ownsHttpClient = $null -eq $HttpClient
    if ($ownsHttpClient) {
        $HttpClient = New-NerdFontHttpClient -MaximumConnections 1
    }

    try {
        for ($attempt = 0; $attempt -le $maximumRetryCount; $attempt++) {
            $response = $null
            $source = $null
            $destination = $null
            $cancellationTokenSource = [System.Threading.CancellationTokenSource]::new()
            try {
                $attemptTimeout = [TimeSpan]::FromSeconds($AttemptTimeoutSeconds)
                $cancellationTokenSource.CancelAfter($attemptTimeout)
                $cancellationToken = $cancellationTokenSource.Token
                $responseHeadersOnly = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
                $response = $httpClient.GetAsync(
                    $Uri,
                    $responseHeadersOnly,
                    $cancellationToken
                ).GetAwaiter().GetResult()

                if (-not $response.IsSuccessStatusCode) {
                    $statusCode = [int] $response.StatusCode
                    $isTransientStatus = $statusCode -eq 408 -or $statusCode -eq 429 -or $statusCode -ge 500
                    if ($isTransientStatus -and $attempt -lt $maximumRetryCount) {
                        Start-Sleep -Seconds $retryIntervalSeconds
                        continue
                    }

                    $errorMessage = "Download failed with HTTP status code [$statusCode]."
                    throw [InvalidOperationException]::new($errorMessage)
                }

                $source = $response.Content.ReadAsStreamAsync($cancellationToken).GetAwaiter().GetResult()
                $destination = [System.IO.FileStream]::new(
                    $temporaryPath,
                    [System.IO.FileMode]::Create,
                    [System.IO.FileAccess]::Write,
                    [System.IO.FileShare]::None,
                    81920,
                    [System.IO.FileOptions]::Asynchronous
                )
                $null = $source.CopyToAsync($destination, 81920, $cancellationToken).GetAwaiter().GetResult()
                $null = $destination.FlushAsync($cancellationToken).GetAwaiter().GetResult()
                $destination.Dispose()
                $destination = $null
                $source.Dispose()
                $source = $null
                [System.IO.File]::Move($temporaryPath, $DestinationPath, $true)
                return
            } catch {
                $isTransientException = @(
                    $_.Exception -is [System.Net.Http.HttpRequestException]
                    $_.Exception -is [System.IO.IOException]
                    $_.Exception -is [System.OperationCanceledException]
                ) -contains $true
                if ($isTransientException -and $attempt -lt $maximumRetryCount) {
                    Start-Sleep -Seconds $retryIntervalSeconds
                    continue
                }

                throw
            } finally {
                if ($destination) {
                    $destination.Dispose()
                }
                if ($source) {
                    $source.Dispose()
                }
                if ($response) {
                    $response.Dispose()
                }
                $cancellationTokenSource.Dispose()
            }
        }
    } finally {
        if ($ownsHttpClient) {
            $HttpClient.Dispose()
        }
        if (Test-Path -LiteralPath $temporaryPath) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}
