param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $GodotPath) {
    $command = Get-Command godot -ErrorAction SilentlyContinue
    if ($command) { $GodotPath = $command.Source }
}
if (-not $GodotPath) {
    $siblingEngine = Join-Path (Split-Path -Parent $projectRoot) 'Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $siblingEngine) { $GodotPath = $siblingEngine }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Set GODOT_BIN, pass -GodotPath, or import project.godot with Godot 4.7.2.'
}
& $GodotPath --path $projectRoot
