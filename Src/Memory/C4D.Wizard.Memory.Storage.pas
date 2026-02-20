unit C4D.Wizard.Memory.Storage;

{
  Memory & Conversation Storage for Code4D Wizard
  =================================================
  JSON-file-based persistence — no extra BPL dependencies required.

  Two files are maintained in the data directory:
    memory.json        — TArray<TMemoryEntry>  (all memory entries)
    conversations.json — TArray<TConversation> headers
    messages/          — one file per conversation: <id>.json

  Both files are loaded eagerly into TDictionary at startup and
  written back to disk on every mutating operation.  This is adequate
  for the expected data volumes (≤ 10 000 entries).
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  C4D.Wizard.Memory.Types;

type
  TC4DWizardMemoryStorage = class
  private
    FDataDir    : string;
    FMemories   : TDictionary<string, TMemoryEntry>;      // id → entry
    FConvHeaders: TDictionary<string, TConversation>;     // id → header

    function MemoryFilePath: string;
    function ConversationsFilePath: string;
    function MessagesFilePath(const AConvId: string): string;

    procedure LoadMemoriesFromDisk;
    procedure SaveMemoriesToDisk;
    procedure LoadConversationsFromDisk;
    procedure SaveConversationsToDisk;
  public
    constructor Create(const ADataDir: string);
    destructor Destroy; override;

    // --- Memory CRUD -------------------------------------------------------
    procedure SaveMemory(const AEntry: TMemoryEntry);
    function  LoadMemory(const AId: string; out AEntry: TMemoryEntry): Boolean;
    procedure UpdateMemory(const AEntry: TMemoryEntry);
    procedure DeleteMemory(const AId: string);
    function  AllMemories: TArray<TMemoryEntry>;

    // --- Conversation CRUD -------------------------------------------------
    procedure SaveConversationHeader(const AConv: TConversation);
    function  LoadConversationHeader(const AId: string;
                out AConv: TConversation): Boolean;
    procedure SaveMessage(const AMsg: TConversationMessage);
    function  LoadMessages(const AConvId: string): TArray<TConversationMessage>;
    function  AllConversations: TArray<TConversation>;

    // --- Simple text search ------------------------------------------------
    /// <summary>Returns entries whose Content or Summary contains AQuery
    /// (case-insensitive); up to ALimit results, newest first.</summary>
    function TextSearch(const AQuery: string;
      ALimit: Integer = 20): TArray<TMemoryEntry>;
    function SearchConversationsByTopic(const ATopic: string;
      ALimit: Integer = 10): TArray<TConversation>;

    // --- Stats -------------------------------------------------------------
    function MemoryCount: Integer;
    function ConversationCount: Integer;
  end;

implementation

{ TC4DWizardMemoryStorage }

constructor TC4DWizardMemoryStorage.Create(const ADataDir: string);
begin
  FDataDir := ADataDir;
  ForceDirectories(ADataDir);
  ForceDirectories(TPath.Combine(ADataDir, 'messages'));
  FMemories    := TDictionary<string, TMemoryEntry>.Create;
  FConvHeaders := TDictionary<string, TConversation>.Create;
  LoadMemoriesFromDisk;
  LoadConversationsFromDisk;
end;

destructor TC4DWizardMemoryStorage.Destroy;
begin
  FMemories.Free;
  FConvHeaders.Free;
  inherited;
end;

{ ---- paths ---- }

function TC4DWizardMemoryStorage.MemoryFilePath: string;
begin
  Result := TPath.Combine(FDataDir, 'memory.json');
end;

function TC4DWizardMemoryStorage.ConversationsFilePath: string;
begin
  Result := TPath.Combine(FDataDir, 'conversations.json');
end;

function TC4DWizardMemoryStorage.MessagesFilePath(const AConvId: string): string;
begin
  Result := TPath.Combine(TPath.Combine(FDataDir, 'messages'), AConvId + '.json');
end;

{ ---- load / save ---- }

procedure TC4DWizardMemoryStorage.LoadMemoriesFromDisk;
var
  LPath : string;
  LArr  : TJSONValue;
  LJArr : TJSONArray;
  I     : Integer;
  LEntry: TMemoryEntry;
begin
  FMemories.Clear;
  LPath := MemoryFilePath;
  if not TFile.Exists(LPath) then Exit;
  try
    LArr := TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath, TEncoding.UTF8));
    try
      if not (LArr is TJSONArray) then Exit;
      LJArr := LArr as TJSONArray;
      for I := 0 to LJArr.Count - 1 do
      begin
        LEntry := TMemoryEntry.FromJSON(LJArr.Items[I] as TJSONObject);
        if not LEntry.Id.IsEmpty then
          FMemories.AddOrSetValue(LEntry.Id, LEntry);
      end;
    finally
      LArr.Free;
    end;
  except
    // Corrupted file — start fresh
  end;
