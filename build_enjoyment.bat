@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "OUT_DIR=E:\Desktop\SwitchU\- Switch Frame Tap -\build\sd_out"

echo [switch-frame-tap] Enjoyment build (kitchen-sink local soak)
echo [switch-frame-tap] Branch tip should be exp/enjoyment = origin/master
echo [switch-frame-tap]   + open PRs (#18 viewer, #19 ethernet, #21 home detach)
echo [switch-frame-tap]   + local SwitchU-capture spike. Not for upstream PRs.
echo [switch-frame-tap] Source: %REPO_ROOT%
echo [switch-frame-tap] Output: %OUT_DIR%
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\build-local.ps1" -OutDir "%OUT_DIR%" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo [switch-frame-tap] Enjoyment build FAILED!
    exit /b %ERRORLEVEL%
)

echo.
echo [switch-frame-tap] Enjoyment build Successful!
echo [switch-frame-tap] Copy contents of %OUT_DIR% to your SD card root, then reboot.
echo [switch-frame-tap] For SwitchU menu capture soak: home_menu = 1 in config.ini
exit /b 0
