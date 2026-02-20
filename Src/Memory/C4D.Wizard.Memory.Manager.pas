unit C4D.Wizard.Memory.Manager;

{
  Memory Manager for Code4D Wizard
  ==================================
  High-level facade over Storage + Vectorizer + Search.

  Responsibilities:
  • CRUD for TMemoryEntry with automatic ID and embedding generation
  • Automatic learning from ended conversations (AI extraction via GitHub Models)
  • Cross-conversation context retrieval for prompt augmentation

  IC4DWizardMemoryManager is the interface exposed to the rest of the plugin.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Generics.Collections,
  C4D.Wizard.Memory.Types,
  C4D.Wizard.Memory.Storage,
  C4D.Wizard.Memory.Vector,
  C4D.Wizard.Memory.Search,
  C4D.Wizard.AI.GitHub;

type
  IC4DWizardMemoryManager = interface
    ['{C3D4E5F6-A7B8-9012-CDEF-123456789012}']
    // CRUD
    function  AddMemory(const AEntry: TMemoryEntry): string;
    function  GetMemory(const AId: string): TMemoryEntry;
    procedure DeleteMemory(const AId: string);
    function  AllMemories: TArray<TMemoryEntry>;

    // Semantic search
    function  SearchMemories(const AQuery: string;
      ALimit: Integer = 5;
      const AProjectPath: string = ''): TArray<TMemorySearchResult>;

    // Conversation learning
    procedure LearnFromConversation(const AConv: TConversation;
      const AMessages: TArray<TConversationMessage>);

    // Context for prompt injection
    function  BuildContextBlock(const AQuery: string;
      const AProjectPath: string = '';
      AMaxEntries: Integer = 5): string;

    // Stats
    function  MemoryCount: Integer;
    function  ConversationCount: Integer;

    // Config
    function  Storage: TC4DWizardMemoryStorage;
  end;

  TC4DWizardMemoryManager = class(TInterfacedObject, IC4DWizardMemoryManager)
  private
    FStorage   : TC4DWizardMemoryStorage;
    FVectorizer: TC4DWizardMemoryVectorizer;
    FSearch    : TC4DWizardMemorySearch;
    FAIClient  : IC4DWizardAIGitHub;   // for learning (may be nil)

    function FormatMessagesForPrompt(
      const AMessages: TArray<TConversationMessage>): string;
    function ExtractLearningPrompt(
      const AConv: TConversation;
      const AMessages: TArray<TConversationMessage>): string;
  protected
    function  AddMemory(const AEntry: TMemoryEntry): string;
    function  GetMemory(const AId: string): TMemoryEntry;
    procedure DeleteMemory(const AId: string);
    function  AllMemories: TArray<TMemoryEntry>;
    function  SearchMemories(const AQuery: string;
      ALimit: Integer = 5;
      const AProjectPath: string = ''): TArray<TMemorySearchResult>;
    procedure LearnFromConversation(const AConv: TConversation;
      const AMessages: TArray<TConversationMessage>);
    function  BuildContextBlock(const AQuery: string;
      const AProjectPath: string = '';
      AMaxEntries: Integer = 5): string;
    function  MemoryCount: Integer;
    function  ConversationCount: Integer;
    function  Storage: TC4DWizardMemoryStorage;
  public
    constructor Create(const ADataDir: string;
      const AOllamaEndpoint: string = '';
      const AOllamaModel: string = 'mxbai-embed-large:latest';
      const AAIClient: IC4DWizardAIGitHub = nil);
    destructor Destroy; override;

    class function New(const ADataDir: string;
      const AOllamaEndpoint: string = '';
      const AOllamaModel: string = 'mxbai-embed-large:latest';
      const AAIClient: IC4DWizardAIGitHub = nil): IC4DWizardMemoryManager;
    class function DefaultDataDir: string;
  end;

implementation

uses
  System.IOUtils,
  System.Math;

{ TC4DWizardMemoryManager }

class function TC4DWizardMemoryManager.DefaultDataDir: string;
begin
  Result := TPath.Combine(
    TPath.Combine(
      TPath.GetHomePath,
      'AppData\Roaming\Code4D'),
    'Memory');
end;

class function TC4DWizardMemoryManager.New(const ADataDir, AOllamaEndpoint,
  AOllamaModel: string; const AAIClient: IC4DWizardAIGitHub): IC4DWizardMemoryManager;
begin
  Result := TC4DWizardMemoryManager.Create(
    ADataDir, AOllamaEndpoint, AOllamaModel, AAIClient);
end;

constructor TC4DWizardMemoryManager.Create(const ADataDir, AOllamaEndpoint,
  AOllamaModel: string; const AAIClient: IC4DWizardAIGitHub);
begin
  FAIClient   := AAIClient;
  FStorage    := TC4DWizardMemoryStorage.Create(ADataDir);
  FVectorizer := TC4DWizardMemoryVectorizer.Create(AOllamaEndpoint, AOllamaModel);
  FSearch     := TC4DWizardMemorySearch.Create(FStorage, FVectorizer);
end;

destructor TC4DWizardMemoryManager.Destroy;
begin
  FSearch.Free;
  FVectorizer.Free;
  FStorage.Free;
  FAIClient := nil;
  inherited;
end;

{ ---- CRUD ---- }

function TC4DWizardMemoryManager.AddMemory(const AEntry: TMemoryEntry): string;
var
  LEntry: TMemoryEntry;
begin
  LEntry := AEntry;
  if LEntry.Id.IsEmpty then
    LEntry.Id := StringReplace(StringReplace(
      GUIDToString(TGUID.NewGuid), '{', '', [rfReplaceAll]),
      '}', '', [rfReplaceAll]).Replace('-','').ToLower;
  if LEntry.CreatedAt = 0     then LEntry.CreatedAt     := Now;
  if LEntry.LastAccessedAt = 0 then LEntry.LastAccessedAt := Now;

  // Generate embedding if Ollama available and not already set
  if FVectorizer.Enabled and (Length(LEntry.Embedding) = 0) then
    LEntry.Embedding := FVectorizer.GetEmbedding(LEntry.Content);

  FStorage.SaveMemory(LEntry);
  Result := LEntry.Id;
end;

function TC4DWizardMemoryManager.GetMemory(const AId: string): TMemoryEntry;
begin
  Result := Default(TMemoryEntry);
  if not FStorage.LoadMemory(AId, Result) then Exit;
  // Bump access stats
  Result.LastAccessedAt := Now;
  Inc(Result.AccessCount);
  FStorage.UpdateMemory(Result);
end;

procedure TC4DWizardMemoryManager.DeleteMemory(const AId: string);
begin
  FStorage.DeleteMemory(AId);
end;

function TC4DWizardMemoryManager.AllMemories: TArray<TMemoryEntry>;
begin
  Result := FStorage.AllMemories;
end;

{ ---- Search ---- }

function TC4DWizardMemoryManager.SearchMemories(const AQuery: string;
  ALimit: Integer; const AProjectPath: string): TArray<TMemorySearchResult>;
begin
  Result := FSearch.Search(AQuery, ALimit, AProjectPath);
  // Bump access stats on results
  for var R in Result do
  begin
    var LUpdated := R.Entry;
    LUpdated.LastAccessedAt := Now;
    Inc(LUpdated.AccessCount);
    FStorage.UpdateMemory(LUpdated);
  end;
end;

{ ---- Learning ---- }

function TC4DWizardMemoryManager.FormatMessagesForPrompt(
  const AMessages: TArray<TConversationMessage>): string;
var
  SB: TStringBuilder;
  M : TConversationMessage;
begin
  SB := TStringBuilder.Create;
  try
    for M in AMessages do
    begin
      SB.Append(M.Role.ToUpper);
      SB.Append(': ');
      SB.AppendLine(M.Content);
      SB.AppendLine;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

function TC4DWizardMemoryManager.ExtractLearningPrompt(
  const AConv: TConversation;
  const AMessages: TArray<TConversationMessage>): string;
begin
  Result :=
    'Analyze the following conversation and extract important learnings.' + #10 +
    'Return ONLY a valid JSON array (no markdown, no explanation) with objects:' + #10 +
    '  {"type":"preference|decision|code_snippet|learning|context",' + #10 +
    '   "content":"...",   ' + #10 +
    '   "summary":"...(max 120 chars)",' + #10 +
    '   "importance":"low|medium|high",' + #10 +
    '   "tags":["tag1","tag2"]}' + #10 + #10 +
    'Conversation title: ' + AConv.Title + #10 +
    'Project: ' + AConv.ProjectPath + #10 + #10 +
    FormatMessagesForPrompt(AMessages);
end;

procedure TC4DWizardMemoryManager.LearnFromConversation(
  const AConv: TConversation;
  const AMessages: TArray<TConversationMessage>);
var
  LResponse  : string;
  LParsed    : TJSONValue;
  LArr       : TJSONArray;
  I          : Integer;
  LEntry     : TMemoryEntry;
  LItemObj   : TJSONObject;
  LTagsArr   : TJSONArray;
begin
  // Always store a conversation-summary memory
  var LSumMem    := Default(TMemoryEntry);
  LSumMem.Type_  := mtConversation;
  LSumMem.Importance := miMedium;
  LSumMem.Summary    := AConv.Title;
  LSumMem.Content    := AConv.Summary;
  LSumMem.Tags       := AConv.Tags;
  LSumMem.ProjectPath := AConv.ProjectPath;
  LSumMem.SetMetaValue('conversation_id', AConv.Id);
  LSumMem.SetMetaValue('message_count', Length(AMessages).ToString);
  AddMemory(LSumMem);

  // If no AI client, skip extraction
  if not Assigned(FAIClient) or (Length(AMessages) = 0) then Exit;

  try
    LResponse := FAIClient.GetCompletion(
      ExtractLearningPrompt(AConv, AMessages), '', '');

    // Strip possible markdown fences
    LResponse := LResponse.Trim;
    if LResponse.StartsWith('```') then
    begin
      var LEnd := LResponse.IndexOf(']');
      var LStart := LResponse.IndexOf('[');
      if (LStart >= 0) and (LEnd > LStart) then
        LResponse := LResponse.Substring(LStart, LEnd - LStart + 1);
    end;

    LParsed := TJSONObject.ParseJSONValue(LResponse);
    if not (LParsed is TJSONArray) then
    begin
      LParsed.Free;
      Exit;
    end;

    LArr := LParsed as TJSONArray;
    try
      for I := 0 to LArr.Count - 1 do
      begin
        LItemObj := LArr.Items[I] as TJSONObject;
        LEntry := Default(TMemoryEntry);
        LEntry.Type_      := StrToMemoryType(LItemObj.GetValue<string>('type', 'learning'));
        LEntry.Content    := LItemObj.GetValue<string>('content', '');
        LEntry.Summary    := LItemObj.GetValue<string>('summary', '');
        LEntry.Importance := StrToImportance(LItemObj.GetValue<string>('importance', 'medium'));
        LTagsArr          := LItemObj.GetValue<TJSONArray>('tags', nil);
        LEntry.Tags       := JSONToStringArray(LTagsArr);
        LEntry.ProjectPath := AConv.ProjectPath;
        LEntry.SetMetaValue('conversation_id', AConv.Id);
        if not LEntry.Content.IsEmpty then
          AddMemory(LEntry);
      end;
    finally
      LArr.Free;
    end;
  except
    // AI or parse failure — non-fatal
  end;
end;

{ ---- Context block ---- }

function TC4DWizardMemoryManager.BuildContextBlock(const AQuery: string;
  const AProjectPath: string; AMaxEntries: Integer): string;
var
  LResults: TArray<TMemorySearchResult>;
  SB: TStringBuilder;
  R : TMemorySearchResult;
begin
  LResults := SearchMemories(AQuery, AMaxEntries, AProjectPath);
  if Length(LResults) = 0 then Exit('');

  SB := TStringBuilder.Create;
  try
    SB.AppendLine('## Relevant Memory');
    for R in LResults do
    begin
      SB.Append('- **');
      SB.Append(R.Entry.Summary);
      SB.Append('** [');
      SB.Append(MemoryTypeToStr(R.Entry.Type_));
      SB.Append(', score=');
      SB.Append(Format('%.2f', [R.Score]));
      SB.AppendLine(']');
      if not R.Entry.Content.IsEmpty and
         (R.Entry.Content <> R.Entry.Summary) then
      begin
        var LShort := R.Entry.Content;
        if LShort.Length > 300 then
          LShort := LShort.Substring(0, 300) + '…';
        SB.AppendLine('  ' + LShort);
      end;
    end;
    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ ---- Stats ---- }

function TC4DWizardMemoryManager.MemoryCount: Integer;
begin
  Result := FStorage.MemoryCount;
end;

function TC4DWizardMemoryManager.ConversationCount: Integer;
begin
  Result := FStorage.ConversationCount;
end;

function TC4DWizardMemoryManager.Storage: TC4DWizardMemoryStorage;
begin
  Result := FStorage;
end;

end.
