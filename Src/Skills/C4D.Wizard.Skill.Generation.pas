unit C4D.Wizard.Skill.Generation;

{
  Skill: Code Generation
  =======================
  Generates Delphi code from a description:
    - Aurelius entity class with all required attributes
    - XData ServiceContract + implementation stub
    - Repository / Manager class

  MCP tool alias: generate_service
}

interface

uses
  System.SysUtils,
  System.JSON,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Skill.Base;

type
  TGenerationTarget = (gtEntity, gtService, gtRepository);

  TC4DSkillGeneration = class(TSkillBase)
  protected
    function BuildSystemPrompt(const AExtraInstructions: string = ''): string; override;
    function TargetFromString(const AStr: string): TGenerationTarget;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub); override;

    function Execute(const AParams: TJSONObject): TJSONObject; override;
    function GetInputSchema: TJSONObject; override;
    function GetOutputSchema: TJSONObject; override;
  end;

implementation

constructor TC4DSkillGeneration.Create(const AAI: IC4DWizardAIGitHub);
begin
  inherited;
  FName        := 'generate_service';
  FDescription := 'Generate Delphi entity, XData service contract, or repository class from a description';
  FCategory    := 'code-generation';
end;

function TC4DSkillGeneration.TargetFromString(const AStr: string): TGenerationTarget;
var
  L: string;
begin
  L := AStr.ToLower;
  if L.Contains('service') or L.Contains('contract') or L.Contains('xdata') then
    Result := gtService
  else if L.Contains('repo') or L.Contains('manager') then
    Result := gtRepository
  else
    Result := gtEntity;
end;

function TC4DSkillGeneration.BuildSystemPrompt(const AExtraInstructions: string): string;
begin
  Result :=
    'You are an expert Delphi RAD Studio developer specialised in TMS Aurelius and TMS XData.' + #13#10 +
    'Generate complete, compilable Delphi 12 Object Pascal code.' + #13#10 +
    #13#10 +
    'For ENTITIES:' + #13#10 +
    '  - Use [Entity, Automapping] + [Table(''TB_NAME'')]' + #13#10 +
    '  - Include [Id] with TIdGenerator.IdentityOrSequence' + #13#10 +
    '  - Add Created:TDateTime and Modified:TNullableDateTime audit fields' + #13#10 +
    '  - Follow FlexGrid naming: T{Module}{Entity}  (e.g. THREmployee)' + #13#10 +
    '  - Include proper associations with cascade rules' + #13#10 +
    #13#10 +
    'For SERVICES (XData):' + #13#10 +
    '  - Use [ServiceContract] on the interface' + #13#10 +
    '  - Add [HttpGet/Post/Put/Delete] + [Route] on each operation' + #13#10 +
    '  - Implement proper error handling (EXDataHttpUnauthorized, etc.)' + #13#10 +
    #13#10 +
    'Add XML doc comments (/// <summary>).' + #13#10 +
    'Return a JSON object: {"unit_name":"...","source_code":"...","notes":"..."}' + #13#10 +
    'Return ONLY valid JSON.';
  if AExtraInstructions <> '' then
    Result := Result + #13#10 + AExtraInstructions;
end;

function TC4DSkillGeneration.Execute(const AParams: TJSONObject): TJSONObject;
var
  LDescription : string;
  LTarget      : string;
  LModule      : string;
  LExisting    : string;
  LPrompt      : string;
  LRaw         : string;
begin
  if not ValidateInput(AParams) then
    Exit(WrapError('Parameters missing'));

  LDescription := AParams.GetValue<string>('description', '');
  if LDescription.Trim = '' then
    Exit(WrapError('description is required'));

  LTarget   := AParams.GetValue<string>('target', 'entity');
  LModule   := AParams.GetValue<string>('module', '');
  LExisting := AParams.GetValue<string>('existing_code', '');

  LPrompt := Format('Generate a Delphi %s for: %s', [LTarget, LDescription]);
  if LModule <> '' then
    LPrompt := LPrompt + #13#10 + 'FlexGrid module: ' + LModule;
  if LExisting <> '' then
    LPrompt := LPrompt + #13#10 + #13#10 + 'Existing code to extend:' + #13#10 + LExisting;

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

function TC4DSkillGeneration.GetInputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"description":{"type":"string","description":"What to generate"},' +
    '"target":{"type":"string","enum":["entity","service","repository"],"default":"entity"},' +
    '"module":{"type":"string","description":"FlexGrid module context"},' +
    '"existing_code":{"type":"string","description":"Optional existing code to extend"}' +
    '},"required":["description"]}') as TJSONObject;
end;

function TC4DSkillGeneration.GetOutputSchema: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(
    '{"type":"object","properties":{' +
    '"unit_name":{"type":"string"},' +
    '"source_code":{"type":"string"},' +
    '"notes":{"type":"string"}' +
    '}}') as TJSONObject;
end;

end.
