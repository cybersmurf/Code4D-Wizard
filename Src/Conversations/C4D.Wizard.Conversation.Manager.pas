unit C4D.Wizard.Conversation.Manager;

{
  Conversation Manager + Export for Code4D Wizard
  =================================================
  Manages the lifetime of a conversation:
    StartNew → AddMessage (n times) → End → triggers memory learning

  Also provides:
  • JSON / Markdown export
  • Cross-conversation similarity search (via MemoryManager)
  • Reference injection (pulls summary + key points from a past conversation)
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.Generics.Collections,
  C4D.Wizard.Memory.Types,
  C4D.Wizard.Memory.Storage,
  C4D.Wizard.Memory.Manager,
  C4D.Wizard.AI.GitHub;

type
  IC4DWizardConversationManager = interface
    ['{D4E5F6A7-B8C9-0123-DEF0-234567890123}']
    // Lifecycle
    procedure StartNew(const AProjectPath: string = '');
    procedure EndCurrent;

    // Messages
    procedure AddMessage(const ARole, AContent: string;
      const ACodeBlocks: TArray<string>);
    function  Messages: TArray<TConversationMessage>;
    function  CurrentConversation: TConversation;

    // Search & reference
    function  FindSimilar(const AQuery: string;
      ALimit: Integer = 5): TArray<TConversation>;
    function  BuildReference(const AConversationId: string): string;

    // Export
    procedure ExportJSON(const AFilePath: string);
    procedure ExportMarkdown(const AFilePath: string);

    // History
    function  AllConversations: TArray<TConversation>;
    function  LoadConversationMessages(
      const AConvId: string): TArray<TConversationMessage>;
  end;

  TC4DWizardConversationManager = class(TInterfacedObject,
    IC4DWizardConversationManager)
  private
    FStorage       : TC4DWizardMemoryStorage;   // not owned
    FMemoryManager : IC4DWizardMemoryManager;   // not owned (interface ref)
    FAIClient      : IC4DWizardAIGitHub;        // may be nil
    FCurrent       : TConversation;
    FMessages      : TList<TConversationMessage>;
    FHasActive     : Boolean;

    function GenerateTitle(const AMessages: TArray<TConversationMessage>): string;
    function GenerateSummary(
      const AMessages: TArray<TConversationMessage>): string;
  protected
    procedure StartNew(const AProjectPath: string);
    procedure EndCurrent;
    procedure AddMessage(const ARole, AContent: string;
      const ACodeBlocks: TArray<string>);
    function  Messages: TArray<TConversationMessage>;
    function  CurrentConversation: TConversation;
    function  FindSimilar(const AQuery: string;
      ALimit: Integer): TArray<TConversation>;
    function  BuildReference(const AConversationId: string): string;
    procedure ExportJSON(const AFilePath: string);
    procedure ExportMarkdown(const AFilePath: string);
    function  AllConversations: TArray<TConversation>;
    function  LoadConversationMessages(
      const AConvId: string): TArray<TConversationMessage>;
  public
    constructor Create(AStorage: TC4DWizardMemoryStorage;
      const AMemoryManager: IC4DWizardMemoryManager;
      const AAIClient: IC4DWizardAIGitHub = nil);
    destructor Destroy; override;
    class function New(AStorage: TC4DWizardMemoryStorage;
      const AMemoryManager: IC4DWizardMemoryManager;
      const AAIClient: IC4DWizardAIGitHub = nil): IC4DWizardConversationManager;
  end;

implementation

uses
  System.DateUtils,
  System.Math;

{ TC4DWizardConversationManager }

class function TC4DWizardConversationManager.New(
  AStorage: TC4DWizardMemoryStorage;
  const AMemoryManager: IC4DWizardMemoryManager;
  const AAIClient: IC4DWizardAIGitHub): IC4DWizardConversationManager;
begin
  Result := TC4DWizardConversationManager.Create(
    AStorage, AMemoryManager, AAIClient);
end;

constructor TC4DWizardConversationManager.Create(
  AStorage: TC4DWizardMemoryStorage;
  const AMemoryManager: IC4DWizardMemoryManager;
  const AAIClient: IC4DWizardAIGitHub);
begin
  FStorage       := AStorage;
  FMemoryManager := AMemoryManager;
  FAIClient      := AAIClient;
  FMessages      := TList<TConversationMessage>.Create;
  FHasActive     := False;
end;

destructor TC4DWizardConversationManager.Destroy;
begin
  if FHasActive then
    EndCurrent;
  FMessages.Free;
  FAIClient      := nil;
  FMemoryManager := nil;
  inherited;
end;

{ ---- Lifecycle ---- }

procedure TC4DWizardConversationManager.StartNew(const AProjectPath: string);
begin
  if FHasActive then
    EndCurrent;

  FCurrent := Default(TConversation);
  FCurrent.Id          := StringReplace(StringReplace(
    GUIDToString(TGUID.NewGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]).Replace('-','').ToLower;
  FCurrent.Title       := 'New Conversation';
  FCurrent.CreatedAt   := Now;
  FCurrent.UpdatedAt   := Now;
  FCurrent.MessageCount := 0;
  FCurrent.ProjectPath := AProjectPath;

  FMessages.Clear;
  FStorage.SaveConversationHeader(FCurrent);
  FHasActive := True;
end;

procedure TC4DWizardConversationManager.EndCurrent;
var
  LMsgs: TArray<TConversationMessage>;
begin
  if not FHasActive then Exit;
  FHasActive := False;
  LMsgs := FMessages.ToArray;

  if Length(LMsgs) > 0 then
  begin
    FCurrent.Title       := GenerateTitle(LMsgs);
    FCurrent.Summary     := GenerateSummary(LMsgs);
    FCurrent.MessageCount := Length(LMsgs);
    FCurrent.UpdatedAt   := Now;
    FStorage.SaveConversationHeader(FCurrent);

    if Assigned(FMemoryManager) then
      FMemoryManager.LearnFromConversation(FCurrent, LMsgs);
  end;
end;

{ ---- Messages ---- }

procedure TC4DWizardConversationManager.AddMessage(const ARole, AContent: string;
  const ACodeBlocks: TArray<string>);
var
  LMsg: TConversationMessage;
begin
  if not FHasActive then
    StartNew;

  LMsg := Default(TConversationMessage);
  LMsg.Id             := StringReplace(StringReplace(
    GUIDToString(TGUID.NewGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]).Replace('-','').ToLower;
  LMsg.ConversationId := FCurrent.Id;
  LMsg.Role           := ARole;
  LMsg.Content        := AContent;
  LMsg.Timestamp      := Now;
  LMsg.CodeBlocks     := ACodeBlocks;

  FMessages.Add(LMsg);
  FStorage.SaveMessage(LMsg);

  FCurrent.UpdatedAt    := Now;
  Inc(FCurrent.MessageCount);
  FStorage.SaveConversationHeader(FCurrent);
end;

function TC4DWizardConversationManager.Messages: TArray<TConversationMessage>;
begin
  Result := FMessages.ToArray;
end;

function TC4DWizardConversationManager.CurrentConversation: TConversation;
begin
  Result := FCurrent;
end;

{ ---- Title + summary generation ---- }

function TC4DWizardConversationManager.GenerateTitle(
  const AMessages: TArray<TConversationMessage>): string;
var
  LPrompt: string;
begin
  // Fallback: use first user message
  for var M in AMessages do
    if M.Role = 'user' then
    begin
      Result := M.Content;
      if Result.Length > 60 then Result := Result.Substring(0, 57) + '…';
      Break;
    end;

  // Try AI title generation
  if Assigned(FAIClient) and (Length(AMessages) >= 2) then
    try
      LPrompt := 'Generate a very short title (max 60 chars) ' +
                 'for this conversation. Return only the title, nothing else.' + #10;
      for var I := 0 to Min(3, High(AMessages)) do
        LPrompt := LPrompt + AMessages[I].Role + ': ' + AMessages[I].Content.Substring(0,200) + #10;
      var LTitle := FAIClient.GetCompletion(LPrompt, '', '').Trim;
      if (LTitle.Length > 0) and (LTitle.Length <= 80) then
        Result := LTitle;
    except
    end;
end;

function TC4DWizardConversationManager.GenerateSummary(
  const AMessages: TArray<TConversationMessage>): string;
var
  LPrompt: string;
  SB     : TStringBuilder;
begin
  if Length(AMessages) = 0 then Exit('');

  // Simple fallback: concat first & last messages
  SB := TStringBuilder.Create;
  try
    for var I := 0 to Min(2, High(AMessages)) do
      SB.AppendLine(AMessages[I].Role + ': ' + AMessages[I].Content.Substring(0, 200));
    if Length(AMessages) > 3 then
      SB.AppendLine(AMessages[High(AMessages)].Role + ': ' +
        AMessages[High(AMessages)].Content.Substring(0, 200));
    Result := SB.ToString.Trim;
  finally
    SB.Free;
  end;

  if Assigned(FAIClient) then
    try
      LPrompt := 'Summarize this conversation in 2-3 sentences:' + #10 + Result;
      var LSummary := FAIClient.GetCompletion(LPrompt, '', '').Trim;
      if LSummary.Length > 0 then Result := LSummary;
    except
    end;
end;

{ ---- Search & reference ---- }

function TC4DWizardConversationManager.FindSimilar(const AQuery: string;
  ALimit: Integer): TArray<TConversation>;
begin
  Result := FStorage.SearchConversationsByTopic(AQuery, ALimit);
end;

function TC4DWizardConversationManager.BuildReference(
  const AConversationId: string): string;
var
  LConv  : TConversation;
  LMsgs  : TArray<TConversationMessage>;
  LResult: TArray<TMemorySearchResult>;
  SB     : TStringBuilder;
begin
  if not FStorage.LoadConversationHeader(AConversationId, LConv) then
    Exit('[Conversation not found: ' + AConversationId + ']');

  SB := TStringBuilder.Create;
  try
    SB.AppendLine('## Referenced Conversation: ' + LConv.Title);
    SB.AppendLine('Date: ' + DateTimeToStr(LConv.CreatedAt));
    if not LConv.Summary.IsEmpty then
      SB.AppendLine('Summary: ' + LConv.Summary);

    // Include the first few messages as context
    LMsgs := FStorage.LoadMessages(AConversationId);
    if Length(LMsgs) > 0 then
    begin
      SB.AppendLine;
      SB.AppendLine('Key exchanges:');
      for var I := 0 to Min(3, High(LMsgs)) do
      begin
        var LShort := LMsgs[I].Content;
        if LShort.Length > 200 then LShort := LShort.Substring(0, 200) + '…';
        SB.AppendLine('  ' + LMsgs[I].Role + ': ' + LShort);
      end;
    end;

    // Memory learnings from that conversation
    if Assigned(FMemoryManager) then
    begin
      LResult := FMemoryManager.SearchMemories(LConv.Title, 3, LConv.ProjectPath);
      if Length(LResult) > 0 then
      begin
        SB.AppendLine;
        SB.AppendLine('Key learnings:');
        for var R in LResult do
          SB.AppendLine('- ' + R.Entry.Summary);
      end;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

{ ---- Export ---- }

procedure TC4DWizardConversationManager.ExportJSON(const AFilePath: string);
var
  LRoot     : TJSONObject;
  LMsgsArr  : TJSONArray;
  LMsgObj   : TJSONObject;
  LMsg      : TConversationMessage;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('id',           FCurrent.Id);
    LRoot.AddPair('title',        FCurrent.Title);
    LRoot.AddPair('summary',      FCurrent.Summary);
    LRoot.AddPair('project_path', FCurrent.ProjectPath);
    LRoot.AddPair('created_at',   DateTimeToStr(FCurrent.CreatedAt));
    LRoot.AddPair('updated_at',   DateTimeToStr(FCurrent.UpdatedAt));

    LMsgsArr := TJSONArray.Create;
    for LMsg in FMessages do
    begin
      LMsgObj := LMsg.ToJSON;
      LMsgsArr.AddElement(LMsgObj);
    end;
    LRoot.AddPair('messages', LMsgsArr);

    ForceDirectories(ExtractFilePath(AFilePath));
    TFile.WriteAllText(AFilePath, LRoot.Format(2), TEncoding.UTF8);
  finally
    LRoot.Free;
  end;
end;

procedure TC4DWizardConversationManager.ExportMarkdown(const AFilePath: string);
var
  SB : TStringBuilder;
  M  : TConversationMessage;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('# ' + FCurrent.Title);
    SB.AppendLine('> Date: ' + DateTimeToStr(FCurrent.CreatedAt));
    if not FCurrent.ProjectPath.IsEmpty then
      SB.AppendLine('> Project: ' + FCurrent.ProjectPath);
    if not FCurrent.Summary.IsEmpty then
    begin
      SB.AppendLine;
      SB.AppendLine('**Summary:** ' + FCurrent.Summary);
    end;
    SB.AppendLine;
    SB.AppendLine('---');
    SB.AppendLine;

    for M in FMessages do
    begin
      var LRoleLabel := M.Role;
      SB.AppendLine('### ' + LRoleLabel.ToUpper + '@' +
        TimeToStr(M.Timestamp));
      SB.AppendLine(M.Content);
      if Length(M.CodeBlocks) > 0 then
        for var CB in M.CodeBlocks do
        begin
          SB.AppendLine;
          SB.AppendLine('```pascal');
          SB.AppendLine(CB);
          SB.AppendLine('```');
        end;
      SB.AppendLine;
    end;

    ForceDirectories(ExtractFilePath(AFilePath));
    TFile.WriteAllText(AFilePath, SB.ToString, TEncoding.UTF8);
  finally
    SB.Free;
  end;
end;

{ ---- History ---- }

function TC4DWizardConversationManager.AllConversations: TArray<TConversation>;
begin
  Result := FStorage.AllConversations;
  // Sort by UpdatedAt desc
  var LList := TList<TConversation>.Create;
  try
    for var C in Result do LList.Add(C);
    LList.Sort(TComparer<TConversation>.Construct(
      function(const A, B: TConversation): Integer
      begin
        if A.UpdatedAt > B.UpdatedAt then Result := -1
        else if A.UpdatedAt < B.UpdatedAt then Result := 1
        else Result := 0;
      end));
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TC4DWizardConversationManager.LoadConversationMessages(
  const AConvId: string): TArray<TConversationMessage>;
begin
  Result := FStorage.LoadMessages(AConvId);
end;

end.
