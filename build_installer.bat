@echo off
echo Building Flutter Windows release...
flutter build windows --release
echo Compiling Inno Setup installer...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
echo Done! Installer is in release_bundle\AnotherIPTVPlayer_Setup.exe
pause
