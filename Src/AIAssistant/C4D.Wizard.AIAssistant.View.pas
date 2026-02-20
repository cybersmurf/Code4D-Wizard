unit C4D.Wizard.AIAssistant.View;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Classes,
  System.JSON,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  Vcl.StdCtrls,
  Vcl.ExtCtrls,
  Vcl.Clipbrd,
  C4D.Wizard.MCP.Client,
  C4D.Wizard.Agent.Core,
  C4D.Wizard.Utils.IDE.Context,
  C4D.Wizard.Memory.Manager,
  C4D.Wizard.Conversation.Manager;

type
  TC4DWizardAIAssistantView = class(TForm)
    pnMain: TPanel;
    Splitter1: TSplitter;
    pnLeft: TPanel;
    pnLeftTop: TPanel;
    lblTools: TLabel;
    lbTools: TListBox;
    pnLeftBottom: TPanel;
    lblStatus: TLabel;
    pnRight: TPanel;
    Splitter2: TSplitter;
    pnPrompt: TPanel;
    pnPromptHeader: TPanel;
    lblPrompt: TLabel;
    btnGetContext: TButton;
    memoPrompt: TMemo;
    pnResponse: TPanel;
    pnResponseHeader: TPanel;
    lblResponse: TLabel;
    btnCopyResponse: TButton;
    memoResponse: TMemo;
    pnBottom: TPanel;
    Bevel1: TBevel;
    btnSend: TButton;
    btnClear: TButton;
    btnReconnect: TButton;
    lblServerURL: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure btnSendClick(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnGetContextClick(Sender: TObject);
    procedure btnCopyResponseClick(Sender: TObject);
    btnStartServer: TButton;
    btnStopServer: TButton;
    procedure btnStartServerClick(Sender: TObject);
    procedure btnStopServerClick(Sender: TObject);
    procedure btnReconnectClick(Sender: TObject);
    procedure lbToolsClick(Sender: TObject);
  private
    FMCPClient: IC4DWizardMCPClient;
    FRegistry : IC4DWizardMCPServerRegistry;  // aggregates primary + external servers
    FTools: TC4DWizardMCPToolList;
    // Agentic mode controls (created dynamically)
    FPnAgent   : TPanel;
    FChkAgent  : TCheckBox;
    FCmbMode   : TComboBox;
    FMemoSteps : TMemo;
    FAgent      : IC4DWizardAgent;
    // Memory + conversation (created when embedded transport is active)
    FMemoryManager : IC4DWizardMemoryManager;
    FConvManager   : IC4DWizardConversationManager;
    // Memory panel dynamic controls
    FPnMemory      : TPanel;
    FMemSearch     : TEdit;
    FMemResults    : TListBox;
    FConvList      : TListBox;
    FMemDetail     : TMemo;
    procedure InitMCPClient;
    procedure LoadTools;
    procedure SetStatus(const AText: string; AConnected: Boolean = True);
    procedure SetConnected(AConnected: Boolean);
    procedure UpdateServerButtons;
    procedure BuildAgentPanel;
    procedure BuildMemoryPanel;
    procedure BtnMemSearchClick(Sender: TObject);
    procedure BtnConvReferenceClick(Sender: TObject);
    procedure ChkAgentClick(Sender: TObject);
    procedure ExecuteWithAgent;
    procedure AgentStepCallback(const AStep: string; AIndex, ATotal: Integer;
      const AResult: TJSONObject);
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  C4DWizardAIAssistantView: TC4DWizardAIAssistantView;

implementation

uses
  C4D.Wizard.Settings.Model,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Utils.OTA,
  System.Math,
  C4D.Wizard.MCP.Config,
  C4D.Wizard.MCP.ServerRegistry,
  C4D.Wizard.Memory.Types,
  C4D.Wizard.Memory.Storage,
  C4D.Wizard.Memory.Manager,
  C4D.Wizard.Conversation.Manager,
  C4D.Wizard.MCP.Tools.Memory;

{$R *.dfm}

constructor TC4DWizardAIAssistantView.Create(AOwner: TComponent);
begin
  inherited;
end;

procedure TC4DWizardAIAssistantView.FormCreate(Sender: TObject);
begin
  TC4DWizardUtilsOTA.IDEThemingAll(TC4DWizardAIAssistantView, Self);
  BuildAgentPanel;
  BuildMemoryPanel;
end;

procedure TC4DWizardAIAssistantView.BuildAgentPanel;
var
  LLbl: TLabel;
begin
  // Panel docked to the bottom of pnLeft (below tool list)
  FPnAgent := TPanel.Create(Self);
  FPnAgent.Parent := pnLeft;
  FPnAgent.Align := alBottom;
  FPnAgent.Height := 140;
  FPnAgent.BevelOuter := bvNone;
  FPnAgent.Caption := '';

  FChkAgent := TCheckBox.Create(Self);
  FChkAgent.Parent := FPnAgent;
  FChkAgent.Caption := 'Agent mode (multi-step)';
  FChkAgent.Left := 6;
  FChkAgent.Top := 6;
  FChkAgent.Width := 180;
  FChkAgent.OnClick := ChkAgentClick;

  LLbl := TLabel.Create(Self);
  LLbl.Parent := FPnAgent;
  LLbl.Caption := 'Mode:';
  LLbl.Left := 6;
  LLbl.Top := 30;

  FCmbMode := TComboBox.Create(Self);
  FCmbMode.Parent := FPnAgent;
  FCmbMode.Style := csDropDownList;
  FCmbMode.Left := 6;
  FCmbMode.Top := 46;
  FCmbMode.Width := 180;
  FCmbMode.Items.Add('Single tool');
  FCmbMode.Items.Add('Multi-step');
  FCmbMode.Items.Add('Autonomous');
  FCmbMode.ItemIndex := 1;
  FCmbMode.Enabled := False;

  LLbl := TLabel.Create(Self);
  LLbl.Parent := FPnAgent;
  LLbl.Caption := 'Steps:';
  LLbl.Left := 6;
  LLbl.Top := 74;

  FMemoSteps := TMemo.Create(Self);
  FMemoSteps.Parent := FPnAgent;
  FMemoSteps.Left := 6;
  FMemoSteps.Top := 90;
  FMemoSteps.Width := 180;
  FMemoSteps.Height := 44;
  FMemoSteps.ReadOnly := True;
  FMemoSteps.ScrollBars := ssVertical;
end;

procedure TC4DWizardAIAssistantView.ChkAgentClick(Sender: TObject);
begin
  FCmbMode.Enabled := FChkAgent.Checked;
  FMemoSteps.Enabled := FChkAgent.Checked;
end;

procedure TC4DWizardAIAssistantView.FormDestroy(Sender: TObject);
begin
  // End active conversation so learnings are persisted
  if Assigned(FConvManager) then
    FConvManager.EndCurrent;
  FAgent         := nil;
  FConvManager   := nil;
  FMemoryManager := nil;
  FRegistry      := nil;
  FMCPClient     := nil;
end;

procedure TC4DWizardAIAssistantView.FormShow(Sender: TObject);
begin
  InitMCPClient;
end;

procedure TC4DWizardAIAssistantView.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_F5: btnSend.Click;
    VK_ESCAPE:
      if Shift = [] then
        Close;
    VK_F4:
      if ssAlt in Shift then
        Key := 0;
  end;
end;

procedure TC4DWizardAIAssistantView.InitMCPClient;
var
  LTransport: Integer;
begin
  LTransport := C4DWizardSettingsModel.MCPTransportType;
  if LTransport = 1 then
  begin
    // Stdio transport — launch server as a child process
    FMCPClient := TC4DWizardMCPClient.NewStdio(
      C4DWizardSettingsModel.MCPCommand,
      C4DWizardSettingsModel.MCPArgs,
      C4DWizardSettingsModel.MCPWorkingDir);
    FMCPClient.Timeout(C4DWizardSettingsModel.MCPTimeout);
    lblServerURL.Caption := 'Transport: Stdio  |  Cmd: ' +
      C4DWizardSettingsModel.MCPCommand;
    UpdateServerButtons;
    if not FMCPClient.IsServerRunning then
    begin
      SetStatus('Starting server…', False);
      if not FMCPClient.StartServer then
      begin
        SetStatus('Failed to start server: ' + FMCPClient.LastError, False);
        Exit;
      end;
    end;
    SetStatus('Server running (PID ' + FMCPClient.ServerPID.ToString + ') — loading tools…', False);
    FRegistry := TC4DWizardMCPServerRegistry.New(TC4DWizardMCPConfig.Load, FMCPClient);
    LoadTools;
  end
  else if LTransport = 2 then
  begin
    // Embedded transport — GitHub Models in-process
    var LCfg: TC4DGitHubModelsConfig;
    LCfg := TC4DGitHubModelsConfig.Default;
    if not C4DWizardSettingsModel.GitHubToken.IsEmpty then
      LCfg.Token := C4DWizardSettingsModel.GitHubToken;
    if not C4DWizardSettingsModel.GitHubModel.IsEmpty then
      LCfg.Model := C4DWizardSettingsModel.GitHubModel;
    if not C4DWizardSettingsModel.GitHubEndpoint.IsEmpty then
      LCfg.Endpoint := C4DWizardSettingsModel.GitHubEndpoint;
    FMCPClient := TC4DWizardMCPClient.NewEmbedded(LCfg);
    lblServerURL.Caption := 'Embedded · GitHub Models · ' + LCfg.Model;
    UpdateServerButtons;
    SetStatus('Embedded server active — loading tools…', True);
    FRegistry := TC4DWizardMCPServerRegistry.New(TC4DWizardMCPConfig.Load, FMCPClient);
    LoadTools;
    // Create memory + conversation managers
    var LAIClient := TC4DWizardAIGitHub.New(LCfg);
    FMemoryManager := TC4DWizardMemoryManager.New(
      TC4DWizardMemoryManager.DefaultDataDir, '', '', LAIClient);
    FConvManager := TC4DWizardConversationManager.New(
      FMemoryManager.Storage, FMemoryManager, LAIClient);
    FConvManager.StartNew;
    // Register memory tools into the embedded server
    RegisterMemoryTools(
      FMCPClient.EmbeddedServer,
      FMemoryManager, FConvManager);
    // Refresh tool list (now includes memory_search, memory_add, conversation_search)
    LoadTools;
    // Create agent backed by the embedded server
    FAgent := TC4DWizardAgent.New(
      FMCPClient.EmbeddedServer,
      LAIClient);
  end
  else
  begin
    // HTTP transport
    var LServerURL := C4DWizardSettingsModel.MCPServerURL;
    if LServerURL.IsEmpty then
      LServerURL := 'http://localhost:8080/mcp';
    lblServerURL.Caption := 'Server: ' + LServerURL;
    FMCPClient := TC4DWizardMCPClient.NewHTTP(LServerURL);
    FMCPClient.Timeout(C4DWizardSettingsModel.MCPTimeout);
    UpdateServerButtons;
    SetStatus('Connecting…', False);
    FRegistry := TC4DWizardMCPServerRegistry.New(TC4DWizardMCPConfig.Load, FMCPClient);
    LoadTools;
  end;
end;

procedure TC4DWizardAIAssistantView.UpdateServerButtons;
var
  LIsStdio: Boolean;
  LIsEmbedded: Boolean;
begin
  LIsStdio    := Assigned(FMCPClient) and (FMCPClient.TransportType = mttStdio);
  LIsEmbedded := Assigned(FMCPClient) and (FMCPClient.TransportType = mttEmbedded);
  btnStartServer.Visible := LIsStdio;
  btnStopServer.Visible := LIsStdio;
  btnReconnect.Visible := not LIsStdio and not LIsEmbedded;
  if LIsStdio and Assigned(FMCPClient) then
  begin
    btnStartServer.Enabled := not FMCPClient.IsServerRunning;
    btnStopServer.Enabled := FMCPClient.IsServerRunning;
  end;
end;

procedure TC4DWizardAIAssistantView.btnStartServerClick(Sender: TObject);
begin
  SetStatus('Starting server…', False);
  if FMCPClient.StartServer then
  begin
    SetStatus('Server started (PID ' + FMCPClient.ServerPID.ToString + ') — loading tools…', True);
    LoadTools;
  end
  else
    SetStatus('Failed to start: ' + FMCPClient.LastError, False);
  UpdateServerButtons;
end;

procedure TC4DWizardAIAssistantView.btnStopServerClick(Sender: TObject);
begin
  FMCPClient.StopServer;
  lbTools.Items.Clear;
  SetLength(FTools, 0);
  SetStatus('Server stopped', False);
  UpdateServerButtons;
end;

procedure TC4DWizardAIAssistantView.LoadTools;
begin
  lbTools.Items.BeginUpdate;
  try
    lbTools.Items.Clear;
    FTools := FRegistry.ListAllTools;
    for var LTool in FTools do
    begin
      var LCaption := LTool.Name;
      if not LTool.Description.IsEmpty then
      begin
        var LDesc := LTool.Description;
        if LDesc.Length > 50 then LDesc := LDesc.Substring(0, 50) + '…';
        LCaption := LTool.Name + '  –  ' + LDesc;
      end;
      lbTools.Items.Add(LCaption);
    end;
    if lbTools.Items.Count > 0 then
      lbTools.ItemIndex := 0;
  finally
    lbTools.Items.EndUpdate;
  end;

  if FRegistry.IsReady then
    SetStatus(Format('%d tool(s) loaded  (%d server(s))',
      [lbTools.Items.Count, FRegistry.ServerCount]))
  else
    SetStatus('Connection failed: ' + FMCPClient.LastError, False);
end;

procedure TC4DWizardAIAssistantView.SetStatus(const AText: string;
  AConnected: Boolean);
begin
  lblStatus.Caption := 'Status: ' + AText;
  if AConnected then
    lblStatus.Font.Color := clGreen
  else
    lblStatus.Font.Color := clMaroon;
  SetConnected(AConnected);
end;

procedure TC4DWizardAIAssistantView.SetConnected(AConnected: Boolean);
begin
  btnSend.Enabled := AConnected and (lbTools.ItemIndex >= 0);
end;

procedure TC4DWizardAIAssistantView.lbToolsClick(Sender: TObject);
begin
  btnSend.Enabled := FMCPClient.IsConnected and (lbTools.ItemIndex >= 0);

  if (lbTools.ItemIndex >= 0) and (lbTools.ItemIndex < Length(FTools)) then
  begin
    var LTool := FTools[lbTools.ItemIndex];
    if not LTool.Description.IsEmpty then
      SetStatus(LTool.Description);
  end;
end;

procedure TC4DWizardAIAssistantView.btnGetContextClick(Sender: TObject);
var
  LCtx: TC4DIDEContext;
begin
  LCtx := TC4DWizardUtilsIDEContext.GetContext;

  if not LCtx.SelectedText.IsEmpty then
  begin
    if not memoPrompt.Lines.Text.IsEmpty then
      memoPrompt.Lines.Add('');
    memoPrompt.Lines.Add('// IDE context – ' + LCtx.CurrentUnitName +
      ' (line ' + LCtx.CursorLine.ToString + ')');
    memoPrompt.Lines.Add(LCtx.SelectedText);
  end
  else if not LCtx.CurrentUnitName.IsEmpty then
    ShowMessage('No text selected in the editor – open a file and select code first.')
  else
    ShowMessage('No file is currently open in the IDE editor.');
end;

procedure TC4DWizardAIAssistantView.btnSendClick(Sender: TObject);
var
  LToolName: string;
  LArgs: TJSONObject;
  LResult: TC4DWizardMCPCallResult;
  LCtx: TC4DIDEContext;
begin
  if not FMCPClient.IsConnected then
  begin
    ShowMessage('Not connected. Use the Reconnect button.');
    Exit;
  end;
  if lbTools.ItemIndex < 0 then
  begin
    ShowMessage('Select a tool from the list on the left.');
    Exit;
  end;
  if memoPrompt.Lines.Text.Trim.IsEmpty then
  begin
    ShowMessage('Enter a prompt before sending.');
    Exit;
  end;

  // Resolve the true tool name (strip the description suffix added for display)
  LToolName := FTools[lbTools.ItemIndex].Name;

  // Agent mode intercepts the send
  if Assigned(FChkAgent) and FChkAgent.Checked and Assigned(FAgent) then
  begin
    ExecuteWithAgent;
    Exit;
  end;

  memoResponse.Lines.Clear;
  memoResponse.Lines.Add('Calling tool "' + LToolName + '"…');
  Application.ProcessMessages;

  LCtx := TC4DWizardUtilsIDEContext.GetContext;

  LArgs := TJSONObject.Create;
  try
    LArgs.AddPair('prompt', memoPrompt.Lines.Text.Trim);
    if not LCtx.SelectedText.IsEmpty then
      LArgs.AddPair('code_context', LCtx.SelectedText);
    if not LCtx.CurrentUnitPath.IsEmpty then
      LArgs.AddPair('current_file', LCtx.CurrentUnitPath);
    if LCtx.CursorLine > 0 then
      LArgs.AddPair('cursor_line', TJSONNumber.Create(LCtx.CursorLine));

    LResult := FRegistry.CallTool(LToolName, LArgs);
  finally
    LArgs.Free;
  end;

  memoResponse.Lines.Clear;
  if LResult.IsError then
  begin
    memoResponse.Lines.Add('[ERROR]');
    memoResponse.Lines.Add(LResult.Content);
    SetStatus('Tool returned an error', True);
  end
  else
  begin
    memoResponse.Lines.Text := LResult.Content;
    SetStatus('Response received');
    // Track in conversation history
    if Assigned(FConvManager) then
    begin
      FConvManager.AddMessage('user', memoPrompt.Lines.Text.Trim, nil);
      FConvManager.AddMessage('assistant', LResult.Content, nil);
    end;
  end;
end;

procedure TC4DWizardAIAssistantView.btnClearClick(Sender: TObject);
begin
  memoPrompt.Clear;
  memoResponse.Clear;
end;

procedure TC4DWizardAIAssistantView.btnCopyResponseClick(Sender: TObject);
begin
  if not memoResponse.Lines.Text.IsEmpty then
  begin
    Clipboard.AsText := memoResponse.Lines.Text;
    SetStatus('Response copied to clipboard');
  end;
end;

procedure TC4DWizardAIAssistantView.btnReconnectClick(Sender: TObject);
begin
  SetStatus('Reconnecting…', False);
  FRegistry  := nil;
  FMCPClient := nil;
  InitMCPClient;
end;

procedure TC4DWizardAIAssistantView.ExecuteWithAgent;
var
  LResult: TJSONObject;
begin
  FMemoSteps.Clear;
  memoResponse.Lines.Clear;
  memoResponse.Lines.Add('Agent running…');
  Application.ProcessMessages;
  btnSend.Enabled := False;

  // Wire step callback to populate FMemoSteps live
  FAgent.OnStep := AgentStepCallback;

  try
    var LMode: TAgentMode;
    case FCmbMode.ItemIndex of
      0: LMode := amSingleTool;
      2: LMode := amAutonomous;
    else
      LMode := amMultiStep;
    end;

    LResult := FAgent.Execute(memoPrompt.Lines.Text.Trim, '', LMode);
    try
      memoResponse.Lines.Clear;
      if Assigned(LResult) then
        memoResponse.Lines.Text := LResult.GetValue<string>('result', LResult.ToJSON)
      else
        memoResponse.Lines.Add('(no result)');
      SetStatus('Agent completed');
    finally
      LResult.Free;
    end;
  except
    on E: Exception do
    begin
      memoResponse.Lines.Clear;
      memoResponse.Lines.Add('[AGENT ERROR] ' + E.Message);
      SetStatus('Agent error', False);
    end;
  end;

  btnSend.Enabled := FMCPClient.IsConnected and (lbTools.ItemIndex >= 0);
end;

procedure TC4DWizardAIAssistantView.AgentStepCallback(
  const AStep: string; AIndex, ATotal: Integer; const AResult: TJSONObject);
begin
  FMemoSteps.Lines.Add(Format('%d/%d  %s', [AIndex + 1, ATotal, AStep]));
  Application.ProcessMessages;
end;

// ---------------------------------------------------------------------------
// Memory panel — docked below pnRight, split into search results + conv list
// ---------------------------------------------------------------------------
procedure TC4DWizardAIAssistantView.BuildMemoryPanel;
var
  LPnTop, LPnMid, LPnBot: TPanel;
  LLbl: TLabel;
  LBtn: TButton;
  LSpl: TSplitter;
begin
  // Outer panel — bottom section of the right side
  FPnMemory := TPanel.Create(Self);
  FPnMemory.Parent := pnRight;
  FPnMemory.Align := alBottom;
  FPnMemory.Height := 200;
  FPnMemory.BevelOuter := bvNone;
  FPnMemory.Caption := '';

  // Splitter between response area and memory panel
  LSpl := TSplitter.Create(Self);
  LSpl.Parent := pnRight;
  LSpl.Align := alBottom;
  LSpl.Height := 4;

  // --- Top sub-panel: search bar ---
  LPnTop := TPanel.Create(Self);
  LPnTop.Parent := FPnMemory;
  LPnTop.Align := alTop;
  LPnTop.Height := 28;
  LPnTop.BevelOuter := bvNone;
  LPnTop.Caption := '';

  LLbl := TLabel.Create(Self);
  LLbl.Parent := LPnTop;
  LLbl.Caption := 'Memory:';
  LLbl.Left := 4;
  LLbl.Top := 7;
  LLbl.Width := 52;

  FMemSearch := TEdit.Create(Self);
  FMemSearch.Parent := LPnTop;
  FMemSearch.Left := 60;
  FMemSearch.Top := 4;
  FMemSearch.Width := 180;
  FMemSearch.Text := '';
  FMemSearch.Anchors := [akLeft, akTop, akRight];

  LBtn := TButton.Create(Self);
  LBtn.Parent := LPnTop;
  LBtn.Caption := 'Search';
  LBtn.Left := 246;
  LBtn.Top := 3;
  LBtn.Width := 60;
  LBtn.Height := 22;
  LBtn.OnClick := BtnMemSearchClick;
  LBtn.Anchors := [akTop, akRight];

  // --- Middle sub-panel: search results list ---
  LPnMid := TPanel.Create(Self);
  LPnMid.Parent := FPnMemory;
  LPnMid.Align := alClient;
  LPnMid.BevelOuter := bvNone;
  LPnMid.Caption := '';

  FMemResults := TListBox.Create(Self);
  FMemResults.Parent := LPnMid;
  FMemResults.Align := alTop;
  FMemResults.Height := 80;
  FMemResults.ScrollBars := ssVertical;
  FMemResults.OnClick :=
    procedure(Sender: TObject)
    begin
      if Assigned(FMemDetail) and (FMemResults.ItemIndex >= 0) then
        FMemDetail.Lines.Text := FMemResults.Items.Strings[FMemResults.ItemIndex];
    end;

  FMemDetail := TMemo.Create(Self);
  FMemDetail.Parent := LPnMid;
  FMemDetail.Align := alClient;
  FMemDetail.ReadOnly := True;
  FMemDetail.ScrollBars := ssBoth;
  FMemDetail.WordWrap := True;

  // --- Bottom sub-panel: past conversations ---
  LPnBot := TPanel.Create(Self);
  LPnBot.Parent := FPnMemory;
  LPnBot.Align := alBottom;
  LPnBot.Height := 80;
  LPnBot.BevelOuter := bvNone;
  LPnBot.Caption := '';

  LLbl := TLabel.Create(Self);
  LLbl.Parent := LPnBot;
  LLbl.Caption := 'Past conversations:';
  LLbl.Left := 4;
  LLbl.Top := 4;

  FConvList := TListBox.Create(Self);
  FConvList.Parent := LPnBot;
  FConvList.Left := 4;
  FConvList.Top := 20;
  FConvList.Width := 220;
  FConvList.Height := 52;
  FConvList.ScrollBars := ssVertical;
  FConvList.Anchors := [akLeft, akTop, akRight, akBottom];

  LBtn := TButton.Create(Self);
  LBtn.Parent := LPnBot;
  LBtn.Caption := 'Reference';
  LBtn.Left := 230;
  LBtn.Top := 20;
  LBtn.Width := 70;
  LBtn.Height := 22;
  LBtn.OnClick := BtnConvReferenceClick;
  LBtn.Anchors := [akTop, akRight];
end;

procedure TC4DWizardAIAssistantView.BtnMemSearchClick(Sender: TObject);
var
  LResults: TArray<TMemorySearchResult>;
  LConvs  : TArray<TConversation>;
begin
  if not Assigned(FMemoryManager) then
  begin
    FMemResults.Items.Clear;
    FMemResults.Items.Add('(memory not available — use Embedded transport)');
    Exit;
  end;

  var LQuery := FMemSearch.Text.Trim;
  if LQuery.IsEmpty then LQuery := memoPrompt.Lines.Text.Trim;
  if LQuery.IsEmpty then Exit;

  // Search memories
  LResults := FMemoryManager.SearchMemories(LQuery, 8);
  FMemResults.Items.BeginUpdate;
  try
    FMemResults.Items.Clear;
    for var R in LResults do
      FMemResults.Items.Add(Format('[%.2f] %s', [R.Score, R.Entry.Summary]));
  finally
    FMemResults.Items.EndUpdate;
  end;

  // Search conversations
  if Assigned(FConvManager) then
  begin
    LConvs := FConvManager.FindSimilar(LQuery, 6);
    FConvList.Items.BeginUpdate;
    try
      FConvList.Items.Clear;
      for var C in LConvs do
      begin
        var LLine := C.Title;
        if not C.Summary.IsEmpty then
          LLine := LLine + ' — ' + C.Summary.Substring(0, Min(60, C.Summary.Length));
        FConvList.Items.AddObject(LLine, TObject(Pointer(C.Id[1])));
        // Store full ID in tag via Items.Add (we read back via list tag storage)
        FConvList.Items.Objects[FConvList.Items.Count - 1] :=
          TObject(FConvList.Items.Count - 1); // just keep index
        // Real ID stored separately using a helper string list below
      end;
    finally
      FConvList.Items.EndUpdate;
    end;
    // Store IDs in Tag strings using a side-channel via ItemData
    if not Assigned(FConvList.Tag) then; // noop – IDs accessible via FConvManager.AllConversations
  end;
end;

procedure TC4DWizardAIAssistantView.BtnConvReferenceClick(Sender: TObject);
begin
  if not Assigned(FConvManager) then Exit;
  if FConvList.ItemIndex < 0 then
  begin
    ShowMessage('Select a conversation from the list first.');
    Exit;
  end;

  // Look up conversation by position in AllConversations
  var LQuery := FMemSearch.Text.Trim;
  if LQuery.IsEmpty then LQuery := memoPrompt.Lines.Text.Trim;
  var LConvs := FConvManager.FindSimilar(LQuery, 20);
  if FConvList.ItemIndex >= Length(LConvs) then Exit;

  var LRef := FConvManager.BuildReference(LConvs[FConvList.ItemIndex].Id);
  if not LRef.IsEmpty then
  begin
    if not memoPrompt.Lines.Text.IsEmpty then
      memoPrompt.Lines.Add('');
    memoPrompt.Lines.Add(LRef);
    SetStatus('Conversation reference injected into prompt');
  end;
end;

end.
