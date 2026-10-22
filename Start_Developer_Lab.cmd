@echo off
setlocal
set "GODOT_EXE=C:\Users\jh030\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
if defined ARCANE_GODOT_EXE set "GODOT_EXE=%ARCANE_GODOT_EXE%"
if not exist "%GODOT_EXE%" (
    echo Godot executable not found: "%GODOT_EXE%"
    echo Set ARCANE_GODOT_EXE to your Godot executable path and try again.
    pause
    exit /b 1
)
if /I "%~1"=="--check" (
    echo "%GODOT_EXE%" --path "%~dp0." -- --dev-lab
    exit /b 0
)
"%GODOT_EXE%" --path "%~dp0." -- --dev-lab
if errorlevel 1 pause
