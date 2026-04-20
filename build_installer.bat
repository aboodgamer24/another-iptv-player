@echo off
echo Building Flutter app...
call flutter build windows --release

echo Creating MSIX...
call dart run msix:create

echo Extracting certificate...
powershell -Command "$sig = Get-AuthenticodeSignature -FilePath 'build\windows\x64\runner\Release\AnotherIPTVPlayer.msix'; [System.IO.File]::WriteAllBytes('build\windows\x64\runner\Release\AnotherIPTVPlayer.cer', $sig.SignerCertificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert))"

echo Building Inno Setup installer...
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer.iss

echo Done! Installer is in release_bundle\
pause
