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

:: Try 7-Zip first
7z a "%WIN_ZIP%" ".\%WIN_SRC%\*" >nul 2>&1
if %ERRORLEVEL% equ 0 goto :ZIP_DONE

:: Fallback to built-in tar (Windows 10/11)
tar -a -c -f "%WIN_ZIP%" -C "%WIN_SRC%" .
if %ERRORLEVEL% equ 0 goto :ZIP_DONE

echo ERROR: Failed to create Windows ZIP. Make sure 7-Zip is installed or 'tar' is available.
pause & exit /b 1

:ZIP_DONE
echo       Created: %WIN_ZIP%
echo.

:: ════════════════════════════════════════════════
:: STEP 3 — Build Windows Installer (NSIS)
:: ════════════════════════════════════════════════
echo [3/4] Compiling Windows installer...

:: Try Inno Setup first (confirmed installed)
if exist "%INNO_PATH%" (
    echo       Using Inno Setup...
    "%INNO_PATH%" installer.iss
    if %ERRORLEVEL% equ 0 (
        if exist "%OUT_DIR%\C4-TV_Setup.exe" (
            move "%OUT_DIR%\C4-TV_Setup.exe" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
            echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
            goto :BUILD_ANDROID
        )
    )
)

:: Fallback to NSIS
echo       Inno Setup failed or not found, trying NSIS...
where makensis >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set NSIS_CMD=makensis
) else (
    if not exist "%NSIS_PATH%" (
        echo WARNING: No installer tool found (Inno Setup or NSIS).
        echo          Skipping installer creation.
        goto :BUILD_ANDROID
    )
    set NSIS_CMD="%NSIS_PATH%"
)

%NSIS_CMD% windows\installer.nsi
if %ERRORLEVEL% neq 0 (
    echo ERROR: Installer compilation failed!
    pause & exit /b 1
)

:: Move NSIS installer to output folder
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
if %ERRORLEVEL% equ 0 (
    echo       Building via WSL...
    wsl bash -c "cd /mnt/c/$(echo '%CD:\=/%' | cut -c4-) && flutter build apk --release --target-platform android-arm,android-arm64,android-x64"
    if !ERRORLEVEL! equ 0 goto :COPY_APK
)

echo       WSL not found/running, attempting native Windows build...
call flutter build apk --release --target-platform android-arm,android-arm64,android-x64
if %ERRORLEVEL% neq 0 (
    echo ERROR: Android APK build failed!
    pause & exit /b 1
)

:COPY_APK
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