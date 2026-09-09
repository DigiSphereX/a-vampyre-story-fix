<#
.SYNOPSIS
    A Vampyre Story - Fix and Play
.DESCRIPTION
    Makes the 2008 Panda3D release of "A Vampyre Story" playable on modern Windows
    (Windows 10/11) by fixing the DirectX9 start-up hang and the black-screen
    after "New Game".

    Applied fixes:
      1. Config.prc   -> force the DirectX9 renderer (load-display pandadx9)
      2. dgVoodoo2    -> local D3D8/D3D9/D3DImm/DDraw wrapper for the modern GPU
                         (auto-downloaded from GitHub, SHA256 verified)
      3. dgVoodoo.conf -> emulates "GeForce FX 5700 Ultra", watermark off
      4. Compatibility -> Windows XP SP2 for main.exe and LAUNCHER.exe
      5. Anti-aliasing -> forced to 0 in assets/scripts/14793.bin
      6. Launch        -> via LAUNCHER.exe (SmartSteamEmu loader)

    Usage:
      .\A_Vampyre_Story_Fix_and_Play.ps1
      .\A_Vampyre_Story_Fix_and_Play.ps1 -Force        (re-apply, re-download)
      .\A_Vampyre_Story_Fix_and_Play.ps1 -SkipInstall  (skip dgVoodoo2 download)
      .\A_Vampyre_Story_Fix_and_Play.ps1 -NoLaunch     (fix only, do not start)
.EXAMPLE
    .\A_Vampyre_Story_Fix_and_Play.ps1 -NoLaunch
.NOTES
    dgVoodoo2 (c) by Dege - https://github.com/dege-diosg/dgVoodoo2 (freeware)
    Launches the game through LAUNCHER.exe so SmartSteamEmu is injected.
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipInstall,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
$GameDir = $PSScriptRoot
if (-not $GameDir) { $GameDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

function Write-Step { param([string]$Msg) Write-Host ("[A Vampyre Story Fix] " + $Msg) }

Write-Step "Game directory: $GameDir"

# ------------------------------------------------------------- checks
$mainExe = Join-Path $GameDir 'main.exe'
$launcherExe = Join-Path $GameDir 'LAUNCHER.exe'
if (-not (Test-Path $mainExe))  { throw "main.exe not found in $GameDir" }
if (-not (Test-Path $launcherExe)) { throw "LAUNCHER.exe not found in $GameDir" }

# ------------------------------------------------------------- 1. Config.prc
$cfg = Join-Path $GameDir 'etc\Config.prc'
if (Test-Path $cfg) {
    $t = Get-Content $cfg -Raw
    if ($t -match 'load-display\s+pandagl') {
        $t = $t -replace 'load-display\s+pandagl', 'load-display pandadx9'
        Set-Content -Path $cfg -Value $t -Encoding ASCII
        Write-Step "Config.prc: switched renderer back to DirectX9 (pandadx9)"
    } elseif ($t -match 'load-display\s+pandadx9') {
        Write-Step "Config.prc: DirectX9 renderer already active"
    } else {
        $t = $t + "`nload-display pandadx9`n"
        Set-Content -Path $cfg -Value $t -Encoding ASCII
        Write-Step "Config.prc: forced DirectX9 renderer (pandadx9)"
    }
} else {
    Write-Warning "Config.prc not found ($cfg) - skipping renderer fix"
}

# ------------------------------------------------------------- 2-3. dgVoodoo2
$needDlls = @('D3D9.dll','D3D8.dll','D3DImm.dll','DDraw.dll') |
    Where-Object { -not (Test-Path (Join-Path $GameDir $_)) }
if ($SkipInstall) {
    Write-Step "SkipInstall: skipping dgVoodoo2 check"
} elseif ($needDlls -or $Force) {
    $zipName  = 'dgVoodoo2_87_4.zip'
    $zipUri   = 'https://github.com/dege-diosg/dgVoodoo2/releases/download/v2.87.4/dgVoodoo2_87_4.zip'
    $expect   = '74AEB464D829DB80E3F4AA8FAE235E6E3B38FC01188776C5C2376BB0DEA0956E'
    $tmpZip   = Join-Path $env:TEMP $zipName
    Write-Step "Downloading dgVoodoo2 v2.87.4 ..."
    Invoke-WebRequest -Uri $zipUri -OutFile $tmpZip -UseBasicParsing
    $hash = (Get-FileHash -Path $tmpZip -Algorithm SHA256).Hash
    if ($hash -ne $expect) { throw "dgVoodoo2 SHA256 mismatch: $hash" }
    Write-Step "SHA256 verified"

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmpDir = Join-Path $env:TEMP ('dgv_' + [guid]::NewGuid().ToString('N'))
    [System.IO.Compression.ZipFile]::ExtractToDirectory($tmpZip, $tmpDir)

    foreach ($d in $needDlls) {
        Copy-Item (Join-Path $tmpDir "MS\x86\$d") $GameDir -Force
    }
    if ($Force -or -not (Test-Path (Join-Path $GameDir 'D3D9.dll'))) {
        Copy-Item (Join-Path $tmpDir 'MS\x86\D3D9.dll') $GameDir -Force
    }
    Copy-Item (Join-Path $tmpDir 'MS\x86\D3D8.dll')   $GameDir -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $tmpDir 'MS\x86\D3DImm.dll') $GameDir -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $tmpDir 'MS\x86\DDraw.dll')  $GameDir -Force -ErrorAction SilentlyContinue
    Copy-Item (Join-Path $tmpDir 'dgVoodooCpl.exe')   $GameDir -Force -ErrorAction SilentlyContinue
    Remove-Item $tmpDir -Recurse -Force
    Write-Step "dgVoodoo2 wrapper files installed"
} else {
    Write-Step "dgVoodoo2 wrapper already present"
    if (-not (Test-Path (Join-Path $GameDir 'dgVoodooCpl.exe'))) {
        Write-Warning "dgVoodooCpl.exe missing"
    }
}

