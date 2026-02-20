unit C4D.Wizard.MCP.EmbeddedServer;

{
  Embedded MCP Server for Code4D Wizard
  ======================================
  Runs inside the IDE process – no external process needed.

  Exposes the same tool interface as the stdio/HTTP transports, but
  dispatches tool calls directly to handler functions backed by the
  GitHub Models inference API.

  Built-in tools (FlexGrid / eMISTR stack):
    analyze_entity       – Review Aurelius entity mappings & suggest fixes
    generate_service     – Generate XData ServiceContract operation
    query_docs           – General Delphi / architecture Q&A

  Custom tools can be registered at runtime via RegisterTool().
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  C4D.Wizard.AI.GitHub;

type
  // -----------------------------------------------------------------------
  // Tool parameter descriptor (mirrors JSON Schema property)
  // -----------------------------------------------------------------------
  TC4DWizardMCPToolParam = record
    Name        : string;
    ParamType   : string;   // 'string', 'boolean', 'integer', etc.
    Description : string;
    Required    : Boolean;
  end;

  TMCPToolParamList = TArray<TC4DWizardMCPToolParam>;

  // -----------------------------------------------------------------------
  // Tool descriptor
  // -----------------------------------------------------------------------
  TC4DWizardMCPToolDef = class
  public
    Name         : string;
    Description  : string;
    SystemPrompt : string;     // overrides default GitHub Models system prompt
    Parameters   : TMCPToolParamList;

    function ToJSON: TJSONObject;
    procedure AddParam(const AName, AType, ADesc: string; ARequired: Boolean = True);
  end;

  // -----------------------------------------------------------------------
  // Tool handler type
  // -----------------------------------------------------------------------
  TC4DWizardMCPToolHandler = reference to function(
    const AParams: TJSONObject): TJSONObject;

  // -----------------------------------------------------------------------
  // Embedded server interface
  // -----------------------------------------------------------------------
  IC4DWizardMCPEmbeddedServer = interface
    ['{C8D9E0F1-A2B3-4567-CDEF-1234567890AB}']
    procedure RegisterTool(const ATool: TC4DWizardMCPToolDef;
      const AHandler: TC4DWizardMCPToolHandler);
    function  ExecuteTool(const AToolName: string;
      const AParams: TJSONObject): TJSONObject;
    function  ListTools: TJSONArray;
    function  IsToolRegistered(const AToolName: string): Boolean;
    function  UpdateGitHubConfig(const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPEmbeddedServer;
  end;

  // -----------------------------------------------------------------------
  // Concrete embedded server
  // -----------------------------------------------------------------------
  TC4DWizardMCPEmbeddedServer = class(TInterfacedObject, IC4DWizardMCPEmbeddedServer)
  private
    FTools    : TObjectDictionary<string, TC4DWizardMCPToolDef>;
    FHandlers : TDictionary<string, TC4DWizardMCPToolHandler>;
    FGitHub   : IC4DWizardAIGitHub;

    procedure RegisterBuiltInTools;

    // Built-in handlers
    function HandleAnalyzeEntity(const AParams: TJSONObject): TJSONObject;
    function HandleGenerateService(const AParams: TJSONObject): TJSONObject;
    function HandleQueryDocs(const AParams: TJSONObject): TJSONObject;
    function HandleAskAI(const AParams: TJSONObject): TJSONObject;

    function MakeResult(const AContent, AToolName: string;
      AInsertable: Boolean = False): TJSONObject;
    function MakeError(const AMessage: string): TJSONObject;
  protected
    procedure RegisterTool(const ATool: TC4DWizardMCPToolDef;
      const AHandler: TC4DWizardMCPToolHandler);
    function  ExecuteTool(const AToolName: string;
      const AParams: TJSONObject): TJSONObject;
    function  ListTools: TJSONArray;
    function  IsToolRegistered(const AToolName: string): Boolean;
    function  UpdateGitHubConfig(
      const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPEmbeddedServer;
  public
    class function New(const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPEmbeddedServer;
    constructor Create(const AConfig: TC4DGitHubModelsConfig);
    destructor Destroy; override;
  end;

implementation

{ TC4DWizardMCPToolDef }

procedure TC4DWizardMCPToolDef.AddParam(const AName, AType, ADesc: string;
  ARequired: Boolean);
var
  P: TC4DWizardMCPToolParam;
begin
  P.Name        := AName;
  P.ParamType   := AType;
  P.Description := ADesc;
  P.Required    := ARequired;
  Parameters    := Parameters + [P];
end;

function TC4DWizardMCPToolDef.ToJSON: TJSONObject;
var
  LSchema   : TJSONObject;
  LProps    : TJSONObject;
  LRequired : TJSONArray;
  LProp     : TJSONObject;
  LP        : TC4DWizardMCPToolParam;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', Name);
  Result.AddPair('description', Description);

  // Build JSON Schema for inputSchema
  LSchema   := TJSONObject.Create;
  LSchema.AddPair('type', 'object');
  LProps    := TJSONObject.Create;
  LRequired := TJSONArray.Create;

  for LP in Parameters do
  begin
    LProp := TJSONObject.Create;
    LProp.AddPair('type', LP.ParamType);
    LProp.AddPair('description', LP.Description);
    LProps.AddPair(LP.Name, LProp);
    if LP.Required then
      LRequired.Add(LP.Name);
  end;

  LSchema.AddPair('properties', LProps);
  LSchema.AddPair('required', LRequired);
  Result.AddPair('inputSchema', LSchema);
end;

{ TC4DWizardMCPEmbeddedServer }

class function TC4DWizardMCPEmbeddedServer.New(
  const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPEmbeddedServer;
begin
  Result := TC4DWizardMCPEmbeddedServer.Create(AConfig);
end;

constructor TC4DWizardMCPEmbeddedServer.Create(const AConfig: TC4DGitHubModelsConfig);
begin
  FTools    := TObjectDictionary<string, TC4DWizardMCPToolDef>.Create([doOwnsValues]);
  FHandlers := TDictionary<string, TC4DWizardMCPToolHandler>.Create;
  FGitHub   := TC4DWizardAIGitHub.New(AConfig);
  RegisterBuiltInTools;
end;

destructor TC4DWizardMCPEmbeddedServer.Destroy;
begin
  FHandlers.Free;
  FTools.Free;
  inherited;
end;

procedure TC4DWizardMCPEmbeddedServer.RegisterBuiltInTools;
var
  LTool: TC4DWizardMCPToolDef;
begin
  // ----- analyze_entity -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'analyze_entity';
  LTool.Description := 'Analyze a Delphi/Aurelius entity class and suggest ' +
                       'improvements: mapping attributes, associations, indexes, ' +
                       'nullable fields.';
  LTool.SystemPrompt := 'You are an expert in TMS Aurelius ORM and Delphi OOP. ' +
    'Analyze the entity and return specific, actionable suggestions in plain text.';
  LTool.AddParam('entity_code', 'string', 'Full source code of the entity class');
  LTool.AddParam('module', 'string',
    'Optional FlexGrid module context (e.g. HR, Inventory)', False);
  RegisterTool(LTool, HandleAnalyzeEntity);

  // ----- generate_service -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'generate_service';
  LTool.Description := 'Generate a complete XData [ServiceContract] operation ' +
                       'for a given entity and CRUD action.';
  LTool.SystemPrompt := 'You are an expert in TMS XData REST services in Delphi. ' +
    'Return only compilable Object Pascal code, no extra explanation.';
  LTool.AddParam('entity_name', 'string', 'Entity class name, e.g. TOrder');
  LTool.AddParam('operation', 'string',
    'CRUD operation: create | read | update | delete | list');
  RegisterTool(LTool, HandleGenerateService);

  // ----- query_docs -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'query_docs';
  LTool.Description := 'Answer questions about Delphi, Aurelius, XData, ' +
                       'FlexGrid MES or general Object Pascal development.';
  LTool.AddParam('query', 'string', 'Your question');
  LTool.AddParam('context', 'string',
    'Optional additional context (selected code, error message, etc.)', False);
  RegisterTool(LTool, HandleQueryDocs);

  // ----- ask_ai (generic free-form) -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'ask_ai';
  LTool.Description := 'Send any prompt to the GitHub Models AI with optional ' +
                       'code context from the IDE editor.';
  LTool.AddParam('prompt', 'string', 'The prompt / instruction for the AI');
  LTool.AddParam('code_context', 'string',
    'Optional code selected in the IDE editor', False);
  LTool.AddParam('system_prompt', 'string',
    'Optional system-level instruction to override the default', False);
  RegisterTool(LTool, HandleAskAI);
end;

procedure TC4DWizardMCPEmbeddedServer.RegisterTool(
  const ATool: TC4DWizardMCPToolDef;
  const AHandler: TC4DWizardMCPToolHandler);
begin
  FTools.AddOrSetValue(ATool.Name, ATool);
  FHandlers.AddOrSetValue(ATool.Name, AHandler);
end;

function TC4DWizardMCPEmbeddedServer.ExecuteTool(const AToolName: string;
  const AParams: TJSONObject): TJSONObject;
var
  LHandler: TC4DWizardMCPToolHandler;
begin
  if not FHandlers.TryGetValue(AToolName, LHandler) then
    Result := MakeError('Tool not found: ' + AToolName)
  else
  try
    Result := LHandler(AParams);
  except
    on E: Exception do
      Result := MakeError(E.Message);
  end;
end;

function TC4DWizardMCPEmbeddedServer.ListTools: TJSONArray;
var
  LPair: TPair<string, TC4DWizardMCPToolDef>;
begin
  Result := TJSONArray.Create;
  for LPair in FTools do
    Result.Add(LPair.Value.ToJSON);
end;

function TC4DWizardMCPEmbeddedServer.IsToolRegistered(
  const AToolName: string): Boolean;
begin
  Result := FTools.ContainsKey(AToolName);
end;

function TC4DWizardMCPEmbeddedServer.UpdateGitHubConfig(
  const AConfig: TC4DGitHubModelsConfig): IC4DWizardMCPEmbeddedServer;
begin
  Result  := Self;
  FGitHub := TC4DWizardAIGitHub.New(AConfig);
end;

function TC4DWizardMCPEmbeddedServer.MakeResult(const AContent, AToolName: string;
  AInsertable: Boolean): TJSONObject;
var
  LArr: TJSONArray;
  LItem: TJSONObject;
begin
  Result := TJSONObject.Create;
  // MCP spec: result.content is an array of {type,text} blocks
  LArr  := TJSONArray.Create;
  LItem := TJSONObject.Create;
  LItem.AddPair('type', 'text');
  LItem.AddPair('text', AContent);
  LArr.Add(LItem);
  Result.AddPair('content', LArr);
  Result.AddPair('tool', AToolName);
  if AInsertable then
    Result.AddPair('insertable', TJSONBool.Create(True));
end;

function TC4DWizardMCPEmbeddedServer.MakeError(
  const AMessage: string): TJSONObject;
var
  LErr: TJSONObject;
begin
  Result := TJSONObject.Create;
  LErr   := TJSONObject.Create;
  LErr.AddPair('code', TJSONNumber.Create(-32603));
  LErr.AddPair('message', AMessage);
  Result.AddPair('error', LErr);
end;

{ Built-in handlers }

function TC4DWizardMCPEmbeddedServer.HandleAnalyzeEntity(
  const AParams: TJSONObject): TJSONObject;
var
  LCode    : string;
  LModule  : string;
  LPrompt  : string;
  LAnswer  : string;
  LSysProm : string;
begin
  LCode   := AParams.GetValue<string>('entity_code', '');
  LModule := AParams.GetValue<string>('module', '');

  if LCode.IsEmpty then
  begin
    Result := MakeError('Parameter entity_code is required');
    Exit;
  end;

  LSysProm := FTools['analyze_entity'].SystemPrompt;

  LPrompt :=
    'Analyze this Delphi/Aurelius entity class:' + sLineBreak +
    '- Check [Entity], [Automapping] and explicit column attributes.' + sLineBreak +
    '- Check all associations ([ManyToOne], [OneToMany], etc.).' + sLineBreak +
    '- Suggest missing indexes ([UniqueKey], [Index]).' + sLineBreak +
    '- Identify nullable vs. required columns.' + sLineBreak +
    '- Note any naming convention issues.';

  if not LModule.IsEmpty then
    LPrompt := LPrompt + sLineBreak + 'Module context: ' + LModule + '.';

  LAnswer := FGitHub.GetCompletion(LPrompt, LCode, LSysProm);

  if LAnswer.IsEmpty then
    Result := MakeError('GitHub Models returned empty response. ' + FGitHub.LastError)
  else
    Result := MakeResult(LAnswer, 'analyze_entity');
end;

function TC4DWizardMCPEmbeddedServer.HandleGenerateService(
  const AParams: TJSONObject): TJSONObject;
var
  LEntity    : string;
  LOperation : string;
  LPrompt    : string;
  LCode      : string;
  LSysProm   : string;
begin
  LEntity    := AParams.GetValue<string>('entity_name', '');
  LOperation := AParams.GetValue<string>('operation', '');

  if LEntity.IsEmpty or LOperation.IsEmpty then
  begin
    Result := MakeError('Parameters entity_name and operation are required');
    Exit;
  end;

  LSysProm := FTools['generate_service'].SystemPrompt;

  LPrompt := Format(
    'Generate a complete TMS XData [ServiceContract] method for the %s entity.%s' +
    'Operation: %s%s' +
    'Requirements:%s' +
    '- Use [ServiceContract] and [HttpGet]/[HttpPost]/[HttpPut]/[HttpDelete] as appropriate.%s' +
    '- Include ObjectManager transaction handling.%s' +
    '- Include error handling (try/except with EXDataHttpException).%s' +
    '- Return the complete compilable unit (interface + implementation).%s' +
    'Output: only Object Pascal code.',
    [LEntity, sLineBreak, LOperation, sLineBreak,
     sLineBreak, sLineBreak, sLineBreak, sLineBreak, sLineBreak]);

  LCode := FGitHub.GetCompletion(LPrompt, '', LSysProm);

  if LCode.IsEmpty then
    Result := MakeError('GitHub Models returned empty response. ' + FGitHub.LastError)
  else
    Result := MakeResult(LCode, 'generate_service', True);  // insertable into editor
end;

function TC4DWizardMCPEmbeddedServer.HandleQueryDocs(
  const AParams: TJSONObject): TJSONObject;
var
  LQuery   : string;
  LContext : string;
  LAnswer  : string;
begin
  LQuery   := AParams.GetValue<string>('query', '');
  LContext := AParams.GetValue<string>('context', '');

  if LQuery.IsEmpty then
  begin
    Result := MakeError('Parameter query is required');
    Exit;
  end;

  LAnswer := FGitHub.GetCompletion(LQuery, LContext);

  if LAnswer.IsEmpty then
    Result := MakeError('GitHub Models returned empty response. ' + FGitHub.LastError)
  else
    Result := MakeResult(LAnswer, 'query_docs');
end;

function TC4DWizardMCPEmbeddedServer.HandleAskAI(
  const AParams: TJSONObject): TJSONObject;
var
  LPrompt  : string;
  LContext : string;
  LSysProm : string;
  LAnswer  : string;
begin
  LPrompt  := AParams.GetValue<string>('prompt', '');
  LContext := AParams.GetValue<string>('code_context', '');
  LSysProm := AParams.GetValue<string>('system_prompt', '');

  if LPrompt.IsEmpty then
  begin
    Result := MakeError('Parameter prompt is required');
    Exit;
  end;

  LAnswer := FGitHub.GetCompletion(LPrompt, LContext, LSysProm);

  if LAnswer.IsEmpty then
    Result := MakeError('GitHub Models returned empty response. ' + FGitHub.LastError)
  else
    Result := MakeResult(LAnswer, 'ask_ai');
end;

end.
