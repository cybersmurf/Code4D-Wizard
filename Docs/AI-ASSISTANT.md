# AI Assistant (MCP) — Setup & Usage Guide

The AI Assistant integrates a **Model Context Protocol (MCP)** client directly into the Delphi IDE toolbar/menu. It lets you browse available AI tools, send prompts with optional code context, and receive generated code — all without leaving the IDE.

The assistant supports two usage tiers:
- **Single-tool mode** — select one MCP tool and send a direct prompt
- **Agentic mode** — the AI plans, decomposes and executes multi-step tasks autonomously

## Contents

1. [Quick Start — Embedded Mode](#1-quick-start--embedded-mode)
2. [Transport Modes](#2-transport-modes)
3. [Agentic Mode](#3-agentic-mode)
4. [Settings Reference](#4-settings-reference)
5. [mcp.json Configuration](#5-mcpjson-configuration)
6. [Built-in Tools (Embedded Mode)](#6-built-in-tools-embedded-mode)
7. [Skills](#7-skills)
8. [Instructions System](#8-instructions-system)
9. [HTTP Transport](#9-http-transport)
10. [Stdio Transport](#10-stdio-transport)
11. [GitHub Token Setup](#11-github-token-setup)
12. [Keyboard Shortcuts](#12-keyboard-shortcuts)

---

## 1. Quick Start — Embedded Mode

The fastest way to get started — no external server required.

**Prerequisites**:
- A GitHub account with access to [GitHub Models](https://github.com/marketplace/models)
- A GitHub Personal Access Token (PAT) with `models:read` scope  
  *or* the `GITHUB_TOKEN` environment variable set (e.g. from GitHub Actions / Codespaces)

**Steps**:

1. Open **Code4D → Settings** in the IDE menu
2. Scroll to the **AI Assistant (MCP)** section
3. Set **Transport** to `Embedded (built-in)`
4. Enter your **GitHub Token** (leave blank to use `GITHUB_TOKEN` env var)
5. Optionally change the **Model** (default: `gpt-4o`)
6. Click **OK**
7. Open **Code4D → AI Assistant** (`Ctrl+Alt+A` by default)

The tool list on the left will populate with the built-in tools. Select a tool, type a prompt, and press **F5** (or click **Send**).

---

## 2. Transport Modes

| Mode | Description | External process? |
|---|---|---|
| **HTTP** | Connects to an already-running MCP server via HTTP | No |
| **Stdio** | Launches an external executable as an MCP server child process | Yes |
| **Embedded** | Runs the MCP server fully in-process inside the IDE | No |

The active mode is chosen in **Code4D → Settings → AI Assistant (MCP) → Transport**.

> **Note**: Agentic mode is only available with the **Embedded** transport, as it requires direct access to the in-process MCP server.

---

## 3. Agentic Mode

Agentic mode enables the AI to **automatically plan and execute multi-step tasks** without manual tool selection. When enabled, the agent:

1. Receives your natural-language request
2. **Plans** it into discrete steps using the GitHub Models API
3. **Executes** each step by picking the appropriate MCP tool and parameters
4. **Accumulates context** from previous steps via in-memory working memory
5. Returns a consolidated result

### Enabling Agentic Mode

In the AI Assistant dialog (requires **Embedded** transport):

1. Check **Agent mode (multi-step)** in the bottom-left panel
2. Choose an execution mode from the dropdown
3. Type your request and press **F5**

### Execution Modes

| Mode | Description |
|---|---|
| **Single tool** | Direct tool call — no planning, identical to non-agent mode |
| **Multi-step** *(default)* | AI decomposes the task and executes each step in sequence |
| **Autonomous** | Like multi-step, but the agent re-plans and retries on step errors (up to `MaxIterations = 10`) |

### Steps Panel

While the agent runs, the **Steps** memo shows each step live:
```
1/3  Analyze entity THREmployee for missing index annotations
2/3  Generate XData service contract for THREmployee
3/3  Add audit fields (Created, Modified, CreatedBy, ModifiedBy)
```

### Example Agentic Prompts

```
Review the selected entity and generate a complete CRUD XData service with audit logging.
```
```
Refactor this service to use lazy-loaded associations and add XML doc comments.
```

### MCP Compliance

The agent conforms to **MCP specification 2025-11-25**:
- Tool discovery: `tools/list` (JSON-RPC 2.0, supports cursor-based pagination)
- Tool execution: `tools/call` with typed `inputSchema` (JSON Schema draft-07)
- **Agent framework**: `Src/Agent/C4D.Wizard.Agent.Core.pas` — `IC4DWizardAgent` / `TC4DWizardAgent`

---

## 4. Settings Reference

All settings are stored in an INI file next to the installed BPL:
```
<Delphi bin folder>\Code4DWizard\code4d-wizard.ini
```
For a typical Delphi 12 install this resolves to:
```
C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\Code4DWizard\code4d-wizard.ini
```

The `mcp.json` configuration is stored separately at `%APPDATA%\Roaming\Code4D\mcp.json`.

### Common
| Setting | Description |
|---|---|
| Transport | `0` = HTTP, `1` = Stdio, `2` = Embedded |
| Timeout (ms) | Request timeout. Default: 30 000 ms |

### HTTP transport
| Setting | Description |
|---|---|
| Server URL | Full URL, e.g. `http://localhost:8080/mcp` |
| API Key | Bearer token sent in `Authorization` header (optional) |

### Stdio transport
| Setting | Description |
|---|---|
| Command | Executable to launch, e.g. `node`, `python`, `npx` |
| Arguments | Args passed to the executable, e.g. `C:\my-mcp-server\dist\index.js` |
| Working Dir | Working directory for the child process (leave blank for default) |

### Embedded transport (GitHub Models)
| Setting | Description | Default |
|---|---|---|
| GitHub Token | PAT or `${env:GITHUB_TOKEN}` | *(env var)* |
| GitHub Model | Model name | `gpt-4o` |
| GitHub Endpoint | Inference API base URL | `https://models.inference.ai.azure.com` |

---

## 5. mcp.json Configuration

The embedded server is also configurable via `%APPDATA%\Code4D\mcp.json`.  
This file is created with sensible defaults the first time the wizard loads.

```json
{
  "githubModels": {
    "enabled": true,
    "model": "gpt-4o",
    "endpoint": "https://models.inference.ai.azure.com",
    "token": "${env:GITHUB_TOKEN}",
    "maxTokens": 2000,
    "temperature": 0.3
  },
  "mcpServers": {
    "embedded": {
      "command": "embedded",
      "tools": ["analyze_entity", "generate_service", "query_docs", "ask_ai"]
    }
  }
}
```

`${env:VARIABLE}` tokens are resolved at runtime, so secrets never need to be hardcoded.

See [Config/mcp.example.json](../Config/mcp.example.json) for all available options including external HTTP/Stdio servers.

---

## 6. Built-in Tools (Embedded Mode)

Built-in tools implement the MCP `tools/call` interface (JSON-RPC 2.0). Each tool exposes a typed `inputSchema` (JSON Schema draft-07) and returns a `content` array with a `text` block.

### `analyze_entity`
Analyses an Aurelius entity class and suggests improvements: missing `[Column]` mappings, index opportunities, naming conventions, nullable fields, etc.

**Input parameters**
| Name | Required | Description |
|---|---|---|
| `entity_code` | ✓ | The full `TMyEntity = class` source code |
| `context` | | Extra context (e.g. related entities) |

**Example prompt**: *"Review this entity and suggest any missing attributes or mappings."*

---

### `generate_service`
Generates an XData `ServiceContract` interface and a skeleton service implementation for a given entity.

**Input parameters**
| Name | Required | Description |
|---|---|---|
| `entity_name` | ✓ | Entity class name, e.g. `TProduct` |
| `operations` | | Comma-separated operations: `list,get,create,update,delete` |

**Example prompt**: *"Generate a full CRUD service for TProduct."*

---

### `query_docs`
Free-form Delphi / RAD Studio / TMS Aurelius / XData documentation Q&A.

**Input parameters**
| Name | Required | Description |
|---|---|---|
| `question` | ✓ | Your question |
| `context` | | Current file or relevant code snippet |

---

### `ask_ai`
Generic prompt. Optionally supply a code snippet and a custom system prompt to guide the response style.

**Input parameters**
| Name | Required | Description |
|---|---|---|
| `prompt` | ✓ | Your request |
| `code` | | Code context pasted from the editor |
| `system` | | Override the default system prompt |

---

## 7. Skills

Skills are higher-level operations built on top of the basic MCP tools. They are defined as Delphi classes implementing `ISkill` (`Src/Skills/`) and loaded by the agent for complex multi-step tasks.

| Skill unit | Category | Description |
|---|---|---|
| `C4D.Wizard.Skill.CodeAnalysis` | Analysis | Deep entity/service analysis with MES best-practice checks |
| `C4D.Wizard.Skill.Generation` | Generation | Full entity + service + DTOs scaffolding |
| `C4D.Wizard.Skill.Refactoring` | Refactoring | Rename, extract, optimise lazy-loading, add indexes |
| `C4D.Wizard.Skill.Documentation` | Documentation | Generate XML doc comments and Markdown API docs |

Skill configuration files live in `Config/skills/` (JSON format) and describe input/output contracts, examples, and which instruction files to load.

Custom skills can be registered at runtime via `TSkillRegistry.RegisterSkill()`.

---

## 8. Instructions System

Instructions are **Markdown files** that inject domain context into the AI system prompt. Loaded at startup from `Config/instructions/` by `TC4DWizardInstructionsManager`.

| File | Purpose |
|---|---|
| `base.md` | Core code generation rules, Delphi conventions, error handling |
| `delphi-expert.md` | Inline vars, anonymous methods, modern Delphi patterns |
| `mes-architecture.md` | MES architecture, entity patterns, module naming |
| `emistr.md` | eMISTR-specific manufacturing execution system patterns |

You can **add your own** `.md` files — they are loaded automatically on the next IDE start. Reference them from a skill JSON: `"instructions": ["base", "my-project"]`.

---

## 9. HTTP Transport

Use this when you have an existing MCP-compatible server running (e.g. a Node.js or Python MCP server).

```
Server URL : http://localhost:8080/mcp
API Key    : sk-...   (leave blank if not required)
Timeout    : 30000
```

The client sends JSON-RPC 2.0 requests to `POST {ServerURL}` with `Content-Type: application/json`.

---

## 10. Stdio Transport

Use this to launch any MCP server as a child process.  
Example — a Node.js server:

```
Command     : node
Arguments   : C:\my-mcp-server\dist\index.js --stdio
Working Dir : C:\my-mcp-server
```

The wizard manages the process lifecycle: **Start Server** / **Stop Server** buttons appear automatically in this mode.

---

## 11. GitHub Token Setup

### Option A — Environment variable (recommended)
Set `GITHUB_TOKEN` in your system environment variables.  
The wizard reads it automatically; no token needs to be stored in settings.

```powershell
# PowerShell (permanent, current user)
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', 'ghp_yourtoken', 'User')
```

### Option B — Paste into Settings
Paste the token directly into **Code4D → Settings → AI Assistant → GitHub Token**.  
It is stored in the INI file under `%APPDATA%\Code4D\`.

### Creating a GitHub PAT
1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Click **Generate new token (classic)**
3. Select scopes: `models:read` (under *GitHub Models*, if visible) — or use a fine-grained token with *Models: Read* permission
4. Copy the token immediately

### Available Models
| Model ID | Note |
|---|---|
| `gpt-4o` | Default — best quality |
| `gpt-4o-mini` | Faster, lower cost |
| `o1-mini` | Reasoning model |
| `Phi-3.5-mini-instruct` | Small / fast |
| `Meta-Llama-3.1-70B-Instruct` | Open-weight |

Full list at [github.com/marketplace/models](https://github.com/marketplace/models).

---

## 12. Keyboard Shortcuts

Default shortcuts can be customised in **Code4D → Settings → AI Assistant**.

| Action | Default shortcut |
|---|---|
| Open AI Assistant | `Ctrl+Alt+A` |
| Send prompt (inside dialog) | `F5` |
| Close dialog | `Escape` |
| Get current editor context | *"Get Context" button* |