# dgVoodoo.conf tuning (only write when missing)
$conf = Join-Path $GameDir 'dgVoodoo.conf'
if (-not (Test-Path $conf) -and -not $SkipInstall) {
    $confText = @(
        'Version                              = 0x287',
        '',
        '[General]',
        'OutputAPI                            = bestavailable',
        'Adapters                             = all',
        'FullScreenOutput                     = default',
        'FullScreenMode                       = true',
        'ScalingMode                          = unspecified',
        'ProgressiveScanlineOrder             = false',
        'EnumerateRefreshRates                = false',
        'Brightness                           = 100',
        'Color                                = 100',
        'Contrast                             = 100',
        'InheritColorProfileInFullScreenMode  = true',
        'KeepWindowAspectRatio                = true',
        'CaptureMouse                         = true',
        'CenterAppWindow                      = false',
        'DisableScreenSaver                   = false',
        '',
        '[GeneralExt]',
        'DesktopResolution                    = ',
        'DesktopBitDepth                      = ',
        'DeframerSize                         = 1',
        'ImageScaleFactor                     = 1',
        'CursorScaleFactor                    = 0',
        'DisplayROI                           = ',
        'Resampling                           = bilinear',
        'PresentationModel                    = auto',
        'ColorSpace                           = appdriven',
        'WatermarkDisplayDuration             = 0',
        'FreeMouse                            = false',
        'WindowedAttributes                   = ',
        'FullscreenAttributes                 = ',
        'FPSLimit                             = 0',
        'Environment                          = ',
        'SystemHookFlags                      = gdi',
        '',
        '[Glide]',
        'VideoCard                           = voodoo_2',
        'OnboardRAM                          = 8',
        'MemorySizeOfTMU                     = 4096',
        'NumberOfTMUs                        = 2',
        'TMUFiltering                        = appdriven',
        'DisableMipmapping                   = false',
        'Resolution                          = unforced',
        'Antialiasing                        = appdriven',
        'EnableGlideGammaRamp                = true',
        'ForceVerticalSync                   = true',
        'ForceEmulatingTruePCIAccess         = false',
        '16BitDepthBuffer                    = false',
        '3DfxWatermark                       = true',
        '3DfxSplashScreen                    = false',
        'PointcastPalette                    = false',
        'EnableInactiveAppState              = false',
        '',
        '[GlideExt]',
        'DitheringEffect                     = pure32bit',
        'Dithering                           = forcealways',
        'DitherOrderedMatrixSizeScale        = 0',
        '',
        '[DirectX]',
        'DisableAndPassThru                  = false',
        'VideoCard                           = geforce_fx_5700_ultra',
        'VRAM                                = 256',
        'Filtering                           = appdriven',
        'Mipmapping                          = appdriven',
        'KeepFilterIfPointSampled            = false',
        'Resolution                          = unforced',
        'Antialiasing                        = appdriven',
        'AppControlledScreenMode             = true',
        'DisableAltEnterToToggleScreenMode   = true',
        'Bilinear2DOperations                = false',
        'PhongShadingWhenPossible            = false',
        'ForceVerticalSync                   = false',
        'dgVoodooWatermark                   = false',
        'FastVideoMemoryAccess               = false',
        'DisableD3DTnLDevice                 = false',
        '',
        '[DirectXExt]',
        'AdapterIDType                       = ',
        'VendorID                            = ',
        'DeviceID                            = ',
        'SubsystemID                         = ',
        'RevisionID                          = ',
        'DefaultEnumeratedResolutions        = all',
        'ExtraEnumeratedResolutions          = ',
        'EnumeratedResolutionBitdepths       = all',
        'DitheringEffect                     = high_quality',
        'Dithering                           = forcealways',
        'DitherOrderedMatrixSizeScale        = 0',
        'DepthBuffersBitDepth                = appdriven',
        'Default3DRenderFormat               = auto',
        'MaxVSConstRegisters                 = 256',
        'D3D12BoundsChecking                 = false',
        'NPatchTesselationLevel              = 0',
        'DisplayOutputEnableMask             = 0xffffffff',
        'MSD3DDeviceNames                    = false',
        'RTTexturesForceScaleAndMSAA         = true',
        'SmoothedDepthSampling               = true',
        'DeferredScreenModeSwitch            = true',
        'PrimarySurfaceBatchedUpdate         = false',
        'SuppressAMDBlacklist                = false',
        ''
    ) -join "`r`n"
    Set-Content -Path $conf -Value $confText -Encoding ASCII
    Write-Step "dgVoodoo.conf created (GeForce FX 5700 Ultra simulation, no watermark)"
} else {
    Write-Step "dgVoodoo.conf already present"
}

