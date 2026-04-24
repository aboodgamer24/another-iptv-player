#define MyAppName "C4-TV"
#define MyAppVersion \"0.7.0-alpha"
#define MyAppPublisher "aboodgamer24"
#define MyAppExeName "C4-TV.exe"
#define MyAppBuildDir "build\windows\x64\runner\Release"

[Setup]
AppId={{03757a36-1d72-472a-8e5a-9932fc6ddd02}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=release_bundle
OutputBaseFilename=C4-TV_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\{#MyAppExeName}
MinVersion=10.0.17763

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Files]
; Main executable
Source: "{#MyAppBuildDir}\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
; All DLLs and data files in the Release folder (non-recursive)
Source: "{#MyAppBuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppBuildDir}\*.dat"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
; Flutter data folder (contains assets, fonts, shaders)
Source: "{#MyAppBuildDir}\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
; Start Menu shortcut
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
; Desktop shortcut
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"

[Run]
; Launch the app after installation finishes (optional, user can uncheck)
Filename: "{app}\{#MyAppExeName}"; Description: "Launch {#MyAppName}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
