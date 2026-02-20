unit C4D.Wizard.LSP.Diagnostics.Generic;

{ Generic Delphi diagnostic rules — no framework-specific logic.
  Rules included:
    DELPHI001  missing_try_finally        — .Create without try-finally around .Free
    DELPHI002  string_concat_in_loop      — string := string + … inside a loop
    DELPHI003  direct_ui_from_thread      — UI component access without Synchronize
    DELPHI004  deprecated_api             — usage of deprecated RTL identifiers }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Math,
  System.RegularExpressions,
  C4D.Wizard.LSP.Diagnostics;

type
  { DELPHI001 }
  TMissingTryFinallyRule = class(TDiagnosticRule)
  public
    function GetName       : string; override;
    function GetDescription: string; override;
    function Check(const ASource: string): TArray<TDiagnostic>; override;
  end;

  { DELPHI002 }
  TStringConcatenationInLoopRule = class(TDiagnosticRule)
  public
    function GetName       : string; override;
    function GetDescription: string; override;
    function Check(const ASource: string): TArray<TDiagnostic>; override;
  end;

  { DELPHI003 }
  TDirectUIFromThreadRule = class(TDiagnosticRule)
  public
    function GetName       : string; override;
    function GetDescription: string; override;
    function Check(const ASource: string): TArray<TDiagnostic>; override;
  end;

  { DELPHI004 }
  TDeprecatedAPIRule = class(TDiagnosticRule)
  public
    function GetName       : string; override;
    function GetDescription: string; override;
    function Check(const ASource: string): TArray<TDiagnostic>; override;
  end;

/// <summary>
///   Create a TDiagnosticsEngine pre-loaded with all generic Delphi rules.
///   Caller is responsible for freeing the returned instance.
/// </summary>
function CreateGenericDiagnosticsEngine: TDiagnosticsEngine;

implementation

{ helpers }

function BuildDiag(ALine, ACol, ALen: Integer; const AMsg: string;
  ASeverity: TDiagnosticSeverity; const ACode, ASource: string): TDiagnostic;
begin
  Result.Line     := ALine;
  Result.Column   := ACol;
  Result.Length   := ALen;
  Result.Message  := AMsg;
  Result.Severity := ASeverity;
  Result.Code     := ACode;
  Result.Source   := ASource;
end;

{ TMissingTryFinallyRule }

function TMissingTryFinallyRule.GetName: string;
begin
  Result := 'missing_try_finally';
end;

function TMissingTryFinallyRule.GetDescription: string;
begin
  Result := 'Object created with .Create but freed without a protecting try-finally block';
end;

function TMissingTryFinallyRule.Check(const ASource: string): TArray<TDiagnostic>;
const
  LOOKAHEAD = 15;
var
  Lines      : TStringList;
  I, J       : Integer;
  HasTry     : Boolean;
  HasFree    : Boolean;
  Diags      : TList<TDiagnostic>;
  CreateRx   : TRegEx;
  FreeRx     : TRegEx;
  TryRx      : TRegEx;
begin
  Lines := TStringList.Create;
  Diags := TList<TDiagnostic>.Create;
  try
    Lines.Text := ASource;
    CreateRx   := TRegEx.Create('\.Create\s*(\(|;)',  [roIgnoreCase]);
    FreeRx     := TRegEx.Create('\.Free\s*;',          [roIgnoreCase]);
    TryRx      := TRegEx.Create('\btry\b',             [roIgnoreCase]);

    for I := 0 to Lines.Count - 1 do
    begin
      if not CreateRx.IsMatch(Lines[I]) then
        Continue;

      HasTry  := False;
      HasFree := False;
      for J := I + 1 to Min(I + LOOKAHEAD, Lines.Count - 1) do
      begin
        if TryRx.IsMatch(Lines[J])  then HasTry  := True;
        if FreeRx.IsMatch(Lines[J]) then HasFree := True;
      end;

      if HasFree and not HasTry then
        Diags.Add(BuildDiag(I + 1, 1, Lines[I].Length,
          'Object created without try-finally protection — potential memory leak if an exception is raised',
          dsWarning, 'DELPHI001', 'delphi'));
    end;

    Result := Diags.ToArray;
  finally
    Diags.Free;
    Lines.Free;
  end;
end;

{ TStringConcatenationInLoopRule }

function TStringConcatenationInLoopRule.GetName: string;
begin
  Result := 'string_concat_in_loop';
end;

function TStringConcatenationInLoopRule.GetDescription: string;
begin
  Result := 'String concatenation operator (+) used inside a loop — use TStringBuilder for O(n) performance';
end;

function TStringConcatenationInLoopRule.Check(const ASource: string): TArray<TDiagnostic>;
var
  Lines   : TStringList;
  I       : Integer;
  Line    : string;
  InLoop  : Integer; // nesting depth
  Diags   : TList<TDiagnostic>;
  LoopRx  : TRegEx;
  EndRx   : TRegEx;
  UntilRx : TRegEx;
