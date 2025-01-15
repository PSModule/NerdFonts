$release = Invoke-RestMethod 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'
$fonts = @()
$fontArchives = $release.assets.browser_download_url | Where-Object { $_ -like '*.zip' }

foreach ($fontArchive in $fontArchives) {
    $fonts += @{
        Name = $fontArchive.Split('/')[-1].Split('.')[0]
        URL  = $fontArchive
    }
}

$parentFolder = Split-Path -Path $PSScriptRoot -Parent
$filePath = Join-Path -Path $parentFolder -ChildPath 'src\FontsData.json'
$null = New-Item -Path $filePath -ItemType File -Force
$fonts | ConvertTo-Json | Set-Content -Path $filePath -Force

git add .
git commit -m 'Update-FontsData'
git push
