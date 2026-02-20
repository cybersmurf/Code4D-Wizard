unit C4D.Wizard.RAG.Watcher;

{ FileSystem watcher built on ReadDirectoryChangesW.
  Each watched directory runs in its own background TThread.
  File changes are pushed onto a TIndexingQueue for the auto-indexer to process. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  Winapi.Windows,
  C4D.Wizard.RAG.Queue;

type
  TFileChangeEvent = procedure(Sender: TObject; const AFilePath: string;
    const AChangeType: TFileChangeType) of object;

  /// <summary>
  ///   Background thread that monitors one directory via ReadDirectoryChangesW
  ///   and enqueues change tasks onto a shared TIndexingQueue.
  /// </summary>
  TFileSystemWatcher = class(TThread)
  private
    FDirectory  : string;
    FRecursive  : Boolean;
    FFilter     : string;              // e.g. '*.md'  (empty = all files)
    FHandle     : THandle;
    FBuffer     : array[0..8191] of Byte;
    FIndexQueue : TIndexingQueue;
    FOnChange   : TFileChangeEvent;

    procedure ProcessNotification(ABuffer: Pointer; AByteCount: DWORD);
    procedure HandleFileChange(const AFilePath: string; AAction: DWORD);
  protected
    procedure Execute; override;
  public
    /// <param name="ADirectory">Directory to monitor.</param>
    /// <param name="ARecursive">Watch subdirectories.</param>
    /// <param name="AFilter">Wildcard filter, e.g. '*.md'. Empty string = all files.</param>
    /// <param name="AIndexQueue">Queue to post change tasks to (may be nil).</param>
    constructor Create(const ADirectory: string; ARecursive: Boolean = True;
      const AFilter: string = '*.md'; AIndexQueue: TIndexingQueue = nil);
    destructor Destroy; override;

    property OnChange: TFileChangeEvent read FOnChange write FOnChange;
  end;

  /// <summary>
  ///   Manages a collection of TFileSystemWatcher threads, one per watched directory.
  /// </summary>
  TDocumentationWatcher = class
  private
    FWatchers  : TObjectList<TFileSystemWatcher>;
    FIndexQueue: TIndexingQueue;   // not owned
    FFilter    : string;

    procedure OnFileChange(Sender: TObject; const AFilePath: string;
      const AChangeType: TFileChangeType);
  public
    constructor Create(AIndexQueue: TIndexingQueue;
      const AFilter: string = '*.md');
    destructor Destroy; override;

    /// <summary>Register a directory to watch (call before Start).</summary>
    procedure WatchDirectory(const ADirectory: string; ARecursive: Boolean = True);

    procedure Start;
    procedure Stop;
  end;

implementation

{ TFileSystemWatcher }

constructor TFileSystemWatcher.Create(const ADirectory: string;
  ARecursive: Boolean; const AFilter: string; AIndexQueue: TIndexingQueue);
begin
  inherited Create(True); // start suspended
  FDirectory   := ADirectory;
  FRecursive   := ARecursive;
  FFilter      := AFilter;
  FIndexQueue  := AIndexQueue;
  FHandle      := INVALID_HANDLE_VALUE;
  FreeOnTerminate := False;
end;

destructor TFileSystemWatcher.Destroy;
begin
  Terminate;
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(FHandle);
    FHandle := INVALID_HANDLE_VALUE;
  end;
  inherited;
end;

procedure TFileSystemWatcher.Execute;
var
  BytesReturned: DWORD;
  Overlapped   : TOverlapped;
  WaitHandles  : array[0..1] of THandle;
  WaitResult   : DWORD;
begin
  FHandle := CreateFile(
    PChar(FDirectory),
    FILE_LIST_DIRECTORY,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
    nil,
    OPEN_EXISTING,
    FILE_FLAG_BACKUP_SEMANTICS or FILE_FLAG_OVERLAPPED,
    0);

  if FHandle = INVALID_HANDLE_VALUE then
    Exit;

  ZeroMemory(@Overlapped, SizeOf(Overlapped));
  Overlapped.hEvent := CreateEvent(nil, True, False, nil);
  if Overlapped.hEvent = 0 then
    Exit;
  try
    WaitHandles[0] := Overlapped.hEvent;

    while not Terminated do
    begin
      ResetEvent(Overlapped.hEvent);

      if not ReadDirectoryChangesW(
        FHandle,
        @FBuffer,
        SizeOf(FBuffer),
        FRecursive,
        FILE_NOTIFY_CHANGE_FILE_NAME or FILE_NOTIFY_CHANGE_LAST_WRITE or FILE_NOTIFY_CHANGE_SIZE,
        nil,        // lpBytesReturned — not used with overlapped
        @Overlapped,
        nil) then
      begin
        Sleep(500);
        Continue;
      end;

      // Wait for either a change notification or termination
      WaitResult := WaitForSingleObject(Overlapped.hEvent, 1000);

      if WaitResult = WAIT_OBJECT_0 then
      begin
        if GetOverlappedResult(FHandle, Overlapped, BytesReturned, False)
          and (BytesReturned > 0) then
          ProcessNotification(@FBuffer, BytesReturned);
      end;
    end;
  finally
    CloseHandle(Overlapped.hEvent);
  end;
end;

procedure TFileSystemWatcher.ProcessNotification(ABuffer: Pointer; AByteCount: DWORD);
var
  Info    : PFileNotifyInformation;
  Offset  : DWORD;
  FileName: string;
begin
  Offset := 0;
  repeat
    if AByteCount = 0 then
      Break;

    Info := PFileNotifyInformation(NativeInt(ABuffer) + Offset);

    SetString(FileName, Info^.FileName, Info^.FileNameLength div SizeOf(WideChar));
    FileName := TPath.Combine(FDirectory, FileName);

    // Apply extension filter when one is set
    if FFilter.IsEmpty or TPath.MatchesPattern(ExtractFileName(FileName), FFilter, True) then
      HandleFileChange(FileName, Info^.Action);

    if Info^.NextEntryOffset = 0 then
      Break;
    Inc(Offset, Info^.NextEntryOffset);
  until False;
end;

procedure TFileSystemWatcher.HandleFileChange(const AFilePath: string; AAction: DWORD);
var
  ChangeType: TFileChangeType;
  FilePath  : string;
begin
  FilePath := AFilePath;  // capture for anonymous proc

  case AAction of
    FILE_ACTION_ADDED             : ChangeType := fctCreated;
    FILE_ACTION_MODIFIED          : ChangeType := fctModified;
    FILE_ACTION_REMOVED           : ChangeType := fctDeleted;
    FILE_ACTION_RENAMED_NEW_NAME  : ChangeType := fctRenamed;
  else
    Exit;
  end;

  if Assigned(FIndexQueue) then
    FIndexQueue.Enqueue(FilePath, ChangeType);

  if Assigned(FOnChange) then
    Synchronize(procedure
    begin
      FOnChange(Self, FilePath, ChangeType);
    end);
end;

{ TDocumentationWatcher }

constructor TDocumentationWatcher.Create(AIndexQueue: TIndexingQueue;
  const AFilter: string);
begin
  inherited Create;
  FIndexQueue := AIndexQueue;
  FFilter     := AFilter;
  FWatchers   := TObjectList<TFileSystemWatcher>.Create(True {OwnsObjects});
end;

destructor TDocumentationWatcher.Destroy;
begin
  Stop;
  FWatchers.Free;
  inherited;
end;

procedure TDocumentationWatcher.WatchDirectory(const ADirectory: string;
  ARecursive: Boolean);
var
  W: TFileSystemWatcher;
begin
  if not TDirectory.Exists(ADirectory) then
    raise Exception.CreateFmt('Directory not found: %s', [ADirectory]);

  W := TFileSystemWatcher.Create(ADirectory, ARecursive, FFilter, FIndexQueue);
  W.OnChange := OnFileChange;
  FWatchers.Add(W);
end;

procedure TDocumentationWatcher.Start;
var
  W: TFileSystemWatcher;
begin
  for W in FWatchers do
    W.Start;
end;

procedure TDocumentationWatcher.Stop;
var
  W: TFileSystemWatcher;
begin
  for W in FWatchers do
  begin
    W.Terminate;
    W.WaitFor;
  end;
end;

procedure TDocumentationWatcher.OnFileChange(Sender: TObject;
  const AFilePath: string; const AChangeType: TFileChangeType);
const
  CHANGE_LABELS: array[TFileChangeType] of string = (
    'created', 'modified', 'deleted', 'renamed');
begin
  {$IFDEF DEBUG}
  OutputDebugString(PChar(Format('[RAG Watcher] File %s: %s',
    [CHANGE_LABELS[AChangeType], AFilePath])));
  {$ENDIF}
end;

end.
