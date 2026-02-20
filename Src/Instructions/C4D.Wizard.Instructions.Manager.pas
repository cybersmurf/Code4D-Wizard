unit C4D.Wizard.Instructions.Manager;

{
  Instructions Manager
  =====================
  Loads vendor-agnostic Markdown instruction files from the
  Config\instructions\ directory and makes them available to the AI agent.

  Files are identified by their filename without extension:
    base.md           -> key 'base'
    delphi-expert.md  -> key 'delphi-expert'
    flexgrid.md       -> key 'flexgrid'
    emistr.md         -> key 'emistr'

  Token substitution: ${var} is replaced with environment variable values.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.IOUtils;

type
  // -----------------------------------------------------------------------
  // Interface
  // -----------------------------------------------------------------------
  IC4DWizardInstructionsManager = interface
    ['{12345678-9ABC-DEF0-1234-567890ABCDEF}']
    procedure LoadFromDirectory(const APath: string);
    function  GetInstruction(const AName: string): string;
    function  GetCombined(const ANames: array of string): string;
    function  AvailableKeys: TArray<string>;
  end;

  // -----------------------------------------------------------------------
  // Concrete implementation
  // -----------------------------------------------------------------------
  TC4DWizardInstructionsManager = class(TInterfacedObject, IC4DWizardInstructionsManager)
  private
    FInstructions : TDictionary<string, string>;

    function ResolveTokens(const AText: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromDirectory(const APath: string);
    function  GetInstruction(const AName: string): string;
    function  GetCombined(const ANames: array of string): string;
    function  AvailableKeys: TArray<string>;

    class function New: IC4DWizardInstructionsManager;
    class function DefaultPath: string;
  end;

implementation

uses
  System.RegularExpressions;

{ TC4DWizardInstructionsManager }

class function TC4DWizardInstructionsManager.New: IC4DWizardInstructionsManager;
begin
  Result := Self.Create;
end;

class function TC4DWizardInstructionsManager.DefaultPath: string;
begin
  // <wizard BPL dir>\Config\instructions
  Result := TPath.Combine(
    TPath.GetDirectoryName(ParamStr(0)),
    TPath.Combine('Config', 'instructions'));
end;

constructor TC4DWizardInstructionsManager.Create;
begin
  FInstructions := TDictionary<string, string>.Create;
end;

destructor TC4DWizardInstructionsManager.Destroy;
begin
  FInstructions.Free;
  inherited;
end;

function TC4DWizardInstructionsManager.ResolveTokens(const AText: string): string;
begin
  // Replace ${env:VAR} with environment variable value
  Result := TRegEx.Replace(AText, '\$\{env:([^}]+)\}',
    function(const AMatch: TMatch): string
    begin
      Result := GetEnvironmentVariable(AMatch.Groups[1].Value);
    end);

  // Replace ${var} (bare) same way
  Result := TRegEx.Replace(Result, '\$\{([^:}][^}]*)\}',
    function(const AMatch: TMatch): string
    begin
      Result := GetEnvironmentVariable(AMatch.Groups[1].Value);
    end);
end;

procedure TC4DWizardInstructionsManager.LoadFromDirectory(const APath: string);
var
  LFiles : TArray<string>;
  LFile  : string;
  LKey   : string;
  LContent : string;
begin
  if not TDirectory.Exists(APath) then
    Exit;  // silently skip missing directory

  LFiles := TDirectory.GetFiles(APath, '*.md');
  for LFile in LFiles do
  begin
    LKey     := TPath.GetFileNameWithoutExtension(LFile).ToLower;
    LContent := ResolveTokens(TFile.ReadAllText(LFile, TEncoding.UTF8));
    FInstructions.AddOrSetValue(LKey, LContent);
  end;
end;

function TC4DWizardInstructionsManager.GetInstruction(
  const AName: string): string;
begin
  if not FInstructions.TryGetValue(AName.ToLower, Result) then
    Result := '';
end;

function TC4DWizardInstructionsManager.GetCombined(
  const ANames: array of string): string;
var
  LName : string;
  LBuf  : TStringBuilder;
begin
  LBuf := TStringBuilder.Create;
  try
    for LName in ANames do
    begin
      var LText := GetInstruction(LName);
      if LText <> '' then
      begin
        LBuf.AppendLine(LText);
        LBuf.AppendLine;
      end;
    end;
    Result := LBuf.ToString;
  finally
    LBuf.Free;
  end;
end;

function TC4DWizardInstructionsManager.AvailableKeys: TArray<string>;
begin
  Result := FInstructions.Keys.ToArray;
end;

end.
