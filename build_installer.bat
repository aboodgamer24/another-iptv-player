@echo off
setlocal enabledelayedexpansion


echo ================================================
echo   C4-TV Build Script - Windows + Android APKs
echo ================================================
echo.


:: ── CONFIG ──────────────────────────────────────
set VERSION=0.7.0-alpha
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
echo [1/6] Building Flutter Windows release...
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
echo [2/6] Creating Windows portable ZIP...
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
echo [3/6] Compiling Windows installer...

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
    echo WARNING: No installer tool found. Skipping installer step.
    goto :BUILD_ANDROID
)

%NSIS_CMD% windows\installer.nsi
if !ERRORLEVEL! neq 0 (
    echo ERROR: NSIS compilation failed!
    pause & exit /b 1
)

:: NSIS output now uses updated APP_NAME (was hardcoded to old name)
if exist "%APP_NAME%-windows-setup.exe" (
    move "%APP_NAME%-windows-setup.exe" "%OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe" >nul
    echo       Created: %OUT_DIR%\%APP_NAME%-windows-setup-%VERSION%.exe
) else (
    echo WARNING: NSIS installer .exe not found after build.
)
echo.


:: ════════════════════════════════════════════════
:: STEP 4 — Build Android Phone APKs via WSL
:: ════════════════════════════════════════════════
:BUILD_ANDROID
echo [4/6] Building Android APKs (phone) via WSL...
echo.

wsl bash ~/build_apk.sh "%VERSION%" --phone --no-sign-check

if !ERRORLEVEL! neq 0 (
    echo ERROR: Android APK build failed in WSL!
    pause & exit /b 1
)

:: Verify phone APKs
set APK_ARM64=%OUT_DIR%\%APP_NAME%-android-%VERSION%-arm64.apk
set APK_ARM32=%OUT_DIR%\%APP_NAME%-android-%VERSION%-arm32.apk
set APK_X64=%OUT_DIR%\%APP_NAME%-android-%VERSION%-x86_64.apk

for %%F in ("%APK_ARM64%" "%APK_ARM32%" "%APK_X64%") do (
    if not exist %%F (
        echo ERROR: APK not found: %%F
        pause & exit /b 1
    )
)

echo       APKs ready:
echo         %APK_ARM64%
echo         %APK_ARM32%
echo         %APK_X64%
echo.


:: ════════════════════════════════════════════════
:: STEP 5 — Compute SHA-256 checksums
:: ════════════════════════════════════════════════
echo [5/6] Computing SHA-256 checksums...
set CHECKSUM_FILE=%OUT_DIR%\checksums-SHA256.txt
if exist "%CHECKSUM_FILE%" del "%CHECKSUM_FILE%"

for %%F in ("%OUT_DIR%\*") do (
    certutil -hashfile "%%F" SHA256 2>nul | findstr /v "^CertUtil" | findstr /v "^SHA" >> "%CHECKSUM_FILE%"
    echo %%~nxF >> "%CHECKSUM_FILE%"
    echo. >> "%CHECKSUM_FILE%"
)
echo       Checksums saved to: %CHECKSUM_FILE%
echo.


:: ════════════════════════════════════════════════
:: STEP 6 — Done
:: ════════════════════════════════════════════════
echo [6/6] All builds complete.

echo.
echo ================================================
echo   BUILD COMPLETE — Output in: %OUT_DIR%\
echo ================================================
echo.
echo Files:
dir /b "%OUT_DIR%"
echo.
echo Total size:
powershell -NoProfile -Command ^
  "(Get-ChildItem '%OUT_DIR%' | Measure-Object -Property Length -Sum).Sum / 1MB | ForEach-Object { Write-Host ('  ' + [math]::Round($_, 2) + ' MB total') }"
echo.
pause