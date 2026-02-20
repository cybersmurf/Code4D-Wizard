@echo off
setlocal enabledelayedexpansion

REM ============================================================
REM Code4D-Wizard DCC64 Compiler Script
REM Usage: dcc-build.bat [DELPHI_VERSION] [CONFIG]
REM   DELPHI_VERSION : 12 (Athens/23.0) or 13 (Florence/24.0)
REM   CONFIG         : Debug or Release  (default: Release)
REM ============================================================

set DELPHI_VERSION=%~1
set BUILD_CONFIG=%~2

if "%DELPHI_VERSION%"=="" set DELPHI_VERSION=13
if "%BUILD_CONFIG%"==""    set BUILD_CONFIG=Release

echo.
echo ========================================
echo   Code4D-Wizard - DCC64
echo   Delphi : %DELPHI_VERSION%
echo   Config : %BUILD_CONFIG%
echo ========================================
echo.

REM --- Resolve paths ---
if /I "%DELPHI_VERSION%"=="12" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\23.0"
) else if /I "%DELPHI_VERSION%"=="13" (
    set "DELPHI_ROOT=C:\Program Files (x86)\Embarcadero\Studio\24.0"
) else (
    echo [ERROR] Unsupported Delphi version: %DELPHI_VERSION%
    exit /b 1
)

set "DCC_PATH=%DELPHI_ROOT%\bin\dcc64.exe"
set "RSVARS_PATH=%DELPHI_ROOT%\bin\rsvars.bat"

if not exist "%DCC_PATH%" (
    echo [ERROR] DCC64 not found at %DCC_PATH%
    exit /b 1
)

REM --- Load Delphi environment (sets BPL, BDSLIB etc.) ---
call "%RSVARS_PATH%"

REM --- Setup output directory ---
set "BPL_OUTPUT=%~dp0..\Package\Win64\%BUILD_CONFIG%"
if not exist "%BPL_OUTPUT%"     mkdir "%BPL_OUTPUT%"
if not exist "%BPL_OUTPUT%\DCU" mkdir "%BPL_OUTPUT%\DCU"

REM --- Compiler switches ---
set "DCC_SWITCHES=-B -Q -W -H"
if /I "%BUILD_CONFIG%"=="Debug"   set "DCC_SWITCHES=%DCC_SWITCHES% -$D+"
if /I "%BUILD_CONFIG%"=="Release" set "DCC_SWITCHES=%DCC_SWITCHES% -$D- -$O+"

REM --- Source search paths ---
set "SRC_PATHS=..\Src;..\Src\AI;..\Src\MCP;..\Src\Utils;..\Src\Settings;..\Src\Interfaces"
set "SRC_PATHS=%SRC_PATHS%;..\Src\AIAssistant;..\Src\IDE\MainMenu;..\Src\IDE\ShortCut"

REM --- Navigate to package ---
cd /d "%~dp0..\Package"

echo [INFO] Compiler : %DCC_PATH%
echo [INFO] Output   : %BPL_OUTPUT%
echo.

"%DCC_PATH%" %DCC_SWITCHES% ^
    -E"%BPL_OUTPUT%" ^
    -N0"%BPL_OUTPUT%\DCU" ^
    -LE"%BPL%" ^
    -LN"%BDSLIB%\Win64\release" ^
    -U"%BDS%\lib\Win64\release;%SRC_PATHS%" ^
    -I"%BDS%\include" ^
    C4DWizard.dpk

if errorlevel 1 (
    echo.
    echo [FAIL] COMPILATION FAILED
    echo.
    exit /b 1
)

echo.
echo [OK] COMPILATION SUCCESSFUL
echo      Output: %BPL_OUTPUT%\C4DWizard.bpl
echo.

endlocal
exit /b 0
