Write-Verbose '----------------------------------------'
Write-Verbose '---  Initializing the NerdFonts list ---'
Write-Verbose '----------------------------------------'
$script:Release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
$script:NerdFonts = $Release.assets.browser_download_url | Where-Object { $_ -like '*.zip' } | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Split('/')[-1].Split('.')[0]
        Version = $Release.tag_name
        URL     = $_
    }
}
$script:ArchiveExtension = '.zip'
