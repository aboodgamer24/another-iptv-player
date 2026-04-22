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
set INNO_PATH=C:\Program Files (x86)\Inno Setup 6\ISCC.exe
set INNO_OUTPUT=%OUT_DIR%\C4-TV_Setup.exe
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

7z a "%WIN_ZIP%" ".\%WIN_SRC%\*" >nul 2>&1
if %ERRORLEVEL% equ 0 goto :ZIP_DONE

tar -a -c -f "%WIN_ZIP%" -C "%WIN_SRC%" .
if %ERRORLEVEL% equ 0 goto :ZIP_DONE

echo ERROR: Failed to create Windows ZIP. Install 7-Zip or use Windows 10+.
pause & exit /b 1

:ZIP_DONE
echo       Created: %WIN_ZIP%
echo.

:: ════════════════════════════════════════════════
:: STEP 3 — Build Windows Installer
:: ════════════════════════════════════════════════
echo [3/4] Compiling Windows installer...

if exist "%INNO_PATH%" (
    echo       Using Inno Setup...
    "%INNO_PATH%" installer.iss
    if !ERRORLEVEL! equ 0 (
        if exist "%INNO_OUTPUT%" (
            move "%INNO_OUTPUT%" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
            echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
            goto :BUILD_ANDROID
        ) else (
            echo WARNING: Inno Setup ran but output not found at %INNO_OUTPUT%
        )
    ) else (
        echo WARNING: Inno Setup compilation failed, trying NSIS...
    )
)

where makensis >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set NSIS_CMD=makensis
) else if exist "%NSIS_PATH%" (
    set "NSIS_CMD=%NSIS_PATH%"
) else (
    echo WARNING: No installer tool found. Skipping.
    goto :BUILD_ANDROID
)

%NSIS_CMD% windows\installer.nsi
if %ERRORLEVEL% neq 0 (
    echo ERROR: NSIS compilation failed!
    pause & exit /b 1
)

if exist "another-iptv-player-windows-setup.exe" (
    move "another-iptv-player-windows-setup.exe" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
    echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
) else (
    echo WARNING: NSIS installer .exe not found after build.
)
echo.

:: ════════════════════════════════════════════════
:: STEP 4 — Build Android Universal APK via WSL
:: ════════════════════════════════════════════════
:BUILD_ANDROID
echo [4/4] Building Android Universal APK via WSL...
echo.

set APK_SRC=build\app\outputs\flutter-apk\app-release.apk
set APK_OUT=%OUT_DIR%\%APP_NAME%-android-%VERSION%-universal.apk

:: Convert current Windows path to WSL path (e.g. C:\Users\foo -> /mnt/c/Users/foo)
for /f "delims=" %%i in ('wsl wslpath -u "%CD%"') do set WSL_PATH=%%i
echo       Project WSL path: !WSL_PATH!
echo.

:: Write a self-contained build script into WSL and execute it
:: This avoids quoting/escaping issues with inline bash -c commands
wsl bash -c "cat > /tmp/c4tv_build.sh << 'BASHEOF'" 
wsl bash << 'WSLEOF'
cat > /tmp/c4tv_build.sh << 'BASHEOF'
#!/bin/bash
set -e

PROJECT_PATH="$1"

echo "  [WSL] Changing to project directory: $PROJECT_PATH"
cd "$PROJECT_PATH"

echo "  [WSL] Checking Flutter..."
if ! command -v flutter &> /dev/null; then
    # Try common Flutter install locations in WSL
    for p in "$HOME/flutter/bin" "/usr/local/flutter/bin" "$HOME/snap/flutter/common/flutter/bin"; do
        if [ -f "$p/flutter" ]; then
            export PATH="$p:$PATH"
            echo "  [WSL] Found Flutter at $p"
            break
        fi
    done
fi

if ! command -v flutter &> /dev/null; then
    echo "  [WSL] ERROR: Flutter not found in WSL!"
    echo "  [WSL] Install Flutter in WSL: https://docs.flutter.dev/get-started/install/linux"
    exit 1
fi

echo "  [WSL] Flutter version: $(flutter --version | head -1)"

echo "  [WSL] Checking Java..."
if ! command -v java &> /dev/null; then
    echo "  [WSL] ERROR: Java not found! Install with:"
    echo "  [WSL]   sudo apt install openjdk-17-jdk"
    exit 1
fi
echo "  [WSL] Java: $(java -version 2>&1 | head -1)"

echo "  [WSL] Running flutter pub get..."
flutter pub get

echo "  [WSL] Building Universal APK..."
flutter build apk --release --target-platform android-arm,android-arm64,android-x64

echo "  [WSL] APK build complete!"
BASHEOF
chmod +x /tmp/c4tv_build.sh
WSLEOF

:: Run the build script inside WSL passing the project path
echo       Starting WSL build...
wsl bash /tmp/c4tv_build.sh "!WSL_PATH!"

if !ERRORLEVEL! neq 0 (
    echo.
    echo ERROR: Android APK build failed in WSL!
    echo.
    echo Common fixes:
    echo   1. Make sure Flutter is installed in WSL
    echo      Run in WSL: sudo snap install flutter --classic
    echo      OR:         git clone https://github.com/flutter/flutter ~/flutter
    echo.
    echo   2. Make sure Java 17 is installed in WSL
    echo      Run in WSL: sudo apt install openjdk-17-jdk
    echo.
    echo   3. Accept Android licenses in WSL
    echo      Run in WSL: flutter doctor --android-licenses
    echo.
    echo   4. Run in WSL to diagnose: flutter doctor
    pause & exit /b 1
)

:COPY_APK
if exist "%APK_SRC%" (
    copy "%APK_SRC%" "%APK_OUT%" >nul
    echo       Created: %APK_OUT%
) else (
    echo ERROR: APK not found at %APK_SRC%
    echo        WSL build ran but APK was not written back to Windows filesystem.
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