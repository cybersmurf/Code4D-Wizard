unit C4D.Wizard.MCP.ServerRegistry;

{
  MCP Server Registry for Code4D Wizard
  ======================================
  Aggregates multiple IC4DWizardMCPClient instances — one "primary" client
  (embedded / HTTP / single stdio from IDE Settings) plus any number of
  external stdio/http servers declared in mcp.json's "mcpServers" section —
  into a single, unified tool-dispatch surface.

  Key guarantees
  • Tool discovery (ListAllTools) merges all servers; secondary-server tools
    are prefixed "[server-name] " in their description so the UI shows origin.
  • Tool dispatch (CallTool) routes each call to the server that originally
    advertised the tool, using a name→client dictionary built during
    ListAllTools.  Falls back to the primary client for unknown names.
  • External servers are started lazily (on first ListAllTools / CallTool).
  • If an external server fails to start or errors during tool discovery,
    the error is recorded in LastError and the remaining servers continue.

  Env-var injection
  Before each external stdio process is spawned, its declared env vars
  (from "env" in mcp.json) are applied to the parent IDE process via
  SetEnvironmentVariable.  The child inherits them automatically, which is
  the simplest approach and is safe for non-conflicting keys such as
  CHROMA_HOST or OLLAMA_HOST.

  Usage
    var LRegistry := TC4DWizardMCPServerRegistry.New(
      TC4DWizardMCPConfig.Load, FMCPClient);
    LTools  := LRegistry.ListAllTools;           // merged from all servers
    LResult := LRegistry.CallTool(name, args);   // dispatched to correct server
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  Winapi.Windows,
  C4D.Wizard.MCP.Client,
  C4D.Wizard.MCP.Config;

type
  // -------------------------------------------------------------------------
  // Registry interface
  // -------------------------------------------------------------------------
  IC4DWizardMCPServerRegistry = interface
    ['{F2A3B4C5-D6E7-8901-BCDE-F12345678902}']
    /// <summary>Merge and return tools from all registered servers.
    /// Rebuilds the internal tool→client dispatch map as a side-effect.</summary>
    function ListAllTools: TC4DWizardMCPToolList;

    /// <summary>Dispatch a tool call to whichever server owns the tool.
    /// Falls back to the primary client if the tool name is not mapped.</summary>
    function CallTool(const AToolName: string;
      AArguments: TJSONObject): TC4DWizardMCPCallResult;

    /// <summary>True when the primary client is connected (embedded is always ready).</summary>
    function IsReady: Boolean;

    /// <summary>Total number of registered clients (primary + external).</summary>
    function ServerCount: Integer;

    /// <summary>Accumulated errors from the most recent ListAllTools call.</summary>
    function LastError: string;

    /// <summary>Human-readable summary line suitable for a status bar.</summary>
    function StatusText: string;
  end;

  // -------------------------------------------------------------------------
  // Concrete registry
  // -------------------------------------------------------------------------
  TC4DWizardMCPServerRegistry = class(TInterfacedObject, IC4DWizardMCPServerRegistry)
  private
    FClients    : TList<IC4DWizardMCPClient>;
    FServerNames: TList<string>;
    FToolMap    : TDictionary<string, IC4DWizardMCPClient>;
    FLastError  : string;

    procedure AddClient(const AName: string; const AClient: IC4DWizardMCPClient);
  protected
    function ListAllTools: TC4DWizardMCPToolList;
    function CallTool(const AToolName: string;
      AArguments: TJSONObject): TC4DWizardMCPCallResult;
    function IsReady: Boolean;
    function ServerCount: Integer;
    function LastError: string;
    function StatusText: string;
  public
    /// <summary>
    /// Builds a registry from a loaded config and a pre-created primary client.
    /// APrimaryClient may be embedded, HTTP or stdio — it becomes "server 0".
    /// External servers declared in AConfig.ExternalServers are added on top.
    /// </summary>
    constructor Create(const AConfig: TC4DWizardMCPConfig;
      const APrimaryClient: IC4DWizardMCPClient);
    destructor Destroy; override;
    class function New(const AConfig: TC4DWizardMCPConfig;
      const APrimaryClient: IC4DWizardMCPClient): IC4DWizardMCPServerRegistry;
  end;

implementation

{ TC4DWizardMCPServerRegistry }

class function TC4DWizardMCPServerRegistry.New(
  const AConfig: TC4DWizardMCPConfig;
  const APrimaryClient: IC4DWizardMCPClient): IC4DWizardMCPServerRegistry;
begin
  Result := TC4DWizardMCPServerRegistry.Create(AConfig, APrimaryClient);
end;

constructor TC4DWizardMCPServerRegistry.Create(
  const AConfig: TC4DWizardMCPConfig;
  const APrimaryClient: IC4DWizardMCPClient);
var
  LServer : TExternalMCPServerConfig;
  LClient : IC4DWizardMCPClient;
  LPair   : TPair<string, string>;
begin
  FClients     := TList<IC4DWizardMCPClient>.Create;
  FServerNames := TList<string>.Create;
  FToolMap     := TDictionary<string, IC4DWizardMCPClient>.Create;

  // Slot 0: primary client (embedded / HTTP / single stdio from IDE settings)
  if Assigned(APrimaryClient) then
    AddClient('delphi_assistant', APrimaryClient);

  // Remaining slots: external servers from mcp.json "mcpServers" section
  for LServer in AConfig.ExternalServers do
  begin
    if not LServer.Enabled then
      Continue;
    try
      if LServer.Transport = 'http' then
      begin
        // HTTP: Command holds the base URL
        LClient := TC4DWizardMCPClient.NewHTTP(LServer.Command);
      end
      else
      begin
        // Stdio: inject env vars so the child process inherits them
        for LPair in LServer.Env do
          SetEnvironmentVariable(PChar(LPair.Key), PChar(LPair.Value));

        LClient := TC4DWizardMCPClient.NewStdio(
          LServer.Command, LServer.Args, LServer.WorkingDir);
      end;
      AddClient(LServer.Name, LClient);
    except
      on E: Exception do
        FLastError := FLastError +
          Format('  [%s] create error: %s'#13#10, [LServer.Name, E.Message]);
    end;
  end;
end;

destructor TC4DWizardMCPServerRegistry.Destroy;
begin
  FToolMap.Free;
  FServerNames.Free;
  FClients.Free;   // interface list — each ref-counted client is released here
  inherited;
end;

procedure TC4DWizardMCPServerRegistry.AddClient(
  const AName: string; const AClient: IC4DWizardMCPClient);
begin
  FClients.Add(AClient);
  FServerNames.Add(AName);
end;

{ --- interface impl --- }

function TC4DWizardMCPServerRegistry.ListAllTools: TC4DWizardMCPToolList;
var
  I        : Integer;
  LTools   : TC4DWizardMCPToolList;
  LTool    : TC4DWizardMCPTool;
  LSrvName : string;
begin
  Result := [];
  FToolMap.Clear;
  FLastError := '';

  for I := 0 to FClients.Count - 1 do
  begin
    LSrvName := FServerNames[I];
    try
      LTools := FClients[I].ListTools;
      for LTool in LTools do
      begin
        // Prefix description with server name for secondary (external) servers
        if I > 0 then
          LTool.Description := '[' + LSrvName + '] ' + LTool.Description;

        FToolMap.AddOrSetValue(LTool.Name, FClients[I]);
        Result := Result + [LTool];
      end;
    except
      on E: Exception do
        FLastError := FLastError +
          Format('  [%s]: %s'#13#10, [LSrvName, E.Message]);
    end;
  end;
end;

function TC4DWizardMCPServerRegistry.CallTool(
  const AToolName: string;
  AArguments: TJSONObject): TC4DWizardMCPCallResult;
var
  LClient: IC4DWizardMCPClient;
begin
  // Route to the server that owns this tool (populated by the last ListAllTools)
  if FToolMap.TryGetValue(AToolName, LClient) then
  begin
    Result := LClient.CallTool(AToolName, AArguments);
    Exit;
  end;

  // Fallback: primary client (slot 0)
  if FClients.Count > 0 then
  begin
    Result := FClients[0].CallTool(AToolName, AArguments);
    Exit;
  end;

  Result.IsError := True;
  Result.Content := 'No MCP server available for tool: ' + AToolName;
  Result.RawJSON := '';
end;

function TC4DWizardMCPServerRegistry.IsReady: Boolean;
begin
  Result := (FClients.Count > 0) and FClients[0].IsConnected;
end;

function TC4DWizardMCPServerRegistry.ServerCount: Integer;
begin
  Result := FClients.Count;
end;

function TC4DWizardMCPServerRegistry.LastError: string;
begin
  Result := FLastError;
end;

function TC4DWizardMCPServerRegistry.StatusText: string;
begin
  if FClients.Count = 0 then
    Result := 'No servers configured'
  else
  begin
    Result := Format('%d server(s) active', [FClients.Count]);
    if not FLastError.IsEmpty then
      Result := Result + ' | Errors: ' + FLastError.Trim;
  end;
end;

end.
