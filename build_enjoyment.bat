@echo off
setlocal
set "REPO_ROOT=%~dp0"
set "OUT_DIR=E:\Desktop\SwitchU\- Switch Frame Tap -\build\sd_out"

echo [switch-frame-tap] Enjoyment build (kitchen-sink soak tree)
echo [switch-frame-tap] Source: %REPO_ROOT%
echo [switch-frame-tap] Output: %OUT_DIR%
echo [switch-frame-tap] Includes: latest upstream + home handoff, ethernet,
echo [switch-frame-tap]   album-capture spike, viewer aspect/chromeless.
echo [switch-frame-tap] Not for upstream PRs - soak / personal testing only.
echo [switch-frame-tap] Windows viewer: build_windows_viewer.bat separately.
echo.

REM Stay on / warn if not enjoyment (do not auto-switch; avoids surprise checkouts)
for /f "delims=" %%b in ('git -C "%REPO_ROOT%." branch --show-current 2^>nul') do set "CUR_BRANCH=%%b"
if /i not "%CUR_BRANCH%"=="exp/enjoyment" (
    echo [switch-frame-tap] WARNING: current branch is "%CUR_BRANCH%" — expected exp/enjoyment
    echo [switch-frame-tap] Continuing anyway so you can build whatever is checked out.
    echo.
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%REPO_ROOT%scripts\build-local.ps1" -OutDir "%OUT_DIR%" %*

if %ERRORLEVEL% neq 0 (
    echo.
    echo [switch-frame-tap] Enjoyment build FAILED!
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo [switch-frame-tap] Build Successful!
echo [switch-frame-tap] Copy contents of %OUT_DIR% to your SD card root.
echo [switch-frame-tap] Then reboot. Volume-Up skips contents sysmodules if needed.
pause
