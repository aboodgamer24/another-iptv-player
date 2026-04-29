@echo off
setlocal enabledelayedexpansion

echo =========================================
echo  C4TV Player - App Rename Script
echo =========================================
echo.

:: --- Make sure we're in the Flutter project root ---
if not exist "pubspec.yaml" (
    echo [ERROR] pubspec.yaml not found.
    echo         Run this script from the root of the Flutter project.
    pause
    exit /b 1
)

echo [1/4] Patching pubspec.yaml ...
powershell -NoProfile -Command ^
  "(Get-Content 'pubspec.yaml' -Raw)" ^
  " -replace 'name: another_iptv_player', 'name: c4tv_player'" ^
  " -replace 'description: ""Another IPTV Player""', 'description: ""C4TV Player""'" ^
  " -replace 'output_name: ""AnotherIPTVPlayer""', 'output_name: ""C4TVPlayer""'" ^
  " | Set-Content 'pubspec.yaml' -NoNewline"
echo     Done.

echo [2/4] Patching android\app\src\main\AndroidManifest.xml ...
powershell -NoProfile -Command ^
  "(Get-Content 'android\app\src\main\AndroidManifest.xml' -Raw)" ^
  " -replace 'android:label=""Another IPTV Player""', 'android:label=""C4TV Player""'" ^
  " | Set-Content 'android\app\src\main\AndroidManifest.xml' -NoNewline"
echo     Done.

echo [3/4] Patching windows\runner\main.cpp ...
powershell -NoProfile -Command ^
  "(Get-Content 'windows\runner\main.cpp' -Raw)" ^
  " -replace 'window\.Create\(L""C4-TV""', 'window.Create(L""C4TV Player""'" ^
  " | Set-Content 'windows\runner\main.cpp' -NoNewline"
echo     Done.

echo [4/4] Renaming import references in Dart source files ...
:: Flutter uses the package name in imports: 'package:another_iptv_player/...'
:: This replaces all occurrences across all .dart files under lib\
powershell -NoProfile -Command ^
  "Get-ChildItem -Path 'lib' -Recurse -Filter '*.dart' | ForEach-Object {" ^
  "  $content = Get-Content $_.FullName -Raw;" ^
  "  $updated = $content -replace 'package:another_iptv_player/', 'package:c4tv_player/';" ^
  "  if ($updated -ne $content) { Set-Content $_.FullName $updated -NoNewline; Write-Host ('  Updated: ' + $_.FullName) }" ^
  "}"
echo     Done.

echo.
echo =========================================
echo  All done! Next steps:
echo    1. Run: flutter pub get
echo    2. Run: flutter clean
echo    3. Rebuild the app normally
echo =========================================
echo.
pause
