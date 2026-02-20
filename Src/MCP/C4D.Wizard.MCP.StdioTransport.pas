unit C4D.Wizard.MCP.StdioTransport;

{
  MCP Stdio Transport for Code4D Wizard
  ======================================
  Spawns an MCP server process and communicates via stdin/stdout pipes —
  exactly the same mechanism used by Claude Desktop, GitHub Copilot,
  VS Code and other MCP-aware tools.

  Protocol: newline-delimited JSON  (one complete JSON object per line).

  Typical server commands:
    node   C:\MyServer\index.js
    python C:\MyServer\server.py
    npx    -y @modelcontextprotocol/server-filesystem C:\workspace

  The process is started lazily on the first JSON-RPC call and is
  kept alive until Shutdown is called (or the object is destroyed).
}

interface

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.JSON,
  C4D.Wizard.dprocess,
  C4D.Wizard.dpipes;

type
  /// <summary>
  /// Raised when the server process cannot be started or sends an error.
  /// </summary>
  EMCPStdioError = class(Exception);

  /// <summary>
  /// Reads lines from an TInputPipeStream in a background thread and
  /// signals whenever a complete JSON line is available.
  /// </summary>
  TC4DMCPStdioReaderThread = class(TThread)
  private
    FPipe: TInputPipeStream;
    FOnLine: TProc<string>;
    FBuffer: string;
  protected
    procedure Execute; override;
  public
    constructor Create(APipe: TInputPipeStream; AOnLine: TProc<string>);
  end;

  /// <summary>
  /// Stdio transport: owns a TProcess and exposes synchronous
  /// SendAndReceive (blocks until a JSON-RPC response line arrives or
  /// the timeout expires).
  /// </summary>
  TC4DWizardMCPStdioTransport = class
  private
    FProcess: TProcess;
    FReaderThread: TC4DMCPStdioReaderThread;
    FLock: TCriticalSection;
    FResponseEvent: TEvent;
    FPendingResponse: string;
    FLastError: string;
    FCommand: string;
    FArguments: string;
    FWorkingDir: string;
    FTimeoutMs: Integer;
    procedure OnResponseLine(const ALine: string);
    procedure EnsureStarted;
    function GetProcessID: Integer;
  public
    constructor Create(const ACommand, AArguments, AWorkingDir: string;
      ATimeoutMs: Integer = 30000);
    destructor Destroy; override;

    /// <summary>Start the server process (called automatically if needed).</summary>
    procedure Start;

    /// <summary>Gracefully terminate the server process.</summary>
    procedure Shutdown;

    /// <summary>Returns True when the child process is alive.</summary>
    function IsRunning: Boolean;

    /// <summary>
    /// Send a JSON-RPC request string and block until a response line
    /// arrives or the timeout elapses.
    /// Returns the raw JSON response string, or empty on timeout/error.
    /// </summary>
    function SendAndReceive(const ARequestJSON: string): string;

    property LastError: string read FLastError;
    property Command: string read FCommand write FCommand;
    property Arguments: string read FArguments write FArguments;
    property WorkingDir: string read FWorkingDir write FWorkingDir;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property ProcessID: Integer read GetProcessID;
  end;

implementation

{ TC4DMCPStdioReaderThread }

constructor TC4DMCPStdioReaderThread.Create(APipe: TInputPipeStream;
  AOnLine: TProc<string>);
begin
  FPipe := APipe;
  FOnLine := AOnLine;
  FBuffer := '';
  FreeOnTerminate := False;
  inherited Create(False);
end;

procedure TC4DMCPStdioReaderThread.Execute;
const
  CHUNK_SIZE = 4096;
var
  LBuf: array[0..CHUNK_SIZE - 1] of AnsiChar;
  LRead: Integer;
  LRaw: string;
  LPos: Integer;
  LLine: string;