# ------------------------------------------------------------- 4. compatibility
$lay = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
foreach ($exe in @($mainExe, $launcherExe)) {
    $already = (Get-ItemProperty -Path $lay -Name $exe -ErrorAction SilentlyContinue).$exe
    if ($already -notmatch 'WINXPSP2') {
        New-Item -Path $lay -Force | Out-Null
        New-ItemProperty -Path $lay -Name $exe -Value " WINXPSP2" -PropertyType String -Force | Out-Null
        Write-Step "Compatibility XP SP2 set: $(Split-Path $exe -Leaf)"
    } else {
        Write-Step "Compatibility XP SP2 already set: $(Split-Path $exe -Leaf)"
    }
}

# ------------------------------------------------------------- 5. anti-aliasing
$aa = Join-Path $GameDir 'assets\scripts\14793.bin'
if (Test-Path $aa) {
    if (-not (Test-Path ($aa + '.bak'))) { Copy-Item $aa ($aa + '.bak') }
    $c  = Get-Content $aa -Raw
    $c2 = $c -replace 'anti_alias_level"\s+value="\d+"', 'anti_alias_level" value="0"'
    if ($c -ne $c2) {
        Set-Content -Path $aa -Value $c2 -Encoding ASCII
        Write-Step "Anti-aliasing disabled (value=0) in assets/scripts/14793.bin"
    } else {
        Write-Step "Anti-aliasing already 0"
    }
} else {
    Write-Warning "14793.bin not found - skipping anti-aliasing fix"
}

Write-Step "All fixes are in place."

# ------------------------------------------------------------- 6. launch
if ($NoLaunch) {
    Write-Step "NoLaunch specified - game not started."
} else {
    Write-Step "Starting game via LAUNCHER.exe ..."
    Start-Process -FilePath $launcherExe -WorkingDirectory $GameDir
    Write-Step "Done. If the window stays black during the intro, press a key to skip it."
}