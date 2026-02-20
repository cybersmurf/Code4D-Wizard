# Code4D-Wizard-MCP

🤖 **GitHub Copilot-like AI Assistant for Delphi IDE** — Universal edition for all Delphi projects

![Delphi Version](https://img.shields.io/badge/Delphi-12%2B-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Windows-lightgrey)
![Framework](https://img.shields.io/badge/framework-VCL%20%7C%20FMX%20%7C%20Console-orange)

Code4D-Wizard is a wizard/plugin designed to be used in the Delphi IDE. It adds to the Delphi IDE several features and functionality to improve development efficiency, speed and productivity — including an embedded AI assistant powered by GitHub Models. This Wizard was developed using OTA (Open Tools API).

---

## ✨ Features

### 🎯 Core Capabilities
- 🤖 **Embedded MCP Server** — Runs directly in the IDE, no external processes
- 🔗 **GitHub Models Integration** — Uses your GitHub account (gpt-4o, claude-3.5, o1)
- ⚡ **Real-time Code Analysis** — Instant feedback while typing (LSP-powered, debounced 500 ms)
- 🛠️ **10+ Built-in Skills** — Code analysis, refactoring, unit tests, documentation
- 🧠 **Agentic Mode** — Multi-step task execution with planning and memory
- 📚 **RAG Knowledge Base** — Auto-indexed Delphi/VCL/FMX docs with semantic search
- ⌨️ **Keyboard Shortcuts** — `Ctrl+Alt+A` to open assistant, `Ctrl+Shift+A` for quick analysis
- 🎨 **IDE Integration** — Native menus, Messages window markers, toolbars

### 🔍 Real-time Diagnostics
| Rule | Code | Default |
|------|------|---------|
| Object created without try-finally | `DELPHI001` | warning |
| String concat in loop (use TStringBuilder) | `DELPHI002` | warning |
| Direct UI access from TThread.Execute | `DELPHI003` | warning |
| Deprecated file I/O API | `DELPHI004` | info |

### 🧠 AI Skills
| Skill | Category | Shortcut |
|-------|----------|----------|
| `analyze_code` | Analysis | `Ctrl+Shift+A` |
| `refactor_code` | Refactoring | — |
| `generate_unit_test` | Testing | `Ctrl+Alt+T` |
| `explain_code` | Documentation | — |
| `find_bugs` | Debugging | — |
| `suggest_patterns` | Architecture | — |
| `modernize_syntax` | Refactoring | — |
| `check_threading` | Concurrency | — |
| `generate_docs` | Documentation | — |
| `optimize_code` | Performance | — |

---

## 📞 Contacts

[![E-mail](https://img.shields.io/badge/E--mail-Send-yellowgreen?logo=maildotru&logoColor=yellowgreen)](mailto:megamrsk@gmail.com)

---

## ⚙️ Installation

### Prerequisites
- **Delphi 12 Athens** or **Delphi 13 Florence**
- **GitHub account** with Models API access ([github.com/marketplace/models](https://github.com/marketplace/models))
- **Windows 10/11**
- *Optional*: ChromaDB for RAG knowledge base

### Steps

1 - Download Code4D-Wizard. You can download the .zip file or clone the project on your PC.

2 - In your Delphi, access the menu File > Open and select the file: Package/C4DWizard.dpk

![image](https://github.com/user-attachments/assets/2e2f606a-441d-4d5b-8aae-75a3b7255f77)

3 - Right-click on the project name and select "Install"

![image](https://github.com/user-attachments/assets/792ce355-d39f-4835-a117-fe441253f167)

4 - The Code4D item will be added to the IDE's MainMenu

![Code4D-item-added-to-MainMenu.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Code4D-item-added-to-MainMenu.png)

<br/>

### GitHub Token Setup

Set the `GITHUB_TOKEN` environment variable so the embedded AI can call GitHub Models:

```cmd
setx GITHUB_TOKEN "ghp_your_github_token_here"
rem Restart IDE after setting
```

Get a token at [github.com/marketplace/models](https://github.com/marketplace/models).

# 👨‍🎓 Complete OTA Training
[**Access training**](https://hotmart.com/pt-br/marketplace/produtos/delphi-ota-open-tools-api/U81331747Y)

<br/>‌

# 🔎 Preview resources Code4D-Wizard

### * Menus add in MainMenu IDE

![Menus-Add-in-MainMenu-IDE-Delphi.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Menus-Add-in-MainMenu-IDE-Delphi.png)

- **Open External Path**: Lets you add items for quick access to resources external to the IDE. How to access files, folders, web links and even CMD commands to perform one or more functions in Windows CMD. Can be configured shortcut keys, and even a logo for each item
  ![Open-External.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Open-External.png)
- **Uses Organization**: Allows you to organize the Uses of the Units, with various configurations, such as the possibility of leaving one Uses per line, sorting uses in alphabetical order, grouping uses by namespaces, breaking lines between namespaces. In addition to making it possible to organize by scope, that is, by the current unit, by open units, project group or project units, and showing a Log with the Units that were orphaned.

  ![Uses-Organization.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Uses-Organization.png)
- **Reopen File History**: Opens a screen, where a history is listed, with all project groups and projects previously opened in the IDE. Enabling the marking of project group or projects as favorites, so that they are shown in prominence. Various information is also presented, such as the date of the last opening and closing, and the possibility of creating a nickname for the item. It is also possible to separate by groups, and search by different filters, including opening dates. On this screen, it is also possible to access various resources of the projects or project group, such as automatically opening the Github Desktop with the project already selected, opening the project in the remote repository, opening the project file in the Windows explorer, among many other resources.
  ![Reopen.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Reopen.png)
- **Translate Text**: Allows texts to be translated between several languages, WITHOUT using any credentials or passwords. If you have any text selected in the IDE's editor at the time the screen is called, the selected text will be loaded onto the screen for translation.
  ![Translate.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Translate.png)
- **Indent Text Selected**: This feature serves to indent the selected code, taking into account some characters, such as := (two equal points), this feature will indent the fonts, aligning the := (two equal points)
- **Find in Files**: Searches the units, with several configuration options, and can search not only in .pas files but also in .dfm, . fmx and in .dpr and .dproj. Another interesting point is that when displaying the search result, it marks the words found in green to make identification easier, in addition to showing a totalizer with the number of occurrences of the searched text and the number of files that have them.
  ![Find-in-files.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Find-in-files.png)

  ![Find-in-files-Messages.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Find-in-files-Messages.png)

- **Replace in Files**: Makes the alteration of texts in the units, with several option of configurations, and it can make the replace not only in .pas files but also in .dfm, . fmx and in .dpr and .dproj. Another interesting point is that when displaying the result of the changes, it shows a totalizer with the number of occurrences of the text changed and the number of files that have them.
  ![Replace-in-files.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Replace-in-files.png)
- **Default Files In Opening Project**: This feature allows you to inform which units or forms are automatically opened as soon as the project is opened in the IDE.
  ![Default-Files-In-Opening-Project.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Default-Files-In-Opening-Project.png)
- **Settings**: It has some settings related to the Wizard, such as the possibility of informing shortcuts for MainMenu items.

  With the option "**Before compiling, check if binary is not running**" checked, always before compiling or building the project, it will be checked if it is not already running, if so, a question will be displayed alerting that the program be closed beforehand, so as not to waste time waiting for the compilation without being able to finish it.
  
  With the option "**Block the INSERT Key**" checked, it will not be possible to press the "Insert" key on the keyboard, thus not allowing the IDE to switch between "Insert" and "Overwrite", preventing the "Overwrite" feature from being unintentionally enabled.
  
  The "**Open Data Folder**" button, opens in the Windows explorer, the folder where the files used by the Code4D-Wizard are created and stored.  
  ![Settings.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Settings.png)
- **Backup/Restore Configs**: Allows you to export and import backup files with the Code4D-Wizard settings and data, so when you format your PC you don't ask for your data. In addition to enabling data sharing among other programmers on your team.
  ![Backup.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/Backup.png)
- **Open in GitHub Desktop**: Allows opening the current project directly on Github Desktop, with the project already open. It is possible to open it in other version management programs, just use the resources available in the Open External Path menu item
- **View in Remote Repository**: Opens the remote repository of the Git project in the browser, it can be GitHub, Bitbucket, GitLab, etc.
- **View Information Remote Repository**: Displays remote repository information of the project
- **View Project File in Explorer**: Opens the current project file in Windows Explorer
- **View Current File in Explorer**: Opens the current file, which is open in the IDE in Windows Explorer
- **View Current Binary in Explorer**: Opens the binary file (.exe) in Windows Explorer, also works for Linux compilation and DLL

‌

- **AI Assistant (MCP)**: An embedded AI coding assistant powered by [GitHub Models](https://github.com/marketplace/models). Supports three transport modes:
  - **HTTP** — connect to any running MCP server
  - **Stdio** — launch an external MCP server as a child process
  - **Embedded (built-in)** — run a fully in-process MCP server with no external dependency. Uses your `GITHUB_TOKEN` to call the GitHub Models inference API directly from inside the IDE.

  **Agentic mode** (Embedded transport): enable multi-step task execution where the AI automatically plans, decomposes and executes complex requests using the built-in agent orchestrator (`Src/Agent/`) and a library of Skills (`Src/Skills/`). Domain context is injected via instruction files (`Config/instructions/`).

  **Real-time diagnostics**: as you type, code is analysed (debounced 500 ms) and issues appear in the Messages window: missing try-finally, string concat in loops, direct UI access from threads, deprecated file I/O.

  **RAG knowledge base**: documentation files in `Knowledge/docs/` are auto-indexed by a background `TFileSystemWatcher` (via `ReadDirectoryChangesW`) into ChromaDB. Queries use semantic search over indexed content.

  Built-in AI tools available in Embedded mode:
  | Tool | Description |
  |---|---|
  | `analyze_code` | Deep code analysis — memory, threading, performance, anti-patterns |
  | `refactor_code` | Extract method, simplify, modernize syntax |
  | `generate_unit_test` | DUnit/DUnitX test generation with configurable coverage |
  | `explain_code` | Natural language explanation with examples |
  | `find_bugs` | Potential bug and runtime error detection |
  | `suggest_patterns` | Design pattern recommendations |
  | `modernize_syntax` | Update code to modern Delphi (inline vars, generics, PPL) |
  | `check_threading` | Threading safety analysis |
  | `generate_docs` | XML documentation comments |
  | `optimize_code` | Performance optimization |
  | `query_docs` | Free-form Delphi / RAD Studio Q&A with RAG |
  | `ask_ai` | Generic prompt with optional code context |

  See **[Docs/AI-ASSISTANT.md](Docs/AI-ASSISTANT.md)** for full setup and usage guide including the Agentic Mode reference.


‌

### * Project Manager PopupMenu

![PopupMenu-Project-Manager.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/PopupMenu-Project-Manager.png)

‌

### * ToolBars

![ToolBars.png](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/Images/ToolBars.png)

#### **ToolBar Build:**

- Button **Build Project In Release**: Executes the Build of the selected project, with several checks and improvements. Before giving the Build, it checks if the project's .exe is not already open, if it is, it gives a message for it to be closed first. It also automatically changes the project from Debug to Release, and after the Build is finished, it returns to Debug if necessary.
- It is also possible to change the Build Configurations directly through the ComboBox of the ToolBar too, you can change it to Debug or Release

#### **ToolBar Branch:**

- In this ToolBar it is possible to visualize the current Git branch that the project is in. If you are in Branch Master or Main, the text will turn red, alerting the programmer to change the Branch.


‌
# 💬 Contributions / Ideas / Bug Fixes
To submit a pull request, follow these steps:

1. Fork the project
2. Create a new branch (`git checkout -b my-new-feature`)
3. Make your changes
4. Make the commit (`git commit -am 'Functionality or adjustment message'`)
5. Push the branch (`git push origin Message about functionality or adjustment`)
6. Open a pull request

‌
# 🔨 Building from Source

See **[Docs/BUILDING.md](Docs/BUILDING.md)** for detailed instructions on building with MSBuild or DCC64, VS Code tasks, and GitHub Actions CI.

Quick start:
```powershell
# PowerShell (MSBuild, Delphi 13 Release)
.\Build\build.ps1 -DelphiVersion 13 -Config Release -Compiler MSBuild

# or DCC:
.\Build\dcc-build.bat 13 Release
```

## ⚠️ License
`Code4D-Wizard` is free and open-source wizard licensed under the [MIT License](https://github.com/Code4Delphi/Code4D-Wizard/blob/master/LICENSE).

