@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Usage: update_version.bat ^<version^> ^<buildNumber^>
    echo Example: update_version.bat 1.5.0 22
    echo          update_version.bat 1.5.0-alpha 23
    exit /b 1
)
if "%~2"=="" (
    echo ERROR: Build number is required.
    echo Usage: update_version.bat ^<version^> ^<buildNumber^>
    echo Example: update_version.bat 1.5.0 22
    exit /b 1
)

set "NEW_VERSION=%~1"
set "BUILD_NUMBER=%~2"

:: Strip pre-release suffix (e.g. -alpha, -beta, -rc1) for pubspec.yaml
:: pubspec only accepts X.Y.Z+N format
for /f "tokens=1 delims=-" %%A in ("%NEW_VERSION%") do set "PUBSPEC_VERSION=%%A"

echo.
echo ==========================================
echo   Updating version to %NEW_VERSION%+%BUILD_NUMBER%
echo   pubspec version: %PUBSPEC_VERSION%+%BUILD_NUMBER%
echo ==========================================
echo.

set "PS_TMP=%TEMP%\uv.ps1"
if exist "%PS_TMP%" del "%PS_TMP%"

>> "%PS_TMP%" echo $v = '%NEW_VERSION%'
>> "%PS_TMP%" echo $pv = '%PUBSPEC_VERSION%'
>> "%PS_TMP%" echo $b = '%BUILD_NUMBER%'
>> "%PS_TMP%" echo $content = Get-Content 'pubspec.yaml'
>> "%PS_TMP%" echo $content = $content -replace '^version: .*$', "version: $pv+$b"
>> "%PS_TMP%" echo Set-Content 'pubspec.yaml' $content
>> "%PS_TMP%" echo Write-Host '[1/3] pubspec.yaml updated.'
>> "%PS_TMP%" echo $content = Get-Content 'build_installer.bat'
>> "%PS_TMP%" echo $content = $content -replace '^set VERSION=.*$', "set VERSION=$v"
>> "%PS_TMP%" echo Set-Content 'build_installer.bat' $content
>> "%PS_TMP%" echo Write-Host '[2/3] build_installer.bat updated.'
>> "%PS_TMP%" echo $content = Get-Content 'installer.iss'
>> "%PS_TMP%" echo $content = $content -replace '#define MyAppVersion "[^"]*"', ('#define MyAppVersion "' + $v + '"')
>> "%PS_TMP%" echo Set-Content 'installer.iss' $content
>> "%PS_TMP%" echo Write-Host '[3/3] installer.iss updated.'

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TMP%"
if %ERRORLEVEL% neq 0 ( echo ERROR: Version update failed! & del "%PS_TMP%" & pause & exit /b 1 )

del "%PS_TMP%"

echo.
echo Done!
echo   pubspec.yaml  ^<-- %PUBSPEC_VERSION%+%BUILD_NUMBER%
echo   build_installer.bat + installer.iss ^<-- %NEW_VERSION%
echo.
echo Run .\build_installer.bat to build.
echo.
endlocal