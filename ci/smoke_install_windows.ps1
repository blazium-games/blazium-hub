# Silent Inno install to a custom DIR + full uninstall smoke.
param(
    [Parameter(Mandatory = $true)][string]$SetupPath,
    [string]$CustomDir = ""
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path $SetupPath)) { throw "Setup not found: $SetupPath" }
if (-not $CustomDir) {
    $CustomDir = Join-Path $env:RUNNER_TEMP "BlaziumCustom"
}
$CustomDir = [System.IO.Path]::GetFullPath($CustomDir)
if (Test-Path $CustomDir) { Remove-Item -Recurse -Force $CustomDir }

$EnvKey = "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"

function Get-MachineEnv([string]$Name) {
    return [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($EnvKey).GetValue($Name, "", "DoNotExpandEnvironmentNames")
}

function Get-MachinePath() {
    return [string](Get-MachineEnv "Path")
}

$SetupLog = Join-Path $env:RUNNER_TEMP "hub-setup-install.log"
if (-not $env:RUNNER_TEMP) { $SetupLog = Join-Path ([System.IO.Path]::GetTempPath()) "hub-setup-install.log" }

Write-Host "=== Silent install to $CustomDir ==="
$p = Start-Process -FilePath $SetupPath -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-",
    "/NOANALYTICS",
    "/DIR=$CustomDir",
    "/LOG=$SetupLog"
) -Wait -PassThru
if ($p.ExitCode -ne 0) {
    if (Test-Path $SetupLog) {
        Write-Host "=== Installer log ($SetupLog) ==="
        Get-Content -Path $SetupLog -ErrorAction SilentlyContinue | Select-Object -Last 80 | ForEach-Object { Write-Host $_ }
    }
    throw "Installer exit $($p.ExitCode)"
}

Write-Host "=== Assert custom-dir layout ==="
$hub = Join-Path $CustomDir "Hub\BlaziumHub.exe"
$cli = Join-Path $CustomDir "blazium-cli.exe"
$crash = Join-Path $CustomDir "Hub\crash_reporter.exe"
$crashVer = Join-Path $CustomDir "Hub\crash_reporter.version"
$hubVer = Join-Path $CustomDir "VERSION"
$shim = Join-Path $CustomDir "blazium.cmd"
if (-not (Test-Path $hub)) { throw "missing $hub" }
if (-not (Test-Path $cli)) { throw "missing $cli" }
if (-not (Test-Path $crash)) { throw "missing $crash" }
if (-not (Test-Path $crashVer)) { throw "missing $crashVer" }
if (-not (Test-Path $hubVer)) { throw "missing $hubVer" }
if (-not (Test-Path $shim)) { throw "missing $shim" }

Write-Host "=== Hub --headless --self-test --quit ==="
$st = Start-Process -FilePath $hub -ArgumentList @("--headless", "--self-test", "--quit") -Wait -PassThru -WorkingDirectory (Split-Path $hub)
if ($st.ExitCode -ne 0) { throw "Hub self-test exit $($st.ExitCode)" }

$blazium = [string](Get-MachineEnv "BLAZIUM")
if ($blazium -ne $CustomDir) {
    throw "BLAZIUM='$blazium' expected '$CustomDir'"
}
$path = Get-MachinePath
if ((";" + $path.ToUpperInvariant() + ";") -notlike ("*;" + $CustomDir.ToUpperInvariant() + ";*")) {
    throw "PATH missing install root: $CustomDir"
}

$proto = (Get-ItemProperty -Path "HKLM:\Software\Classes\blazium\shell\open\command" -ErrorAction SilentlyContinue)."(default)"
if (-not $proto -or ($proto -notlike "*$CustomDir*")) {
    # Wow6432Node / HKCR merge
    $proto = (Get-ItemProperty -Path "Registry::HKEY_CLASSES_ROOT\blazium\shell\open\command" -ErrorAction SilentlyContinue)."(default)"
}
if (-not $proto -or ($proto -notlike "*blazium-cli.exe*" -and $proto -notlike "*handle-uri*")) {
    throw "protocol command missing blazium-cli handle-uri: $proto"
}
if ($proto -notlike "*$($CustomDir.Replace('\','*'))*" -and $proto -notlike "*$CustomDir*") {
    # Allow forward/back slash variance
    $norm = $proto -replace '/', '\'
    if ($norm -notlike "*$CustomDir*") {
        throw "protocol does not point at custom dir: $proto"
    }
}

Write-Host "=== blazium-cli version ==="
$verOut = & $cli version 2>&1
if ($LASTEXITCODE -ne 0) { throw "blazium-cli version exit ${LASTEXITCODE}: $verOut" }
$verText = ($verOut | Out-String).Trim()
if (-not $verText) { throw "blazium-cli version produced empty output" }
Write-Host $verText
if (-not (Test-Path $cli)) { throw "cli vanished" }

function Assert-HubRemoteJson([string]$Path, [string]$Label) {
    if (-not (Test-Path $Path)) { throw "missing $Label hub_remote.json: $Path" }
    $obj = Get-Content -Raw -Path $Path | ConvertFrom-Json
    $tok = [string]$obj.token
    if ($tok.Length -lt 32) { throw "$Label hub_remote token too short ($($tok.Length)): $Path" }
    return $tok
}

