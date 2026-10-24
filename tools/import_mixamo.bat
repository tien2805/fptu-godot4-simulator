@echo off
chcp 65001 >nul
cd /d "%~dp0\.."
echo ============================================================
echo   MIXAMO MOCAP CHO CINEMATIC (chi tren may nay, khong commit)
echo ============================================================
set "SRC=%~1"
if "%SRC%"=="" set "SRC=D:\mixamo_fight"
if not exist "%SRC%\*.fbx" (
    echo [LOI] Khong thay file .fbx trong "%SRC%".
    echo       Cach dung: tools\import_mixamo.bat [thu muc chua file .fbx]
    pause
    exit /b 1
)
if not exist assets\local\mixamo mkdir assets\local\mixamo
echo [1/3] Chep file FBX tu "%SRC%" vao assets\local\mixamo ...
copy /Y "%SRC%\*.fbx" assets\local\mixamo\ >nul
echo [2/3] Godot import FBX (ufbx co san)...
godot --headless --import --path . > assets\local\mixamo_import.log 2>&1
echo [3/3] Kiem tra retarget...
godot --headless --path . --script tools/mixamo_report.gd
echo Xong. Thu muc assets\local\ da duoc .gitignore va loai khoi ban export.
pause
