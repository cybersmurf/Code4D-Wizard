object C4DWizardSettingsView: TC4DWizardSettingsView
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu]
  Caption = 'Code4D - Settings'
  ClientHeight = 845
  ClientWidth = 686
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poScreenCenter
  OnClose = FormClose
  OnCreate = FormCreate
  OnKeyDown = FormKeyDown
  OnShow = FormShow
  PixelsPerInch = 96
  TextHeight = 13
  object Panel9: TPanel
    Left = 0
    Top = 0
    Width = 686
    Height = 620
    Align = alClient
    BevelOuter = bvNone
    ParentBackground = False
    TabOrder = 0
    ExplicitHeight = 571
    object Bevel1: TBevel
      AlignWithMargins = True
      Left = 0
      Top = 484
      Width = 686
      Height = 1
      Margins.Left = 0
      Margins.Top = 0
      Margins.Right = 0
      Align = alBottom
      Shape = bsTopLine
      ExplicitTop = 158
      ExplicitWidth = 441
    end
    object gBoxShortcut: TGroupBox
      Left = 0
      Top = 0
      Width = 686
      Height = 313
      Align = alTop
      Caption = ' Shortcut '
      TabOrder = 0
      ExplicitTop = -6
      object ckShortcutUsesOrganizationUse: TCheckBox
        Left = 48
        Top = 26
        Width = 110
        Height = 17
        Cursor = crHandPoint
        Caption = 'Uses Organization'
        TabOrder = 0
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object ckShortcutReopenFileHistoryUse: TCheckBox
        Left = 48
        Top = 51
        Width = 117
        Height = 17
        Cursor = crHandPoint
        Caption = 'Reopen File History'
        TabOrder = 2
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object ckShortcutGitHubDesktopUse: TCheckBox
        Left = 48
        Top = 256
        Width = 97
        Height = 17
        Cursor = crHandPoint
        Caption = 'GitHub Desktop'
        TabOrder = 18
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object ckShortcutTranslateTextUse: TCheckBox
        Left = 48
        Top = 77
        Width = 94
        Height = 17
        Cursor = crHandPoint
        Caption = 'Translate Text'
        TabOrder = 4
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutUsesOrganization: THotKey
        Left = 226
        Top = 26
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
      end
      object edtShortcutReopenFileHistory: THotKey
        Left = 226
        Top = 51
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
      end
      object edtShortcutGitHubDesktop: THotKey
        Left = 226
        Top = 256
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 19
      end
      object edtShortcutTranslateText: THotKey
        Left = 226
        Top = 77
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
      end
      object ckShortcutIndentUse: TCheckBox
        Left = 48
        Top = 103
        Width = 55
        Height = 17
        Cursor = crHandPoint
        Caption = 'Indent'
        TabOrder = 6
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutIndent: THotKey
        Left = 226
        Top = 103
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 7
      end
      object ckShortcutReplaceFilesUse: TCheckBox
        Left = 48
        Top = 154
        Width = 95
        Height = 17
        Cursor = crHandPoint
        Caption = 'Replace in Files'
        TabOrder = 10
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutReplaceFiles: THotKey
        Left = 226
        Top = 154
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
      end
      object ckShortcutFindInFilesUse: TCheckBox
        Left = 48
        Top = 128
        Width = 78
        Height = 17
        Cursor = crHandPoint
        Caption = 'Find in Files'
        TabOrder = 8
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutFindInFiles: THotKey
        Left = 226
        Top = 128
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
      end
      object ckShortcutDefaultFilesInOpeningProjectUse: TCheckBox
        Left = 48
        Top = 230
        Width = 174
        Height = 17
        Cursor = crHandPoint
        Caption = 'Default Files In Opening Project'
        TabOrder = 16
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutDefaultFilesInOpeningProject: THotKey
        Left = 226
        Top = 230
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 17
      end
      object ckShortcutNotesUse: TCheckBox
        Left = 48
        Top = 180
        Width = 49
        Height = 17
        Cursor = crHandPoint
        Caption = 'Notes'
        TabOrder = 12
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutNotes: THotKey
        Left = 226
        Top = 180
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 13
      end
      object ckShortcutVsCodeIntegrationOpenUse: TCheckBox
        Left = 48
        Top = 205
        Width = 101
        Height = 17
        Cursor = crHandPoint
        Caption = 'Open In VS Code'
        TabOrder = 14
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutVsCodeIntegrationOpen: THotKey
        Left = 226
        Top = 205
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 15
      end
    end
    object gBoxAIAssistant: TGroupBox
      Left = 0
      Top = 426
      Width = 686
      Height = 320
      Align = alTop
      Caption = ' AI Assistant (MCP) '
      TabOrder = 4
      object lblMCPTransport: TLabel
        Left = 8
        Top = 24
        Width = 52
        Height = 13
        Caption = 'Transport:'
      end
      object lblMCPServerURL: TLabel
        Left = 8
        Top = 52
        Width = 62
        Height = 13
        Caption = 'Server URL:'
      end
      object lblMCPAPIKey: TLabel
        Left = 8
        Top = 80
        Width = 42
        Height = 13
        Caption = 'API Key:'
      end
      object lblMCPTimeout: TLabel
        Left = 576
        Top = 80
        Width = 60
        Height = 13
        Caption = 'Timeout (ms):'
      end
      object lblMCPCommand: TLabel
        Left = 8
        Top = 112
        Width = 51
        Height = 13
        Caption = 'Command:'
      end
      object lblMCPArgs: TLabel
        Left = 8
        Top = 140
        Width = 54
        Height = 13
        Caption = 'Arguments:'
      end
      object lblMCPWorkingDir: TLabel
        Left = 8
        Top = 168
        Width = 60
        Height = 13
        Caption = 'Working Dir:'
      end
      object cmbMCPTransport: TComboBox
        Left = 78
        Top = 20
        Width = 120
        Height = 21
        Hint = 'HTTP: connect to running server  |  Stdio: launch server as child process'
        Style = csDropDownList
        ItemIndex = 0
        ParentShowHint = False
        ShowHint = True
        TabOrder = 0
        Text = 'HTTP'
        OnChange = cmbMCPTransportChange
        Items.Strings = (
          'HTTP'
          'Stdio (launch process)'
          'Embedded (built-in)')
      end
      object edtMCPServerURL: TEdit
        Left = 78
        Top = 48
        Width = 592
        Height = 21
        Hint = 'MCP server URL (e.g. http://localhost:8080/mcp)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 1
      end
      object edtMCPAPIKey: TEdit
        Left = 78
        Top = 76
        Width = 490
        Height = 21
        Hint = 'API Key / Bearer token (leave blank if not required)'
        PasswordChar = '*'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 2
      end
      object edtMCPTimeout: TEdit
        Left = 642
        Top = 76
        Width = 30
        Height = 21
        Hint = 'Request timeout in milliseconds'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 3
        Text = '30000'
      end
      object edtMCPCommand: TEdit
        Left = 78
        Top = 108
        Width = 592
        Height = 21
        Hint = 'Executable to launch (e.g. node, python, npx)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 4
      end
      object edtMCPArgs: TEdit
        Left = 78
        Top = 136
        Width = 592
        Height = 21
        Hint = 'Arguments passed to command (e.g. C:\server\index.js)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 5
      end
      object edtMCPWorkingDir: TEdit
        Left = 78
        Top = 164
        Width = 592
        Height = 21
        Hint = 'Working directory for the server process (leave blank for default)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 6
      end
      object ckShortcutAIAssistantUse: TCheckBox
        Left = 48
        Top = 290
        Width = 94
        Height = 17
        Cursor = crHandPoint
        Caption = 'AI Assistant'
        TabOrder = 7
        OnClick = ckShortcutUsesOrganizationUseClick
      end
      object edtShortcutAIAssistant: THotKey
        Left = 226
        Top = 288
        Width = 150
        Height = 19
        Cursor = crArrow
        Hint = 'Customize Shortcut'
        HotKey = 0
        InvalidKeys = [hcNone]
        Modifiers = []
        ParentShowHint = False
        ShowHint = True
        TabOrder = 8
      end
      object lblGitHubToken: TLabel
        Left = 8
        Top = 204
        Width = 69
        Height = 13
        Caption = 'GitHub Token:'
        Visible = False
      end
      object lblGitHubModel: TLabel
        Left = 8
        Top = 232
        Width = 65
        Height = 13
        Caption = 'GitHub Model:'
        Visible = False
      end
      object lblGitHubEndpoint: TLabel
        Left = 8
        Top = 260
        Width = 76
        Height = 13
        Caption = 'GitHub Endpoint:'
        Visible = False
      end
      object edtGitHubToken: TEdit
        Left = 92
        Top = 200
        Width = 578
        Height = 21
        Hint = 'GitHub Personal Access Token (or leave blank to use GITHUB_TOKEN env var)'
        PasswordChar = '*'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 9
        Visible = False
      end
      object edtGitHubModel: TEdit
        Left = 92
        Top = 228
        Width = 200
        Height = 21
        Hint = 'GitHub Models model name (e.g. gpt-4o, gpt-4o-mini)'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 10
        Text = 'gpt-4o'
        Visible = False
      end
      object edtGitHubEndpoint: TEdit
        Left = 92
        Top = 256
        Width = 578
        Height = 21
        Hint = 'GitHub Models inference endpoint'
        ParentShowHint = False
        ShowHint = True
        TabOrder = 11
        Text = 'https://models.inference.ai.azure.com'
        Visible = False
      end
    end
    object gboxData: TGroupBox
      Left = 0
      Top = 426
      Width = 686
      Height = 58
      Align = alBottom
      Caption = ' Data '
      Padding.Left = 2
      Padding.Top = 5
      Padding.Bottom = 3
      TabOrder = 2
      ExplicitTop = 377
      object btnOpenDataFolder: TButton
        Left = 4
        Top = 20
        Width = 122
        Height = 33
        Cursor = crHandPoint
        Align = alLeft
        Caption = 'Open Data Folder'
        TabOrder = 0
        OnClick = btnOpenDataFolderClick
      end
    end
    object gBoxSettings: TGroupBox
      Left = 0
      Top = 313
      Width = 686
      Height = 113
      Align = alClient
      Caption = ' Settings '
      TabOrder = 1
      ExplicitTop = 281
      ExplicitHeight = 96
      object ckBlockKeyInsert: TCheckBox
        Left = 48
        Top = 48
        Width = 134
        Height = 17
        Cursor = crHandPoint
        Caption = 'Block the INSERT Key'
        TabOrder = 1
      end
      object ckBeforeCompilingCheckRunning: TCheckBox
        Left = 48
        Top = 26
        Width = 244
        Height = 17
        Cursor = crHandPoint
        Caption = 'Before compiling, check if binary is not running'
        TabOrder = 0
      end
    end
  end
  object Panel1: TPanel
    Left = 0
    Top = 620
    Width = 686
    Height = 35
    Align = alBottom
    BevelEdges = [beLeft, beRight, beBottom]
    BevelOuter = bvNone
    Padding.Left = 2
    Padding.Top = 2
    Padding.Right = 2
    Padding.Bottom = 2
    ParentBackground = False
    TabOrder = 1
    ExplicitTop = 439
    object Label4: TLabel
      Left = 8
      Top = 3
      Width = 433
      Height = 13
      Caption = 
        '* Attention, some shortcut changes only work after restarting th' +
        'e Delphi IDE'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Tahoma'
      Font.Style = [fsBold]
      ParentFont = False
    end
    object btnConfirm: TButton
      AlignWithMargins = True
      Left = 458
      Top = 2
      Width = 110
      Height = 31
      Cursor = crHandPoint
      Margins.Left = 0
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Caption = 'Confirm'
      TabOrder = 0
      OnClick = btnConfirmClick
    end
    object btnClose: TButton
      AlignWithMargins = True
      Left = 571
      Top = 2
      Width = 110
      Height = 31
      Cursor = crHandPoint
      Margins.Left = 0
      Margins.Top = 0
      Margins.Bottom = 0
      Align = alRight
      Caption = 'Close'
      TabOrder = 1
      OnClick = btnCloseClick
    end
  end
end
