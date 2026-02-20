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
  System.Generics.Collections,
  C4D.Wizard.AI.GitHub;

type
  // -----------------------------------------------------------------------
  // External MCP server entry from "mcpServers" in mcp.json (non-embedded)
  // -----------------------------------------------------------------------
  TExternalMCPServerConfig = record
    Name      : string;
    Command   : string;           // executable path (stdio) or base URL (http)
    Args      : string;           // command-line arguments, space-separated
    WorkingDir: string;
    Transport : string;           // 'stdio' (default) | 'http'
    Env       : TArray<TPair<string, string>>;
    Tools     : TArray<string>;   // declared tool names (informational)
    Enabled   : Boolean;
  end;

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

    // External stdio/http servers from "mcpServers" (non-embedded entries)
    ExternalServers: TArray<TExternalMCPServerConfig>;

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

      // Parse external servers (skip entries with command = "embedded")
      var LServersObj := LJSON.GetValue<TJSONObject>('mcpServers', nil);
      if Assigned(LServersObj) then
        for var LP in LServersObj do
        begin
          var LSrv := LP.JsonValue as TJSONObject;
          if not (LSrv is TJSONObject) then Continue;
          if LSrv.GetValue<string>('command', '').ToLower = 'embedded' then Continue;

          var LExtSrv: TExternalMCPServerConfig;
          LExtSrv.Name       := LP.JsonString.Value;
          LExtSrv.Command    := LSrv.GetValue<string>('command', '');
          LExtSrv.WorkingDir := LSrv.GetValue<string>('workingDir', '');
          LExtSrv.Transport  := LSrv.GetValue<string>('transport', 'stdio');
          LExtSrv.Enabled    := LSrv.GetValue<Boolean>('enabled', True);

          // args — accept both a plain string and a JSON array
          var LArgVal := LSrv.GetValue('args');
          if LArgVal is TJSONString then
            LExtSrv.Args := TJSONString(LArgVal).Value
          else if LArgVal is TJSONArray then
          begin
            var LArgParts := TStringList.Create;
            try
              for var AJ := 0 to TJSONArray(LArgVal).Count - 1 do
              begin
                var LArgItem := TJSONArray(LArgVal).Items[AJ].Value;
                if LArgItem.Contains(' ') then
                  LArgParts.Add('"' + LArgItem + '"')
                else
                  LArgParts.Add(LArgItem);
              end;
              LExtSrv.Args := string.Join(' ', LArgParts.ToStringArray);
            finally
              LArgParts.Free;
            end;
          end
          else
            LExtSrv.Args := '';

          // env — resolve ${env:VAR} tokens
          var LEnvObj := LSrv.GetValue<TJSONObject>('env', nil);
          LExtSrv.Env := [];
          if Assigned(LEnvObj) then
            for var EP in LEnvObj do
            begin
              var LVal := EP.JsonValue.Value;
              if LVal.StartsWith('${env:', True) and LVal.EndsWith('}') then
                LVal := GetEnvironmentVariable(LVal.Substring(6, LVal.Length - 7));
              LExtSrv.Env := LExtSrv.Env +
                [TPair<string, string>.Create(EP.JsonString.Value, LVal)];
            end;

          // tools array (informational — used by registry build only)
          var LToolsArr := LSrv.GetValue<TJSONArray>('tools', nil);
          LExtSrv.Tools := [];
          if Assigned(LToolsArr) then
            for var TJ := 0 to LToolsArr.Count - 1 do
              LExtSrv.Tools := LExtSrv.Tools + [LToolsArr.Items[TJ].Value];

          Result.ExternalServers := Result.ExternalServers + [LExtSrv];
        end;
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
