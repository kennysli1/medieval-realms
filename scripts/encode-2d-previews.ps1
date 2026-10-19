param([Parameter(Mandatory = $true)][string]$FfmpegPath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$previewRoot = Join-Path $projectRoot 'docs/previews'
New-Item -ItemType Directory -Path $previewRoot -Force | Out-Null
New-Item -ItemType File -Path (Join-Path $previewRoot '.gdignore') -Force | Out-Null
foreach ($mode in @('resident', 'battle')) {
    $inputPattern = Join-Path $projectRoot "exports/pixel-proof/$mode/%04d.png"
    $mp4Path = Join-Path $previewRoot "$mode-2d.mp4"
    $gifPath = Join-Path $previewRoot "$mode-2d.gif"
    & $FfmpegPath -hide_banner -loglevel error -y -framerate 20 -start_number 1 -i $inputPattern -an -c:v libx264 -crf 19 -pix_fmt yuv420p -movflags +faststart $mp4Path
    if ($LASTEXITCODE -ne 0) { throw "MP4 encoding failed: $mode" }
    $filter = '[0:v]fps=15,scale=960:-1:flags=neighbor,split[a][b];[a]palettegen=max_colors=256:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=3'
    & $FfmpegPath -hide_banner -loglevel error -y -framerate 20 -start_number 1 -i $inputPattern -filter_complex $filter -loop 0 $gifPath
    if ($LASTEXITCODE -ne 0) { throw "GIF encoding failed: $mode" }
    & $FfmpegPath -hide_banner -loglevel error -i $mp4Path -f null -
    if ($LASTEXITCODE -ne 0) { throw "MP4 verification failed: $mode" }
    Write-Host "Saved and verified $mode GIF/MP4."
}