begin
  Lines := TStringList.Create;
  Diags := TList<TDiagnostic>.Create;
  try
    Lines.Text := ASource;
    LoopRx  := TRegEx.Create('\b(for|while|repeat)\b', [roIgnoreCase]);
    EndRx   := TRegEx.Create('^end\s*;',               [roIgnoreCase]);
    UntilRx := TRegEx.Create('^until\b',               [roIgnoreCase]);
    InLoop  := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I].Trim;

      if LoopRx.IsMatch(Line)  then Inc(InLoop);
      if EndRx.IsMatch(Line)   then Dec(InLoop);
      if UntilRx.IsMatch(Line) then Dec(InLoop);

      if InLoop <= 0 then
        InLoop := 0;

      // Flag string concat only when *inside* a loop
      if (InLoop > 0)
        and Line.Contains(' := ')
        and Line.Contains(' + ')
        and (TRegEx.IsMatch(Line, ':=\s*.+\s*\+\s*', [roIgnoreCase])) then
      begin
        Diags.Add(BuildDiag(I + 1, 1, Line.Length,
          'String concatenation in loop — use TStringBuilder for better performance',
          dsWarning, 'DELPHI002', 'delphi'));
      end;
    end;

    Result := Diags.ToArray;
  finally
    Diags.Free;
    Lines.Free;
  end;
end;

{ TDirectUIFromThreadRule }

function TDirectUIFromThreadRule.GetName: string;
begin
  Result := 'direct_ui_from_thread';
end;

function TDirectUIFromThreadRule.GetDescription: string;
begin
  Result := 'Possible direct VCL/FMX UI access inside TThread.Execute without Synchronize/Queue';
end;

function TDirectUIFromThreadRule.Check(const ASource: string): TArray<TDiagnostic>;
var
  Lines      : TStringList;
  I          : Integer;
  Line       : string;
  InExecute  : Boolean;
  InSync     : Integer;
  Diags      : TList<TDiagnostic>;
  UIPatternRx: TRegEx;
begin
  Lines := TStringList.Create;
  Diags := TList<TDiagnostic>.Create;
  try
    Lines.Text := ASource;
    // Rough heuristic: .Caption :=, .Text :=, .Color :=, .Visible :=, .Enabled :=
    UIPatternRx := TRegEx.Create(
      '\.(Caption|Text|Color|Visible|Enabled|Items|Lines|Value)\s*:=',
      [roIgnoreCase]);

    InExecute := False;
    InSync    := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I].Trim;

      if TRegEx.IsMatch(Line, '\bprocedure\s+\w+\.Execute\b', [roIgnoreCase]) then
        InExecute := True;

      // Track Synchronize / Queue blocks (anonymous proc)
      if InExecute and TRegEx.IsMatch(Line, '\b(Synchronize|Queue)\s*\(', [roIgnoreCase]) then
        Inc(InSync);
      if (InSync > 0) and TRegEx.IsMatch(Line, '^end\b', [roIgnoreCase]) then
        Dec(InSync);

      if InExecute and (InSync = 0) and UIPatternRx.IsMatch(Line) then
        Diags.Add(BuildDiag(I + 1, 1, Line.Length,
          'Possible UI property assignment in TThread.Execute without Synchronize/Queue',
          dsWarning, 'DELPHI003', 'delphi'));

      // End of Execute procedure
      if InExecute and TRegEx.IsMatch(Line, '^end\s*;', [roIgnoreCase]) and (InSync = 0) then
        InExecute := False;
    end;

    Result := Diags.ToArray;
  finally
    Diags.Free;
    Lines.Free;
  end;
end;

{ TDeprecatedAPIRule }

const
  C_DEPRECATED: array[0..5] of record Call, Replacement: string end = (
    (Call: 'IntToStr';    Replacement: 'use Int.ToString or Format'),   // not deprecated, just an example alternative
    (Call: 'StrToInt';    Replacement: 'use StrToIntDef for safety'),
    (Call: 'AssignFile';  Replacement: 'use TStreamReader/TFile'),
    (Call: 'CloseFile';   Replacement: 'use TStreamReader/TFile'),
    (Call: 'Append(';     Replacement: 'use TStreamWriter'),
    (Call: 'BlockRead(';  Replacement: 'use TFileStream')
  );

function TDeprecatedAPIRule.GetName: string;
begin
  Result := 'deprecated_api';
end;

function TDeprecatedAPIRule.GetDescription: string;
begin
  Result := 'Usage of old-style Pascal file I/O or patterns with modern alternatives';
end;

function TDeprecatedAPIRule.Check(const ASource: string): TArray<TDiagnostic>;
var
  Lines : TStringList;
  I, K  : Integer;
  Line  : string;
  Diags : TList<TDiagnostic>;
begin
  Lines := TStringList.Create;
  Diags := TList<TDiagnostic>.Create;
  try
    Lines.Text := ASource;
    for I := 0 to Lines.Count - 1 do
    begin
      Line := Lines[I];
      for K := Low(C_DEPRECATED) to High(C_DEPRECATED) do
      begin
        if Line.Contains(C_DEPRECATED[K].Call) then
          Diags.Add(BuildDiag(I + 1, 1, Line.TrimLeft.Length,
            Format('Consider replacing ''%s'' — %s',
              [C_DEPRECATED[K].Call, C_DEPRECATED[K].Replacement]),
            dsInfo, 'DELPHI004', 'delphi'));
      end;
    end;
    Result := Diags.ToArray;
  finally
    Diags.Free;
    Lines.Free;
  end;
end;

{ factory }

function CreateGenericDiagnosticsEngine: TDiagnosticsEngine;
begin
  Result := TDiagnosticsEngine.Create;
  Result.RegisterRule(TMissingTryFinallyRule.Create);
  Result.RegisterRule(TStringConcatenationInLoopRule.Create);
  Result.RegisterRule(TDirectUIFromThreadRule.Create);
  Result.RegisterRule(TDeprecatedAPIRule.Create);
end;

end.
