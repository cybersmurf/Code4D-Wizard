unit C4D.Wizard.MCP.Tools.Memory;

{
  Memory Tools for Code4D Wizard MCP Embedded Server
  =====================================================
  Exposes three MCP tools that external LLM clients can call:

    memory_search       — semantic search over stored memories
    memory_add          — store a new memory entry
    conversation_search — find past conversations by topic

  These are registered into an existing TC4DWizardMCPEmbeddedServer
  instance by calling RegisterMemoryTools().

  The actual data is managed by IC4DWizardMemoryManager and
  IC4DWizardConversationManager which must be created and passed in.
  The embedded server only handles JSON marshalling.
}

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  C4D.Wizard.Memory.Types,
  C4D.Wizard.Memory.Manager,
  C4D.Wizard.Conversation.Manager,
  C4D.Wizard.MCP.EmbeddedServer;

/// <summary>Registers memory/conversation tools into AServer.
/// AMem and AConv must remain alive for the server's lifetime.</summary>
procedure RegisterMemoryTools(const AServer: IC4DWizardMCPEmbeddedServer;
  const AMem: IC4DWizardMemoryManager;
  const AConv: IC4DWizardConversationManager);

implementation

{ ---- tool handler factories ---- }

procedure RegisterMemoryTools(const AServer: IC4DWizardMCPEmbeddedServer;
  const AMem: IC4DWizardMemoryManager;
  const AConv: IC4DWizardConversationManager);
var
  LTool: TC4DWizardMCPToolDef;
