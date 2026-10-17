@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "OUT_DIR=E:\Desktop\SwitchU\- Switch Frame Tap -\build\sd_out"

echo [switch-frame-tap] Native local build (devkitPro — Switch SD payload only)
echo [switch-frame-tap] Source: %REPO_ROOT%
echo [switch-frame-tap] Output: %OUT_DIR%
echo [switch-frame-tap] For SwitchFrameTap.exe, use build_windows_viewer.bat
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\build-local.ps1" -OutDir "%OUT_DIR%" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo [switch-frame-tap] Build FAILED!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [switch-frame-tap] Build Successful!
echo [switch-frame-tap] Copy contents of %OUT_DIR% to your SD card root.
echo [switch-frame-tap] Then reboot. Volume-Up skips contents sysmodules if needed.
pause
