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
  C4D.Wizard.Utils.IDE.Context;

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
    FTools: TC4DWizardMCPToolList;
    procedure InitMCPClient;
    procedure LoadTools;
    procedure SetStatus(const AText: string; AConnected: Boolean = True);
    procedure SetConnected(AConnected: Boolean);
    procedure UpdateServerButtons;
  public
    constructor Create(AOwner: TComponent); override;
  end;

var
  C4DWizardAIAssistantView: TC4DWizardAIAssistantView;

implementation

uses
  C4D.Wizard.Settings.Model,
  C4D.Wizard.AI.GitHub,
  C4D.Wizard.Utils.OTA;

{$R *.dfm}

constructor TC4DWizardAIAssistantView.Create(AOwner: TComponent);
begin
  inherited;
end;

procedure TC4DWizardAIAssistantView.FormCreate(Sender: TObject);
begin
  TC4DWizardUtilsOTA.IDEThemingAll(TC4DWizardAIAssistantView, Self);
end;

procedure TC4DWizardAIAssistantView.FormDestroy(Sender: TObject);
begin
  FMCPClient := nil;
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
    LoadTools;
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
    FTools := FMCPClient.ListTools;
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

  if FMCPClient.IsConnected then
    SetStatus(Format('%d tool(s) loaded', [lbTools.Items.Count]))
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

    LResult := FMCPClient.CallTool(LToolName, LArgs);
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
  FMCPClient := nil;
  InitMCPClient;
end;

end.
