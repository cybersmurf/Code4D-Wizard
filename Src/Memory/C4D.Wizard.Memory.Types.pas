unit C4D.Wizard.Memory.Types;

{
  Memory & Conversation Types for Code4D Wizard
  ===============================================
  Central type definitions for the memory system.

  Memory entries persist across IDE sessions.
  Conversations store a full message transcript with
  automatic learning triggered when a session ends.
}

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  System.JSON;

type
  // -----------------------------------------------------------------------
  // Memory classification
  // -----------------------------------------------------------------------
  TMemoryType = (
    mtConversation,   // Summarised chat session
    mtCodeSnippet,    // Code extracted from a conversation
    mtDecision,       // Design / architecture decision made by the user
    mtPreference,     // Coding style or tooling preference
    mtContext,        // Project-specific context note
    mtLearning        // General best-practice learnt during interactions
  );

  TMemoryImportance = (miLow, miMedium, miHigh, miCritical);

  // -----------------------------------------------------------------------
  // Memory entry — persisted to memory.json
  // -----------------------------------------------------------------------
  TMemoryEntry = record
    Id             : string;
    Type_          : TMemoryType;
    Importance     : TMemoryImportance;
    Content        : string;          // full text (for search)
    Summary        : string;          // ≤120 chars; shown in list views
    Tags           : TArray<string>;
    RelatedIds     : TArray<string>;  // IDs of related entries
    Embedding      : TArray<Double>;  // 1024-dim (mxbai-embed-large)
    ProjectPath    : string;
    CreatedAt      : TDateTime;
    LastAccessedAt : TDateTime;
    AccessCount    : Integer;
    // Optional key-value bag (serialised as JSON string in storage)
    function MetaValue(const AKey: string): string;
    procedure SetMetaValue(const AKey, AValue: string);
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TMemoryEntry; static;
  private
    FMeta: string;   // JSON-encoded metadata string
  end;

  // -----------------------------------------------------------------------
  // Conversation message
  // -----------------------------------------------------------------------
  TConversationMessage = record
    Id             : string;
    ConversationId : string;
    Role           : string;          // 'user' | 'assistant' | 'system'
    Content        : string;
    Timestamp      : TDateTime;
    CodeBlocks     : TArray<string>;
    MemoryRefs     : TArray<string>;  // IDs of memories referenced during this turn
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TConversationMessage; static;
  end;

  // -----------------------------------------------------------------------
  // Conversation header
  // -----------------------------------------------------------------------
  TConversation = record
    Id           : string;
    Title        : string;
    Summary      : string;
    CreatedAt    : TDateTime;
    UpdatedAt    : TDateTime;
    MessageCount : Integer;
    ProjectPath  : string;
    Tags         : TArray<string>;
    function ToJSON: TJSONObject;
    class function FromJSON(AObj: TJSONObject): TConversation; static;
  end;

  // -----------------------------------------------------------------------
  // Search result envelope
  // -----------------------------------------------------------------------
  TMemorySearchResult = record
    Entry : TMemoryEntry;
    Score : Double;   // 0..1; higher = more relevant
  end;

// -----------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------
function MemoryTypeToStr(AType: TMemoryType): string;
function StrToMemoryType(const S: string): TMemoryType;
function ImportanceToStr(AImp: TMemoryImportance): string;
function StrToImportance(const S: string): TMemoryImportance;
function StringArrayToJSON(const A: TArray<string>): TJSONArray;
function JSONToStringArray(AArr: TJSONArray): TArray<string>;
function EmbeddingToJSON(const E: TArray<Double>): TJSONArray;
function JSONToEmbedding(AArr: TJSONArray): TArray<Double>;

implementation

{ ---- helpers ---- }

function MemoryTypeToStr(AType: TMemoryType): string;
const NAMES: array[TMemoryType] of string = (
  'conversation','code_snippet','decision','preference','context','learning');
