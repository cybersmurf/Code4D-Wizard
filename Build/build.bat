@echo off
REM ============================================================
REM Wrapper: delegates to build.ps1
REM Usage: build.bat [DELPHI_VERSION] [CONFIG] [COMPILER]
REM ============================================================
powershell -ExecutionPolicy Bypass -File "%~dp0build.ps1" ^
    -DelphiVersion %1 -Config %2 -Compiler %3
exit /b %errorlevel%
