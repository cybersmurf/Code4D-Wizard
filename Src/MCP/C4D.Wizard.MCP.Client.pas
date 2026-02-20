unit C4D.Wizard.MCP.Client;

{
  MCP (Model Context Protocol) Client for Code4D Wizard
  =======================================================
  Supports two transports:

  HTTP  — connects to an already-running MCP server at a URL.
  Stdio — spawns the server as a child process and communicates via
          stdin/stdout pipes, exactly like Claude Desktop, GitHub Copilot
          and VS Code.  The server starts automatically on the first
          call and stops when the client is destroyed.

  JSON-RPC 2.0;  implements: initialize, tools/list, tools/call.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  C4D.Wizard.MCP.StdioTransport,
  C4D.Wizard.MCP.EmbeddedServer;

type
  // ------------------------------------------------------------------
  // Transport selector
  // ------------------------------------------------------------------
  TMCPTransportType = (
    mttHTTP,      // connect to http(s):// URL
    mttStdio,     // spawn process and use stdin/stdout pipes
    mttEmbedded   // built-in server running in-process (no external process)
  );

  // ------------------------------------------------------------------
  // Shared types
  // ------------------------------------------------------------------
  TC4DWizardMCPTool = record
    Name: string;
    Description: string;
    InputSchema: TJSONObject;
  end;

  TC4DWizardMCPToolList = TArray<TC4DWizardMCPTool>;

  TC4DWizardMCPCallResult = record
    Content: string;
    IsError: Boolean;
    RawJSON: string;
  end;

  // ------------------------------------------------------------------
  // Client interface
  // ------------------------------------------------------------------
  IC4DWizardMCPClient = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    // Common
    function Timeout: Integer; overload;
    function Timeout(AValue: Integer): IC4DWizardMCPClient; overload;
    function Initialize: Boolean;
    function IsConnected: Boolean;
    function ListTools: TC4DWizardMCPToolList;
    function CallTool(const AToolName: string; AArguments: TJSONObject): TC4DWizardMCPCallResult;
    function LastError: string;
    function TransportType: TMCPTransportType;
    // HTTP transport
    function ServerURL: string; overload;
    function ServerURL(const AValue: string): IC4DWizardMCPClient; overload;
    // Stdio transport
    function IsServerRunning: Boolean;
    function StartServer: Boolean;
    procedure StopServer;
    function ServerPID: Integer;
  end;

  // ------------------------------------------------------------------
  // Concrete client
  // ------------------------------------------------------------------
  TC4DWizardMCPClient = class(TInterfacedObject, IC4DWizardMCPClient)
  private
    FTransportType: TMCPTransportType;
    FTimeout: Integer;
    FConnected: Boolean;
    FLastError: string;
    FRequestID: Integer;
    // HTTP
    FServerURL: string;
    FHttpClient: THTTPClient;
    // Stdio
    FStdioTransport: TC4DWizardMCPStdioTransport;
    // Embedded
    FEmbeddedServer: IC4DWizardMCPEmbeddedServer;
    // internals
    function NextID: Integer;
    function BuildRequest(const AMethod: string; AParams: TJSONValue = nil): string;
    function DispatchRequest(const ABody: string): TJSONObject;
    function SendHTTP(const ABody: string): TJSONObject;
    function SendStdio(const ABody: string): TJSONObject;
    function ExtractTextContent(AResult: TJSONValue): string;
  protected
    function Timeout: Integer; overload;
    function Timeout(AValue: Integer): IC4DWizardMCPClient; overload;
    function Initialize: Boolean;
    function IsConnected: Boolean;
    function ListTools: TC4DWizardMCPToolList;
    function CallTool(const AToolName: string; AArguments: TJSONObject): TC4DWizardMCPCallResult;
    function LastError: string;
    function TransportType: TMCPTransportType;
    function ServerURL: string; overload;
    function ServerURL(const AValue: string): IC4DWizardMCPClient; overload;
    function IsServerRunning: Boolean;
    function StartServer: Boolean;
    procedure StopServer;
    function ServerPID: Integer;
  public
    class function New(const AServerURL: string = 'http://localhost:8080/mcp'): IC4DWizardMCPClient;
    class function NewHTTP(const AServerURL: string = 'http://localhost:8080/mcp'): IC4DWizardMCPClient;
    class function NewStdio(const ACommand, AArguments: string;
      const AWorkingDir: string = ''): IC4DWizardMCPClient;
    class function NewEmbedded(const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPClient;
    constructor CreateHTTP(const AServerURL: string);
    constructor CreateStdio(const ACommand, AArguments, AWorkingDir: string);
    constructor CreateEmbedded(const AConfig: TC4DGitHubModelsConfig);
    destructor Destroy; override;
  end;

implementation

{ ---- Factory ---- }

class function TC4DWizardMCPClient.New(const AServerURL: string): IC4DWizardMCPClient;
begin
  Result := NewHTTP(AServerURL);
end;

class function TC4DWizardMCPClient.NewHTTP(const AServerURL: string): IC4DWizardMCPClient;
begin
  Result := TC4DWizardMCPClient.CreateHTTP(AServerURL);
end;

class function TC4DWizardMCPClient.NewStdio(const ACommand, AArguments,
  AWorkingDir: string): IC4DWizardMCPClient;
begin
  Result := TC4DWizardMCPClient.CreateStdio(ACommand, AArguments, AWorkingDir);
end;

class function TC4DWizardMCPClient.NewEmbedded(
  const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPClient;
begin
  Result := TC4DWizardMCPClient.CreateEmbedded(AConfig);
end;

{ ---- Construction ---- }

constructor TC4DWizardMCPClient.CreateHTTP(const AServerURL: string);
begin
  FTransportType := mttHTTP;
  FServerURL := AServerURL;
  FTimeout := 30000;
  FConnected := False;
  FRequestID := 0;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ContentType := 'application/json';
  FHttpClient.Accept := 'application/json';
end;

constructor TC4DWizardMCPClient.CreateStdio(const ACommand, AArguments,
  AWorkingDir: string);
begin
  FTransportType := mttStdio;
  FTimeout := 30000;
  FConnected := False;
  FRequestID := 0;
  FStdioTransport := TC4DWizardMCPStdioTransport.Create(
    ACommand, AArguments, AWorkingDir, FTimeout);
end;

constructor TC4DWizardMCPClient.CreateEmbedded(
  const AConfig: TC4DGitHubModelsConfig);
begin
  FTransportType   := mttEmbedded;
  FTimeout         := 30000;
  FConnected       := True;  // always "connected" – in-process
  FRequestID       := 0;
  FEmbeddedServer  := TC4DWizardMCPEmbeddedServer.New(AConfig);
end;

destructor TC4DWizardMCPClient.Destroy;
begin
  FHttpClient.Free;
  FStdioTransport.Free; // also terminates the child process
  FEmbeddedServer := nil; // interface, releases ref
  inherited;
end;

{ ---- Internals ---- }

function TC4DWizardMCPClient.NextID: Integer;
begin
  Inc(FRequestID);
  Result := FRequestID;
end;

function TC4DWizardMCPClient.BuildRequest(const AMethod: string;
  AParams: TJSONValue): string;
var
  LReq: TJSONObject;
begin
  LReq := TJSONObject.Create;
  try
    LReq.AddPair('jsonrpc', '2.0');
    LReq.AddPair('id', TJSONNumber.Create(NextID));
    LReq.AddPair('method', AMethod);
    if Assigned(AParams) then
      LReq.AddPair('params', AParams.Clone as TJSONValue)
    else
      LReq.AddPair('params', TJSONObject.Create);
    Result := LReq.ToJSON;
  finally
    LReq.Free;
  end;
end;

function TC4DWizardMCPClient.SendHTTP(const ABody: string): TJSONObject;
var
  LStream: TStringStream;
  LResp: IHTTPResponse;
  LBody: string;
  LParsed: TJSONValue;
begin
  Result := nil;
  FLastError := '';
  LStream := TStringStream.Create(ABody, TEncoding.UTF8);
  try
    try
      FHttpClient.ConnectionTimeout := FTimeout;
      FHttpClient.ResponseTimeout := FTimeout;
      LResp := FHttpClient.Post(FServerURL, LStream, nil,
        [TNameValuePair.Create('Content-Type', 'application/json'),
         TNameValuePair.Create('Accept', 'application/json')]);
      LBody := LResp.ContentAsString(TEncoding.UTF8);
      if LResp.StatusCode <> 200 then
      begin
        FLastError := Format('HTTP %d: %s', [LResp.StatusCode, LBody]);
        Exit;
      end;
      LParsed := TJSONObject.ParseJSONValue(LBody);
      if LParsed is TJSONObject then
        Result := LParsed as TJSONObject
      else
      begin
        FreeAndNil(LParsed);
        FLastError := 'Invalid JSON response: ' + LBody;
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := nil;
      end;
    end;
  finally
    LStream.Free;
  end;
end;

function TC4DWizardMCPClient.SendStdio(const ABody: string): TJSONObject;
var
  LRaw: string;
  LParsed: TJSONValue;
begin
  Result := nil;
  FLastError := '';
  try
    LRaw := FStdioTransport.SendAndReceive(ABody);
    if LRaw.IsEmpty then
    begin
      FLastError := FStdioTransport.LastError;
      if not FStdioTransport.IsRunning then
        FConnected := False;
      Exit;
    end;
    LParsed := TJSONObject.ParseJSONValue(LRaw);
    if LParsed is TJSONObject then
      Result := LParsed as TJSONObject
    else
    begin
      FreeAndNil(LParsed);
      FLastError := 'Invalid JSON from server process: ' + LRaw;
    end;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := nil;
    end;
  end;
end;

function TC4DWizardMCPClient.DispatchRequest(const ABody: string): TJSONObject;
begin
  case FTransportType of
    mttHTTP:  Result := SendHTTP(ABody);
    mttStdio: Result := SendStdio(ABody);
  else
    Result := nil;
  end;
end;

function TC4DWizardMCPClient.ExtractTextContent(AResult: TJSONValue): string;
var
  LArr: TJSONArray;
  LItem: TJSONObject;
  LParts: TStringList;
  I: Integer;
begin
  Result := '';
  if not Assigned(AResult) then Exit;
  if AResult is TJSONObject then
    LArr := TJSONObject(AResult).GetValue<TJSONArray>('content', nil)
  else if AResult is TJSONArray then
    LArr := TJSONArray(AResult)
  else
    Exit;
  if not Assigned(LArr) then
  begin
    if AResult is TJSONObject then
      Result := TJSONObject(AResult).GetValue<string>('text', AResult.ToString);
    Exit;
  end;
  LParts := TStringList.Create;
  try
    for I := 0 to LArr.Count - 1 do
    begin
      LItem := LArr.Items[I] as TJSONObject;
      if LItem.GetValue<string>('type', '') = 'text' then
        LParts.Add(LItem.GetValue<string>('text', ''));
    end;
    Result := LParts.Text.TrimRight;
  finally
    LParts.Free;
  end;
end;

{ ---- Interface implementation ---- }

function TC4DWizardMCPClient.TransportType: TMCPTransportType;
begin
  Result := FTransportType;
end;

function TC4DWizardMCPClient.ServerURL: string;
begin
  Result := FServerURL;
end;

function TC4DWizardMCPClient.ServerURL(const AValue: string): IC4DWizardMCPClient;
begin
  Result := Self;
  FServerURL := AValue;
  FConnected := False;
end;

function TC4DWizardMCPClient.Timeout: Integer;
begin
  Result := FTimeout;
end;

function TC4DWizardMCPClient.Timeout(AValue: Integer): IC4DWizardMCPClient;
begin
  Result := Self;
  FTimeout := AValue;
  if Assigned(FStdioTransport) then
    FStdioTransport.TimeoutMs := AValue;
  if Assigned(FHttpClient) then
  begin
    FHttpClient.ConnectionTimeout := AValue;
    FHttpClient.ResponseTimeout := AValue;
  end;
end;

function TC4DWizardMCPClient.LastError: string;
begin
  Result := FLastError;
end;

function TC4DWizardMCPClient.IsConnected: Boolean;
begin
  case FTransportType of
    mttStdio    : Result := FConnected and Assigned(FStdioTransport) and FStdioTransport.IsRunning;
    mttEmbedded : Result := True;  // always available
  else
    Result := FConnected;
  end;
end;

function TC4DWizardMCPClient.IsServerRunning: Boolean;
begin
  case FTransportType of
    mttStdio    : Result := Assigned(FStdioTransport) and FStdioTransport.IsRunning;
    mttEmbedded : Result := True;
    mttHTTP     : Result := FConnected;
  else
    Result := False;
  end;
end;

function TC4DWizardMCPClient.StartServer: Boolean;
begin
  Result := False;
  if FTransportType = mttEmbedded then
  begin
    Result := True;  // always running
    Exit;
  end;
  if FTransportType <> mttStdio then Exit;
  try
    FStdioTransport.Start;
    Result := FStdioTransport.IsRunning;
    if not Result then
      FLastError := FStdioTransport.LastError;
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      Result := False;
    end;
  end;
end;

procedure TC4DWizardMCPClient.StopServer;
begin
  if FTransportType = mttStdio then
  begin
    FStdioTransport.Shutdown;
    FConnected := False;
  end;
  // Embedded: no-op – server always alive while client exists
end;

procedure TC4DWizardMCPClient.UpdateEmbeddedConfig(
  const AConfig: TC4DGitHubModelsConfig);
begin
  if (FTransportType = mttEmbedded) and Assigned(FEmbeddedServer) then
    FEmbeddedServer.UpdateGitHubConfig(AConfig);
end;

function TC4DWizardMCPClient.ServerPID: Integer;
begin
  if (FTransportType = mttStdio) and Assigned(FStdioTransport) then
    Result := FStdioTransport.ProcessID
  else
    Result := 0;
end;

{ ---- Initialize ---- }

function TC4DWizardMCPClient.Initialize: Boolean;
var
  LParams, LClientInfo, LCaps: TJSONObject;
  LResponse: TJSONObject;
begin
  // Embedded transport is always initialised
  if FTransportType = mttEmbedded then
  begin
    FConnected := True;
    Result := True;
    Exit;
  end;

  Result := False;
  FConnected := False;
  // For stdio: ensure the process is alive before sending
  if (FTransportType = mttStdio) and not FStdioTransport.IsRunning then
  begin
    try
      FStdioTransport.Start;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Exit;
      end;
    end;
  end;
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('protocolVersion', '2024-11-05');
    LClientInfo := TJSONObject.Create;
    LClientInfo.AddPair('name', 'Code4D-Wizard');
    LClientInfo.AddPair('version', '1.0.0');
    LParams.AddPair('clientInfo', LClientInfo);
    LCaps := TJSONObject.Create;
    LParams.AddPair('capabilities', LCaps);
    LResponse := DispatchRequest(BuildRequest('initialize', LParams));
    try
      if not Assigned(LResponse) then Exit;
      if LResponse.GetValue('error') <> nil then
      begin
        FLastError := LResponse.GetValue<string>('error.message', 'initialize failed');
        Exit;
      end;
      FConnected := True;
      Result := True;
    finally
      LResponse.Free;
    end;
  finally
    LParams.Free;
  end;
end;

{ ---- ListTools ---- }

function TC4DWizardMCPClient.ListTools: TC4DWizardMCPToolList;
var
  LResponse, LResult: TJSONObject;
  LToolsArr: TJSONArray;
  LTool: TJSONObject;
  LItem: TC4DWizardMCPTool;
  I: Integer;
begin
  Result := [];

  // Embedded: ask the in-process server directly (no JSON-RPC round-trip)
  if FTransportType = mttEmbedded then
  begin
    LToolsArr := FEmbeddedServer.ListTools;
    try
      SetLength(Result, LToolsArr.Count);
      for I := 0 to LToolsArr.Count - 1 do
      begin
        LTool := LToolsArr.Items[I] as TJSONObject;
        LItem.Name        := LTool.GetValue<string>('name', '');
        LItem.Description := LTool.GetValue<string>('description', '');
        LItem.InputSchema := LTool.GetValue<TJSONObject>('inputSchema', nil);
        Result[I] := LItem;
      end;
    finally
      LToolsArr.Free;
    end;
    Exit;
  end;

  if not FConnected then
    if not Initialize then Exit;
  LResponse := DispatchRequest(BuildRequest('tools/list'));
  try
    if not Assigned(LResponse) then Exit;
    if LResponse.GetValue('error') <> nil then
    begin
      FLastError := LResponse.GetValue<string>('error.message', 'tools/list failed');
      Exit;
    end;
    LResult := LResponse.GetValue<TJSONObject>('result', nil);
    if not Assigned(LResult) then Exit;
    LToolsArr := LResult.GetValue<TJSONArray>('tools', nil);
    if not Assigned(LToolsArr) then Exit;
    SetLength(Result, LToolsArr.Count);
    for I := 0 to LToolsArr.Count - 1 do
    begin
      LTool := LToolsArr.Items[I] as TJSONObject;
      LItem.Name := LTool.GetValue<string>('name', '');
      LItem.Description := LTool.GetValue<string>('description', '');
      LItem.InputSchema := LTool.GetValue<TJSONObject>('inputSchema', nil);
      Result[I] := LItem;
    end;
  finally
    LResponse.Free;
  end;
end;

{ ---- CallTool ---- }

function TC4DWizardMCPClient.CallTool(const AToolName: string;
  AArguments: TJSONObject): TC4DWizardMCPCallResult;
var
  LParams, LArgs: TJSONObject;
  LResponse: TJSONObject;
  LResult: TJSONValue;
  LError: TJSONObject;
begin
  Result.Content := '';
  Result.IsError := False;
  Result.RawJSON := '';

  // Embedded: call in-process server directly
  if FTransportType = mttEmbedded then
  begin
    LResponse := FEmbeddedServer.ExecuteTool(AToolName, AArguments);
    try
      if not Assigned(LResponse) then
      begin
        Result.IsError := True;
        Result.Content := 'Embedded tool returned nil';
        Exit;
      end;
      Result.RawJSON := LResponse.ToString;
      LError := LResponse.GetValue<TJSONObject>('error', nil);
      if Assigned(LError) then
      begin
        Result.IsError := True;
        Result.Content := LError.GetValue<string>('message', 'Tool error');
        Exit;
      end;
      // Embedded result: {content:[{type,text}], tool:...}
      Result.Content := ExtractTextContent(LResponse);
    finally
      LResponse.Free;
    end;
    Exit;
  end;

  if not FConnected then
    if not Initialize then
    begin
      Result.IsError := True;
      Result.Content := 'Not connected: ' + FLastError;
      Exit;
    end;
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('name', AToolName);
    if Assigned(AArguments) then
      LArgs := AArguments.Clone as TJSONObject
    else
      LArgs := TJSONObject.Create;
    LParams.AddPair('arguments', LArgs);
    LResponse := DispatchRequest(BuildRequest('tools/call', LParams));
    try
      if not Assigned(LResponse) then
      begin
        Result.IsError := True;
        Result.Content := 'No response: ' + FLastError;
        Exit;
      end;
      Result.RawJSON := LResponse.ToString;
      LError := LResponse.GetValue<TJSONObject>('error', nil);
      if Assigned(LError) then
      begin
        Result.IsError := True;
        Result.Content := LError.GetValue<string>('message', 'Tool error');
        Exit;
      end;
      LResult := LResponse.GetValue('result');
      if Assigned(LResult) then
      begin
        Result.IsError := (LResult is TJSONObject) and
          TJSONObject(LResult).GetValue<Boolean>('isError', False);
        Result.Content := ExtractTextContent(LResult);
      end;
    finally
      LResponse.Free;
    end;
  finally
    LParams.Free;
  end;
end;

end.
