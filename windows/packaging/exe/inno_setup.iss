[Setup]
AppId=B9F6E402-0CAE-4045-BDE6-14BD6C39C4EA
AppVersion=1.12.2+27
AppName=Nexus Music
AppPublisher=especialidades-dev
AppPublisherURL=https://github.com/especialidades-dev/nexus-music
AppSupportURL=https://github.com/especialidades-dev/nexus-music
AppUpdatesURL=https://github.com/especialidades-dev/nexus-music
DefaultDirName={autopf}\nexusmusic
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename=nexusmusic-1.14.1
Compression=lzma
SolidCompression=yes
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
WizardStyle=modern
PrivilegesRequired=lowest
LicenseFile=..\..\LICENSE
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "..\..\build\windows\x64\runner\Release\nexusmusic.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{autoprograms}\Nexus Music"; Filename: "{app}\nexusmusic.exe"
Name: "{autodesktop}\Nexus Music"; Filename: "{app}\nexusmusic.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\nexusmusic.exe"; Description: "{cm:LaunchProgram,{#StringChange('Nexus Music', '&', '&&')}}"; Flags: nowait postinstall skipifsilent