begin
  Result := NAMES[AType];
end;

function StrToMemoryType(const S: string): TMemoryType;
begin
  if S = 'code_snippet'  then Exit(mtCodeSnippet);
  if S = 'decision'      then Exit(mtDecision);
  if S = 'preference'    then Exit(mtPreference);
  if S = 'context'       then Exit(mtContext);
  if S = 'learning'      then Exit(mtLearning);
  Result := mtConversation;
end;

function ImportanceToStr(AImp: TMemoryImportance): string;
const NAMES: array[TMemoryImportance] of string = ('low','medium','high','critical');
begin
  Result := NAMES[AImp];
end;

function StrToImportance(const S: string): TMemoryImportance;
begin
  if S = 'high'     then Exit(miHigh);
  if S = 'critical' then Exit(miCritical);
  if S = 'low'      then Exit(miLow);
  Result := miMedium;
end;

function StringArrayToJSON(const A: TArray<string>): TJSONArray;
begin
  Result := TJSONArray.Create;
  for var S in A do Result.Add(S);
end;

function JSONToStringArray(AArr: TJSONArray): TArray<string>;
begin
  if not Assigned(AArr) then Exit([]);
  SetLength(Result, AArr.Count);
  for var I := 0 to AArr.Count - 1 do
    Result[I] := AArr.Items[I].Value;
end;

function EmbeddingToJSON(const E: TArray<Double>): TJSONArray;
begin
  Result := TJSONArray.Create;
  for var V in E do Result.Add(V);
end;

function JSONToEmbedding(AArr: TJSONArray): TArray<Double>;
begin
  if not Assigned(AArr) then Exit([]);
  SetLength(Result, AArr.Count);
  for var I := 0 to AArr.Count - 1 do
    Result[I] := (AArr.Items[I] as TJSONNumber).AsDouble;
end;

{ TMemoryEntry }

function TMemoryEntry.MetaValue(const AKey: string): string;
var
  LObj: TJSONValue;
  LRoot: TJSONObject;
begin
  Result := '';
  if FMeta.IsEmpty then Exit;
  LObj := TJSONObject.ParseJSONValue(FMeta);
  if not (LObj is TJSONObject) then begin LObj.Free; Exit; end;
  LRoot := LObj as TJSONObject;
  try
    Result := LRoot.GetValue<string>(AKey, '');
  finally
    LRoot.Free;
  end;
end;

procedure TMemoryEntry.SetMetaValue(const AKey, AValue: string);
var
  LObj  : TJSONValue;
  LRoot : TJSONObject;
begin
  if FMeta.IsEmpty then
    LRoot := TJSONObject.Create
  else
  begin
    LObj := TJSONObject.ParseJSONValue(FMeta);
    if LObj is TJSONObject then
      LRoot := LObj as TJSONObject
    else
    begin
      FreeAndNil(LObj);
      LRoot := TJSONObject.Create;
    end;
  end;
  try
    LRoot.AddOrSetValue(AKey, AValue);
    FMeta := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TMemoryEntry.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id',              Id);
  Result.AddPair('type',            MemoryTypeToStr(Type_));
  Result.AddPair('importance',      ImportanceToStr(Importance));
  Result.AddPair('content',         Content);
  Result.AddPair('summary',         Summary);
  Result.AddPair('tags',            StringArrayToJSON(Tags));
  Result.AddPair('related_ids',     StringArrayToJSON(RelatedIds));
  Result.AddPair('embedding',       EmbeddingToJSON(Embedding));
  Result.AddPair('project_path',    ProjectPath);
  Result.AddPair('created_at',      TJSONNumber.Create(CreatedAt));
  Result.AddPair('last_accessed',   TJSONNumber.Create(LastAccessedAt));
  Result.AddPair('access_count',    TJSONNumber.Create(AccessCount));
  Result.AddPair('meta',            FMeta);
end;

