# Local switch-frame-tap build for Windows + native devkitPro (NO Docker).
# Same idea as SwitchU scripts/build-local.ps1.
#
# Usage:
#   .\build_local.bat
#   .\scripts\build-local.ps1
#   .\scripts\build-local.ps1 -Clean     # wipe applet-mitm build dirs, then rebuild
#
# First run clones Atmosphere to C:\switch-frame-tap-ams\Atmosphere (large)
# and builds libstratosphere (~5-10 min once). Later runs are incremental
# (changed .cpp only) — typically under a minute when libstrat is cached.
param(
    [string]$OutDir = "E:\Desktop\SwitchU\- Switch Frame Tap -\build\sd_out",
    [string]$AtmosphereDir = "C:\switch-frame-tap-ams\Atmosphere",
    [string]$AtmosphereTag = "1.11.2",
    [switch]$SkipClone,
    [switch]$Clean
)

$ErrorActionPreference = "Stop"
$swTotal = [System.Diagnostics.Stopwatch]::StartNew()

$RepoRoot = Split-Path -Parent $PSScriptRoot
$DevkitPro = "C:\devkitPro"
$Bash = Join-Path $DevkitPro "msys2\usr\bin\bash.exe"
$Src = Join-Path $RepoRoot "tier4\applet-mitm"

Set-Location $RepoRoot
Write-Host "[switch-frame-tap] Repo: $RepoRoot"
Write-Host "[switch-frame-tap] Native build (devkitPro) - no Docker"

if (-not (Test-Path "$DevkitPro\devkitA64\bin\aarch64-none-elf-g++.exe")) {
    throw "devkitPro not found at $DevkitPro"
}
if (-not (Test-Path $Bash)) {
    throw "msys2 bash not found at $Bash"
}

if (-not (Test-Path "C:\opt")) {
    New-Item -ItemType Directory -Path "C:\opt" | Out-Null
}
if (-not (Test-Path "C:\opt\devkitpro")) {
    & "$env:SystemRoot\System32\cmd.exe" /c mklink /J "C:\opt\devkitpro" $DevkitPro | Out-Null
}

$env:DEVKITPRO = $DevkitPro
$env:DEVKITARM = Join-Path $DevkitPro "devkitARM"
$env:Path = @(
    "C:\Program Files\Git\cmd",
    "$DevkitPro\devkitA64\bin",
    "$DevkitPro\tools\bin",
    "$DevkitPro\portlibs\switch\bin",
    "$DevkitPro\msys2\usr\bin",
    $env:Path
) -join ";"

$python = $null
foreach ($name in @('python', 'py')) {
    $cmd = Get-Command $name -ErrorAction SilentlyContinue
    if ($cmd -and ($cmd.Source -notmatch 'WindowsApps')) {
        $python = $cmd.Source
        break
    }
}
if (-not $python) {
    $cmd = Get-Command python -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source }
}
if (-not $python) {
    throw "python not found (needed for patch_libstrat.py)"
}

$git = Get-Command git -ErrorAction SilentlyContinue
if (-not $git) {
    throw "git not found"
}

Write-Host "[switch-frame-tap] DEVKITPRO=$env:DEVKITPRO"
Write-Host "[switch-frame-tap] python=$python"

