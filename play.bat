@echo off
setlocal
cd /d "%~dp0"
if defined GODOT_BIN (
    set "gameGodotPath=%GODOT_BIN%"
    goto run_game
)
set "gameGodotPath=%~dp0..\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe"
if exist "%gameGodotPath%" goto run_game
where godot >nul 2>nul
if errorlevel 1 (
    echo Godot not found. Set GODOT_BIN or open project.godot with Godot 4.7.2.
    pause
    exit /b 1
)
set "gameGodotPath=godot"
:run_game
"%gameGodotPath%" --path "%~dp0." %*
if errorlevel 1 pause