begin
  while not Terminated do
  begin
    try
      // NumBytesAvailable avoids a blocking Read when nothing is there
      if FPipe.NumBytesAvailable = 0 then
      begin
        Sleep(5);
        Continue;
      end;
      LRead := FPipe.Read(LBuf, CHUNK_SIZE);
      if LRead <= 0 then
      begin
        Sleep(5);
        Continue;
      end;
      LRaw := TEncoding.UTF8.GetString(TBytes(@LBuf), 0, LRead);
      FBuffer := FBuffer + LRaw;
      // Dispatch every complete line
      repeat
        LPos := FBuffer.IndexOf(#10);  // LF
        if LPos < 0 then Break;
        LLine := FBuffer.Substring(0, LPos).TrimRight;
        FBuffer := FBuffer.Substring(LPos + 1);
        if not LLine.IsEmpty then
        begin
          var LCapture := LLine; // capture for closure
          if Assigned(FOnLine) then
            FOnLine(LCapture);
        end;
      until False;
    except
      // Pipe closed / process died
      Break;
    end;
  end;
end;

{ TC4DWizardMCPStdioTransport }

constructor TC4DWizardMCPStdioTransport.Create(const ACommand, AArguments,
  AWorkingDir: string; ATimeoutMs: Integer);
begin
  FCommand := ACommand;
  FArguments := AArguments;
  FWorkingDir := AWorkingDir;
  FTimeoutMs := ATimeoutMs;
  FLock := TCriticalSection.Create;
  FResponseEvent := TEvent.Create(nil, False, False, '');
  FProcess := nil;
  FReaderThread := nil;
  FPendingResponse := '';
  FLastError := '';
end;

destructor TC4DWizardMCPStdioTransport.Destroy;
begin
  Shutdown;
  FResponseEvent.Free;
  FLock.Free;
  inherited;
end;

procedure TC4DWizardMCPStdioTransport.OnResponseLine(const ALine: string);
begin
  // Called from the reader thread — store the line and signal the waiter
  FLock.Enter;
  try
    FPendingResponse := ALine;
  finally
    FLock.Leave;
  end;
  FResponseEvent.SetEvent;
end;

procedure TC4DWizardMCPStdioTransport.Start;
var
  LParams: TStringList;
  LArg: string;
  LParts: TArray<string>;
begin
  if IsRunning then
    Exit;

  FLastError := '';
  FProcess := TProcess.Create(nil);
  try
    FProcess.Executable := FCommand;
    FProcess.Options := [poUsePipes, poNoConsole, poStderrToOutPut];
    FProcess.ShowWindow := swoHide;

    if not FWorkingDir.IsEmpty then
      FProcess.CurrentDirectory := FWorkingDir;

    // Split arguments on spaces respecting quoted segments
    LParams := TStringList.Create;
    try
      // Simple split: honour "quoted args" as single token
      var LRest := FArguments.Trim;
      while LRest.Length > 0 do
      begin
        LRest := LRest.TrimLeft;
        if LRest.IsEmpty then Break;
        if LRest.StartsWith('"') then
        begin
          var LEnd := LRest.IndexOf('"', 1);
          if LEnd < 0 then LEnd := LRest.Length - 1;
          LParams.Add(LRest.Substring(1, LEnd - 1));
          LRest := LRest.Substring(LEnd + 1).TrimLeft;
        end
        else
        begin
          var LSp := LRest.IndexOf(' ');
          if LSp < 0 then
          begin
            LParams.Add(LRest);
            Break;
          end
          else
          begin
            LParams.Add(LRest.Substring(0, LSp));
            LRest := LRest.Substring(LSp + 1);
          end;
        end;
      end;
      for LArg in LParams do
        FProcess.Parameters.Add(LArg);
    finally
      LParams.Free;
    end;

    FProcess.Execute;

    // Start async reader on the process stdout
    FReaderThread := TC4DMCPStdioReaderThread.Create(
      FProcess.Output, OnResponseLine);

  except
    on E: Exception do
    begin
      FLastError := 'Failed to start MCP server: ' + E.Message;
      FreeAndNil(FProcess);
      raise EMCPStdioError.Create(FLastError);
    end;
  end;
end;

procedure TC4DWizardMCPStdioTransport.EnsureStarted;
begin
  if not IsRunning then
    Start;
end;

procedure TC4DWizardMCPStdioTransport.Shutdown;
begin
  if Assigned(FReaderThread) then
  begin
    FReaderThread.Terminate;
    FReaderThread.WaitFor;
    FreeAndNil(FReaderThread);
  end;
  if Assigned(FProcess) then
  begin
    try
      if FProcess.Running then
        FProcess.Terminate(0);
    except
    end;
    FreeAndNil(FProcess);
  end;
  FResponseEvent.ResetEvent;
  FPendingResponse := '';
end;

function TC4DWizardMCPStdioTransport.GetProcessID: Integer;
begin
  if Assigned(FProcess) then
    Result := FProcess.ProcessID
  else
    Result := 0;
end;


begin
  Result := Assigned(FProcess) and FProcess.Running;
end;

function TC4DWizardMCPStdioTransport.SendAndReceive(
  const ARequestJSON: string): string;
var
  LBytes: TBytes;
  LLine: string;
  LWait: TWaitResult;
begin
  Result := '';
  FLastError := '';

  EnsureStarted;

  if not IsRunning then
  begin
    FLastError := 'Server process is not running';
    Exit;
  end;

  // Clear any leftover event/response from previous call
  FResponseEvent.ResetEvent;
  FLock.Enter;
  try
    FPendingResponse := '';
  finally
    FLock.Leave;
  end;

  // Write request followed by newline (NDJSON — newline-delimited JSON)
  LLine := ARequestJSON + #10;
  LBytes := TEncoding.UTF8.GetBytes(LLine);
  try
    FProcess.Input.WriteBuffer(LBytes[0], Length(LBytes));
  except
    on E: Exception do
    begin
      FLastError := 'Write to server stdin failed: ' + E.Message;
      Exit;
    end;
  end;

  // Wait for a response line
  LWait := FResponseEvent.WaitFor(FTimeoutMs);
  case LWait of
    wrSignaled:
      begin
        FLock.Enter;
        try
          Result := FPendingResponse;
        finally
          FLock.Leave;
        end;
      end;
    wrTimeout:
      FLastError := Format('Timeout (%d ms) waiting for server response', [FTimeoutMs]);
    else
      FLastError := 'Wait error on server response event';
  end;
end;

end.
