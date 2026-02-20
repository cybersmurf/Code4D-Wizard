unit C4D.Wizard.LSP.Diagnostics.Realtime;

{ Real-time diagnostics for the active editor.
  Analysis is debounced (default 500 ms) so it does not fire on every keystroke.
  Results are posted to the IDE Messages window via TIDEMarkerManager. }

interface

uses
  System.SysUtils,
  System.Classes,
  Vcl.ExtCtrls,
  ToolsAPI,
  C4D.Wizard.LSP.Diagnostics,
  C4D.Wizard.LSP.Markers;

type
  /// <summary>
  ///   Debounced real-time analysis engine.
  ///   Wire up an instance to keyboard / edit notifications, then call
  ///   AnalyzeCurrentEditor or AnalyzeSource.  After the debounce delay expires
  ///   the engine runs all registered rules and shows results in the Messages window.
  /// </summary>
  TRealtimeDiagnostics = class
  private
    FEngine        : TDiagnosticsEngine;   // owned
    FMarkers       : TIDEMarkerManager;    // owned
    FDebounceTimer : TTimer;               // owned
    FPendingSource : string;
    FPendingFile   : string;
    FDebounceDelay : Integer;

    procedure OnTimer(Sender: TObject);
    procedure RunAnalysis(const ASource, AFileName: string);
    function  GetDebounceDelay: Integer;
    procedure SetDebounceDelay(AValue: Integer);
  public
    /// <param name="AEngine">
    ///   Diagnostics engine to use. TRealtimeDiagnostics takes ownership.
    ///   Pass CreateGenericDiagnosticsEngine (from C4D.Wizard.LSP.Diagnostics.Generic)
    ///   or a custom instance.
    /// </param>
    constructor Create(AEngine: TDiagnosticsEngine);
    destructor  Destroy; override;

    /// <summary>
    ///   Trigger analysis of the currently focused editor.
    ///   Safe to call on every keystroke — internally debounced.
    /// </summary>
    procedure AnalyzeCurrentEditor;

    /// <summary>
    ///   Trigger analysis of an explicit source / filename pair.
    ///   Restarts the debounce timer.
    /// </summary>
    procedure AnalyzeSource(const ASource, AFileName: string);

    /// <summary>Immediately remove all markers for AFileName.</summary>
    procedure ClearDiagnostics(const AFileName: string);

    /// <summary>Immediately remove all markers for all files.</summary>
    procedure ClearAll;

    /// <summary>Debounce delay in milliseconds (default 500).</summary>
    property DebounceDelay: Integer read GetDebounceDelay write SetDebounceDelay;

    /// <summary>The underlying marker manager (for external customisation).</summary>
    property Markers: TIDEMarkerManager read FMarkers;
  end;

implementation

{ helpers }

/// <summary>Read full source text from an IOTASourceEditor.</summary>
function GetEditorText(const AEditor: IOTASourceEditor): string;
const
  CHUNK = 4096;
var
  Reader : IOTAEditReader;
  Buf    : array[0..CHUNK] of AnsiChar;
  Pos    : Integer;
  Read   : Integer;
  SB     : TStringBuilder;
begin
  SB := TStringBuilder.Create;
  try
    Reader := AEditor.CreateReader;
    Pos    := 0;
    repeat
      Read := Reader.GetText(Pos, @Buf[0], CHUNK);
      Buf[Read] := #0;
      SB.Append(string(AnsiString(PAnsiChar(@Buf[0]))));
      Inc(Pos, Read);
    until Read = 0;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

/// <summary>Return the IOTASourceEditor for the current module, or nil.</summary>
function GetCurrentSourceEditor(out AFileName: string): IOTASourceEditor;
var
  ModSvc : IOTAModuleServices;
  Module : IOTAModule;
  I      : Integer;
  Editor : IOTAEditor;
begin
  Result   := nil;
  AFileName := '';

  if not Supports(BorlandIDEServices, IOTAModuleServices, ModSvc) then
    Exit;

  Module := ModSvc.CurrentModule;
  if not Assigned(Module) then
    Exit;

  for I := 0 to Module.GetModuleFileCount - 1 do
  begin
    Editor := Module.GetModuleFileEditor(I);
    if Supports(Editor, IOTASourceEditor, Result) then
    begin
      AFileName := Module.FileName;
      Exit;
    end;
  end;

  Result := nil;
end;

{ TRealtimeDiagnostics }

constructor TRealtimeDiagnostics.Create(AEngine: TDiagnosticsEngine);
begin
  inherited Create;
  FEngine  := AEngine;
  FMarkers := TIDEMarkerManager.Create;

  FDebounceDelay := 500;
  FDebounceTimer := TTimer.Create(nil);
  FDebounceTimer.Interval := FDebounceDelay;
  FDebounceTimer.Enabled  := False;
  FDebounceTimer.OnTimer  := OnTimer;
end;

destructor TRealtimeDiagnostics.Destroy;
begin
  FDebounceTimer.Free;
  FMarkers.Free;
  FEngine.Free;
  inherited;
end;

function TRealtimeDiagnostics.GetDebounceDelay: Integer;
begin
  Result := FDebounceDelay;
end;

procedure TRealtimeDiagnostics.SetDebounceDelay(AValue: Integer);
begin
  FDebounceDelay := AValue;
  FDebounceTimer.Interval := AValue;
end;

procedure TRealtimeDiagnostics.AnalyzeCurrentEditor;
var
  SrcEditor: IOTASourceEditor;
  FileName : string;
  Source   : string;
begin
  SrcEditor := GetCurrentSourceEditor(FileName);
  if not Assigned(SrcEditor) then
    Exit;

  Source := GetEditorText(SrcEditor);
  AnalyzeSource(Source, FileName);
end;

procedure TRealtimeDiagnostics.AnalyzeSource(const ASource, AFileName: string);
begin
  FPendingSource := ASource;
  FPendingFile   := AFileName;

  // Restart debounce timer
  FDebounceTimer.Enabled := False;
  FDebounceTimer.Enabled := True;
end;

procedure TRealtimeDiagnostics.OnTimer(Sender: TObject);
begin
  FDebounceTimer.Enabled := False;

  if FPendingSource.IsEmpty or FPendingFile.IsEmpty then
    Exit;

  RunAnalysis(FPendingSource, FPendingFile);
end;

procedure TRealtimeDiagnostics.RunAnalysis(const ASource, AFileName: string);
var
  Diagnostics: TArray<TDiagnostic>;
  D          : TDiagnostic;
begin
  FMarkers.ClearMarkers(AFileName);

  Diagnostics := FEngine.Analyze(ASource);

  for D in Diagnostics do
    FMarkers.AddMarker(
      AFileName,
      D.Line,
      D.Column,
      D.Length,
      Format('[%s] %s', [D.Code, D.Message]),
      D.Severity);
end;

procedure TRealtimeDiagnostics.ClearDiagnostics(const AFileName: string);
begin
  FMarkers.ClearMarkers(AFileName);
end;

procedure TRealtimeDiagnostics.ClearAll;
begin
  FMarkers.ClearAll;
end;

end.
