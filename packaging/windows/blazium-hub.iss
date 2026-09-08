; Blazium Hub — Inno Setup
; Install root: {app} (= machine BLAZIUM). Default {autopf}\Blazium; any path via /DIR=.
; Bundles Hub + blazium-cli + crash_reporter + PATH shims (blazium.cmd → CLI).
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
; Silent install and download the GPLv3 toolchain manager via bundled CLI:
;   ... /INSTALLTOOLCHAIN
; Silent install without anonymous install analytics (CI smokes must pass this):
;   ... /NOANALYTICS

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
Name: "analytics"; Description: "Help improve Blazium Hub with anonymous analytics"; GroupDescription: "Privacy:"

[Files]
; Hub/ stages BlaziumHub.exe with an embedded pack (embed_pck=true).
Source: "{#MyAppSourceDir}\Hub\*"; DestDir: "{app}\Hub"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "{#MyAppSourceDir}\blazium-cli.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\Hub\crash_reporter.exe"; DestDir: "{app}\Hub"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\VERSION"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\blazium.cmd"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#MyAppSourceDir}\blazium-hub.cmd"; DestDir: "{app}"; Flags: ignoreversion
; Wizard-only texts (extracted in InitializeWizard; not installed).
Source: "toolchain-LICENSE.txt"; Flags: dontcopy
Source: "toolchain-features.txt"; Flags: dontcopy

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\Hub\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\Hub\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; hub_remote.json ensure runs from [Code] CurStepChanged (ignores exit codes; mirrors Linux postinst || true).
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
  ToolchainPage: TWizardPage;
  ToolchainCheck: TNewCheckBox;
  ToolchainInfo: TNewMemo;
  ToolchainLicensePage: TWizardPage;
  ToolchainLicenseMemo: TNewMemo;
  ToolchainAccept: TNewRadioButton;
  ToolchainDecline: TNewRadioButton;

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

function LoadDontCopyText(const Name: string): string;
var
  Data: AnsiString;
