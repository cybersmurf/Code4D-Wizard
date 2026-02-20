<#
.SYNOPSIS
    Universal build script for Code4D-Wizard

.DESCRIPTION
    Builds the Code4D-Wizard package using MSBuild or DCC64.
    Supports Delphi 12 (Athens) and Delphi 13 (Florence).

.PARAMETER DelphiVersion
    Delphi version number. Supported: 12, 13. Default: 13.

.PARAMETER Config
    Build configuration. Supported: Debug, Release. Default: Release.

.PARAMETER Compiler
    Compiler to use. Supported: MSBuild, DCC. Default: MSBuild.

.PARAMETER Platform
    Target platform. Supported: Win32, Win64. Default: Win64.

.EXAMPLE
    .\build.ps1
    .\build.ps1 -DelphiVersion 13 -Config Release -Compiler MSBuild
    .\build.ps1 -DelphiVersion 12 -Config Debug   -Compiler DCC
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('12', '13')]
    [string]$DelphiVersion = '13',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Release',

    [Parameter(Mandatory = $false)]
    [ValidateSet('MSBuild', 'DCC')]
    [string]$Compiler = 'MSBuild',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Header {
    param([string]$Text)
    Write-Host "`n$('=' * 48)" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor Cyan
    Write-Host "$('=' * 48)`n" -ForegroundColor Cyan
}

function Write-Step {
    param([string]$Text)
    Write-Host "  >> $Text" -ForegroundColor Yellow
}

function Write-Success {
    param([string]$Text)
    Write-Host "`n  [OK] $Text`n" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Text)
    Write-Host "`n  [FAIL] $Text`n" -ForegroundColor Red
}

# ---------------------------------------------------------------------------
# Delphi install paths
# ---------------------------------------------------------------------------
$DelphiRoots = @{
    '12' = 'C:\Program Files (x86)\Embarcadero\Studio\23.0'
    '13' = 'C:\Program Files (x86)\Embarcadero\Studio\24.0'
}

$DelphiRoot = $DelphiRoots[$DelphiVersion]

Write-Header "Code4D-Wizard Build  |  D$DelphiVersion $Platform $Config ($Compiler)"

if (-not (Test-Path $DelphiRoot)) {
    Write-Failure "Delphi $DelphiVersion not found at: $DelphiRoot"
    exit 1
}

# ---------------------------------------------------------------------------
# Set environment variables (equivalent to rsvars.bat)
# ---------------------------------------------------------------------------
Write-Step "Loading Delphi $DelphiVersion environment"
$env:BDS      = $DelphiRoot
$env:BDSBIN   = "$DelphiRoot\bin"
$env:BDSLIB   = "$DelphiRoot\lib"
$env:BDSCOMMON= "$env:PUBLIC\Documents\Embarcadero\Studio\$DelphiVersion.0"
$env:Path     = "$env:BDSBIN;$env:Path"

# ---------------------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------------------
$ScriptDir   = $PSScriptRoot
$PackageDir  = Resolve-Path "$ScriptDir\..\Package"
$OutputDir   = "$PackageDir\$Platform\$Config"
$DcuDir      = "$OutputDir\DCU"

foreach ($Dir in @($OutputDir, $DcuDir)) {
    if (-not (Test-Path $Dir)) {
        New-Item -ItemType Directory -Path $Dir | Out-Null
    }
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
Push-Location $PackageDir

try {
    if ($Compiler -eq 'MSBuild') {

        Write-Step "Running MSBuild on C4DWizard.dproj"

        $MsBuildArgs = @(
            'C4DWizard.dproj'
            "/p:Configuration=$Config"
            "/p:Platform=$Platform"
            "/p:DCC_DcuOutput=$DcuDir"
            '/t:Build'
            '/v:m'
            '/nologo'
        )

        & msbuild @MsBuildArgs

    } else {

        Write-Step "Running DCC64 on C4DWizard.dpk"

        $DccPath = "$DelphiRoot\bin\dcc64.exe"
        if (-not (Test-Path $DccPath)) {
            Write-Failure "DCC64 not found at: $DccPath"
            exit 1
        }

        $SrcPaths = @(
            '..\Src', '..\Src\AI', '..\Src\MCP', '..\Src\Utils',
            '..\Src\Settings', '..\Src\Interfaces', '..\Src\AIAssistant',
            '..\Src\IDE\MainMenu', '..\Src\IDE\ShortCut'
        ) -join ';'

        $LibPath = "$env:BDSLIB\$Platform\release"

        $DccArgs = @(
            '-B', '-Q', '-W', '-H'
            if ($Config -eq 'Debug')   { '-$D+' } else { '-$D-'; '-$O+' }
            "-E$OutputDir"
            "-N0$DcuDir"
            "-LE$env:BPL"
            "-LN$LibPath"
            "-U$LibPath;$SrcPaths"
            'C4DWizard.dpk'
        )

        & $DccPath @DccArgs
    }
}
finally {
    Pop-Location
}

if ($LASTEXITCODE -ne 0) {
    Write-Failure "Build failed (exit code $LASTEXITCODE)"
    exit $LASTEXITCODE
}

Write-Success "Build successful"
Write-Host "  Output : $OutputDir\C4DWizard.bpl" -ForegroundColor Green
Write-Host ""
