$script:Release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
$script:NerdFonts = $script:Release.assets.browser_download_url | Where-Object { $_ -like '*.zip' } | ForEach-Object {
    [pscustomobject]@{
        Name    = $_.Split('/')[-1].Split('.')[0]
        Version = $script:Release.tag_name
        URL     = $_
    }
}
$script:ArchiveExtension = '.zip'
