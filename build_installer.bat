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
:: Inno Setup outputs here based on installer.iss:
::   OutputDir=release_bundle
::   OutputBaseFilename=C4-TV_Setup
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

:: Try 7-Zip first
7z a "%WIN_ZIP%" ".\%WIN_SRC%\*" >nul 2>&1
if %ERRORLEVEL% equ 0 goto :ZIP_DONE

:: Fallback to built-in tar (Windows 10/11)
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

:: Try Inno Setup first (installer.iss at repo root)
if exist "%INNO_PATH%" (
    echo       Using Inno Setup...
    "%INNO_PATH%" installer.iss
    if !ERRORLEVEL! equ 0 (
        :: Inno outputs to release_bundle\C4-TV_Setup.exe per installer.iss
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

:: Fallback to NSIS (installer.nsi lives inside windows\ folder)
where makensis >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set NSIS_CMD=makensis
) else if exist "%NSIS_PATH%" (
    set "NSIS_CMD=%NSIS_PATH%"
) else (
    echo WARNING: No installer tool found (Inno Setup or NSIS^). Skipping.
    goto :BUILD_ANDROID
)

%NSIS_CMD% windows\installer.nsi
if %ERRORLEVEL% neq 0 (
    echo ERROR: NSIS compilation failed!
    pause & exit /b 1
)

:: NSIS outputs another-iptv-player-windows-setup.exe at repo root
if exist "another-iptv-player-windows-setup.exe" (
    move "another-iptv-player-windows-setup.exe" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
    echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
) else (
    echo WARNING: NSIS installer .exe not found after build.
)
echo.

:: ════════════════════════════════════════════════
:: STEP 4 — Build Android Universal APK
:: ════════════════════════════════════════════════
:BUILD_ANDROID
echo [4/4] Building Android Universal APK...
echo.

set APK_SRC=build\app\outputs\flutter-apk\app-release.apk
set APK_OUT=%OUT_DIR%\%APP_NAME%-android-%VERSION%-universal.apk
set FLUTTER_APK_CMD=flutter build apk --release --target-platform android-arm,android-arm64,android-x64

:: Try WSL first (more reliable for Android SDK on Windows)
wsl --status >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo       Building via WSL...
    :: Convert current Windows path to WSL mount path (e.g. C:\foo -> /mnt/c/foo)
    for /f "delims=" %%i in ('wsl wslpath -u "%CD%"') do set WSL_PATH=%%i
    wsl bash -c "cd '!WSL_PATH!' && %FLUTTER_APK_CMD%"
    if !ERRORLEVEL! equ 0 goto :COPY_APK
    echo       WSL build failed, trying native Windows...
)

:: Native Windows fallback (requires Android SDK in PATH)
echo       Attempting native Windows build...
call %FLUTTER_APK_CMD%
if %ERRORLEVEL% neq 0 (
    echo ERROR: Android APK build failed!
    echo        Make sure Android SDK + Java 17 are installed and in PATH.
    echo        Run: flutter doctor
    pause & exit /b 1
)

:COPY_APK
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