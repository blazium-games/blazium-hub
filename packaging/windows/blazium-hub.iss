; Blazium Hub — Inno Setup
; Install root: {app} (= machine BLAZIUM). Default {autopf}\Blazium; any path via /DIR=.
; Bundles Hub + blazium-cli + PATH shims (blazium.cmd → CLI).
;
; Build (CI):
;   iscc /DMyAppVersion=0.1.0 /DMyAppArchLabel=x86_64 /DMyAppSourceDir=... blazium-hub.iss
;   iscc /DMyAppVersion=0.1.0 /DMyAppArchLabel=x86_32 /DMyAppIs32=1 /DMyAppSourceDir=... blazium-hub.iss
;
; Silent install (any directory):
;   BlaziumHub-Setup-VERSION-x86_64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="D:\Tools\Blazium"

#define MyAppName "Blazium Hub"
#ifndef MyAppVersion
  #define MyAppVersion "0.1.0"
#endif
#ifndef MyAppArchLabel
  #define MyAppArchLabel "x86_64"
#endif
#ifndef MyAppIs32
  #define MyAppIs32 0
#endif
#define MyAppPublisher "Blazium Games"
#define MyAppURL "https://blazium.app"
#define MyAppExeName "BlaziumHub.exe"
#ifndef MyAppSourceDir
  #define MyAppSourceDir "..\..\build\package\windows"
#endif

[Setup]
#if MyAppIs32
AppId={{A7C3E9B1-4D2F-4E8A-9C11-BLAZIUMHUB0032}
ArchitecturesAllowed=x86compatible x64compatible
#else
AppId={{A7C3E9B1-4D2F-4E8A-9C11-BLAZIUMHUB0001}
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
#endif
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\Blazium
DefaultGroupName={#MyAppName}
AllowNoIcons=yes
UsePreviousAppDir=yes
LicenseFile=..\..\LICENSE
OutputDir=Output
OutputBaseFilename=BlaziumHub-Setup-{#MyAppVersion}-{#MyAppArchLabel}
SetupIconFile=blazium-hub.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
UninstallDisplayIcon={app}\Hub\{#MyAppExeName}
ChangesAssociations=yes
ChangesEnvironment=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Hub/ currently stages only BlaziumHub.exe (embedded pack). A second Hub\* line
; that Excludes the exe would match zero files and abort the compile.
Source: "{#MyAppSourceDir}\Hub\*"; DestDir: "{app}\Hub"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppSourceDir}\blazium-cli.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\blazium.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\blazium-hub.cmd"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\Hub\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\Hub\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\Hub\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "BLAZIUM"; ValueData: "{app}"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "blazium"; ValueType: string; ValueData: "URL:Blazium Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "blazium"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "blazium\DefaultIcon"; ValueType: string; ValueData: "{app}\Hub\{#MyAppExeName},0"
Root: HKCR; Subkey: "blazium\shell\open\command"; ValueType: string; ValueData: """{app}\Hub\{#MyAppExeName}"" ""%1"""

[Code]
const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';

function NeedsAddPath(Param: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', OrigPath) then
  begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Uppercase(Param) + ';', ';' + Uppercase(OrigPath) + ';') = 0;
end;

procedure EnvAddPath(Path: string);
var
  Paths: string;
begin
  if not NeedsAddPath(Path) then
    exit;
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
    Paths := '';
  if Paths <> '' then
    Paths := Paths + ';' + Path
  else
    Paths := Path;
  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths);
end;

procedure EnvRemovePath(Path: string);
var
  Paths: string;
  P: Integer;
begin
  if not RegQueryStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths) then
    exit;
  P := Pos(';' + Uppercase(Path) + ';', ';' + Uppercase(Paths) + ';');
  if P = 0 then
    exit;
  Delete(Paths, P, Length(Path) + 1);
  while (Length(Paths) > 0) and (Paths[1] = ';') do
    Delete(Paths, 1, 1);
  while (Length(Paths) > 0) and (Paths[Length(Paths)] = ';') do
    Delete(Paths, Length(Paths), 1);
  RegWriteExpandStringValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'Path', Paths);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
    EnvAddPath(ExpandConstant('{app}'));
end;

procedure WipeDir(const Dir: string);
begin
  if Dir = '' then
    exit;
  if DirExists(Dir) then
    DelTree(Dir, True, True, True);
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  UserAppData, LocalAppData: string;
begin
  if CurUninstallStep = usUninstall then
  begin
    EnvRemovePath(ExpandConstant('{app}'));
    RegDeleteValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'BLAZIUM');

    UserAppData := ExpandConstant('{userappdata}');
    LocalAppData := ExpandConstant('{localappdata}');
    WipeDir(UserAppData + '\blazium');
    WipeDir(LocalAppData + '\Blazium');
    WipeDir(UserAppData + '\Godot\app_userdata\Blazium Hub');
  end;
end;
