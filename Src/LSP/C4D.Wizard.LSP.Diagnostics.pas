unit C4D.Wizard.LSP.Diagnostics;

{ Base types and abstract rule class for the Code4D LSP diagnostics engine.
  Concrete rule sets live in separate units (e.g. C4D.Wizard.LSP.Diagnostics.Generic). }

interface

uses
  System.SysUtils,
  System.Generics.Collections;

type
  /// <summary>Diagnostic severity level.</summary>
  TDiagnosticSeverity = (dsError, dsWarning, dsInfo, dsHint);

  /// <summary>Single diagnostic result produced by a rule check.</summary>
  TDiagnostic = record
    /// 1-based source line number.
    Line    : Integer;
    /// 1-based column number.
    Column  : Integer;
    /// Length of the highlighted span (characters).
    Length  : Integer;
    Message : string;
    Severity: TDiagnosticSeverity;
    /// Short rule identifier, e.g. 'DELPHI001'.
    Code    : string;
    /// Rule source identifier, e.g. 'delphi'.
    Source  : string;
  end;

  /// <summary>
  ///   Abstract base class for a single diagnostic rule.
  ///   Subclass and override GetName / GetDescription / Check.
  /// </summary>
  TDiagnosticRule = class abstract
  public
    function GetName       : string; virtual; abstract;
    function GetDescription: string; virtual; abstract;
    /// <summary>Analyse ASource and return any diagnostics found.</summary>
    function Check(const ASource: string): TArray<TDiagnostic>; virtual; abstract;
  end;

  /// <summary>
  ///   Runs a collection of TDiagnosticRule instances against a source string
  ///   and accumulates results.
  /// </summary>
  TDiagnosticsEngine = class
  private
    FRules: TObjectList<TDiagnosticRule>;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>Register a rule with the engine (takes ownership).</summary>
    procedure RegisterRule(ARule: TDiagnosticRule);

    /// <summary>Run all registered rules against ASource.</summary>
    function  Analyze(const ASource: string): TArray<TDiagnostic>;
  end;

implementation

{ TDiagnosticsEngine }

constructor TDiagnosticsEngine.Create;
begin
  inherited Create;
  FRules := TObjectList<TDiagnosticRule>.Create(True {OwnsObjects});
end;

destructor TDiagnosticsEngine.Destroy;
begin
  FRules.Free;
  inherited;
end;

procedure TDiagnosticsEngine.RegisterRule(ARule: TDiagnosticRule);
begin
  FRules.Add(ARule);
end;

function TDiagnosticsEngine.Analyze(const ASource: string): TArray<TDiagnostic>;
var
  Rule            : TDiagnosticRule;
  RuleDiagnostics : TArray<TDiagnostic>;
  All             : TList<TDiagnostic>;
  D               : TDiagnostic;
begin
  All := TList<TDiagnostic>.Create;
  try
    for Rule in FRules do
    begin
      RuleDiagnostics := Rule.Check(ASource);
      for D in RuleDiagnostics do
        All.Add(D);
    end;
    Result := All.ToArray;
  finally
    All.Free;
  end;
end;

end.
