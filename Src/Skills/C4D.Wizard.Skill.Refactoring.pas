unit C4D.Wizard.Skill.Refactoring;

{
  Skill: Refactoring
  ===================
  Refactors and optimises existing Delphi code:
    - Rename identifiers to follow conventions
    - Extract methods / remove code duplication
    - Fix Aurelius lazy-loading N+1 anti-patterns
    - Modernise to Delphi 10.3+ syntax (inline var, generics, etc.)

  MCP tool alias: refactor_code
}

interface

uses
  System.SysUtils,
  System.JSON,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Skill.Base;

type
  TC4DSkillRefactoring = class(TSkillBase)
  protected
    function BuildSystemPrompt(const AExtraInstructions: string = ''): string; override;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub); override;

    function Execute(const AParams: TJSONObject): TJSONObject; override;
    function GetInputSchema: TJSONObject; override;
    function GetOutputSchema: TJSONObject; override;
  end;

implementation

constructor TC4DSkillRefactoring.Create(const AAI: IC4DWizardAIGitHub);
begin
  inherited;
  FName        := 'refactor_code';
  FDescription := 'Refactor and modernise existing Delphi code following best practices';
  FCategory    := 'refactoring';
end;

function TC4DSkillRefactoring.BuildSystemPrompt(const AExtraInstructions: string): string;
begin
  Result :=
    'You are a Delphi refactoring expert.' + #13#10 +
    'Refactor the provided code according to the requested goal.' + #13#10 +
    #13#10 +
    'Rules:' + #13#10 +
    '  - Keep behaviour identical unless goal explicitly changes it' + #13#10 +
    '  - Follow Delphi naming conventions (TClassName, FField, etc.)' + #13#10 +
    '  - Prefer inline var / anonymous methods where appropriate (Delphi 10.3+)' + #13#10 +
    '  - Fix memory management issues (try-finally, interface-based lifetime)' + #13#10 +
    '  - Remove N+1 query patterns in Aurelius code' + #13#10 +
    '  - Consolidate duplicate logic into private helpers' + #13#10 +
    #13#10 +
    'Return a JSON object:' + #13#10 +
    '  {"refactored_code":"...","changes":["description of change 1",...],"notes":"..."}' + #13#10 +
    'Return ONLY valid JSON.';
  if AExtraInstructions <> '' then
    Result := Result + #13#10 + AExtraInstructions;
end;

function TC4DSkillRefactoring.Execute(const AParams: TJSONObject): TJSONObject;
var
  LSourceCode : string;
  LGoal       : string;
  LPrompt     : string;
  LRaw        : string;
begin
  if not ValidateInput(AParams) then
    Exit(WrapError('Parameters missing'));

  LSourceCode := AParams.GetValue<string>('source_code', '');
  if LSourceCode.Trim = '' then
    Exit(WrapError('source_code is required'));

  LGoal := AParams.GetValue<string>('goal', 'general refactoring');

  LPrompt := Format(
    'Goal: %s' + #13#10#13#10 +
    'Code to refactor:' + #13#10 + '%s',
    [LGoal, LSourceCode]);

  LRaw := FAI.GetCompletion(LPrompt, '', BuildSystemPrompt);

  var LJson := TJSONObject.ParseJSONValue(LRaw.Trim) as TJSONObject;
  if Assigned(LJson) then
  begin
    LJson.AddPair('status', 'ok');
    Result := LJson;
  end
  else
    Result := WrapResult(LRaw);
end;

function TC4DSkillRefactoring.GetInputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"source_code":{"type":"string","description":"Delphi source code to refactor"},' +
    '"goal":{"type":"string","description":"Refactoring goal (e.g. fix naming, remove duplication, fix N+1)"}' +
    '},"required":["source_code"]}') as TJSONObject;
end;

function TC4DSkillRefactoring.GetOutputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"refactored_code":{"type":"string"},' +
    '"changes":{"type":"array","items":{"type":"string"}},' +
    '"notes":{"type":"string"}' +
    '}}') as TJSONObject;
end;

end.
