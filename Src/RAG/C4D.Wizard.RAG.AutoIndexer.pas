unit C4D.Wizard.RAG.AutoIndexer;

{ Background thread that drains TIndexingQueue and delegates each task to a
  caller-supplied IDocumentIndexer implementation.

  The concrete indexer (e.g. ChromaDB + embeddings) is injected via the interface,
  keeping this unit free of any external library dependency. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  System.SyncObjs,
  C4D.Wizard.RAG.Queue;

type
  TIndexingStatus = (isIdle, isIndexing, isPaused);

  TIndexProgressEvent = procedure(Sender: TObject; const AFilePath: string;
    AProgress, ATotal: Integer) of object;

  /// <summary>
  ///   Abstract indexer interface.  Implement this in a concrete unit
  ///   (e.g. using ChromaDB + embeddings) and inject into TAutoIndexer.Create.
  /// </summary>
  IDocumentIndexer = interface
    ['{4B7A1C3E-0F2D-4E5A-8B6C-9D1E2F3A4B5C}']
    /// <summary>Index the given file. Returns True on success.</summary>
    function IndexFile(const AFilePath: string): Boolean;
    /// <summary>Remove the given file from the index.</summary>
    procedure RemoveFile(const AFilePath: string);
  end;

  /// <summary>
  ///   Consumer thread: dequeues TIndexingTask items, applies a debounce filter
  ///   and calls IDocumentIndexer for each unique file change.
  /// </summary>
  TAutoIndexer = class(TThread)
  private
    FQueue            : TIndexingQueue;      // not owned
    FIndexer          : IDocumentIndexer;    // interface — ref-counted
    FStatus           : TIndexingStatus;
    FDebounceInterval : Integer;             // milliseconds
    FLastProcessed    : TDictionary<string, TDateTime>;
    FOnProgress       : TIndexProgressEvent;

    function  ShouldProcess(const AFilePath: string): Boolean;
    procedure ProcessTask(const ATask: TIndexingTask);
  protected
    procedure Execute; override;
  public
    /// <param name="AQueue">Shared queue (not owned).</param>
    /// <param name="AIndexer">Concrete indexer implementation (interface).</param>
    constructor Create(AQueue: TIndexingQueue; AIndexer: IDocumentIndexer);
    destructor  Destroy; override;

    procedure Pause;
    procedure Resume;

    /// <summary>Current processing state.</summary>
    property Status           : TIndexingStatus    read FStatus;
    /// <summary>Minimum milliseconds between re-indexing the same file.</summary>
    property DebounceInterval : Integer            read FDebounceInterval
                                                   write FDebounceInterval;
    /// <summary>Fired (in the main thread) when a file finishes indexing.</summary>
    property OnProgress       : TIndexProgressEvent read FOnProgress
                                                    write FOnProgress;
  end;

implementation

uses
  System.IOUtils;

{ TAutoIndexer }

constructor TAutoIndexer.Create(AQueue: TIndexingQueue; AIndexer: IDocumentIndexer);
begin
  inherited Create(True); // suspended
  FQueue             := AQueue;
  FIndexer           := AIndexer;
  FStatus            := isIdle;
  FDebounceInterval  := 2000;  // 2 s default
  FLastProcessed     := TDictionary<string, TDateTime>.Create;
  FreeOnTerminate    := False;
end;

destructor TAutoIndexer.Destroy;
begin
  Terminate;
  FQueue.Event.SetEvent;  // wake thread so it can exit cleanly
  WaitFor;
  FLastProcessed.Free;
  inherited;
end;

procedure TAutoIndexer.Execute;
var
  Task      : TIndexingTask;
  WaitResult: TWaitResult;
begin
  while not Terminated do
  begin
    if FStatus = isPaused then
    begin
      Sleep(100);
      Continue;
    end;

    // Block until a new item arrives or 1-second timeout
    WaitResult := FQueue.Event.WaitFor(1000);

    if WaitResult = wrSignaled then
    begin
      while FQueue.Dequeue(Task) do
      begin
        if Terminated then Break;

        if ShouldProcess(Task.FilePath) then
        begin
          FStatus := isIndexing;
          ProcessTask(Task);
          FStatus := isIdle;
        end;
      end;
    end;
  end;
end;

function TAutoIndexer.ShouldProcess(const AFilePath: string): Boolean;
var
  LastTime  : TDateTime;
  ElapsedMs : Int64;
begin
  Result := True;

  // Check debounce window
  if FLastProcessed.TryGetValue(AFilePath, LastTime) then
  begin
    ElapsedMs := MilliSecondsBetween(Now, LastTime);
    if ElapsedMs < FDebounceInterval then
      Exit(False);
  end;

  // Deleted files obviously won't exist — the indexer handles removal
end;

procedure TAutoIndexer.ProcessTask(const ATask: TIndexingTask);
var
  FilePath: string;
  Progress: TIndexProgressEvent;
begin
  FilePath := ATask.FilePath;
  Progress := FOnProgress;

  try
    case ATask.ChangeType of
      fctCreated, fctModified, fctRenamed:
      begin
        if TFile.Exists(FilePath) and Assigned(FIndexer) then
        begin
          {$IFDEF DEBUG}
          OutputDebugString(PChar(Format('[AutoIndexer] Indexing: %s', [FilePath])));
          {$ENDIF}
          if FIndexer.IndexFile(FilePath) then
          begin
            FLastProcessed.AddOrSetValue(FilePath, Now);
            if Assigned(Progress) then
              Synchronize(procedure
              begin
                Progress(Self, FilePath, 1, 1);
              end);
          end;
        end;
      end;

      fctDeleted:
      begin
        {$IFDEF DEBUG}
        OutputDebugString(PChar(Format('[AutoIndexer] Removing: %s', [FilePath])));
        {$ENDIF}
        if Assigned(FIndexer) then
          FIndexer.RemoveFile(FilePath);
        FLastProcessed.Remove(FilePath);
      end;
    end;

  except
    on E: Exception do
    begin
      {$IFDEF DEBUG}
      OutputDebugString(PChar(Format('[AutoIndexer] Error (%s): %s', [FilePath, E.Message])));
      {$ENDIF}
    end;
  end;
end;

procedure TAutoIndexer.Pause;
begin
  FStatus := isPaused;
end;

procedure TAutoIndexer.Resume;
begin
  FStatus := isIdle;
  FQueue.Event.SetEvent;  // unblock the wait immediately
end;

end.
