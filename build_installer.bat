@echo off
echo Building Flutter Windows release...
call flutter build windows --release
echo Compiling Inno Setup installer...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss
echo Done! Installer is in release_bundle\C4-TV_Setup.exe
pause