end;

procedure TC4DWizardMemoryStorage.SaveMemoriesToDisk;
var
  LArr : TJSONArray;
  LPair: TPair<string, TMemoryEntry>;
  LObj : TJSONObject;
begin
  LArr := TJSONArray.Create;
  try
    for LPair in FMemories do
    begin
      LObj := LPair.Value.ToJSON;
      LArr.AddElement(LObj);
    end;
    TFile.WriteAllText(MemoryFilePath, LArr.Format(2), TEncoding.UTF8);
  finally
    LArr.Free;
  end;
end;

procedure TC4DWizardMemoryStorage.LoadConversationsFromDisk;
var
  LPath : string;
  LArr  : TJSONValue;
  LJArr : TJSONArray;
  I     : Integer;
  LConv : TConversation;
begin
  FConvHeaders.Clear;
  LPath := ConversationsFilePath;
  if not TFile.Exists(LPath) then Exit;
  try
    LArr := TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath, TEncoding.UTF8));
    try
      if not (LArr is TJSONArray) then Exit;
      LJArr := LArr as TJSONArray;
      for I := 0 to LJArr.Count - 1 do
      begin
        LConv := TConversation.FromJSON(LJArr.Items[I] as TJSONObject);
        if not LConv.Id.IsEmpty then
          FConvHeaders.AddOrSetValue(LConv.Id, LConv);
      end;
    finally
      LArr.Free;
    end;
  except
    // Corrupted — start fresh
  end;
end;

procedure TC4DWizardMemoryStorage.SaveConversationsToDisk;
var
  LArr : TJSONArray;
  LPair: TPair<string, TConversation>;
  LObj : TJSONObject;
begin
  LArr := TJSONArray.Create;
  try
    for LPair in FConvHeaders do
    begin
      LObj := LPair.Value.ToJSON;
      LArr.AddElement(LObj);
    end;
    TFile.WriteAllText(ConversationsFilePath, LArr.Format(2), TEncoding.UTF8);
  finally
    LArr.Free;
  end;
end;

{ ---- Memory CRUD ---- }

procedure TC4DWizardMemoryStorage.SaveMemory(const AEntry: TMemoryEntry);
begin
  FMemories.AddOrSetValue(AEntry.Id, AEntry);
  SaveMemoriesToDisk;
end;

function TC4DWizardMemoryStorage.LoadMemory(const AId: string;
  out AEntry: TMemoryEntry): Boolean;
begin
  Result := FMemories.TryGetValue(AId, AEntry);
end;

procedure TC4DWizardMemoryStorage.UpdateMemory(const AEntry: TMemoryEntry);
begin
  if FMemories.ContainsKey(AEntry.Id) then
  begin
    FMemories[AEntry.Id] := AEntry;
    SaveMemoriesToDisk;
  end;
end;

procedure TC4DWizardMemoryStorage.DeleteMemory(const AId: string);
begin
  if FMemories.Remove(AId) > 0 then
    SaveMemoriesToDisk;
end;

function TC4DWizardMemoryStorage.AllMemories: TArray<TMemoryEntry>;
var
  LPair: TPair<string, TMemoryEntry>;
  I    : Integer;
begin
  SetLength(Result, FMemories.Count);
  I := 0;
  for LPair in FMemories do
  begin
    Result[I] := LPair.Value;
    Inc(I);
  end;
end;

{ ---- Conversation CRUD ---- }

procedure TC4DWizardMemoryStorage.SaveConversationHeader(const AConv: TConversation);
begin
  FConvHeaders.AddOrSetValue(AConv.Id, AConv);
  SaveConversationsToDisk;
end;

function TC4DWizardMemoryStorage.LoadConversationHeader(const AId: string;
  out AConv: TConversation): Boolean;
begin
  Result := FConvHeaders.TryGetValue(AId, AConv);
end;

procedure TC4DWizardMemoryStorage.SaveMessage(const AMsg: TConversationMessage);
var
  LPath  : string;
  LArr   : TJSONValue;
  LJArr  : TJSONArray;
