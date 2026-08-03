; Blazium Hub — Inno Setup
; Install root: {app} (= machine BLAZIUM). Default {autopf}\Blazium; any path via /DIR=.
; Bundles Hub + blazium-cli + PATH shims (blazium.cmd → CLI).
;
; Admin / machine-wide only (PrivilegesRequired=admin). Do not set
; PrivilegesRequiredOverridesAllowed — /CURRENTUSER must not downgrade to a
; per-user install. Program Files + HKLM BLAZIUM let Hub self-update by
; re-running this elevated Setup (CloseApplications closes running Hub/CLI).
;
; Build (CI):
;   iscc /DMyAppVersion=0.1.0 /DMyAppArchLabel=x86_64 /DMyAppSourceDir=... blazium-hub.iss
;   iscc /DMyAppVersion=0.1.0 /DMyAppArchLabel=x86_32 /DMyAppIs32=1 /DMyAppSourceDir=... blazium-hub.iss
;
; Silent install (any directory):
;   BlaziumHub-Setup-VERSION-x86_64.exe /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR="D:\Tools\Blazium"
; Silent install and auto-launch Hub:
;   ... /DIR="D:\Tools\Blazium" /LAUNCH

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
; Machine-wide install under {autopf}; required for HKLM env/protocol and Hub/CLI updates.
PrivilegesRequired=admin
UninstallDisplayIcon={app}\Hub\{#MyAppExeName}
ChangesAssociations=yes
ChangesEnvironment=yes
CloseApplications=yes

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
; Always ensure machine + original-user hub_remote.json (idempotent; never rotates a valid token).
; postinstall is required for runasoriginaluser; both ensures run before optional /LAUNCH.
Filename: "{app}\Hub\{#MyAppExeName}"; Parameters: "--headless --ensure-hub-remote --hub-remote-path=""{commonappdata}\blazium\hub_remote.json"" --quit"; StatusMsg: "Ensuring Hub remote secret (machine)..."; Flags: postinstall runhidden waituntilterminated
Filename: "{app}\Hub\{#MyAppExeName}"; Parameters: "--headless --ensure-hub-remote --quit"; StatusMsg: "Ensuring Hub remote secret (user)..."; Flags: postinstall runasoriginaluser runhidden waituntilterminated
; Interactive finish-page checkboxes (skipped in silent mode).
Filename: "{app}\Hub\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{#MyAppURL}"; Description: "Visit Blazium.app"; Flags: postinstall shellexec skipifsilent unchecked
; Silent/CLI: launch Hub only when /LAUNCH is passed.
Filename: "{app}\Hub\{#MyAppExeName}"; Flags: nowait postinstall skipifnotsilent; Check: ShouldLaunchAfterSilent

[Registry]
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; ValueType: expandsz; ValueName: "BLAZIUM"; ValueData: "{app}"; Flags: uninsdeletevalue
Root: HKCR; Subkey: "blazium"; ValueType: string; ValueData: "URL:Blazium Protocol"; Flags: uninsdeletekey
Root: HKCR; Subkey: "blazium"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCR; Subkey: "blazium\DefaultIcon"; ValueType: string; ValueData: "{app}\Hub\{#MyAppExeName},0"
; OS deep links go to blazium-cli; CLI launches/talks to Hub or editors over remote_control.
Root: HKCR; Subkey: "blazium\shell\open\command"; ValueType: string; ValueData: """{app}\blazium-cli.exe"" handle-uri ""%1"""
; Install kind metadata (written from [Code] as well for PreviousVersion).
Root: HKLM; Subkey: "SOFTWARE\Blazium\Hub"; ValueType: string; ValueName: "InstallVersion"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletekey

[Code]
const
  EnvironmentKey = 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  BlaziumHubRegKey = 'SOFTWARE\Blazium\Hub';

var
  GIsUpgrade: Boolean;
  GPreviousVersion: string;

function UninstallRegKey: string;
begin
#if MyAppIs32
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7C3E9B1-4D2F-4E8A-9C11-BLAZIUMHUB0032}_is1';
#else
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{A7C3E9B1-4D2F-4E8A-9C11-BLAZIUMHUB0001}_is1';
#endif
end;

function CmdLineParamExists(const Param: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Param) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

function ShouldLaunchAfterSilent: Boolean;
begin
  Result := CmdLineParamExists('/LAUNCH');
end;

function IsUpgradeInstall: Boolean;
begin
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, UninstallRegKey) or
            FileExists(ExpandConstant('{app}\Hub\{#MyAppExeName}'));
end;

function InitializeSetup: Boolean;
begin
  GIsUpgrade := IsUpgradeInstall;
  GPreviousVersion := '';
  if GIsUpgrade then
    RegQueryStringValue(HKEY_LOCAL_MACHINE, UninstallRegKey, 'DisplayVersion', GPreviousVersion);
  if GIsUpgrade then
    Log('InstallKind=upgrade PreviousVersion=' + GPreviousVersion)
  else
    Log('InstallKind=fresh');
  Result := True;
end;

function UpdateReadyMemo(const Space, NewLine, MemoUserInfoInfo, MemoDirInfo,
  MemoTypeInfo, MemoComponentsInfo, MemoGroupInfo, MemoTasksInfo: string): string;
var
  Kind: string;
begin
  if GIsUpgrade then
    Kind := 'Updating Blazium Hub...'
  else
    Kind := 'Installing Blazium Hub...';
  Result := Kind + NewLine + NewLine +
            MemoDirInfo + NewLine + NewLine +
            MemoGroupInfo + NewLine + NewLine +
            MemoTasksInfo;
end;

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

procedure WriteInstallKindRegistry;
var
  Kind: string;
begin
  if GIsUpgrade then
    Kind := 'upgrade'
  else
    Kind := 'fresh';
  RegWriteStringValue(HKEY_LOCAL_MACHINE, BlaziumHubRegKey, 'InstallKind', Kind);
  RegWriteStringValue(HKEY_LOCAL_MACHINE, BlaziumHubRegKey, 'InstallVersion', '{#MyAppVersion}');
  if GIsUpgrade and (GPreviousVersion <> '') then
    RegWriteStringValue(HKEY_LOCAL_MACHINE, BlaziumHubRegKey, 'PreviousVersion', GPreviousVersion);
  Log('Wrote HKLM\' + BlaziumHubRegKey + ' InstallKind=' + Kind);
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    EnvAddPath(ExpandConstant('{app}'));
    WriteInstallKindRegistry;
  end;
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
  UserAppData, LocalAppData, CommonAppData: string;
begin
  if CurUninstallStep = usUninstall then
  begin
    EnvRemovePath(ExpandConstant('{app}'));
    RegDeleteValue(HKEY_LOCAL_MACHINE, EnvironmentKey, 'BLAZIUM');

    UserAppData := ExpandConstant('{userappdata}');
    LocalAppData := ExpandConstant('{localappdata}');
    CommonAppData := ExpandConstant('{commonappdata}');
    WipeDir(UserAppData + '\blazium');
    WipeDir(CommonAppData + '\blazium');
    WipeDir(LocalAppData + '\Blazium');
    WipeDir(UserAppData + '\Godot\app_userdata\Blazium Hub');
  end;
end;
