unit C4D.Wizard.Agent.Memory;

{
  Agent Memory - Conversation & context memory store
  =====================================================
  Keeps a rolling history of tasks, step results, and conversation messages
  so that multi-step agentic operations can build context across calls.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON;

type
  // -----------------------------------------------------------------------
  // Single item in the conversation history (role + content)
  // -----------------------------------------------------------------------
  TC4DAgentMessage = record
    Role    : string;   // 'user' | 'assistant' | 'system'
    Content : string;
    StepIdx : Integer;  // -1 for non-step messages
  end;

  // -----------------------------------------------------------------------
  // Memory interface
  // -----------------------------------------------------------------------
  IC4DWizardAgentMemory = interface
    ['{11223344-5566-7788-99AA-BBCCDDEEFF00}']
    procedure AddMessage(const ARole, AContent: string; AStepIdx: Integer = -1);
    procedure AddStepResult(const ATaskId: string; AStepIdx: Integer;
      const AResult: TJSONObject);
    function  GetTaskResult(const ATaskId: string): TJSONObject;
    function  GetIterationCount(const ATaskId: string): Integer;
    function  GetMessages: TArray<TC4DAgentMessage>;
    procedure Clear;
  end;

  // -----------------------------------------------------------------------
  // Concrete memory store
  // -----------------------------------------------------------------------
  TC4DWizardAgentMemory = class(TInterfacedObject, IC4DWizardAgentMemory)
  private
    FMessages        : TList<TC4DAgentMessage>;
    FStepResults     : TObjectDictionary<string, TJSONObject>;  // key = 'taskId:stepIdx'
    FIterationCounts : TDictionary<string, Integer>;
    FTaskResults     : TObjectDictionary<string, TJSONObject>;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddMessage(const ARole, AContent: string; AStepIdx: Integer = -1);
    procedure AddStepResult(const ATaskId: string; AStepIdx: Integer;
      const AResult: TJSONObject);
    function  GetTaskResult(const ATaskId: string): TJSONObject;
    function  GetIterationCount(const ATaskId: string): Integer;
    function  GetMessages: TArray<TC4DAgentMessage>;
    procedure Clear;

    class function New: IC4DWizardAgentMemory;
  end;

implementation

{ TC4DWizardAgentMemory }

class function TC4DWizardAgentMemory.New: IC4DWizardAgentMemory;
begin
  Result := Self.Create;
end;

constructor TC4DWizardAgentMemory.Create;
begin
  FMessages        := TList<TC4DAgentMessage>.Create;
  FStepResults     := TObjectDictionary<string, TJSONObject>.Create([doOwnsValues]);
  FIterationCounts := TDictionary<string, Integer>.Create;
  FTaskResults     := TObjectDictionary<string, TJSONObject>.Create([doOwnsValues]);
end;

destructor TC4DWizardAgentMemory.Destroy;
begin
  FMessages.Free;
  FStepResults.Free;
  FIterationCounts.Free;
  FTaskResults.Free;
  inherited;
end;

procedure TC4DWizardAgentMemory.AddMessage(const ARole, AContent: string;
  AStepIdx: Integer);
var
  LMsg: TC4DAgentMessage;
begin
  LMsg.Role    := ARole;
  LMsg.Content := AContent;
  LMsg.StepIdx := AStepIdx;
  FMessages.Add(LMsg);
end;

procedure TC4DWizardAgentMemory.AddStepResult(const ATaskId: string;
  AStepIdx: Integer; const AResult: TJSONObject);
var
  LKey     : string;
  LCount   : Integer;
  LMerged  : TJSONObject;
begin
  if not Assigned(AResult) then
    Exit;

  LKey := ATaskId + ':' + AStepIdx.ToString;
  FStepResults.AddOrSetValue(LKey, AResult.Clone as TJSONObject);

  // accumulate iteration counter
  if not FIterationCounts.TryGetValue(ATaskId, LCount) then
    LCount := 0;
  FIterationCounts.AddOrSetValue(ATaskId, LCount + 1);

  // merge into task-level result
  if not FTaskResults.TryGetValue(ATaskId, LMerged) then
  begin
    LMerged := TJSONObject.Create;
    FTaskResults.Add(ATaskId, LMerged);
  end;
  LMerged.AddPair(Format('step_%d', [AStepIdx]), AResult.Clone as TJSONObject);
end;

function TC4DWizardAgentMemory.GetTaskResult(const ATaskId: string): TJSONObject;
begin
  if not FTaskResults.TryGetValue(ATaskId, Result) then
    Result := nil;
end;

function TC4DWizardAgentMemory.GetIterationCount(const ATaskId: string): Integer;
begin
  if not FIterationCounts.TryGetValue(ATaskId, Result) then
    Result := 0;
end;

function TC4DWizardAgentMemory.GetMessages: TArray<TC4DAgentMessage>;
begin
  Result := FMessages.ToArray;
end;

procedure TC4DWizardAgentMemory.Clear;
begin
  FMessages.Clear;
  FStepResults.Clear;
  FIterationCounts.Clear;
  FTaskResults.Clear;
end;

end.
