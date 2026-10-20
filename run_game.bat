@echo off
chcp 65001 >nul
cd /d "%~dp0"
echo ============================================================
echo   FPTU STUDENT SIMULATOR (GODOT 4 EDITION) - TEST RUNNER
echo ============================================================
echo [1/3] Dang kiem tra cu phap GDScript (--check-only)...
godot --headless --quit --check-only --path .
if %ERRORLEVEL% NEQ 0 (
    echo [LOI] Phat hien loi cu phap trong script! Vui long kiem tra lai.
    pause
    exit /b %ERRORLEVEL%
)
echo [OK] 0 Loi bien dich!
echo [2/3] Smoke test: nap va chay thu ca 7 man (tests/smoke_all_stages.gd)...
godot --headless --path . --script tests/smoke_all_stages.gd > smoke_log.txt 2>&1
set SMOKE_RC=%ERRORLEVEL%
type smoke_log.txt
if %SMOKE_RC% NEQ 0 (
    echo [LOI] Smoke test that bai! Xem log phia tren.
    pause
    exit /b %SMOKE_RC%
)
findstr /C:"ERROR:" /C:"SCRIPT ERROR" smoke_log.txt >nul
if %ERRORLEVEL% EQU 0 (
    echo [LOI] Smoke test chay het nhung log co dong ERROR - loi runtime trong _ready/_process. Sua xong moi choi!
    pause
    exit /b 1
)
del smoke_log.txt
echo [OK] Smoke test pass, 0 dong ERROR!
echo      (Bot test tung man: godot --headless --path . --script tests/test_stage1_race.gd ... xem tests/)
echo [3/3] Dang khoi chay game... (Nhan [M] trong game de mo Campaign Hub chon man!)
godot --path .
