unit C4D.Wizard.Skill.CodeAnalysis;

{
  Skill: Code Analysis
  =====================
  Analyzes Delphi / Aurelius entity or service code and returns:
    - A list of issues (severity, line hint, message, suggestion)
    - Optionally the corrected source code

  MCP tool alias: analyze_entity
}

interface

uses
  System.SysUtils,
  System.JSON,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Skill.Base;

type
  TC4DSkillCodeAnalysis = class(TSkillBase)
  protected
    function BuildSystemPrompt(const AExtraInstructions: string = ''): string; override;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub); override;

    function Execute(const AParams: TJSONObject): TJSONObject; override;
    function GetInputSchema: TJSONObject; override;
    function GetOutputSchema: TJSONObject; override;
  end;

implementation

constructor TC4DSkillCodeAnalysis.Create(const AAI: IC4DWizardAIGitHub);
begin
  inherited;
  FName        := 'analyze_entity';
  FDescription := 'Deep analysis of Delphi/Aurelius entity or service code with FlexGrid best-practices feedback';
  FCategory    := 'code-analysis';
end;

function TC4DSkillCodeAnalysis.BuildSystemPrompt(const AExtraInstructions: string): string;
begin
  Result :=
    'You are a Delphi code reviewer specialised in TMS Aurelius ORM.' + #13#10 +
    'Analyze the provided entity class and return a JSON object with:' + #13#10 +
    '  "issues": array of {severity, line, message, suggestion}' + #13#10 +
    '  "suggested_code": corrected source (optional, only if changes needed)' + #13#10 +
    '  "summary": brief plain-text summary' + #13#10 +
    'severity values: "error" | "warning" | "info"' + #13#10 +
    'Check for: missing [Entity,Automapping], missing [Id], wrong cascade rules,' + #13#10 +
    '  missing audit fields (Created, Modified), N+1 risks, missing indexes,' + #13#10 +
    '  FlexGrid naming convention (T{Module}{Entity}).' + #13#10 +
    'Return ONLY valid JSON.';
end;

function TC4DSkillCodeAnalysis.Execute(const AParams: TJSONObject): TJSONObject;
var
  LEntityCode : string;
  LModule     : string;
  LRaw        : string;
  LPrompt     : string;
begin
  if not ValidateInput(AParams) then
    Exit(WrapError('Parameters missing'));

  LEntityCode := AParams.GetValue<string>('entity_code', '');
  if LEntityCode.Trim = '' then
    Exit(WrapError('entity_code is required'));

  LModule := AParams.GetValue<string>('module', '');

  LPrompt := 'Analyze this Delphi entity';
  if LModule <> '' then
    LPrompt := LPrompt + ' (FlexGrid module: ' + LModule + ')';
  LPrompt := LPrompt + ':' + #13#10#13#10 + LEntityCode;

  LRaw := FAI.GetCompletion(LPrompt, '', BuildSystemPrompt);

  // Try to parse as JSON; if not valid, wrap as plain content
  var LJson := TJSONObject.ParseJSONValue(LRaw.Trim) as TJSONObject;
  if Assigned(LJson) then
  begin
    LJson.AddPair('status', 'ok');
    Result := LJson;
  end
  else
    Result := WrapResult(LRaw);
end;

function TC4DSkillCodeAnalysis.GetInputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"entity_code":{"type":"string","description":"Complete entity class source code"},' +
    '"module":{"type":"string","description":"FlexGrid module context (HR/Inventory/Planning/Quality/Stations)"},' +
    '"check_indexes":{"type":"boolean","default":true},' +
    '"check_associations":{"type":"boolean","default":true}' +
    '},"required":["entity_code"]}') as TJSONObject;
end;

function TC4DSkillCodeAnalysis.GetOutputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"issues":{"type":"array"},' +
    '"suggested_code":{"type":"string"},' +
    '"summary":{"type":"string"}' +
    '}}') as TJSONObject;
end;

end.
