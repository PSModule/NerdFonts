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

        $maximumRetryCount = 5
        $retryIntervalSeconds = 5
        $temporaryPath = "$DownloadPath.$PID.tmp"
        $httpClient = [System.Net.Http.HttpClient]::new()
        $httpClient.Timeout = [System.Threading.Timeout]::InfiniteTimeSpan

        try {
            for ($attempt = 0; $attempt -le $maximumRetryCount; $attempt++) {
                $response = $null
                $source = $null
                $destination = $null
                try {
                    $responseHeadersOnly = [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead
                    $response = $httpClient.GetAsync($DownloadUri, $responseHeadersOnly).GetAwaiter().GetResult()

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

                    $source = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
                    $destination = [System.IO.FileStream]::new(
                        $temporaryPath,
                        [System.IO.FileMode]::Create,
                        [System.IO.FileAccess]::Write,
                        [System.IO.FileShare]::None,
                        81920,
                        [System.IO.FileOptions]::Asynchronous
                    )
                    $null = $source.CopyToAsync($destination).GetAwaiter().GetResult()
                    $null = $destination.FlushAsync().GetAwaiter().GetResult()
                    $destination.Dispose()
                    $destination = $null
                    $source.Dispose()
                    $source = $null
                    [System.IO.File]::Move($temporaryPath, $DownloadPath, $true)
                    return
                } catch {
                    $isTransientException = @(
                        $_.Exception -is [System.Net.Http.HttpRequestException]
                        $_.Exception -is [System.IO.IOException]
                        $_.Exception -is [System.Threading.Tasks.TaskCanceledException]
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
                }
            }
        } finally {
            $httpClient.Dispose()
            if (Test-Path -LiteralPath $temporaryPath) {
                Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
            }
        }
    }

    return Start-ThreadJob -ScriptBlock $downloadScript -ArgumentList $Uri, $DestinationPath
}
