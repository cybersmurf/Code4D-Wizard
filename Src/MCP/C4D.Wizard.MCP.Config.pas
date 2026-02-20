unit C4D.Wizard.MCP.Config;

{
  MCP Configuration Loader for Code4D Wizard
  ============================================
  Reads mcp.json from %APPDATA%\Code4D\mcp.json (or a custom path).
  Falls back to the installed copy in <plugin-dir>\Config\mcp.json.
  Creates a default file on first run if none exists.

  Format matches the VS Code / Claude Desktop pattern:
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
      "mes-architecture": {
        "command": "embedded",
        "tools": ["analyze_entity", "generate_service", "query_docs"]
      }
    }
  }
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.IOUtils,
  C4D.Wizard.AI.GitHub;

type
  // -----------------------------------------------------------------------
  // Aggregate config returned from Load()
  // -----------------------------------------------------------------------
  TC4DWizardMCPConfig = record
    // GitHub Models
    GitHubEnabled     : Boolean;
    GitHubToken       : string;
    GitHubModel       : string;
    GitHubEndpoint    : string;
    GitHubMaxTokens   : Integer;
    GitHubTemperature : Double;

    // Resolved config path (for diagnostics)
    ConfigPath : string;

    function ToGitHubConfig: TC4DGitHubModelsConfig;
    class function Load(const AConfigPath: string = ''): TC4DWizardMCPConfig; static;
    class function DefaultConfigPath: string; static;
    class procedure CreateDefaultFile(const APath: string); static;
  end;

implementation

const
  C_CONFIG_FILENAME = 'mcp.json';
  C_APPDATA_FOLDER  = 'Code4D';

{ TC4DWizardMCPConfig }

class function TC4DWizardMCPConfig.DefaultConfigPath: string;
begin
  Result := TPath.Combine(
    TPath.Combine(
      TPath.GetHomePath,
      'AppData' + PathDelim + 'Roaming' + PathDelim + C_APPDATA_FOLDER),
    C_CONFIG_FILENAME);
end;

class procedure TC4DWizardMCPConfig.CreateDefaultFile(const APath: string);
const
  CJSON =
    '{' + #13#10 +
    '  "githubModels": {' + #13#10 +
    '    "enabled": true,' + #13#10 +
    '    "model": "gpt-4o",' + #13#10 +
    '    "endpoint": "https://models.inference.ai.azure.com",' + #13#10 +
    '    "token": "${env:GITHUB_TOKEN}",' + #13#10 +
    '    "maxTokens": 2000,' + #13#10 +
    '    "temperature": 0.3' + #13#10 +
    '  },' + #13#10 +
    '  "mcpServers": {' + #13#10 +
    '    "embedded": {' + #13#10 +
    '      "command": "embedded",' + #13#10 +
    '      "description": "Built-in tools for Delphi / MES / eMISTR",' + #13#10 +
    '      "tools": ["analyze_entity", "generate_service", "query_docs", "ask_ai"]' + #13#10 +
    '    }' + #13#10 +
    '  }' + #13#10 +
    '}';
begin
  ForceDirectories(ExtractFilePath(APath));
  TFile.WriteAllText(APath, CJSON, TEncoding.UTF8);
end;

class function TC4DWizardMCPConfig.Load(
  const AConfigPath: string): TC4DWizardMCPConfig;
var
  LPath    : string;
  LJSON    : TJSONObject;
  LGH      : TJSONObject;
  LRaw     : string;
  LEnvName : string;
begin
  // Defaults
  Result.GitHubEnabled     := True;
  Result.GitHubToken       := '';
  Result.GitHubModel       := 'gpt-4o';
  Result.GitHubEndpoint    := 'https://models.inference.ai.azure.com';
  Result.GitHubMaxTokens   := 2000;
  Result.GitHubTemperature := 0.3;

  // Resolve path
  if not AConfigPath.IsEmpty then
    LPath := AConfigPath
  else
    LPath := DefaultConfigPath;
  Result.ConfigPath := LPath;

  // Create default if missing
  if not TFile.Exists(LPath) then
    CreateDefaultFile(LPath);

  // Parse
  try
    LJSON := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(LPath, TEncoding.UTF8)) as TJSONObject;
    if not Assigned(LJSON) then Exit;
    try
      LGH := LJSON.GetValue<TJSONObject>('githubModels', nil);
      if not Assigned(LGH) then Exit;

      Result.GitHubEnabled  := LGH.GetValue<Boolean>('enabled', True);
      Result.GitHubModel    := LGH.GetValue<string>('model', Result.GitHubModel);
      Result.GitHubEndpoint := LGH.GetValue<string>('endpoint', Result.GitHubEndpoint);
      Result.GitHubMaxTokens   := LGH.GetValue<Integer>('maxTokens', Result.GitHubMaxTokens);
      Result.GitHubTemperature := LGH.GetValue<Double>('temperature', Result.GitHubTemperature);

      // Resolve token – support ${env:VAR} pattern
      LRaw := LGH.GetValue<string>('token', '');
      if LRaw.StartsWith('${env:', True) and LRaw.EndsWith('}') then
      begin
        LEnvName := LRaw.Substring(6, LRaw.Length - 7);
        Result.GitHubToken := GetEnvironmentVariable(LEnvName);
      end
      else
        Result.GitHubToken := LRaw;
    finally
      LJSON.Free;
    end;
  except
    // Swallow parse errors – caller will get defaults
  end;
end;

function TC4DWizardMCPConfig.ToGitHubConfig: TC4DGitHubModelsConfig;
begin
  Result.Token       := GitHubToken;
  Result.Model       := GitHubModel;
  Result.Endpoint    := GitHubEndpoint;
  Result.MaxTokens   := GitHubMaxTokens;
  Result.Temperature := GitHubTemperature;
end;

end.