begin
  LPath := MessagesFilePath(AMsg.ConversationId);
  if TFile.Exists(LPath) then
  begin
    LArr := TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath, TEncoding.UTF8));
    if LArr is TJSONArray then
      LJArr := LArr as TJSONArray
    else
    begin
      FreeAndNil(LArr);
      LJArr := TJSONArray.Create;
    end;
  end
  else
    LJArr := TJSONArray.Create;

  try
    LJArr.AddElement(AMsg.ToJSON);
    TFile.WriteAllText(LPath, LJArr.Format(2), TEncoding.UTF8);
  finally
    LJArr.Free;
  end;
end;

function TC4DWizardMemoryStorage.LoadMessages(
  const AConvId: string): TArray<TConversationMessage>;
var
  LPath : string;
  LArr  : TJSONValue;
  LJArr : TJSONArray;
  I     : Integer;
begin
  Result := [];
  LPath := MessagesFilePath(AConvId);
  if not TFile.Exists(LPath) then Exit;
  try
    LArr := TJSONObject.ParseJSONValue(TFile.ReadAllText(LPath, TEncoding.UTF8));
    try
      if not (LArr is TJSONArray) then Exit;
      LJArr := LArr as TJSONArray;
      SetLength(Result, LJArr.Count);
      for I := 0 to LJArr.Count - 1 do
        Result[I] := TConversationMessage.FromJSON(LJArr.Items[I] as TJSONObject);
    finally
      LArr.Free;
    end;
  except
    Result := [];
  end;
end;

function TC4DWizardMemoryStorage.AllConversations: TArray<TConversation>;
var
  LPair: TPair<string, TConversation>;
  I    : Integer;
begin
  SetLength(Result, FConvHeaders.Count);
  I := 0;
  for LPair in FConvHeaders do
  begin
    Result[I] := LPair.Value;
    Inc(I);
  end;
end;

{ ---- Text search ---- }

function TC4DWizardMemoryStorage.TextSearch(const AQuery: string;
  ALimit: Integer): TArray<TMemoryEntry>;
var
  LLower  : string;
  LResults: TList<TMemoryEntry>;
  LPair   : TPair<string, TMemoryEntry>;
  LEntry  : TMemoryEntry;
begin
  LLower := AQuery.ToLower;
  LResults := TList<TMemoryEntry>.Create;
  try
    for LPair in FMemories do
    begin
      LEntry := LPair.Value;
      if LEntry.Content.ToLower.Contains(LLower) or
         LEntry.Summary.ToLower.Contains(LLower) then
        LResults.Add(LEntry);
    end;
    // Sort by LastAccessedAt desc, truncate
    LResults.Sort(TComparer<TMemoryEntry>.Construct(
      function(const A, B: TMemoryEntry): Integer
      begin
        if A.LastAccessedAt > B.LastAccessedAt then Result := -1
        else if A.LastAccessedAt < B.LastAccessedAt then Result := 1
        else Result := 0;
      end));
    if LResults.Count > ALimit then
      LResults.Count := ALimit;
    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

function TC4DWizardMemoryStorage.SearchConversationsByTopic(const ATopic: string;
  ALimit: Integer): TArray<TConversation>;
var
  LLower  : string;
  LResults: TList<TConversation>;
  LPair   : TPair<string, TConversation>;
  LConv   : TConversation;
begin
  LLower := ATopic.ToLower;
  LResults := TList<TConversation>.Create;
  try
    for LPair in FConvHeaders do
    begin
      LConv := LPair.Value;
      if LConv.Title.ToLower.Contains(LLower) or
         LConv.Summary.ToLower.Contains(LLower) then
        LResults.Add(LConv);
    end;
    LResults.Sort(TComparer<TConversation>.Construct(
      function(const A, B: TConversation): Integer
      begin
        if A.UpdatedAt > B.UpdatedAt then Result := -1
        else if A.UpdatedAt < B.UpdatedAt then Result := 1
        else Result := 0;
      end));
    if LResults.Count > ALimit then
      LResults.Count := ALimit;
    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

{ ---- Stats ---- }

function TC4DWizardMemoryStorage.MemoryCount: Integer;
begin
  Result := FMemories.Count;
end;

function TC4DWizardMemoryStorage.ConversationCount: Integer;
begin
  Result := FConvHeaders.Count;
end;

end.
