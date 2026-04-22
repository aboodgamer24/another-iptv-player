@echo off
setlocal enabledelayedexpansion

echo ================================================
echo   C4-TV Build Script - Windows + Android APK
echo ================================================
echo.

:: ── CONFIG ──────────────────────────────────────
set VERSION=1.4.0
set APP_NAME=C4-TV
set OUT_DIR=release_bundle
set NSIS_PATH=C:\Program Files (x86)\NSIS\makensis.exe
:: ────────────────────────────────────────────────

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"

:: ════════════════════════════════════════════════
:: STEP 1 — Build Windows
:: ════════════════════════════════════════════════
echo [1/4] Building Flutter Windows release...
call flutter build windows --release
if %ERRORLEVEL% neq 0 (
    echo ERROR: Windows build failed!
    pause & exit /b 1
)
echo       Windows build complete.
echo.

:: ════════════════════════════════════════════════
:: STEP 2 — Package Windows (Portable ZIP)
:: ════════════════════════════════════════════════
echo [2/4] Creating Windows portable ZIP...
set WIN_SRC=build\windows\x64\runner\Release
set WIN_ZIP=%OUT_DIR%\%APP_NAME%-windows-%VERSION%.zip

if exist "%WIN_ZIP%" del "%WIN_ZIP%"
7z a "%WIN_ZIP%" ".\%WIN_SRC%\*" >nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Failed to create Windows ZIP. Make sure 7-Zip is installed.
    pause & exit /b 1
)
echo       Created: %WIN_ZIP%
echo.

:: ════════════════════════════════════════════════
:: STEP 3 — Build Windows Installer (NSIS)
:: ════════════════════════════════════════════════
echo [3/4] Compiling NSIS installer...
if not exist "%NSIS_PATH%" (
    echo WARNING: NSIS not found at "%NSIS_PATH%"
    echo          Skipping installer creation. Install NSIS and re-run if needed.
    echo          Download: https://nsis.sourceforge.io/
    goto :BUILD_ANDROID
)

"%NSIS_PATH%" windows\installer.nsi
if %ERRORLEVEL% neq 0 (
    echo ERROR: NSIS installer compilation failed!
    pause & exit /b 1
)

:: Move installer to output folder
if exist "another-iptv-player-windows-setup.exe" (
    move "another-iptv-player-windows-setup.exe" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
    echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
) else (
    echo WARNING: Installer .exe not found after NSIS build.
)
echo.

:: ════════════════════════════════════════════════
:: STEP 4 — Build Android Universal APK (via WSL)
:: ════════════════════════════════════════════════
:BUILD_ANDROID
echo [4/4] Building Android Universal APK...
echo.

:: Check if WSL is available
wsl --status >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo WARNING: WSL not found or not running.
    echo          Android APK requires WSL with Flutter + Android SDK installed.
    echo          To set up: https://docs.flutter.dev/get-started/install/linux
    echo          Skipping Android build.
    goto :DONE
)

echo       Building via WSL (this takes a few minutes)...
echo       Running: flutter build apk --release --target-platform android-arm,android-arm64,android-x64
echo.

:: Convert Windows path to WSL path for output copy
wsl bash -c "cd /mnt/c/$(echo '%CD:\=/%' | cut -c4-) && flutter build apk --release --target-platform android-arm,android-arm64,android-x64"

if %ERRORLEVEL% neq 0 (
    echo ERROR: Android APK build failed inside WSL!
    echo        Make sure Flutter and Android SDK are set up in WSL.
    echo        Run inside WSL: flutter doctor
    pause & exit /b 1
)

:: Copy APK to output folder
set APK_SRC=build\app\outputs\flutter-apk\app-release.apk
set APK_OUT=%OUT_DIR%\%APP_NAME%-android-%VERSION%-universal.apk

if exist "%APK_SRC%" (
    copy "%APK_SRC%" "%APK_OUT%" >nul
    echo       Created: %APK_OUT%
) else (
    echo ERROR: APK not found at %APK_SRC%
    pause & exit /b 1
)

:: ════════════════════════════════════════════════
:DONE
echo.
echo ================================================
echo   BUILD COMPLETE — Output in: %OUT_DIR%\
echo ================================================
echo.
dir /b "%OUT_DIR%"
echo.
pause