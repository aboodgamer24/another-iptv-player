@echo off
setlocal enabledelayedexpansion


if "%~1"=="" (
    echo Usage: update_version.bat ^<version^> [buildNumber]
    echo Example: update_version.bat 1.5.0
    echo          update_version.bat 1.5.0-alpha
    echo          update_version.bat 1.5.0 42   ^(force build number^)
    exit /b 1
)


set "NEW_VERSION=%~1"


:: Read current build number from pubspec.yaml
for /f "tokens=2 delims=+" %%A in ('findstr /r "^version:" pubspec.yaml') do set "CURRENT_BUILD=%%A"
if "%CURRENT_BUILD%"=="" set "CURRENT_BUILD=0"


:: Auto-increment if not provided
if "%~2"=="" (
    set /a "BUILD_NUMBER=CURRENT_BUILD+1"
    echo [INFO] Auto-incremented build number: %CURRENT_BUILD% ^> !BUILD_NUMBER!
) else (
    set /a "BUILD_NUMBER=%~2"
    if !BUILD_NUMBER! LEQ %CURRENT_BUILD% (
        echo ERROR: Build number !BUILD_NUMBER! must be greater than current %CURRENT_BUILD%
        exit /b 1
    )
)


:: Strip pre-release suffix for pubspec.yaml (needs X.Y.Z+N format)
for /f "tokens=1 delims=-" %%A in ("%NEW_VERSION%") do set "PUBSPEC_VERSION=%%A"


echo.
echo ==========================================
echo   Updating version to %NEW_VERSION%+!BUILD_NUMBER!
echo   pubspec version: %PUBSPEC_VERSION%+!BUILD_NUMBER!
echo ==========================================
echo.


set "PS_TMP=%TEMP%\uv.ps1"
if exist "%PS_TMP%" del "%PS_TMP%"

:: WSL path to build_apk.sh (UNC path accessible from Windows)
set "WSL_APK_SH=\\wsl.localhost\Debian\home\abood\build_apk.sh"


>> "%PS_TMP%" echo $v  = '%NEW_VERSION%'
>> "%PS_TMP%" echo $pv = '%PUBSPEC_VERSION%'
>> "%PS_TMP%" echo $b  = '!BUILD_NUMBER!'
>> "%PS_TMP%" echo.
>> "%PS_TMP%" echo # 1 — pubspec.yaml
>> "%PS_TMP%" echo $content = Get-Content 'pubspec.yaml'
>> "%PS_TMP%" echo $content = $content -replace '^version: .*$', "version: $pv+$b"
>> "%PS_TMP%" echo Set-Content 'pubspec.yaml' $content
>> "%PS_TMP%" echo Write-Host '[1/4] pubspec.yaml updated.'
>> "%PS_TMP%" echo.
>> "%PS_TMP%" echo # 2 — build_installer.bat
>> "%PS_TMP%" echo $content = Get-Content 'build_installer.bat'
>> "%PS_TMP%" echo $content = $content -replace '^set VERSION=.*$', "set VERSION=$v"
>> "%PS_TMP%" echo Set-Content 'build_installer.bat' $content
>> "%PS_TMP%" echo Write-Host '[2/4] build_installer.bat updated.'
>> "%PS_TMP%" echo.
>> "%PS_TMP%" echo # 3 — installer.iss
>> "%PS_TMP%" echo $content = Get-Content 'installer.iss'
>> "%PS_TMP%" echo $content = $content -replace '#define MyAppVersion "[^"]*"', ('#define MyAppVersion "' + $v + '"')
>> "%PS_TMP%" echo Set-Content 'installer.iss' $content
>> "%PS_TMP%" echo Write-Host '[3/4] installer.iss updated.'
>> "%PS_TMP%" echo.
>> "%PS_TMP%" echo # 4 — build_apk.sh inside WSL via UNC path
>> "%PS_TMP%" echo $wslSh = '%WSL_APK_SH%'
>> "%PS_TMP%" echo if (Test-Path $wslSh) {
>> "%PS_TMP%" echo     $sh = (Get-Content $wslSh -Raw)
>> "%PS_TMP%" echo     $sh = $sh -replace 'VERSION="[^"]*"', "VERSION=`"$v`""
>> "%PS_TMP%" echo     [System.IO.File]::WriteAllText($wslSh, $sh)
>> "%PS_TMP%" echo     Write-Host '[4/4] build_apk.sh updated.'
>> "%PS_TMP%" echo } else {
>> "%PS_TMP%" echo     Write-Warning '[4/4] build_apk.sh not found at: ' + $wslSh
>> "%PS_TMP%" echo     Write-Warning 'Make sure WSL (Debian) is running and build_apk.sh exists at ~/build_apk.sh'
>> "%PS_TMP%" echo }


powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TMP%"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Version update failed!
    del "%PS_TMP%"
    pause & exit /b 1
)


del "%PS_TMP%"


echo.
echo Done!
echo   pubspec.yaml        ^<-- %PUBSPEC_VERSION%+!BUILD_NUMBER!
echo   build_installer.bat ^<-- %NEW_VERSION%
echo   installer.iss       ^<-- %NEW_VERSION%
echo   build_apk.sh        ^<-- %NEW_VERSION%
echo.
echo Next steps:
echo   .\build_installer.bat          -- build everything (Windows + Phone + TV)
echo   wsl bash ~/build_apk.sh --all  -- APKs only (phone + TV)
echo   wsl bash ~/build_apk.sh --tv   -- TV APK only
echo.
endlocal