if ($null -eq ('NerdFonts.ArchiveDownloader' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading.Tasks;

namespace NerdFonts
{
    public static class ArchiveDownloader
    {
        public static async Task DownloadAsync(
            HttpClient client,
            Uri uri,
            string destinationPath,
            int maximumRetryCount,
            TimeSpan retryInterval)
        {
            string temporaryPath = destinationPath + "." + Guid.NewGuid().ToString("N") + ".tmp";

            try
            {
                for (int attempt = 0; ; attempt++)
                {
                    try
                    {
                        if (File.Exists(temporaryPath))
                        {
                            File.Delete(temporaryPath);
                        }

                        using (HttpResponseMessage response = await client.GetAsync(
                            uri,
                            HttpCompletionOption.ResponseHeadersRead).ConfigureAwait(false))
                        {
                            if (!response.IsSuccessStatusCode)
                            {
                                if (IsTransient(response.StatusCode) && attempt < maximumRetryCount)
                                {
                                    await Task.Delay(retryInterval).ConfigureAwait(false);
                                    continue;
                                }

                                response.EnsureSuccessStatusCode();
                            }

                            using (Stream source = await response.Content.ReadAsStreamAsync().ConfigureAwait(false))
                            using (FileStream destination = new FileStream(
                                temporaryPath,
                                FileMode.Create,
                                FileAccess.Write,
                                FileShare.None,
                                81920,
                                FileOptions.Asynchronous))
                            {
                                await source.CopyToAsync(destination, 81920).ConfigureAwait(false);
                                await destination.FlushAsync().ConfigureAwait(false);
                            }
                        }

                        File.Move(temporaryPath, destinationPath, true);
                        return;
                    }
                    catch (Exception exception) when (
                        IsTransient(exception) &&
                        attempt < maximumRetryCount)
                    {
                        await Task.Delay(retryInterval).ConfigureAwait(false);
                    }
                }
            }
            finally
            {
                if (File.Exists(temporaryPath))
                {
                    File.Delete(temporaryPath);
                }
            }
        }

        private static bool IsTransient(HttpStatusCode statusCode)
        {
            return statusCode == HttpStatusCode.RequestTimeout ||
                statusCode == (HttpStatusCode)429 ||
                (int)statusCode >= 500;
        }

        private static bool IsTransient(Exception exception)
        {
            return exception is HttpRequestException ||
                exception is IOException ||
                exception is TaskCanceledException;
        }
    }
}
'@ -ErrorAction Stop
}

function Invoke-NerdFontDownload {
    <#
        .SYNOPSIS
        Downloads a font archive with bounded-memory retries.
    #>
    [OutputType([System.Threading.Tasks.Task])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [System.Net.Http.HttpClient] $HttpClient,

        [Parameter(Mandatory)]
        [uri] $Uri,

        [Parameter(Mandatory)]
        [string] $DestinationPath
    )

    return [NerdFonts.ArchiveDownloader]::DownloadAsync(
        $HttpClient,
        $Uri,
        $DestinationPath,
        5,
        [TimeSpan]::FromSeconds(5)
    )
}
