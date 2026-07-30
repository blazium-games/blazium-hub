@echo off
REM Thin shim: `blazium` invokes bundled blazium-cli (not Hub GUI).
"%~dp0blazium-cli.exe" %*
