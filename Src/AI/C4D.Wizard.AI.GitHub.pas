unit C4D.Wizard.AI.GitHub;

{
  GitHub Models API Client for Code4D Wizard
  =============================================
  Calls the GitHub Models inference endpoint (OpenAI-compatible chat completions
  API) using a GitHub personal-access-token or GITHUB_TOKEN env-var.

  Endpoint : https://models.inference.ai.azure.com/chat/completions
  Auth     : Bearer <GITHUB_TOKEN>
  Models   : gpt-4o, claude-3.5-sonnet, o1-preview, etc.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient;

type
  // -----------------------------------------------------------------------
  // Configuration record
  // -----------------------------------------------------------------------
  TC4DGitHubModelsConfig = record
    Token    : string;   // GitHub PAT or GITHUB_TOKEN env value
    Model    : string;   // e.g. 'gpt-4o'
    Endpoint : string;   // e.g. 'https://models.inference.ai.azure.com'
    MaxTokens   : Integer;
    Temperature : Double;

    class function Default: TC4DGitHubModelsConfig; static;
  end;

  // -----------------------------------------------------------------------
  // Interface
  // -----------------------------------------------------------------------
  IC4DWizardAIGitHub = interface
    ['{B7C8D9E0-F1A2-3456-BCDE-F1234567890A}']
    /// <summary>
    /// Synchronous single completion.  Returns the assistant message text.
    /// Raises on HTTP error.
    /// </summary>
    function GetCompletion(const APrompt: string;
      const ACodeContext: string = '';
      const ASystemPrompt: string = ''): string;

    /// <summary>
    /// Streaming completion – calls AOnChunk for each SSE delta text fragment.
    /// Returns True on success.
    /// </summary>
    function GetStreamCompletion(const APrompt: string;
      const AOnChunk: TProc<string>;
      const ACodeContext: string = ''): Boolean;

    function LastError: string;
    function Config: TC4DGitHubModelsConfig;
    function Config(const AValue: TC4DGitHubModelsConfig): IC4DWizardAIGitHub; overload;
  end;

  // -----------------------------------------------------------------------
  // Concrete class
  // -----------------------------------------------------------------------
  TC4DWizardAIGitHub = class(TInterfacedObject, IC4DWizardAIGitHub)
  private
    FConfig     : TC4DGitHubModelsConfig;
    FHttpClient : THTTPClient;
    FLastError  : string;

    function BuildMessages(const APrompt, AContext, ASystemPrompt: string): TJSONArray;
    function BuildRequest(const APrompt, AContext, ASystemPrompt: string;
      AStream: Boolean): TJSONObject;
    function CompletionsURL: string;
  protected
    function GetCompletion(const APrompt: string;
      const ACodeContext: string = '';
      const ASystemPrompt: string = ''): string;
    function GetStreamCompletion(const APrompt: string;
      const AOnChunk: TProc<string>;
      const ACodeContext: string = ''): Boolean;
    function LastError: string;
    function Config: TC4DGitHubModelsConfig; overload;
    function Config(const AValue: TC4DGitHubModelsConfig): IC4DWizardAIGitHub; overload;
  public
    class function New(const AConfig: TC4DGitHubModelsConfig): IC4DWizardAIGitHub;
    constructor Create(const AConfig: TC4DGitHubModelsConfig);
    destructor Destroy; override;
  end;

  // -----------------------------------------------------------------------
  // Helper to resolve ${env:VAR} tokens
  // -----------------------------------------------------------------------
  TC4DEnvResolver = class
    class function Resolve(const AValue: string): string;
  end;

implementation

const
  C_DEFAULT_ENDPOINT = 'https://models.inference.ai.azure.com';
  C_DEFAULT_MODEL    = 'gpt-4o';
  C_DEFAULT_SYSTEM   =
    'You are an expert Delphi developer specialising in object-oriented ' +
    'design, TMS Aurelius/XData and RAD Studio OTA/IDE plugins. ' +
    'Provide concise, production-quality Object Pascal code.';

{ TC4DGitHubModelsConfig }

class function TC4DGitHubModelsConfig.Default: TC4DGitHubModelsConfig;
begin
  Result.Token      := TC4DEnvResolver.Resolve('${env:GITHUB_TOKEN}');
  Result.Model      := C_DEFAULT_MODEL;
  Result.Endpoint   := C_DEFAULT_ENDPOINT;
  Result.MaxTokens  := 2000;
  Result.Temperature := 0.3;
end;

{ TC4DEnvResolver }

class function TC4DEnvResolver.Resolve(const AValue: string): string;
var
  LEnvName: string;
begin
  Result := AValue;
  if AValue.StartsWith('${env:', True) and AValue.EndsWith('}') then
  begin
    LEnvName := AValue.Substring(6, AValue.Length - 7);
    Result   := GetEnvironmentVariable(LEnvName);
  end;
end;

{ TC4DWizardAIGitHub }

class function TC4DWizardAIGitHub.New(
  const AConfig: TC4DGitHubModelsConfig): IC4DWizardAIGitHub;
begin
  Result := TC4DWizardAIGitHub.Create(AConfig);
end;

constructor TC4DWizardAIGitHub.Create(const AConfig: TC4DGitHubModelsConfig);
begin
  FConfig     := AConfig;
  FHttpClient := THTTPClient.Create;
end;

destructor TC4DWizardAIGitHub.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function TC4DWizardAIGitHub.CompletionsURL: string;
begin
  Result := FConfig.Endpoint.TrimRight(['/']) + '/chat/completions';
end;

function TC4DWizardAIGitHub.BuildMessages(const APrompt, AContext,
  ASystemPrompt: string): TJSONArray;
var
  LSys, LUser: TJSONObject;
  LSysText, LUserText: string;
begin
  Result := TJSONArray.Create;

  // System message
  if not ASystemPrompt.IsEmpty then
    LSysText := ASystemPrompt
  else
    LSysText := C_DEFAULT_SYSTEM;

  LSys := TJSONObject.Create;
  LSys.AddPair('role', 'system');
  LSys.AddPair('content', LSysText);
  Result.Add(LSys);

  // User message (optional context block + prompt)
  if not AContext.IsEmpty then
    LUserText := 'Code context:' + sLineBreak + AContext +
                 sLineBreak + sLineBreak + 'Task: ' + APrompt
  else
    LUserText := APrompt;

  LUser := TJSONObject.Create;
  LUser.AddPair('role', 'user');
  LUser.AddPair('content', LUserText);
  Result.Add(LUser);
end;

function TC4DWizardAIGitHub.BuildRequest(const APrompt, AContext,
  ASystemPrompt: string; AStream: Boolean): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('model', FConfig.Model);
  Result.AddPair('temperature', TJSONNumber.Create(FConfig.Temperature));
  Result.AddPair('max_tokens', TJSONNumber.Create(FConfig.MaxTokens));
  Result.AddPair('messages', BuildMessages(APrompt, AContext, ASystemPrompt));
  if AStream then
    Result.AddPair('stream', TJSONBool.Create(True));
end;

function TC4DWizardAIGitHub.GetCompletion(const APrompt: string;
  const ACodeContext: string; const ASystemPrompt: string): string;
var
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResp    : IHTTPResponse;
  LJSON    : TJSONObject;
  LChoices : TJSONArray;
  LToken   : string;
begin
  Result    := '';
  FLastError := '';
  LToken := TC4DEnvResolver.Resolve(FConfig.Token);
  if LToken.IsEmpty then
  begin
    FLastError := 'GitHub token is empty. Set GITHUB_TOKEN or configure the token in Settings.';
    Exit;
  end;

  LRequest := BuildRequest(APrompt, ACodeContext, ASystemPrompt, False);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResp := FHttpClient.Post(
        CompletionsURL, LBody, nil,
        [TNetHeader.Create('Authorization', 'Bearer ' + LToken),
         TNetHeader.Create('Content-Type', 'application/json'),
         TNetHeader.Create('Accept', 'application/json')]);

      if LResp.StatusCode = 200 then
      begin
        LJSON := TJSONObject.ParseJSONValue(
          LResp.ContentAsString(TEncoding.UTF8)) as TJSONObject;
        if Assigned(LJSON) then
        try
          LChoices := LJSON.GetValue<TJSONArray>('choices', nil);
          if Assigned(LChoices) and (LChoices.Count > 0) then
            Result := (LChoices.Items[0] as TJSONObject)
                        .GetValue<TJSONObject>('message', nil)
                        .GetValue<string>('content', '');
        finally
          LJSON.Free;
        end;
      end
      else
      begin
        FLastError := Format('GitHub Models API error %d: %s',
          [LResp.StatusCode, LResp.ContentAsString(TEncoding.UTF8)]);
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := '';
      end;
    end;
  finally
    LBody.Free;
    LRequest.Free;
  end;
end;

function TC4DWizardAIGitHub.GetStreamCompletion(const APrompt: string;
  const AOnChunk: TProc<string>; const ACodeContext: string): Boolean;
var
  LRequest : TJSONObject;
  LBody    : TStringStream;
  LResp    : IHTTPResponse;
  LLines   : TStringList;
  LLine    : string;
  LChunk   : TJSONObject;
  LToken   : string;
  LDelta   : string;
  I        : Integer;
begin
  Result     := False;
  FLastError := '';
  LToken := TC4DEnvResolver.Resolve(FConfig.Token);
  if LToken.IsEmpty then
  begin
    FLastError := 'GitHub token is empty.';
    Exit;
  end;

  LRequest := BuildRequest(APrompt, ACodeContext, '', True);
  LBody    := TStringStream.Create(LRequest.ToJSON, TEncoding.UTF8);
  try
    try
      LResp := FHttpClient.Post(
        CompletionsURL, LBody, nil,
        [TNetHeader.Create('Authorization', 'Bearer ' + LToken),
         TNetHeader.Create('Content-Type', 'application/json')]);

      if LResp.StatusCode <> 200 then
      begin
        FLastError := Format('HTTP %d: %s',
          [LResp.StatusCode, LResp.ContentAsString(TEncoding.UTF8)]);
        Exit;
      end;

      LLines := TStringList.Create;
      try
        LLines.Text := LResp.ContentAsString(TEncoding.UTF8);
        for I := 0 to LLines.Count - 1 do
        begin
          LLine := LLines[I].Trim;
          if not LLine.StartsWith('data: ') then Continue;
          LLine := LLine.Substring(6);
          if LLine = '[DONE]' then Break;

          LChunk := TJSONObject.ParseJSONValue(LLine) as TJSONObject;
          if Assigned(LChunk) then
          try
            if LChunk.TryGetValue<string>('choices[0].delta.content', LDelta) then
              AOnChunk(LDelta);
          finally
            LChunk.Free;
          end;
        end;
        Result := True;
      finally
        LLines.Free;
      end;
    except
      on E: Exception do
      begin
        FLastError := E.Message;
        Result := False;
      end;
    end;
  finally
    LBody.Free;
    LRequest.Free;
  end;
end;

function TC4DWizardAIGitHub.LastError: string;
begin
  Result := FLastError;
end;

function TC4DWizardAIGitHub.Config: TC4DGitHubModelsConfig;
begin
  Result := FConfig;
end;

function TC4DWizardAIGitHub.Config(
  const AValue: TC4DGitHubModelsConfig): IC4DWizardAIGitHub;
begin
  Result  := Self;
  FConfig := AValue;
end;

end.
