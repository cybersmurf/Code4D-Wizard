unit C4D.Wizard.Skill.Documentation;

{
  Skill: Documentation Generation
  =================================
  Generates XML documentation comments for Delphi units, classes, and methods.
  Also generates Markdown API docs and README snippets.

  MCP tool alias: generate_docs
}

interface

uses
  System.SysUtils,
  System.JSON,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Skill.Base;

type
  TC4DSkillDocumentation = class(TSkillBase)
  protected
    function BuildSystemPrompt(const AExtraInstructions: string = ''): string; override;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub); override;

    function Execute(const AParams: TJSONObject): TJSONObject; override;
    function GetInputSchema: TJSONObject; override;
    function GetOutputSchema: TJSONObject; override;
  end;

implementation

constructor TC4DSkillDocumentation.Create(const AAI: IC4DWizardAIGitHub);
begin
  inherited;
  FName        := 'generate_docs';
  FDescription := 'Generate XML documentation comments and/or Markdown API docs for Delphi code';
  FCategory    := 'documentation';
end;

function TC4DSkillDocumentation.BuildSystemPrompt(const AExtraInstructions: string): string;
begin
  Result :=
    'You are a Delphi documentation expert.' + #13#10 +
    'Generate clear, concise documentation for the provided code.' + #13#10 +
    #13#10 +
    'For XML docs (format=xml):' + #13#10 +
    '  - Use /// <summary>, /// <param name="X">, /// <returns>, /// <remarks>' + #13#10 +
    '  - Place comments immediately before the declaration' + #13#10 +
    '  - Keep summaries to 1-2 sentences' + #13#10 +
    #13#10 +
    'For Markdown docs (format=markdown):' + #13#10 +
    '  - Use ## for class name, ### for methods' + #13#10 +
    '  - Include parameter and return value tables' + #13#10 +
    '  - Add a usage example per method' + #13#10 +
    #13#10 +
    'Return a JSON object:' + #13#10 +
    '  {"documented_code":"...","format":"xml|markdown","notes":"..."}' + #13#10 +
    'Return ONLY valid JSON.';
  if AExtraInstructions <> '' then
    Result := Result + #13#10 + AExtraInstructions;
end;

function TC4DSkillDocumentation.Execute(const AParams: TJSONObject): TJSONObject;
var
  LSourceCode : string;
  LFormat     : string;
  LScope      : string;
  LPrompt     : string;
  LRaw        : string;
begin
  if not ValidateInput(AParams) then
    Exit(WrapError('Parameters missing'));

  LSourceCode := AParams.GetValue<string>('source_code', '');
  if LSourceCode.Trim = '' then
    Exit(WrapError('source_code is required'));

  LFormat := AParams.GetValue<string>('format', 'xml');
  LScope  := AParams.GetValue<string>('scope', 'all');  // 'all'|'public'|'published'

  LPrompt := Format(
    'Generate %s documentation (scope: %s) for:' + #13#10#13#10 + '%s',
    [LFormat, LScope, LSourceCode]);

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

function TC4DSkillDocumentation.GetInputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"source_code":{"type":"string","description":"Delphi source code to document"},' +
    '"format":{"type":"string","enum":["xml","markdown"],"default":"xml"},' +
    '"scope":{"type":"string","enum":["all","public","published"],"default":"all"}' +
    '},"required":["source_code"]}') as TJSONObject;
end;

function TC4DSkillDocumentation.GetOutputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"documented_code":{"type":"string"},' +
    '"format":{"type":"string"},' +
    '"notes":{"type":"string"}' +
    '}}') as TJSONObject;
end;

end.
