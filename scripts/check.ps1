param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $godotCommand = Get-Command godot -ErrorAction SilentlyContinue
    if ($godotCommand) { $GodotPath = $godotCommand.Source }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Provide -GodotPath pointing to Godot 4.7.2, or set GODOT_BIN.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$version = & $GodotPath --version
if ($LASTEXITCODE -ne 0 -or $version -notmatch '^4\.7\.2\.') { throw "Expected Godot 4.7.2, got $version" }
function Invoke-GodotCheck([string[]]$GodotArgs) {
    $output = & $GodotPath @GodotArgs 2>&1
    $exitCode = $LASTEXITCODE
    $output | ForEach-Object { Write-Host $_ }
    if ($exitCode -ne 0 -or ($output -match 'SCRIPT ERROR:|Parse Error:|ERROR:')) {
        throw "Godot check failed: $GodotArgs"
    }
}
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--editor', '--import', '--quit')
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_tests.gd')
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_city_tests.gd')
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_ui_tests.gd')
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--script', 'res://tests/run_pixel_proof_tests.gd')
Invoke-GodotCheck @('--headless', '--path', $projectRoot, '--quit-after', '3')
Write-Host 'All foundation checks passed.'
