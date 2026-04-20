#define MyAppName "Another IPTV Player"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "aboodgamer24"
#define MyAppExeName "AnotherIPTVPlayer.msix"
#define MyCertFile "AnotherIPTVPlayer.cer"

[Setup]
AppId={{03757a36-1d72-472a-8e5a-9932fc6ddd02}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=release_bundle
OutputBaseFilename=AnotherIPTVPlayer_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Require admin so certutil works
PrivilegesRequired=admin
; Nice installer icon (replace with your own .ico)
; SetupIconFile=assets\icon.ico
UninstallDisplayIcon={app}\unins000.exe
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Bundle the MSIX and cert — copy to temp dir during install
Source: "build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{tmp}"; Flags: deleteafterinstall
Source: "build\windows\x64\runner\Release\{#MyCertFile}"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Run]
; 1. Install certificate silently into Trusted People store
Filename: "certutil.exe"; \
  Parameters: "-addstore -f ""TrustedPeople"" ""{tmp}\{#MyCertFile}"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Installing trusted certificate..."

; 2. Install the MSIX silently
Filename: "powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -Command ""Add-AppxPackage -Path '{tmp}\{#MyAppExeName}'"""; \
  Flags: runhidden waituntilterminated; \
  StatusMsg: "Installing {#MyAppName}..."

[UninstallRun]
; Remove the app on uninstall
Filename: "powershell.exe"; \
  Parameters: "-ExecutionPolicy Bypass -Command ""Get-AppxPackage *AnotherIPTVPlayer* | Remove-AppxPackage"""; \
  Flags: runhidden waituntilterminated

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
