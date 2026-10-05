@echo off
REM Launch BlaziumHub from PATH. Engine is the current folder; Hub remains for older installs.
if exist "%~dp0Engine\BlaziumHub.exe" (
  start "" "%~dp0Engine\BlaziumHub.exe" %*
) else (
  start "" "%~dp0Hub\BlaziumHub.exe" %*
)
