param(
    [string]$Editor = "",
    [string]$JUnit = ""
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not $Editor) {
    $candidates = @(
        "blazium"
        Join-Path $Root "..\blazium\bin\blazium.windows.editor.tests.x86_64.exe"
        Join-Path $Root "..\blazium\bin\blazium.windows.editor.dev.tests.x86_64.exe"
        Join-Path $Root "..\blazium\bin\blazium.windows.editor.x86_64.exe"
    )
    foreach ($c in $candidates) {
        if ($c -eq "blazium") {
            $cmd = Get-Command blazium -ErrorAction SilentlyContinue
            if ($cmd) {
                $Editor = $cmd.Source
                break
            }
            continue
        }
        if (Test-Path $c) {
            $Editor = (Resolve-Path $c).Path
            break
        }
    }
}

if (-not $Editor) {
    Write-Error "No Blazium editor found. Pass -Editor <path> or install blazium on PATH."
    exit 1
}

Write-Host "Using editor: $Editor"
$env:HUB_AUTOWORK = "1"
$args = @("--headless", "--path", $Root, "-s", "run_tests.gd")
if ($JUnit) {
    $args += "--aw-junit=$JUnit"
}

& $Editor @args
exit $LASTEXITCODE
