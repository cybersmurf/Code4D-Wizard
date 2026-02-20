unit C4D.Wizard.RAG.Queue;

{ Thread-safe queue of file-change indexing tasks.
  TFileChangeType is defined here and reused by Watcher and AutoIndexer. }

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs;

type
  /// <summary>Type of filesystem change that triggered indexing.</summary>
  TFileChangeType = (fctCreated, fctModified, fctDeleted, fctRenamed);

  /// <summary>A single unit of work placed on the indexing queue.</summary>
  TIndexingTask = record
    FilePath  : string;
    ChangeType: TFileChangeType;
    Timestamp : TDateTime;
  end;

  /// <summary>
  ///   Thread-safe FIFO queue for TIndexingTask items.
  ///   Producer threads call Enqueue; the consumer (TAutoIndexer) calls Dequeue.
  ///   The Event is signalled whenever a new item is added, allowing the consumer
  ///   to block on WaitFor instead of busy-polling.
  /// </summary>
  TIndexingQueue = class
  private
    FQueue: TQueue<TIndexingTask>;
    FLock : TCriticalSection;
    FEvent: TEvent;
  public
    constructor Create;
    destructor  Destroy; override;

    /// <summary>Add a file-change task; signals Event.</summary>
    procedure Enqueue(const AFilePath: string; const AChangeType: TFileChangeType);

    /// <summary>Remove and return the next task. Returns False if the queue is empty.</summary>
    function  Dequeue(out ATask: TIndexingTask): Boolean;

    /// <summary>Current number of pending tasks (snapshot; may change immediately).</summary>
    function  Count: Integer;

    /// <summary>Discard all pending tasks.</summary>
    procedure Clear;

    /// <summary>Auto-reset event signalled by Enqueue; consumer blocks on WaitFor.</summary>
    property  Event: TEvent read FEvent;
  end;

implementation

{ TIndexingQueue }

constructor TIndexingQueue.Create;
begin
  inherited Create;
  FQueue := TQueue<TIndexingTask>.Create;
  FLock  := TCriticalSection.Create;
  FEvent := TEvent.Create(nil, False {auto-reset}, False, '');
end;

destructor TIndexingQueue.Destroy;
begin
  FEvent.Free;
  FLock.Free;
  FQueue.Free;
  inherited;
end;

procedure TIndexingQueue.Enqueue(const AFilePath: string;
  const AChangeType: TFileChangeType);
var
  Task: TIndexingTask;
begin
  Task.FilePath   := AFilePath;
  Task.ChangeType := AChangeType;
  Task.Timestamp  := Now;

  FLock.Enter;
  try
    FQueue.Enqueue(Task);
    FEvent.SetEvent;
  finally
    FLock.Leave;
  end;
end;

function TIndexingQueue.Dequeue(out ATask: TIndexingTask): Boolean;
begin
  FLock.Enter;
  try
    Result := FQueue.Count > 0;
    if Result then
      ATask := FQueue.Dequeue;
  finally
    FLock.Leave;
  end;
end;

function TIndexingQueue.Count: Integer;
begin
  FLock.Enter;
  try
    Result := FQueue.Count;
  finally
    FLock.Leave;
  end;
end;

procedure TIndexingQueue.Clear;
begin
  FLock.Enter;
  try
    FQueue.Clear;
  finally
    FLock.Leave;
  end;
end;

end.
