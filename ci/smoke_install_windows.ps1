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

Write-Host "=== Silent install to $CustomDir ==="
$p = Start-Process -FilePath $SetupPath -ArgumentList @(
    "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-",
    "/DIR=$CustomDir"
) -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "Installer exit $($p.ExitCode)" }

Write-Host "=== Assert custom-dir layout ==="
$hub = Join-Path $CustomDir "Hub\BlaziumHub.exe"
$cli = Join-Path $CustomDir "blazium-cli.exe"
$shim = Join-Path $CustomDir "blazium.cmd"
if (-not (Test-Path $hub)) { throw "missing $hub" }
if (-not (Test-Path $cli)) { throw "missing $cli" }
if (-not (Test-Path $shim)) { throw "missing $shim" }

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
if (-not $proto -or ($proto -notlike "*BlaziumHub.exe*")) {
    throw "protocol command missing Hub exe: $proto"
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
if ($LASTEXITCODE -ne 0) { throw "blazium-cli version exit $LASTEXITCODE: $verOut" }
$verText = ($verOut | Out-String).Trim()
if (-not $verText) { throw "blazium-cli version produced empty output" }
Write-Host $verText
if (-not (Test-Path $cli)) { throw "cli vanished" }

Write-Host "=== Seed user markers ==="
$appData = Join-Path $env:APPDATA "blazium"
$local = Join-Path $env:LOCALAPPDATA "Blazium"
$godot = Join-Path $env:APPDATA "Godot\app_userdata\Blazium Hub"
New-Item -ItemType Directory -Force -Path $appData, $local, $godot | Out-Null
Set-Content -Path (Join-Path $appData "hub.json") -Value "smoke"
Set-Content -Path (Join-Path $local "marker") -Value "smoke"
Set-Content -Path (Join-Path $godot "marker") -Value "smoke"

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
if (Test-Path $local) { throw "LOCALAPPDATA\Blazium still exists" }
if (Test-Path $godot) { throw "Godot userdata still exists" }

Write-Host "Windows custom-dir install/uninstall smoke OK"