class function TMemoryEntry.FromJSON(AObj: TJSONObject): TMemoryEntry;
begin
  Result := Default(TMemoryEntry);
  if not Assigned(AObj) then Exit;
  Result.Id             := AObj.GetValue<string>('id', '');
  Result.Type_          := StrToMemoryType(AObj.GetValue<string>('type', 'conversation'));
  Result.Importance     := StrToImportance(AObj.GetValue<string>('importance', 'medium'));
  Result.Content        := AObj.GetValue<string>('content', '');
  Result.Summary        := AObj.GetValue<string>('summary', '');
  Result.Tags           := JSONToStringArray(AObj.GetValue<TJSONArray>('tags', nil));
  Result.RelatedIds     := JSONToStringArray(AObj.GetValue<TJSONArray>('related_ids', nil));
  Result.Embedding      := JSONToEmbedding(AObj.GetValue<TJSONArray>('embedding', nil));
  Result.ProjectPath    := AObj.GetValue<string>('project_path', '');
  Result.CreatedAt      := AObj.GetValue<Double>('created_at', 0);
  Result.LastAccessedAt := AObj.GetValue<Double>('last_accessed', 0);
  Result.AccessCount    := AObj.GetValue<Integer>('access_count', 0);
  Result.FMeta          := AObj.GetValue<string>('meta', '');
end;

{ TConversationMessage }

function TConversationMessage.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id',              Id);
  Result.AddPair('conversation_id', ConversationId);
  Result.AddPair('role',            Role);
  Result.AddPair('content',         Content);
  Result.AddPair('timestamp',       TJSONNumber.Create(Timestamp));
  Result.AddPair('code_blocks',     StringArrayToJSON(CodeBlocks));
  Result.AddPair('memory_refs',     StringArrayToJSON(MemoryRefs));
end;

class function TConversationMessage.FromJSON(AObj: TJSONObject): TConversationMessage;
begin
  Result := Default(TConversationMessage);
  if not Assigned(AObj) then Exit;
  Result.Id             := AObj.GetValue<string>('id', '');
  Result.ConversationId := AObj.GetValue<string>('conversation_id', '');
  Result.Role           := AObj.GetValue<string>('role', 'user');
  Result.Content        := AObj.GetValue<string>('content', '');
  Result.Timestamp      := AObj.GetValue<Double>('timestamp', 0);
  Result.CodeBlocks     := JSONToStringArray(AObj.GetValue<TJSONArray>('code_blocks', nil));
  Result.MemoryRefs     := JSONToStringArray(AObj.GetValue<TJSONArray>('memory_refs', nil));
end;

{ TConversation }

function TConversation.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id',            Id);
  Result.AddPair('title',         Title);
  Result.AddPair('summary',       Summary);
  Result.AddPair('created_at',    TJSONNumber.Create(CreatedAt));
  Result.AddPair('updated_at',    TJSONNumber.Create(UpdatedAt));
  Result.AddPair('message_count', TJSONNumber.Create(MessageCount));
  Result.AddPair('project_path',  ProjectPath);
  Result.AddPair('tags',          StringArrayToJSON(Tags));
end;

class function TConversation.FromJSON(AObj: TJSONObject): TConversation;
begin
  Result := Default(TConversation);
  if not Assigned(AObj) then Exit;
  Result.Id           := AObj.GetValue<string>('id', '');
  Result.Title        := AObj.GetValue<string>('title', '');
  Result.Summary      := AObj.GetValue<string>('summary', '');
  Result.CreatedAt    := AObj.GetValue<Double>('created_at', 0);
  Result.UpdatedAt    := AObj.GetValue<Double>('updated_at', 0);
  Result.MessageCount := AObj.GetValue<Integer>('message_count', 0);
  Result.ProjectPath  := AObj.GetValue<string>('project_path', '');
  Result.Tags         := JSONToStringArray(AObj.GetValue<TJSONArray>('tags', nil));
end;

end.
