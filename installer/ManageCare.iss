; Inno Setup script for Manage Care (business_manager.exe)
;
; Prerequisites:
;   1. Install Inno Setup: winget install JRSoftware.InnoSetup
;   2. Build the release binaries first: flutter build windows --release
;
; Build the installer:
;   "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" installer\ManageCare.iss
;
; Output goes to installer\Output\ManageCareSetup-<version>.exe

#define MyAppName "Manage Care"
#define MyAppVersion "2.0.60"
#define MyAppPublisher "Manage Care"
#define MyAppExeName "business_manager.exe"
#define MyReleaseDir "..\build\windows\x64\runner\Release"

[Setup]
; Keep this GUID stable across versions so upgrades replace the old install
; instead of installing side-by-side.
AppId={{323CC609-B632-4244-920C-FEF82965AE92}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=Output
OutputBaseFilename=ManageCareSetup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; Pulls in the exe, every plugin DLL, and the data\ folder (flutter_assets,
; icudtl.dat, app.so) as a unit -- a Flutter Windows build only runs when
; these all sit next to each other.
Source: "{#MyReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
