# Building Code4D-Wizard from Source

## Contents

1. [Prerequisites](#1-prerequisites)
2. [Repository Structure](#2-repository-structure)
3. [Build with PowerShell (recommended)](#3-build-with-powershell-recommended)
4. [Build with MSBuild directly](#4-build-with-msbuild-directly)
5. [Build with DCC64 directly](#5-build-with-dcc64-directly)
6. [VS Code Build Tasks](#6-vs-code-build-tasks)
7. [Installing the Package](#7-installing-the-package)
8. [Cleaning Build Output](#8-cleaning-build-output)
9. [GitHub Actions CI](#9-github-actions-ci)
10. [Supported Delphi Versions](#10-supported-delphi-versions)

---

## 1. Prerequisites

| Requirement | Notes |
|---|---|
| Delphi 12 Athens (23.0) **or** Delphi 13 Florence (24.0) | Required to compile |
| Windows 10 / 11 | Build scripts are Windows-only |
| PowerShell 5.1+ | For `build.ps1` and `clean.ps1` |
| Git | To clone the repository |
| VS Code (optional) | For the included build tasks |

---

## 2. Repository Structure

```
Code4D-Wizard-master/
│
├── Src/                        # All Pascal source files
│   ├── AI/                     # GitHub Models API client
│   │   └── C4D.Wizard.AI.GitHub.pas
│   ├── MCP/                    # MCP client + embedded server
│   │   ├── C4D.Wizard.MCP.Client.pas
│   │   ├── C4D.Wizard.MCP.Config.pas
│   │   ├── C4D.Wizard.MCP.EmbeddedServer.pas
│   │   └── C4D.Wizard.MCP.StdioTransport.pas
│   ├── Agent/                  # Agentic orchestrator
│   │   ├── C4D.Wizard.Agent.Core.pas
│   │   ├── C4D.Wizard.Agent.Planning.pas
│   │   └── C4D.Wizard.Agent.Memory.pas
│   ├── Instructions/           # Instruction file loader
│   │   └── C4D.Wizard.Instructions.Manager.pas
│   ├── Skills/                 # Skill implementations
│   │   ├── C4D.Wizard.Skill.Base.pas
│   │   ├── C4D.Wizard.Skill.CodeAnalysis.pas
│   │   ├── C4D.Wizard.Skill.Generation.pas
│   │   ├── C4D.Wizard.Skill.Refactoring.pas
│   │   └── C4D.Wizard.Skill.Documentation.pas
│   ├── AIAssistant/            # AI Assistant dialog (VCL form)
│   ├── Settings/               # Settings model + view
│   ├── Interfaces/             # Global interfaces
│   └── ...                     # All other wizard features
│
├── Package/
│   ├── C4DWizard.dpk           # Package source (DPK)
│   └── C4DWizard.dproj         # MSBuild project file
│
├── Config/
│   ├── mcp.json                # Default MCP/GitHub Models config
│   ├── mcp.example.json        # Example with all options
│   ├── instructions/           # AI system prompt instruction files
│   │   ├── base.md
│   │   ├── delphi-expert.md
│   │   ├── mes-architecture.md
│   │   └── emistr.md
│   └── skills/                 # Skill definition files (JSON Schema)
│       ├── analyze_entity.json
│       ├── generate_service.json
│       └── refactor_code.json
│
├── Build/
│   ├── build.ps1               # Universal PowerShell build script
│   ├── build.bat               # Batch wrapper for build.ps1
│   ├── msbuild-build.bat       # MSBuild-specific script
│   ├── dcc-build.bat           # DCC64-specific script
│   ├── install.bat             # Copy BPL + register in IDE
│   └── clean.ps1               # Remove all build artefacts
│
├── .vscode/
│   ├── tasks.json              # VS Code build tasks
│   ├── launch.json             # Debug attach config
│   └── settings.json           # File associations + exclusions
│
├── .github/
│   └── workflows/
│       ├── build-msbuild.yml   # CI: MSBuild matrix (D12 + D13)
│       ├── build-dcc.yml       # CI: manual DCC build
│       └── release.yml         # Auto-release on version tag
│
└── Docs/
    ├── AI-ASSISTANT.md         # AI Assistant setup guide (incl. Agentic Mode)
    └── BUILDING.md             # This file
```

---

## 3. Build with PowerShell (recommended)

```powershell
# Default: Delphi 13, Release, MSBuild
.\Build\build.ps1

# Specific version + config
.\Build\build.ps1 -DelphiVersion 12 -Config Release -Compiler MSBuild
.\Build\build.ps1 -DelphiVersion 13 -Config Debug   -Compiler DCC

# Parameters
#   -DelphiVersion  12 | 13              (default: 13)
#   -Config         Debug | Release      (default: Release)
#   -Compiler       MSBuild | DCC        (default: MSBuild)
#   -Platform       Win32 | Win64        (default: Win64)
```

Output: `Package\Win64\Release\C4DWizard.bpl`

---

## 4. Build with MSBuild directly

```batch
cd Package
call "C:\Program Files (x86)\Embarcadero\Studio\24.0\bin\rsvars.bat"
msbuild C4DWizard.dproj /p:Configuration=Release /p:Platform=Win64 /t:Build /v:m /nologo
```

Or use the script:
```batch
Build\msbuild-build.bat 13 Release
Build\msbuild-build.bat 12 Release
```

---

## 5. Build with DCC64 directly

```batch
Build\dcc-build.bat 13 Release
Build\dcc-build.bat 12 Debug
```

The script:
1. Calls `rsvars.bat` to set `BPL`, `BDSLIB` etc.
2. Runs `dcc64.exe` with full source search paths
3. Places the BPL in `Package\Win64\<Config>\`

---

## 6. VS Code Build Tasks

Open the workspace in VS Code (`code .`) and press **Ctrl+Shift+B** to run the default build task (MSBuild, Delphi 13, Release).

All available tasks (`Ctrl+Shift+P` → *Tasks: Run Task*):

| Task | Description |
|---|---|
| **Build with MSBuild (Delphi 13)** *(default)* | MSBuild, D13, Release |
| Build with MSBuild (Delphi 12) | MSBuild, D12, Release |
| Build with DCC (Delphi 13) | DCC64, D13, Release |
| Build with DCC (Delphi 12) | DCC64, D12, Release |
| Build All Delphi Versions | Runs D12 + D13 in sequence |
| Clean Build Output | Deletes `Win32/`, `Win64/`, DCU files |
| Install Package in IDE (Delphi 13) | Build + copy BPL + register |

Delphi errors and warnings are parsed by the built-in problem matcher and shown in the **Problems** panel.

---

## 7. Installing the Package

### Manual (via Delphi IDE)
1. Build the package (any method above)
2. In Delphi: **Component → Install Packages...**
3. Browse to `Package\Win64\Release\C4DWizard.bpl`
4. Click **Add** → **OK**
5. Restart the IDE

### Automated script
```batch
Build\install.bat 13
```
Copies the BPL to `%DELPHI_ROOT%\bin` and writes the `Known Packages` registry key.  
> Run as Administrator if you get an "Access denied" error.

### Pre-built BPLs
Pre-compiled BPLs for each Delphi version are in `Install-BPLs/`:
```
Install-BPLs/
  Delphi-10.0-Seattle/
  Delphi-10.1-Berlin/
  Delphi-10.2-Tokyo/
  Delphi-10.3-Rio/
  Delphi-10.4-Sydney/
  Delphi-11.3-Alexandria/
  Delphi-12.0-Athens/
```

> A pre-built BPL for Delphi 13 is not included yet. Build it yourself with `Build\msbuild-build.bat 13 Release` and drop the output into a new `Install-BPLs/Delphi-13.0-Florence/` folder.

---

## 8. Cleaning Build Output

```powershell
# Remove all Win32/, Win64/, __history/, *.dcu, *.bpl etc.
.\Build\clean.ps1

# Preview what would be removed (dry run)
.\Build\clean.ps1 -WhatIf
```

---

## 9. GitHub Actions CI

Three workflows are included:

### `build-msbuild.yml` — Continuous integration
- Triggers on push/PR to `main` or `develop`
- Matrix: Delphi 12 × 13, Release configuration
- Uploads BPL as a build artefact (30-day retention)

### `build-dcc.yml` — Manual DCC build
- Triggered manually via **Actions → Build (DCC) → Run workflow**
- Select Delphi version and config at runtime

### `release.yml` — Automated release
- Triggers when a tag matching `v*.*.*` is pushed
- Builds for both Delphi versions
- Creates a GitHub Release with:
  - ZIP archives per Delphi version
  - Auto-generated release notes

**Creating a release**:
```bash
git tag v1.2.0
git push --tags
```

> **Note**: GitHub-hosted `windows-latest` runners do **not** include Delphi. For real CI, use a **self-hosted runner** with Delphi installed, or add a Delphi installation step to the workflow.

---

## 10. Supported Delphi Versions

| Version | Studio ver | Compiler key | Pre-built BPL |
|---|---|---|---|
| Delphi 10.0 Seattle | 17.0 | — | ✓ |
| Delphi 10.1 Berlin | 18.0 | — | ✓ |
| Delphi 10.2 Tokyo | 19.0 | — | ✓ |
| Delphi 10.3 Rio | 20.0 | — | ✓ |
| Delphi 10.4 Sydney | 21.0 | — | ✓ |
| Delphi 11.3 Alexandria | 22.0 | — | ✓ |
| Delphi 12.0 Athens | 23.0 | `12` | ✓ + Build scripts |
| Delphi 13.0 Florence | 24.0 | `13` | Build scripts only (no pre-built BPL yet) |

> The AI Assistant (Embedded/GitHub Models) requires Delphi 12+ due to use of inline variable declarations (`var x := ...`) and `TNetHTTPClient`.
