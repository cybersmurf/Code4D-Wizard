@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM Install C4DWizard.bpl into the Delphi IDE
REM Usage: install.bat [DELPHI_VERSION]
REM   Copies the BPL to the IDE's BPL folder and registers it.
REM ============================================================

set DELPHI_VERSION=%~1
if "%DELPHI_VERSION%"=="" set DELPHI_VERSION=13

if /I "%DELPHI_VERSION%"=="12" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\23.0"
    set "REG_KEY=HKCU\Software\Embarcadero\BDS\23.0\Known Packages"
) else if /I "%DELPHI_VERSION%"=="13" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\24.0"
    set "REG_KEY=HKCU\Software\Embarcadero\BDS\24.0\Known Packages"
) else (
    echo [ERROR] Unsupported Delphi version: %DELPHI_VERSION%
    exit /b 1
)

set "BPL_SRC=%~dp0..\Package\Win64\Release\C4DWizard.bpl"
set "BPL_DST=%DELPHI_ROOT%\bin\C4DWizard.bpl"

if not exist "%BPL_SRC%" (
    echo [ERROR] BPL not found. Build first: msbuild-build.bat %DELPHI_VERSION% Release
    exit /b 1
)

echo [INFO] Copying BPL to Delphi bin folder...
copy /Y "%BPL_SRC%" "%BPL_DST%"
if errorlevel 1 (
    echo [ERROR] Copy failed. Run as Administrator if required.
    exit /b 1
)

echo [INFO] Registering package in Windows Registry...
reg add "%REG_KEY%" /v "%BPL_DST%" /t REG_SZ /d "Code4D Wizard MCP" /f
if errorlevel 1 (
    echo [WARN] Registry update failed - you may need to install the package manually via IDE.
)

echo.
echo [OK] Package installed. Restart Delphi IDE to load the package.
echo.

endlocal
exit /b 0