begin
  // ----- memory_search -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'memory_search';
  LTool.Description := 'Search memories from previous conversations. ' +
    'Returns relevant entries ranked by semantic similarity. ' +
    'Use to answer "remember when…" or to provide context from past work.';
  LTool.AddParam('query', 'string', 'Natural-language search query');
  LTool.AddParam('limit', 'integer',
    'Maximum number of results (1–20, default 5)', False);
  LTool.AddParam('project_path', 'string',
    'Filter to a specific project directory path', False);

  AServer.RegisterTool(LTool,
    function(const AParams: TJSONObject): TJSONObject
    var
      LQuery   : string;
      LLimit   : Integer;
      LProject : string;
      LResults : TArray<TMemorySearchResult>;
      LArr     : TJSONArray;
      LItem    : TJSONObject;
      SB       : TStringBuilder;
    begin
      LQuery   := AParams.GetValue<string>('query', '');
      LLimit   := AParams.GetValue<Integer>('limit', 5);
      LProject := AParams.GetValue<string>('project_path', '');
      if LLimit < 1  then LLimit := 1;
      if LLimit > 20 then LLimit := 20;

      LResults := AMem.SearchMemories(LQuery, LLimit, LProject);

      SB  := TStringBuilder.Create;
      LArr := TJSONArray.Create;
      try
        if Length(LResults) = 0 then
          SB.AppendLine('No matching memories found.')
        else
        begin
          SB.AppendLine(Format('Found %d relevant memories:', [Length(LResults)]));
          SB.AppendLine;
          for var R in LResults do
          begin
            SB.AppendLine(Format('**%s** [%s, score=%.2f]',
              [R.Entry.Summary, MemoryTypeToStr(R.Entry.Type_), R.Score]));
            if (not R.Entry.Content.IsEmpty) and
               (R.Entry.Content <> R.Entry.Summary) then
            begin
              var LShort := R.Entry.Content;
              if LShort.Length > 400 then LShort := LShort.Substring(0, 400) + '…';
              SB.AppendLine(LShort);
            end;
            if Length(R.Entry.Tags) > 0 then
              SB.AppendLine('Tags: ' + string.Join(', ', R.Entry.Tags));
            SB.AppendLine;

            LItem := TJSONObject.Create;
            LItem.AddPair('id',        R.Entry.Id);
            LItem.AddPair('type',      MemoryTypeToStr(R.Entry.Type_));
            LItem.AddPair('summary',   R.Entry.Summary);
            LItem.AddPair('content',   R.Entry.Content);
            LItem.AddPair('score',     TJSONNumber.Create(R.Score));
            LItem.AddPair('importance', ImportanceToStr(R.Entry.Importance));
            LArr.AddElement(LItem);
          end;
        end;

        Result := TJSONObject.Create;
        Result.AddPair('content', TJSONArray.Create(
          TJSONObject.Create
            .AddPair('type', 'text')
            .AddPair('text', SB.ToString.TrimRight)));
        Result.AddPair('memories', LArr);
        LArr := nil;   // ownership transferred
      finally
        SB.Free;
        LArr.Free;  // only freed if not nil (i.e. exception path)
      end;
    end);

  // ----- memory_add -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'memory_add';
  LTool.Description := 'Store a new memory entry. Use when important information ' +
    'should be remembered for future conversations: preferences, decisions, patterns, etc.';
  LTool.AddParam('content',    'string', 'Full text of the memory');
  LTool.AddParam('summary',    'string', 'Short summary (max 120 chars)', False);
  LTool.AddParam('type',       'string',
    'Memory type: conversation|code_snippet|decision|preference|context|learning', False);
  LTool.AddParam('importance', 'string',
    'Importance: low|medium|high|critical', False);
  LTool.AddParam('tags',       'string',
    'Comma-separated tags for categorisation', False);
  LTool.AddParam('project_path', 'string',
    'Associate with a project path', False);

  AServer.RegisterTool(LTool,
    function(const AParams: TJSONObject): TJSONObject
    var
      LEntry: TMemoryEntry;
      LId   : string;
      LTags : string;
    begin
      LEntry := Default(TMemoryEntry);
      LEntry.Content    := AParams.GetValue<string>('content', '');
      LEntry.Summary    := AParams.GetValue<string>('summary', '');
      LEntry.Type_      := StrToMemoryType(AParams.GetValue<string>('type', 'learning'));
      LEntry.Importance := StrToImportance(AParams.GetValue<string>('importance', 'medium'));
      LEntry.ProjectPath := AParams.GetValue<string>('project_path', '');

      if LEntry.Summary.IsEmpty and (LEntry.Content.Length <= 120) then
        LEntry.Summary := LEntry.Content
      else if LEntry.Summary.IsEmpty then
        LEntry.Summary := LEntry.Content.Substring(0, 117) + '…';

      LTags := AParams.GetValue<string>('tags', '');
      if not LTags.IsEmpty then
        LEntry.Tags := LTags.Split([',', ';']);

      if LEntry.Content.IsEmpty then
      begin
        Result := TJSONObject.Create;
        Result.AddPair('content', TJSONArray.Create(
          TJSONObject.Create.AddPair('type','text')
            .AddPair('text', 'Error: content is required.')));
        Result.AddPair('isError', TJSONTrue.Create);
        Exit;
      end;

      LId := AMem.AddMemory(LEntry);

      Result := TJSONObject.Create;
      Result.AddPair('content', TJSONArray.Create(
        TJSONObject.Create.AddPair('type', 'text')
          .AddPair('text', Format('Memory stored (id=%s).', [LId]))));
      Result.AddPair('memory_id', LId);
    end);

  // ----- conversation_search -----
  LTool := TC4DWizardMCPToolDef.Create;
  LTool.Name        := 'conversation_search';
  LTool.Description := 'Search past conversation sessions by topic or keyword. ' +
    'Returns matching conversation headers. Use with memory_search for detailed look-back.';
  LTool.AddParam('query', 'string', 'Search topic or keyword');
  LTool.AddParam('limit', 'integer', 'Max results (1–20, default 5)', False);

  AServer.RegisterTool(LTool,
    function(const AParams: TJSONObject): TJSONObject
    var
      LQuery  : string;
      LLimit  : Integer;
      LConvs  : TArray<TConversation>;
      SB      : TStringBuilder;
      LArr    : TJSONArray;
      LItem   : TJSONObject;
    begin
      LQuery := AParams.GetValue<string>('query', '');
      LLimit := AParams.GetValue<Integer>('limit', 5);
      if LLimit < 1  then LLimit := 1;
      if LLimit > 20 then LLimit := 20;

      LConvs := AConv.FindSimilar(LQuery, LLimit);

      SB   := TStringBuilder.Create;
      LArr := TJSONArray.Create;
      try
        if Length(LConvs) = 0 then
          SB.AppendLine('No matching conversations found.')
        else
        begin
          SB.AppendLine(Format('Found %d matching conversations:', [Length(LConvs)]));
          SB.AppendLine;
          for var C in LConvs do
          begin
            SB.AppendLine(Format('**%s** — %s',
              [C.Title, DateTimeToStr(C.UpdatedAt)]));
            if not C.Summary.IsEmpty then
              SB.AppendLine('  ' + C.Summary);
            SB.AppendLine;

            LItem := TJSONObject.Create;
            LItem.AddPair('id',           C.Id);
            LItem.AddPair('title',        C.Title);
            LItem.AddPair('summary',      C.Summary);
            LItem.AddPair('updated_at',   DateTimeToStr(C.UpdatedAt));
            LItem.AddPair('message_count', TJSONNumber.Create(C.MessageCount));
            LArr.AddElement(LItem);
          end;
        end;

        Result := TJSONObject.Create;
        Result.AddPair('content', TJSONArray.Create(
          TJSONObject.Create.AddPair('type','text')
            .AddPair('text', SB.ToString.TrimRight)));
        Result.AddPair('conversations', LArr);
        LArr := nil;  // ownership transferred
      finally
        SB.Free;
        LArr.Free;
      end;
    end);
end;

end.
