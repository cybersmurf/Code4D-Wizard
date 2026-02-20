unit C4D.Wizard.Agent.Planning;

{
  Agent Planning - Task decomposition via GitHub Models
  ======================================================
  Given a free-form user request, the planner asks the AI to break it down
  into a list of concrete execution steps.  Each step is a plain-text
  instruction that the execution loop can route to the appropriate MCP tool.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  C4D.Wizard.AI.GitHub;

type
  // -----------------------------------------------------------------------
  // Result of task decomposition
  // -----------------------------------------------------------------------
  TC4DAgentPlan = record
    TaskId      : string;
    Description : string;
    Steps       : TStringList;   // owns the list

    class function Create(const AId, ADesc: string): TC4DAgentPlan; static;
    procedure Free;
  end;

  // -----------------------------------------------------------------------
  // Interface
  // -----------------------------------------------------------------------
  IC4DWizardAgentPlanner = interface
    ['{AABBCCDD-EEFF-0011-2233-445566778899}']
    function Plan(const AUserRequest: string;
      const AToolsJson: string;
      const ASystemContext: string = ''): TC4DAgentPlan;
  end;

  // -----------------------------------------------------------------------
  // Concrete planner
  // -----------------------------------------------------------------------
  TC4DWizardAgentPlanner = class(TInterfacedObject, IC4DWizardAgentPlanner)
  private
    FAI: IC4DWizardAIGitHub;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub);

    function Plan(const AUserRequest: string;
      const AToolsJson: string;
      const ASystemContext: string = ''): TC4DAgentPlan;

    class function New(const AAI: IC4DWizardAIGitHub): IC4DWizardAgentPlanner;
  end;

implementation

uses
  System.RegularExpressions;

{ TC4DAgentPlan }

class function TC4DAgentPlan.Create(const AId, ADesc: string): TC4DAgentPlan;
begin
  Result.TaskId      := AId;
  Result.Description := ADesc;
  Result.Steps       := TStringList.Create;
end;

procedure TC4DAgentPlan.Free;
begin
  Steps.Free;
end;

{ TC4DWizardAgentPlanner }

class function TC4DWizardAgentPlanner.New(const AAI: IC4DWizardAIGitHub): IC4DWizardAgentPlanner;
begin
  Result := Self.Create(AAI);
end;

constructor TC4DWizardAgentPlanner.Create(const AAI: IC4DWizardAIGitHub);
begin
  FAI := AAI;
end;

function TC4DWizardAgentPlanner.Plan(const AUserRequest: string;
  const AToolsJson: string;
  const ASystemContext: string): TC4DAgentPlan;
const
  C_SYSTEM =
    'You are a task planner for a Delphi IDE AI assistant.' + #13#10 +
    'Break the user request into a numbered list of concrete, actionable steps.' + #13#10 +
    'Each step must be achievable using ONE of the provided MCP tools.' + #13#10 +
    'Return ONLY valid JSON: {"steps":["step1","step2",...]}' + #13#10 +
    'Keep each step short and tool-focused.';
var
  LPrompt  : string;
  LRaw     : string;
  LJson    : TJSONObject;
  LSteps   : TJSONArray;
  I        : Integer;
  LPlan    : TC4DAgentPlan;
begin
  LPlan := TC4DAgentPlan.Create(TGUID.NewGuid.ToString, AUserRequest);

  LPrompt := Format(
    'User request: "%s"' + #13#10#13#10 +
    'Available tools:' + #13#10 + '%s' + #13#10#13#10 +
    '%s',
    [AUserRequest, AToolsJson, ASystemContext]);

  LRaw := FAI.GetCompletion(LPrompt, '', C_SYSTEM);

  // strip possible markdown fence
  LRaw := TRegEx.Replace(LRaw, '```[a-z]*\s*', '');
  LRaw := LRaw.Replace('```', '');

  LJson := TJSONObject.ParseJSONValue(Trim(LRaw)) as TJSONObject;
  try
    if Assigned(LJson) then
    begin
      LSteps := LJson.GetValue<TJSONArray>('steps');
      if Assigned(LSteps) then
        for I := 0 to LSteps.Count - 1 do
          LPlan.Steps.Add(LSteps.Items[I].Value);
    end;
  finally
    LJson.Free;
  end;

  // fallback: treat the whole request as a single step
  if LPlan.Steps.Count = 0 then
    LPlan.Steps.Add(AUserRequest);

  Result := LPlan;
end;

end.
