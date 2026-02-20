@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM Code4D-Wizard MSBuild Script
REM Usage: msbuild-build.bat [DELPHI_VERSION] [CONFIG]
REM   DELPHI_VERSION : 12 (Athens/23.0) or 13 (Florence/24.0)
REM   CONFIG         : Debug or Release  (default: Release)
REM ============================================================

set DELPHI_VERSION=%~1
set BUILD_CONFIG=%~2

if "%DELPHI_VERSION%"=="" set DELPHI_VERSION=13
if "%BUILD_CONFIG%"==""    set BUILD_CONFIG=Release

echo.
echo ========================================
echo   Code4D-Wizard - MSBuild
echo   Delphi : %DELPHI_VERSION%
echo   Config : %BUILD_CONFIG%
echo ========================================
echo.

REM --- Resolve Delphi install root ---
if /I "%DELPHI_VERSION%"=="12" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\23.0"
) else if /I "%DELPHI_VERSION%"=="13" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\24.0"
) else (
    echo [ERROR] Unsupported Delphi version: %DELPHI_VERSION%
    echo         Supported values: 12, 13
    exit /b 1
)

set "RSVARS_PATH=%DELPHI_ROOT%\bin\rsvars.bat"

if not exist "%RSVARS_PATH%" (
    echo [ERROR] Delphi %DELPHI_VERSION% not found.
    echo         Expected: %DELPHI_ROOT%
    exit /b 1
)

echo [INFO] Loading Delphi environment from:
echo        %RSVARS_PATH%
call "%RSVARS_PATH%"
echo.

REM --- Navigate to Package dir ---
cd /d "%~dp0..\Package"

echo [INFO] Building: %CD%\C4DWizard.dproj
echo.

msbuild C4DWizard.dproj ^
    /p:Configuration=%BUILD_CONFIG% ^
    /p:Platform=Win64 ^
    /p:DCC_DcuOutput=.\Win64\%BUILD_CONFIG%\DCU ^
    /t:Build ^
    /v:m ^
    /nologo

if errorlevel 1 (
    echo.
    echo [FAIL] BUILD FAILED - check output above
    echo.
    exit /b 1
)

echo.
echo [OK] BUILD SUCCESSFUL
echo      Output: %CD%\Win64\%BUILD_CONFIG%\C4DWizard.bpl
echo.

endlocal
exit /b 0
