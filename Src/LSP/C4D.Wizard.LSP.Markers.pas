unit C4D.Wizard.LSP.Markers;

{ Writes diagnostics into the Delphi IDE "Messages" window
  as tool messages, grouped under 'Code4D Diagnostics'. }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  ToolsAPI,
  C4D.Wizard.LSP.Diagnostics;

type
  /// <summary>
  ///   Manages tool messages written to the IDE Messages window for a set of files.
  ///   Call AddMarker to add individual diagnostics; ClearMarkers to wipe previous
  ///   results for a specific file.
  ///
  ///   NOTE: All public methods must be called from the main (IDE) thread.
  /// </summary>
  TIDEMarkerManager = class
  private
    /// Tracks which files currently have markers so we can clear selectively.
    FFileTrack: TDictionary<string, Boolean>;

    function  GetOrCreateMessageGroup: IOTAMessageGroup;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>Add one diagnostic marker for AFileName into the Messages window.</summary>
    procedure AddMarker(const AFileName: string; ALine, AColumn, ALength: Integer;
      const AMessage: string; ASeverity: TDiagnosticSeverity);

    /// <summary>Remove all markers previously added for AFileName.</summary>
    procedure ClearMarkers(const AFileName: string);

    /// <summary>Remove all markers for all files.</summary>
    procedure ClearAll;
  end;

implementation

const
  C_GROUP_NAME = 'Code4D Diagnostics';

{ TIDEMarkerManager }

constructor TIDEMarkerManager.Create;
begin
  inherited Create;
  FFileTrack := TDictionary<string, Boolean>.Create;
end;

destructor TIDEMarkerManager.Destroy;
begin
  FFileTrack.Free;
  inherited;
end;

function TIDEMarkerManager.GetOrCreateMessageGroup: IOTAMessageGroup;
var
  MsgSvc: IOTAMessageServices;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, IOTAMessageServices, MsgSvc) then
    Exit;

  Result := MsgSvc.GetGroup(C_GROUP_NAME);
  if not Assigned(Result) then
    Result := MsgSvc.AddMessageGroup(C_GROUP_NAME);
end;

procedure TIDEMarkerManager.AddMarker(const AFileName: string;
  ALine, AColumn, ALength: Integer; const AMessage: string;
  ASeverity: TDiagnosticSeverity);
var
  MsgSvc: IOTAMessageServices;
  Group : IOTAMessageGroup;
  Prefix: string;
begin
  if not Supports(BorlandIDEServices, IOTAMessageServices, MsgSvc) then
    Exit;

  Group := GetOrCreateMessageGroup;

  // Prefix the message with a severity indicator
  case ASeverity of
    dsError  : Prefix := '[Error] ';
    dsWarning: Prefix := '[Warn]  ';
    dsHint   : Prefix := '[Hint]  ';
  else
    Prefix := '[Info]  ';
  end;

  MsgSvc.AddToolMessage(
    AFileName,
    Prefix + AMessage,
    'Code4D',
    ALine,
    AColumn,
    nil,   // IOTASourcePosition
    nil,   // no extra pointer
    Group);

  FFileTrack.AddOrSetValue(AFileName, True);
end;

procedure TIDEMarkerManager.ClearMarkers(const AFileName: string);
var
  MsgSvc: IOTAMessageServices;
  Group : IOTAMessageGroup;
begin
  if not FFileTrack.ContainsKey(AFileName) then
    Exit;

  if not Supports(BorlandIDEServices, IOTAMessageServices, MsgSvc) then
    Exit;

  Group := GetOrCreateMessageGroup;
  if Assigned(Group) then
    Group.ClearMessages;   // clears the whole group (file-scoped clear not in OTA)

  FFileTrack.Remove(AFileName);
end;

procedure TIDEMarkerManager.ClearAll;
var
  MsgSvc: IOTAMessageServices;
  Group : IOTAMessageGroup;
begin
  if not Supports(BorlandIDEServices, IOTAMessageServices, MsgSvc) then
    Exit;

  Group := GetOrCreateMessageGroup;
  if Assigned(Group) then
    Group.ClearMessages;

  FFileTrack.Clear;
end;

end.
