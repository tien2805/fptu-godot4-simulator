@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   FPTU STUDENT SIMULATOR - BUILD BAN WINDOWS (export)
echo ============================================================
set "TPL=%APPDATA%\Godot\export_templates\4.7.2.stable\windows_release_x86_64.exe"
if not exist "%TPL%" (
    echo [LOI] Chua cai Export Templates cho Godot 4.7.2.
    echo       Cach 1: mo Godot Editor - menu Editor - Manage Export Templates - Download and Install.
    echo       Cach 2: tai Godot_v4.7.2-stable_export_templates.tpz tu github.com/godotengine/godot/releases,
    echo               doi duoi .tpz thanh .zip, giai nen va chep noi dung thu muc templates vao:
    echo               %APPDATA%\Godot\export_templates\4.7.2.stable\
    pause
    exit /b 1
)
echo [1/4] Import tai nguyen...
godot --headless --path . --import
echo [2/4] Kiem tra cu phap...
godot --headless --path . --quit --check-only
if %ERRORLEVEL% NEQ 0 (
    echo [LOI] Loi cu phap GDScript.
    pause
    exit /b 1
)
echo [3/4] Export Windows Desktop...
if not exist build\windows mkdir build\windows
godot --headless --path . --export-release "Windows Desktop" build\windows\FPTU-Student-Simulator.exe
if %ERRORLEVEL% NEQ 0 (
    echo [LOI] Export that bai - xem log phia tren.
    pause
    exit /b 1
)
echo [4/4] Dong goi zip...
copy /Y README.md build\windows\README.md >nul
powershell -NoProfile -Command "Compress-Archive -Force -Path 'build\windows\*' -DestinationPath 'build\FPTU-Student-Simulator-windows.zip'"
echo.
echo [OK] Xong: build\FPTU-Student-Simulator-windows.zip
echo      Nguoi choi chi can giai nen va chay FPTU-Student-Simulator.exe.
pause
