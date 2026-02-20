unit C4D.Wizard.Agent.Core;

{
  Agent Core - Agentic Orchestrator
  ===================================
  The main entry point for multi-step AI operations inside the IDE.

  Modes:
    amSingleTool   Sends the request directly to a single MCP tool
    amMultiStep    AI plans the task, then executes each step sequentially
    amAutonomous   Like MultiStep but the agent re-plans on errors (up to MaxIterations)

  Usage:
    var LAgent := TC4DWizardAgent.New(LMCPServer, LGitHubAI);
    LAgent.MaxIterations := 8;
    LResult := LAgent.Execute('Generate service for THREmployee', amMultiStep);
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.MCP.EmbeddedServer,
  C4D.Wizard.Agent.Planning,
  C4D.Wizard.Agent.Memory;

type
  TAgentMode = (amSingleTool, amMultiStep, amAutonomous);

  TAgentStepEvent = procedure(const AStep: string; AIndex, ATotal: Integer;
    const AResult: TJSONObject) of object;

  // -----------------------------------------------------------------------
  // Interface
  // -----------------------------------------------------------------------
  IC4DWizardAgent = interface
    ['{FEDCBA98-7654-3210-FEDC-BA9876543210}']
    function Execute(const AUserRequest: string;
      const ACodeContext: string = '';
      AMode: TAgentMode = amMultiStep): TJSONObject;

    function GetMaxIterations: Integer;
    procedure SetMaxIterations(Value: Integer);
    function GetOnStep: TAgentStepEvent;
    procedure SetOnStep(Value: TAgentStepEvent);

    property MaxIterations : Integer          read GetMaxIterations  write SetMaxIterations;
    property OnStep        : TAgentStepEvent  read GetOnStep         write SetOnStep;
  end;

  // -----------------------------------------------------------------------
  // Concrete agent
  // -----------------------------------------------------------------------
  TC4DWizardAgent = class(TInterfacedObject, IC4DWizardAgent)
  private
    FAI             : IC4DWizardAIGitHub;
    FMCPServer      : IC4DWizardMCPEmbeddedServer;
    FPlanner        : IC4DWizardAgentPlanner;
    FMemory         : IC4DWizardAgentMemory;
    FMaxIterations  : Integer;
    FOnStep         : TAgentStepEvent;
    FSystemContext  : string;   // loaded from instructions

    function ExecuteStep(const AStep: string; AStepIdx: Integer;
      const AContext: TJSONObject): TJSONObject;
    function PickTool(const AStep: string;
      const AContext: TJSONObject): TJSONObject; // {"tool":"...", "params":{...}}
    procedure DoOnStep(const AStep: string; AIndex, ATotal: Integer;
      const AResult: TJSONObject);
  public
    constructor Create(const AMCPServer: IC4DWizardMCPEmbeddedServer;
      const AAI: IC4DWizardAIGitHub);
    destructor Destroy; override;

    function Execute(const AUserRequest: string;
      const ACodeContext: string = '';
      AMode: TAgentMode = amMultiStep): TJSONObject;

    function GetMaxIterations: Integer;
    procedure SetMaxIterations(Value: Integer);
    function GetOnStep: TAgentStepEvent;
    procedure SetOnStep(Value: TAgentStepEvent);

    procedure LoadSystemContext(const AInstructionsPath: string);

    class function New(const AMCPServer: IC4DWizardMCPEmbeddedServer;
      const AAI: IC4DWizardAIGitHub): IC4DWizardAgent;
  end;

implementation

uses
  System.RegularExpressions,
  System.IOUtils;

{ TC4DWizardAgent }

class function TC4DWizardAgent.New(const AMCPServer: IC4DWizardMCPEmbeddedServer;
  const AAI: IC4DWizardAIGitHub): IC4DWizardAgent;
begin
  Result := Self.Create(AMCPServer, AAI);
end;

constructor TC4DWizardAgent.Create(const AMCPServer: IC4DWizardMCPEmbeddedServer;
  const AAI: IC4DWizardAIGitHub);
begin
  FAI            := AAI;
  FMCPServer     := AMCPServer;
  FPlanner       := TC4DWizardAgentPlanner.New(AAI);
  FMemory        := TC4DWizardAgentMemory.New;
  FMaxIterations := 10;
end;

destructor TC4DWizardAgent.Destroy;
begin
  inherited;
end;

function TC4DWizardAgent.GetMaxIterations: Integer;
begin
  Result := FMaxIterations;
end;

procedure TC4DWizardAgent.SetMaxIterations(Value: Integer);
begin
  FMaxIterations := Value;
end;

function TC4DWizardAgent.GetOnStep: TAgentStepEvent;
begin
  Result := FOnStep;
end;

procedure TC4DWizardAgent.SetOnStep(Value: TAgentStepEvent);
begin
  FOnStep := Value;
end;

procedure TC4DWizardAgent.LoadSystemContext(const AInstructionsPath: string);
const
  C_FILES: array[0..2] of string = ('base', 'delphi-expert', 'flexgrid');
var
  LFile  : string;
  LPath  : string;
  LBuf   : TStringBuilder;
begin
  LBuf := TStringBuilder.Create;
  try
    for LFile in C_FILES do
    begin
      LPath := TPath.Combine(AInstructionsPath, LFile + '.md');
      if TFile.Exists(LPath) then
      begin
        LBuf.AppendLine(TFile.ReadAllText(LPath, TEncoding.UTF8));
        LBuf.AppendLine;
      end;
    end;
    FSystemContext := LBuf.ToString;
  finally
    LBuf.Free;
  end;
end;

procedure TC4DWizardAgent.DoOnStep(const AStep: string; AIndex, ATotal: Integer;
  const AResult: TJSONObject);
begin
  if Assigned(FOnStep) then
    FOnStep(AStep, AIndex, ATotal, AResult);
end;

function TC4DWizardAgent.Execute(const AUserRequest: string;
  const ACodeContext: string; AMode: TAgentMode): TJSONObject;
var
  LPlan        : TC4DAgentPlan;
  LToolsJson   : string;
  LCtx         : TJSONObject;
  I            : Integer;
  LStepResult  : TJSONObject;
  LStatus      : string;
begin
  FMemory.Clear;
  FMemory.AddMessage('user', AUserRequest);

  LToolsJson := FMCPServer.ListTools.ToJSON;

  if AMode = amSingleTool then
  begin
    // Fast-path: directly pick+execute one tool
    LCtx := TJSONObject.Create;
    try
      if ACodeContext <> '' then
        LCtx.AddPair('code_context', ACodeContext);
      Result := ExecuteStep(AUserRequest, 0, LCtx);
    finally
      LCtx.Free;
    end;
    Exit;
  end;

  // Multi-step: plan first
  LPlan := FPlanner.Plan(AUserRequest, LToolsJson, FSystemContext);
  try
    LCtx := TJSONObject.Create;
    try
      if ACodeContext <> '' then
        LCtx.AddPair('code_context', ACodeContext);

      LStatus := 'completed';
      for I := 0 to LPlan.Steps.Count - 1 do
      begin
        if FMemory.GetIterationCount(LPlan.TaskId) >= FMaxIterations then
        begin
          LStatus := 'max_iterations_reached';
          Break;
        end;

        LStepResult := ExecuteStep(LPlan.Steps[I], I, LCtx);

        // carry step result into context for the next step
        if Assigned(LStepResult) then
        begin
          LCtx.AddPair(Format('step_%d_result', [I]),
            LStepResult.Clone as TJSONObject);

          FMemory.AddStepResult(LPlan.TaskId, I, LStepResult);
          DoOnStep(LPlan.Steps[I], I, LPlan.Steps.Count, LStepResult);

          // check for explicit failure marker
          if LStepResult.GetValue<string>('status', '') = 'error' then
          begin
            if AMode <> amAutonomous then
            begin
              LStatus := 'step_failed';
              Break;
            end;
            // autonomous: re-plan remaining steps (simple: just continue)
          end;

          LStepResult.Free;
        end;
      end;

      Result := TJSONObject.Create;
      Result.AddPair('task_id', LPlan.TaskId);
      Result.AddPair('status',  LStatus);
      Result.AddPair('steps_completed', TJSONNumber.Create(
        FMemory.GetIterationCount(LPlan.TaskId)));

      var LTaskResult := FMemory.GetTaskResult(LPlan.TaskId);
      if Assigned(LTaskResult) then
        Result.AddPair('results', LTaskResult.Clone as TJSONObject);

    finally
      LCtx.Free;
    end;
  finally
    LPlan.Free;
  end;
end;

function TC4DWizardAgent.PickTool(const AStep: string;
  const AContext: TJSONObject): TJSONObject;
const
  C_SYSTEM =
    'You are a Delphi IDE AI tool dispatcher.' + #13#10 +
    'Given a task step and available MCP tools, choose the BEST tool and extract parameters.' + #13#10 +
    'Return ONLY valid JSON: {"tool":"tool_name","params":{...}}';
var
  LTools  : string;
  LPrompt : string;
  LRaw    : string;
begin
  LTools  := FMCPServer.ListTools.ToJSON;
  LPrompt := Format(
    'Step: "%s"' + #13#10 +
    'Context: %s' + #13#10 +
    'Available tools: %s',
    [AStep, AContext.ToJSON, LTools]);

  LRaw := FAI.GetCompletion(LPrompt, '', C_SYSTEM);
  LRaw := TRegEx.Replace(LRaw, '```[a-z]*\s*', '');
  LRaw := LRaw.Replace('```', '');

  Result := TJSONObject.ParseJSONValue(Trim(LRaw)) as TJSONObject;
  if not Assigned(Result) then
  begin
    // fallback: ask_ai
    Result := TJSONObject.Create;
    Result.AddPair('tool', 'ask_ai');
    var LParams := TJSONObject.Create;
    LParams.AddPair('question', AStep);
    Result.AddPair('params', LParams);
  end;
end;

function TC4DWizardAgent.ExecuteStep(const AStep: string; AStepIdx: Integer;
  const AContext: TJSONObject): TJSONObject;
var
  LDispatch : TJSONObject;
  LToolName : string;
  LParams   : TJSONObject;
begin
  LDispatch := PickTool(AStep, AContext);
  try
    if not Assigned(LDispatch) then
    begin
      Result := TJSONObject.Create;
      Result.AddPair('status', 'error');
      Result.AddPair('message', 'Failed to pick tool for step: ' + AStep);
      Exit;
    end;

    LToolName := LDispatch.GetValue<string>('tool', 'ask_ai');
    LParams   := LDispatch.GetValue<TJSONObject>('params');

    if not Assigned(LParams) then
    begin
      LParams := TJSONObject.Create;
      LParams.AddPair('question', AStep);
    end
    else
      LParams := LParams.Clone as TJSONObject;

    FMemory.AddMessage('assistant',
      Format('[Step %d] Tool: %s  Params: %s', [AStepIdx, LToolName, LParams.ToJSON]),
      AStepIdx);

    try
      Result := FMCPServer.ExecuteTool(LToolName, LParams);
    except
      on E: Exception do
      begin
        Result := TJSONObject.Create;
        Result.AddPair('status', 'error');
        Result.AddPair('message', E.Message);
      end;
    end;
    LParams.Free;
  finally
    LDispatch.Free;
  end;
end;

end.
