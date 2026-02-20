# AI Assistant (MCP) — Setup & Usage Guide

The AI Assistant integrates a **Model Context Protocol (MCP)** client directly into the Delphi IDE toolbar/menu. It lets you browse available AI tools, send prompts with optional code context, and receive generated code — all without leaving the IDE.

## Contents

1. [Quick Start — Embedded Mode](#1-quick-start--embedded-mode)
2. [Transport Modes](#2-transport-modes)
3. [Settings Reference](#3-settings-reference)
4. [mcp.json Configuration](#4-mcpjson-configuration)
5. [Built-in Tools (Embedded Mode)](#5-built-in-tools-embedded-mode)
6. [HTTP Transport](#6-http-transport)
7. [Stdio Transport](#7-stdio-transport)
8. [GitHub Token Setup](#8-github-token-setup)
9. [Keyboard Shortcuts](#9-keyboard-shortcuts)

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

The tool list on the left will populate with the four built-in tools. Select a tool, type a prompt, and press **F5** (or click **Send**).

---

## 2. Transport Modes

| Mode | Description | External process? |
|---|---|---|
| **HTTP** | Connects to an already-running MCP server via HTTP | No |
| **Stdio** | Launches an external executable as an MCP server child process | Yes |
| **Embedded** | Runs the MCP server fully in-process inside the IDE | No |

The active mode is chosen in **Code4D → Settings → AI Assistant (MCP) → Transport**.

---

## 3. Settings Reference

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

## 4. mcp.json Configuration

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

## 5. Built-in Tools (Embedded Mode)

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
Free-form Delphi / RAD Studio / Aurelius / XData documentation Q&A.

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

## 6. HTTP Transport

Use this when you have an existing MCP-compatible server running (e.g. a Node.js or Python MCP server).

```
Server URL : http://localhost:8080/mcp
API Key    : sk-...   (leave blank if not required)
Timeout    : 30000
```

The client sends JSON-RPC 2.0 requests to `POST {ServerURL}` with `Content-Type: application/json`.

---

## 7. Stdio Transport

Use this to launch any MCP server as a child process.  
Example — a Node.js server:

```
Command     : node
Arguments   : C:\my-mcp-server\dist\index.js --stdio
Working Dir : C:\my-mcp-server
```

The wizard manages the process lifecycle: **Start Server** / **Stop Server** buttons appear automatically in this mode.

---

## 8. GitHub Token Setup

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

## 9. Keyboard Shortcuts

Default shortcuts can be customised in **Code4D → Settings → AI Assistant**.

| Action | Default shortcut |
|---|---|
| Open AI Assistant | `Ctrl+Alt+A` |
| Send prompt (inside dialog) | `F5` |
| Close dialog | `Escape` |
| Get current editor context | *"Get Context" button* |