begin
  Result := '';
  ExtractTemporaryFile(Name);
  if LoadStringFromFile(ExpandConstant('{tmp}\') + Name, Data) then
    Result := string(Data);
end;

function WantAnalytics: Boolean;
begin
  if CmdLineParamExists('/NOANALYTICS') then
  begin
    Result := False;
    Exit;
  end;
  if WizardSilent then
  begin
    Result := True;
    Exit;
  end;
  Result := WizardIsTaskSelected('analytics');
end;

function WantToolchain: Boolean;
begin
  if WizardSilent then
  begin
    Result := CmdLineParamExists('/INSTALLTOOLCHAIN');
    Exit;
  end;
  Result := False;
  if ToolchainCheck <> nil then
    Result := ToolchainCheck.Checked;
  if Result and (ToolchainAccept <> nil) then
    Result := ToolchainAccept.Checked;
end;

procedure InitializeWizard;
var
  Features, LicenseText: string;
  RadioTop: Integer;
begin
  ToolchainPage := CreateCustomPage(wpLicense,
    'Blazium Toolchain (optional)',
    'Optionally download the GPLv3 console toolchain manager after Hub is installed.');

  ToolchainCheck := TNewCheckBox.Create(ToolchainPage);
  ToolchainCheck.Parent := ToolchainPage.Surface;
  ToolchainCheck.Top := ScaleY(0);
  ToolchainCheck.Left := ScaleX(0);
  ToolchainCheck.Width := ToolchainPage.SurfaceWidth;
  ToolchainCheck.Height := ScaleY(22);
  ToolchainCheck.Caption := 'Download Blazium Toolchain after setup (GPLv3)';
  ToolchainCheck.Checked := CmdLineParamExists('/INSTALLTOOLCHAIN');

  ToolchainInfo := TNewMemo.Create(ToolchainPage);
  ToolchainInfo.Parent := ToolchainPage.Surface;
  ToolchainInfo.Top := ToolchainCheck.Top + ToolchainCheck.Height + ScaleY(8);
  ToolchainInfo.Left := 0;
  ToolchainInfo.Width := ToolchainPage.SurfaceWidth;
  ToolchainInfo.Height := ToolchainPage.SurfaceHeight - ToolchainInfo.Top;
  ToolchainInfo.ReadOnly := True;
  ToolchainInfo.ScrollBars := ssVertical;
  Features := LoadDontCopyText('toolchain-features.txt');
  if Features = '' then
    Features := 'Blazium Toolchain manager (GPL-3.0-or-later). Compilers stay in the user cache.';
  ToolchainInfo.Text := Features;

  ToolchainLicensePage := CreateCustomPage(ToolchainPage.ID,
    'Toolchain License Agreement',
    'Please review the GNU GPL before installing the toolchain.');

  RadioTop := ToolchainLicensePage.SurfaceHeight - ScaleY(44);
  ToolchainLicenseMemo := TNewMemo.Create(ToolchainLicensePage);
  ToolchainLicenseMemo.Parent := ToolchainLicensePage.Surface;
  ToolchainLicenseMemo.Top := 0;
  ToolchainLicenseMemo.Left := 0;
  ToolchainLicenseMemo.Width := ToolchainLicensePage.SurfaceWidth;
  ToolchainLicenseMemo.Height := RadioTop - ScaleY(8);
  ToolchainLicenseMemo.ReadOnly := True;
  ToolchainLicenseMemo.ScrollBars := ssVertical;
  LicenseText := LoadDontCopyText('toolchain-LICENSE.txt');
  if LicenseText = '' then
    LicenseText := 'GNU General Public License version 3 or later. See https://www.gnu.org/licenses/gpl-3.0.html';
  ToolchainLicenseMemo.Text := LicenseText;

  ToolchainAccept := TNewRadioButton.Create(ToolchainLicensePage);
  ToolchainAccept.Parent := ToolchainLicensePage.Surface;
  ToolchainAccept.Top := RadioTop;
  ToolchainAccept.Left := 0;
  ToolchainAccept.Width := ToolchainLicensePage.SurfaceWidth;
  ToolchainAccept.Height := ScaleY(20);
  ToolchainAccept.Caption := 'I accept the toolchain license (GPL-3.0-or-later)';
  ToolchainAccept.Checked := CmdLineParamExists('/INSTALLTOOLCHAIN');

  ToolchainDecline := TNewRadioButton.Create(ToolchainLicensePage);
  ToolchainDecline.Parent := ToolchainLicensePage.Surface;
  ToolchainDecline.Top := RadioTop + ScaleY(20);
  ToolchainDecline.Left := 0;
  ToolchainDecline.Width := ToolchainLicensePage.SurfaceWidth;
  ToolchainDecline.Height := ScaleY(20);
  ToolchainDecline.Caption := 'I decline; skip the toolchain and continue installing Hub';
  ToolchainDecline.Checked := not ToolchainAccept.Checked;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if (ToolchainLicensePage <> nil) and (PageID = ToolchainLicensePage.ID) then
    Result := (ToolchainCheck = nil) or (not ToolchainCheck.Checked);
end;

function NextButtonClick(CurPageID: Integer): Boolean;
begin
  Result := True;
  if (ToolchainLicensePage <> nil) and (CurPageID = ToolchainLicensePage.ID) then
  begin
    if (ToolchainAccept = nil) or (not ToolchainAccept.Checked) then
    begin
      if ToolchainCheck <> nil then
        ToolchainCheck.Checked := False;
      Log('Toolchain GPL declined; skipping toolchain download');
    end
    else
      Log('Toolchain GPL accepted');
  end;
end;

function IsUpgradeInstall: Boolean;
begin
  // Do not ExpandConstant('{app}') here — {app} is not initialized during InitializeSetup.
  Result := RegKeyExists(HKEY_LOCAL_MACHINE, UninstallRegKey);
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
  if WantToolchain then
    Result := Result + NewLine + NewLine +
              'Blazium Toolchain will be downloaded after files are copied (GPL accepted).';
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

{ Prefer bundled blazium-cli hub-remote ensure; fall back to Hub --ensure-hub-remote.
  Never abort setup on non-zero exit (same as Linux postinst || true). }
procedure EnsureHubRemoteSecrets;
var
  ResultCode: Integer;
  CliPath, HubPath, MachinePath: string;
  MachineOk, UserOk: Boolean;
begin
  CliPath := ExpandConstant('{app}\blazium-cli.exe');
  HubPath := ExpandConstant('{app}\Hub\') + '{#MyAppExeName}';
  MachinePath := ExpandConstant('{commonappdata}\blazium\hub_remote.json');
  MachineOk := False;
  UserOk := False;

  if FileExists(CliPath) then
  begin
    Log('Ensuring machine hub_remote via blazium-cli...');
    if Exec(CliPath, 'hub-remote ensure --path "' + MachinePath + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      MachineOk := (ResultCode = 0)
    else
      ResultCode := -1;
    Log('CLI machine hub-remote ensure exit=' + IntToStr(ResultCode));

    Log('Ensuring user hub_remote via blazium-cli (original user)...');
    if ExecAsOriginalUser(CliPath, 'hub-remote ensure', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
      UserOk := (ResultCode = 0)
    else
      ResultCode := -1;
    Log('CLI user hub-remote ensure exit=' + IntToStr(ResultCode));
  end;

  if FileExists(HubPath) then
  begin
    if not MachineOk then
    begin
      Log('Fallback: Hub headless machine ensure...');
      Exec(HubPath, '--headless --ensure-hub-remote --hub-remote-path="' + MachinePath + '" --quit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Log('Hub machine ensure exit=' + IntToStr(ResultCode));
    end;
    if not UserOk then
    begin
      Log('Fallback: Hub headless user ensure (original user)...');
      ExecAsOriginalUser(HubPath, '--headless --ensure-hub-remote --quit', '', SW_HIDE, ewWaitUntilTerminated, ResultCode);
      Log('Hub user ensure exit=' + IntToStr(ResultCode));
    end;
  end;
end;

{ Download the GPLv3 toolchain manager via bundled CLI. Never fail Hub setup. }
procedure InstallToolchainViaCli;
var
  ResultCode: Integer;
  CliPath, AppDir: string;
begin
  if not WantToolchain then
  begin
    Log('Toolchain download skipped');
    Exit;
  end;
  CliPath := ExpandConstant('{app}\blazium-cli.exe');
  AppDir := ExpandConstant('{app}');
  if not FileExists(CliPath) then
  begin
    Log('Toolchain requested but blazium-cli.exe is missing');
    Exit;
  end;
  Log('Downloading toolchain via blazium-cli update apply --product toolchain');
  if Exec(CliPath, 'update apply --product toolchain --install-root "' + AppDir + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
    Log('CLI toolchain apply exit=' + IntToStr(ResultCode))
  else
    Log('CLI toolchain apply failed to start');
end;

procedure PersistHubAnalyticsConsent;
var
  CfgDir, CfgPath, Enabled: string;
begin
  CfgDir := ExpandConstant('{userappdata}\Godot\app_userdata\Blazium Hub');
  CfgPath := CfgDir + '\hub_settings.cfg';
  if WantAnalytics then
    Enabled := 'true'
  else
    Enabled := 'false';
  ForceDirectories(CfgDir);
  SetIniString('privacy', 'data_collection_decided', 'true', CfgPath);
  SetIniString('privacy', 'data_collection_enabled', Enabled, CfgPath);
  SetIniString('privacy', 'data_collection_anonymous', 'true', CfgPath);
  Log('Wrote Hub analytics consent enabled=' + Enabled + ' path=' + CfgPath);
end;

procedure PostAnonymousInstallEvent;
var
  Http: Variant;
  Body, EventName, Kind: string;
begin
  if not WantAnalytics then
  begin
    Log('Install analytics skipped');
    Exit;
  end;
  if GIsUpgrade then
  begin
    EventName := 'hub_upgraded';
    Kind := 'upgrade';
  end
  else
  begin
    EventName := 'hub_installed';
    Kind := 'fresh';
  end;
  Body := '{"event":"' + EventName + '","anonymous":true,"os":"Windows","arch":"{#MyAppArchLabel}","version":"{#MyAppVersion}","install_kind":"' + Kind + '"}';
  try
    Http := CreateOleObject('WinHttp.WinHttpRequest.5.1');
    Http.Open('POST', 'https://crash.blazium.app/v1/events', False);
    Http.SetRequestHeader('Content-Type', 'application/json');
    Http.SetRequestHeader('X-App-Id', 'blazium-hub');
    Http.SetRequestHeader('X-Build-Id', '{#MyAppVersion}');
    Http.SetTimeouts(4000, 4000, 4000, 8000);
    Http.Send(Body);
    Log('Install analytics WinHTTP status=' + IntToStr(Http.Status) + ' event=' + EventName);
  except
    Log('Install analytics POST failed (ignored)');
  end;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    EnvAddPath(ExpandConstant('{app}'));
    WriteInstallKindRegistry;
    PersistHubAnalyticsConsent;
    PostAnonymousInstallEvent;
    EnsureHubRemoteSecrets;
    InstallToolchainViaCli;
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