function To-UnixPath([string]$winPath) {
    $drive = $winPath.Substring(0, 1).ToLower()
    $rest = $winPath.Substring(2).Replace('\', '/')
    return "/$drive$rest"
}

function Write-Step([string]$msg) {
    Write-Host ("[switch-frame-tap] {0}  ({1:n1}s elapsed)" -f $msg, $swTotal.Elapsed.TotalSeconds)
}

$refLink = Join-Path $RepoRoot "ref\Atmosphere"
$amsOk = Test-Path (Join-Path $AtmosphereDir "libraries\config\templates\stratosphere.mk")

if (-not $amsOk) {
    if ($SkipClone) {
        throw "Atmosphere missing at $AtmosphereDir"
    }
    Write-Step "Cloning Atmosphere $AtmosphereTag -> $AtmosphereDir (first run only)"
    $parent = Split-Path -Parent $AtmosphereDir
    New-Item -ItemType Directory -Force -Path $parent | Out-Null
    if (Test-Path $AtmosphereDir) {
        Remove-Item $AtmosphereDir -Recurse -Force
    }
    & git clone --recursive --branch $AtmosphereTag --depth 1 `
        https://github.com/Atmosphere-NX/Atmosphere.git $AtmosphereDir
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[switch-frame-tap] Tagged clone failed; cloning default branch..."
        if (Test-Path $AtmosphereDir) {
            Remove-Item $AtmosphereDir -Recurse -Force
        }
        & git clone --recursive https://github.com/Atmosphere-NX/Atmosphere.git $AtmosphereDir
        if ($LASTEXITCODE -ne 0) {
            throw "Atmosphere clone failed"
        }
    }
}

New-Item -ItemType Directory -Force -Path (Join-Path $RepoRoot "ref") | Out-Null
if (Test-Path $refLink) {
    $item = Get-Item $refLink -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        & "$env:SystemRoot\System32\cmd.exe" /c rmdir "$refLink" | Out-Null
    }
}
if (-not (Test-Path $refLink)) {
    & "$env:SystemRoot\System32\cmd.exe" /c mklink /J "$refLink" "$AtmosphereDir" | Out-Null
}
Write-Step "Atmosphere: $AtmosphereDir"

Write-Step "Applying patch_libstrat.py (no-op if already patched)..."
& $python (Join-Path $Src "patch_libstrat.py") $AtmosphereDir
if ($LASTEXITCODE -ne 0) {
    throw "patch_libstrat.py failed"
}

$dst = Join-Path $AtmosphereDir "stratosphere\applet-mitm"
Write-Step "Syncing sources -> $dst (incremental; keeps build/)"
New-Item -ItemType Directory -Force -Path $dst | Out-Null

if ($Clean) {
    Write-Step "Clean: removing applet-mitm build/ and out/"
    foreach ($d in @('build', 'out')) {
        $p = Join-Path $dst $d
        if (Test-Path $p) { Remove-Item $p -Recurse -Force }
    }
}

# IMPORTANT: do NOT delete sources before copy. Wiping .cpp resets mtimes and
# forces a full recompile every export (the SwitchU xmake path never does this).
# robocopy only copies files that differ by size/time; /XO skips older sources.
$rc = 0
& robocopy $Src $dst /E /XO /XD out build test /XF build.sh build_native.sh patch_libstrat.py *.nsp /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
$rc = $LASTEXITCODE
if ($rc -ge 8) {
    throw "robocopy failed (code $rc)"
}
Write-Step ("Source sync done (robocopy code {0}: 0/1 = nothing/copied)" -f $rc)

$libA = Join-Path $AtmosphereDir "libraries\libstratosphere\lib\nintendo_nx_arm64_armv8a\release\libstratosphere.a"
$haveLib = Test-Path $libA
if ($haveLib) {
    $libMb = [math]::Round((Get-Item $libA).Length / 1MB, 1)
    Write-Step "libstratosphere.a present (${libMb} MB) — skipping lib rebuild check"
} else {
    Write-Step "libstratosphere.a missing — first make will build it (~5-10 min once)"
}

# Cap parallelism: -j64 + LTO thrashes; SwitchU enjoyment builds stay leaner.
$jobs = [Math]::Min(16, [Math]::Max(4, [Environment]::ProcessorCount))
$dstUnix = To-UnixPath $dst
Write-Step "make nx_release -j$jobs ..."
$env:MSYSTEM = "MSYS"
$env:CHERE_INVOKING = "1"

# ATMOSPHERE_CHECKED_LIBSTRATOSPHERE=1 tells system_module.mk the .a is already
# good — make will not descend into libstratosphere (saves a slow no-op walk).
$checked = if ($haveLib) { "ATMOSPHERE_CHECKED_LIBSTRATOSPHERE=1" } else { "" }

$makeScript = @"
set -e
export DEVKITPRO=/c/devkitPro
export PATH="`$DEVKITPRO/devkitA64/bin:`$DEVKITPRO/tools/bin:`$PATH"
export MAKEFLAGS='-j$jobs'
cd '$dstUnix'
make nx_release $checked
"@

$swMake = [System.Diagnostics.Stopwatch]::StartNew()
& $Bash -lc $makeScript
if ($LASTEXITCODE -ne 0) {
    throw "make nx_release failed"
}
Write-Step ("make finished in {0:n1}s" -f $swMake.Elapsed.TotalSeconds)

$builtNsp = Get-ChildItem (Join-Path $dst "out") -Recurse -Filter "*.nsp" -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1
if (-not $builtNsp) {
    throw "No .nsp under $dst\out"
}

$localNsp = Join-Path $Src $builtNsp.Name
Copy-Item $builtNsp.FullName $localNsp -Force
Write-Step "NSP: $localNsp"

# v0.7.10+: memory donor (no boot2); applet-mitm launches it while a viewer is connected.
# Build in a no-space path - libnx donor Makefile breaks when CURDIR has spaces.
$donorDir = Join-Path $RepoRoot "tier4\donor"
$donorWork = "C:\switch-frame-tap-ams\donor"
Write-Step "make sft-donor (workdir $donorWork) ..."
if (Test-Path $donorWork) { Remove-Item $donorWork -Recurse -Force }
New-Item -ItemType Directory -Force -Path $donorWork | Out-Null
Copy-Item (Join-Path $donorDir '*') $donorWork -Recurse -Force
$donorMake = @"
set -e
export DEVKITPRO=/c/devkitPro
export PATH="`$DEVKITPRO/devkitA64/bin:`$DEVKITPRO/tools/bin:`$PATH"
cd /c/switch-frame-tap-ams/donor
make
"@
& $Bash -lc $donorMake
if ($LASTEXITCODE -ne 0) {
    throw "donor make failed"
}
$donorNsp = Join-Path $donorDir "sft-donor.nsp"
Copy-Item (Join-Path $donorWork "sft-donor.nsp") $donorNsp -Force
if (-not (Test-Path $donorNsp)) {
    throw "No sft-donor.nsp under $donorDir"
}
Write-Step "donor NSP: $donorNsp"

Write-Step "Staging SD output -> $OutDir"
if (Test-Path $OutDir) {
    Remove-Item $OutDir -Recurse -Force
}
$content = Join-Path $OutDir "atmosphere\contents\0100000000000C20"
New-Item -ItemType Directory -Force -Path (Join-Path $content "flags") | Out-Null
Copy-Item $localNsp (Join-Path $content "exefs.nsp")
New-Item -ItemType File -Force -Path (Join-Path $content "flags\boot2.flag") | Out-Null

$donorContent = Join-Path $OutDir "atmosphere\contents\0100000000000C21"
New-Item -ItemType Directory -Force -Path $donorContent | Out-Null
Copy-Item $donorNsp (Join-Path $donorContent "exefs.nsp")

# Ship a starter config snippet for detach-on-home (does not overwrite user config).
$expCfg = Join-Path $RepoRoot "EXP_DETACH_ON_HOME\config.ini.example"
if (Test-Path $expCfg) {
    Copy-Item $expCfg (Join-Path $OutDir "config_switch-frame-tap_example.ini") -Force
}

$toolbox = @'
{
    "name": "Switch Frame Tap (local)",
    "tid": "0100000000000C20",
    "requires_reboot": true
}
'@
Set-Content -Encoding ascii (Join-Path $content "toolbox.json") $toolbox

$branch = ""
try { $branch = (git -C $RepoRoot branch --show-current 2>$null) } catch { }
$enjoy = ($branch -eq "exp/enjoyment")
$readme = if ($enjoy) {
@'
switch-frame-tap ENJOYMENT build (kitchen-sink soak)
====================================================
Copy this folder onto the ROOT of your SD card (merge/overwrite).

Includes:
  atmosphere/contents/0100000000000C20  (sysmodule, boot2)
  atmosphere/contents/0100000000000C21  (sft-donor, no boot2)

Stack (on latest upstream): faster HOME handoff, ethernet/mid-join,
gated capture_album=1 probe for SwitchU 100D. detach_on_home already upstream.

Opt out of detach: detach_on_home = 0 in sdmc:/config/switch-frame-tap/config.ini
Album probe (optional): capture_album = 1 in that config.ini

Recovery: Volume Up at boot, or delete atmosphere/contents/0100000000000C20/

Built with native devkitPro (no Docker). Windows viewer: build_windows_viewer.bat
'@
} else {
@'
switch-frame-tap LOCAL native test build
========================================
Copy this folder onto the ROOT of your SD card (merge/overwrite).

Includes:
  atmosphere/contents/0100000000000C20  (sysmodule, boot2)
  atmosphere/contents/0100000000000C21  (sft-donor, no boot2)

detach_on_home is ON by default (upstream PR #13).
Opt out with: detach_on_home = 0 in sdmc:/config/switch-frame-tap/config.ini

Recovery: Volume Up at boot, or delete atmosphere/contents/0100000000000C20/

Built with native devkitPro (no Docker).
'@
}
Set-Content -Encoding ascii (Join-Path $OutDir "README_TEST.txt") $readme

Write-Host ""
Write-Host ("[switch-frame-tap] Ready: {0}  (total {1:n1}s)" -f $OutDir, $swTotal.Elapsed.TotalSeconds) -ForegroundColor Green
Write-Host "[switch-frame-tap] Copy that folder onto the SD root, then reboot."
