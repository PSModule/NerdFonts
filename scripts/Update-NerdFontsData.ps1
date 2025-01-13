$release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
$fonts = @()
$fontArchives = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' }

foreach ($fontArchive in $fontArchives) {
    $fonts += @{
        Name = $fontArchive.Split('/')[-1].Split('.')[0]
        URL  = $fontArchive
    }
}

New-Item -Path 'data\NerdFonts.json' -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path 'data\NerdFonts.json' -Force