# 32-bit Inno on 64-bit Windows writes HKLM\SOFTWARE under WOW6432Node.
function Get-HubInstallKind() {
    foreach ($p in @(
        "HKLM:\SOFTWARE\Blazium\Hub",
        "HKLM:\SOFTWARE\WOW6432Node\Blazium\Hub"
    )) {
        $v = [string](Get-ItemProperty -Path $p -ErrorAction SilentlyContinue).InstallKind
        if ($v) { return $v }
    }
    return ""
}

Write-Host "=== Assert hub_remote.json (machine and/or user) ==="
$machineRemote = Join-Path $env:PROGRAMDATA "blazium\hub_remote.json"
$userRemote = Join-Path $env:APPDATA "blazium\hub_remote.json"
$machineTok = $null
$userTok = $null
if (Test-Path $machineRemote) { $machineTok = Assert-HubRemoteJson $machineRemote "machine" }
if (Test-Path $userRemote) { $userTok = Assert-HubRemoteJson $userRemote "user" }
if (-not $machineTok -and -not $userTok) {
    throw "neither machine nor user hub_remote.json exists after install"
}
$kind = Get-HubInstallKind
if ($kind -ne "fresh") { throw "InstallKind='$kind' expected 'fresh' after first install" }
Write-Host "InstallKind=$kind machine=$([bool]$machineTok) user=$([bool]$userTok)"

$tokenBeforeUpgrade = if ($userTok) { $userTok } else { $machineTok }

$UpgradeLog = Join-Path $env:RUNNER_TEMP "hub-setup-upgrade.log"
if (-not $env:RUNNER_TEMP) { $UpgradeLog = Join-Path ([System.IO.Path]::GetTempPath()) "hub-setup-upgrade.log" }

Write-Host "=== Silent reinstall (upgrade) ==="
$p2 = Start-Process -FilePath $SetupPath -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-",
    "/NOANALYTICS",
    "/DIR=$CustomDir",
    "/LOG=$UpgradeLog"
) -Wait -PassThru
if ($p2.ExitCode -ne 0) {
    if (Test-Path $UpgradeLog) {
        Write-Host "=== Upgrade installer log ($UpgradeLog) ==="
        Get-Content -Path $UpgradeLog -ErrorAction SilentlyContinue | Select-Object -Last 80 | ForEach-Object { Write-Host $_ }
    }
    throw "Upgrade installer exit $($p2.ExitCode)"
}
$kind2 = Get-HubInstallKind
if ($kind2 -ne "upgrade") { throw "InstallKind='$kind2' expected 'upgrade' after second install" }
$tokenAfter = $null
if (Test-Path $userRemote) { $tokenAfter = Assert-HubRemoteJson $userRemote "user-after-upgrade" }
elseif (Test-Path $machineRemote) { $tokenAfter = Assert-HubRemoteJson $machineRemote "machine-after-upgrade" }
else { throw "hub_remote.json missing after upgrade" }
if ($tokenAfter -ne $tokenBeforeUpgrade) {
    throw "hub_remote token changed on upgrade (before=$tokenBeforeUpgrade after=$tokenAfter)"
}
Write-Host "Upgrade InstallKind=$kind2 token unchanged"

Write-Host "=== Seed user markers ==="
$appData = Join-Path $env:APPDATA "blazium"
$local = Join-Path $env:LOCALAPPDATA "Blazium"
New-Item -ItemType Directory -Force -Path $appData, $local | Out-Null
Set-Content -Path (Join-Path $appData "hub.json") -Value "smoke"
Set-Content -Path (Join-Path $local "marker") -Value "smoke"

$unins = Get-ChildItem -Path $CustomDir -Filter "unins*.exe" | Select-Object -First 1
if (-not $unins) { throw "uninstaller not found under $CustomDir" }

Write-Host "=== Silent uninstall $($unins.FullName) ==="
$u = Start-Process -FilePath $unins.FullName -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART"
) -Wait -PassThru
if ($u.ExitCode -ne 0) { throw "Uninstaller exit $($u.ExitCode)" }

# Give Inno a moment to finish file deletes
Start-Sleep -Seconds 2

Write-Host "=== Assert full removal ==="
if (Test-Path $CustomDir) {
    $left = Get-ChildItem -Force $CustomDir -ErrorAction SilentlyContinue
    if ($left -and $left.Count -gt 0) {
        throw "install dir not empty after uninstall: $CustomDir"
    }
}
$blaziumAfter = [string](Get-MachineEnv "BLAZIUM")
if ($blaziumAfter -and $blaziumAfter -ne "") {
    throw "BLAZIUM still set: $blaziumAfter"
}
$pathAfter = Get-MachinePath
if ((";" + $pathAfter.ToUpperInvariant() + ";") -like ("*;" + $CustomDir.ToUpperInvariant() + ";*")) {
    throw "PATH still contains install root"
}
if (Test-Path $appData) { throw "APPDATA\blazium still exists" }
$commonBlazium = Join-Path $env:PROGRAMDATA "blazium"
if (Test-Path $commonBlazium) { throw "PROGRAMDATA\blazium still exists" }
if (Test-Path $local) { throw "LOCALAPPDATA\Blazium still exists" }

Write-Host "Windows custom-dir install/uninstall smoke OK"
