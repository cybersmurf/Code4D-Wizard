unit C4D.Wizard.Skill.Base;

{
  Skill Base — Interface + Registry for MCP AI Skills
  =====================================================
  A Skill is a named, schema-validated AI capability that wraps one or more
  MCP tool calls and returns structured JSON output.

  Concrete skills (CodeAnalysis, Generation, etc.) extend TSkillBase.
  The TSkillRegistry is a central registry so the agent can look up skills
  by name and expose them alongside the built-in MCP tools.
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
  // Skill interface
  // -----------------------------------------------------------------------
  IC4DWizardSkill = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    function GetName: string;
    function GetDescription: string;
    function GetCategory: string;
    function Execute(const AParams: TJSONObject): TJSONObject;
    function GetInputSchema: TJSONObject;
    function GetOutputSchema: TJSONObject;
  end;

  // -----------------------------------------------------------------------
  // Abstract base
  // -----------------------------------------------------------------------
  TSkillBase = class abstract(TInterfacedObject, IC4DWizardSkill)
  protected
    FName        : string;
    FDescription : string;
    FCategory    : string;
    FAI          : IC4DWizardAIGitHub;

    function BuildSystemPrompt(const AExtraInstructions: string = ''): string; virtual;
    function ValidateInput(const AParams: TJSONObject): Boolean; virtual;
    function WrapError(const AMsg: string): TJSONObject;
    function WrapResult(const AContent: string): TJSONObject;
  public
    constructor Create(const AAI: IC4DWizardAIGitHub); virtual;

    function GetName: string;
    function GetDescription: string;
    function GetCategory: string;

    function Execute(const AParams: TJSONObject): TJSONObject; virtual; abstract;
    function GetInputSchema: TJSONObject; virtual;
    function GetOutputSchema: TJSONObject; virtual;
  end;

  // -----------------------------------------------------------------------
  // Skill registry - singleton-safe
  // -----------------------------------------------------------------------
  TSkillRegistry = class
  private
    FSkills : TDictionary<string, IC4DWizardSkill>;
    class var FInstance: TSkillRegistry;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Register(const ASkill: IC4DWizardSkill);
    function  GetSkill(const AName: string): IC4DWizardSkill;
    function  HasSkill(const AName: string): Boolean;
    function  ListSkills: TJSONArray;
    function  AllSkills: TArray<IC4DWizardSkill>;

    class function Instance: TSkillRegistry;
    class procedure FreeInstance2;
  end;

implementation

{ TSkillBase }

constructor TSkillBase.Create(const AAI: IC4DWizardAIGitHub);
begin
  FAI := AAI;
end;

function TSkillBase.GetName: string;
begin
  Result := FName;
end;

function TSkillBase.GetDescription: string;
begin
  Result := FDescription;
end;

function TSkillBase.GetCategory: string;
begin
  Result := FCategory;
end;

function TSkillBase.BuildSystemPrompt(const AExtraInstructions: string): string;
begin
  Result :=
    'You are an expert Delphi / RAD Studio developer.' + #13#10 +
    'Generate clean, compilable Object Pascal code.' + #13#10 +
    'Follow Delphi naming conventions (TClassName, FFieldName, etc.).' + #13#10 +
    'Include proper unit structure (interface, implementation, uses).' + #13#10 +
    'Add XML doc comments (/// <summary>).' + #13#10;
  if AExtraInstructions <> '' then
    Result := Result + #13#10 + AExtraInstructions;
end;

function TSkillBase.ValidateInput(const AParams: TJSONObject): Boolean;
begin
  Result := Assigned(AParams);
end;

function TSkillBase.WrapError(const AMsg: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('status', 'error');
  Result.AddPair('message', AMsg);
end;

function TSkillBase.WrapResult(const AContent: string): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('status', 'ok');
  Result.AddPair('content', AContent);
end;

function TSkillBase.GetInputSchema: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
end;

function TSkillBase.GetOutputSchema: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('type', 'object');
end;

{ TSkillRegistry }

class function TSkillRegistry.Instance: TSkillRegistry;
begin
  if not Assigned(FInstance) then
    FInstance := TSkillRegistry.Create;
  Result := FInstance;
end;

class procedure TSkillRegistry.FreeInstance2;
begin
  FreeAndNil(FInstance);
end;

constructor TSkillRegistry.Create;
begin
  FSkills := TDictionary<string, IC4DWizardSkill>.Create;
end;

destructor TSkillRegistry.Destroy;
begin
  FSkills.Free;
  inherited;
end;

procedure TSkillRegistry.Register(const ASkill: IC4DWizardSkill);
begin
  if Assigned(ASkill) then
    FSkills.AddOrSetValue(ASkill.GetName, ASkill);
end;

function TSkillRegistry.GetSkill(const AName: string): IC4DWizardSkill;
begin
  if not FSkills.TryGetValue(AName, Result) then
    raise Exception.CreateFmt('Skill not registered: %s', [AName]);
end;

function TSkillRegistry.HasSkill(const AName: string): Boolean;
begin
  Result := FSkills.ContainsKey(AName);
end;

function TSkillRegistry.ListSkills: TJSONArray;
var
  LSkill : IC4DWizardSkill;
  LItem  : TJSONObject;
begin
  Result := TJSONArray.Create;
  for LSkill in FSkills.Values do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('name',        LSkill.GetName);
    LItem.AddPair('description', LSkill.GetDescription);
    LItem.AddPair('category',    LSkill.GetCategory);
    Result.Add(LItem);
  end;
end;

function TSkillRegistry.AllSkills: TArray<IC4DWizardSkill>;
begin
  Result := FSkills.Values.ToArray;
end;

initialization

finalization
  TSkillRegistry.FreeInstance2;

end.
