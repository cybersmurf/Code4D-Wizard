unit C4D.Wizard.IDE.MainMenu.AIAssistant;

{
  AI Assistant (MCP) submenu for the Code4D main menu.
  Follows the same pattern as C4D.Wizard.IDE.MainMenu.VsCodeIntegration.
}

interface

uses
  System.SysUtils,
  System.Classes,
  VCL.Menus;

type
  IC4DWizardIDEMainMenuAIAssistant = interface
    ['{B7C5E2A1-3F49-4D8C-9E10-FA2345678901}']
    function Process: IC4DWizardIDEMainMenuAIAssistant;
  end;

  TC4DWizardIDEMainMenuAIAssistant = class(TInterfacedObject,
    IC4DWizardIDEMainMenuAIAssistant)
  private
    FMenuItemC4D: TMenuItem;
    FMenuItemAI: TMenuItem;
    procedure AddMenuAIAssistant;
    procedure AddSubMenuOpenDialog;
    procedure AddSubMenuRefreshTools;
    procedure AddSeparator(const AName: string);
    function GetShortcutAIAssistant: string;
  protected
    function Process: IC4DWizardIDEMainMenuAIAssistant;
  public
    class function New(AMenuItemParent: TMenuItem): IC4DWizardIDEMainMenuAIAssistant;
    constructor Create(AMenuItemParent: TMenuItem);
  end;

implementation

uses
  C4D.Wizard.Consts,
  C4D.Wizard.Utils,
  C4D.Wizard.IDE.ImageListMain,
  C4D.Wizard.IDE.MainMenu.Clicks,
  C4D.Wizard.Settings.Model;

class function TC4DWizardIDEMainMenuAIAssistant.New(
  AMenuItemParent: TMenuItem): IC4DWizardIDEMainMenuAIAssistant;
begin
  Result := Self.Create(AMenuItemParent);
end;

constructor TC4DWizardIDEMainMenuAIAssistant.Create(AMenuItemParent: TMenuItem);
begin
  FMenuItemC4D := AMenuItemParent;
end;

function TC4DWizardIDEMainMenuAIAssistant.Process: IC4DWizardIDEMainMenuAIAssistant;
begin
  Result := Self;
  Self.AddMenuAIAssistant;
  Self.AddSubMenuOpenDialog;
  Self.AddSeparator('C4DAIAssistantSeparator01');
  Self.AddSubMenuRefreshTools;
end;

procedure TC4DWizardIDEMainMenuAIAssistant.AddMenuAIAssistant;
begin
  FMenuItemAI := TMenuItem.Create(FMenuItemC4D);
  FMenuItemAI.Name := TC4DConsts.MENU_IDE_AI_ASSISTANT_NAME;
  FMenuItemAI.Caption := TC4DConsts.MENU_IDE_AI_ASSISTANT_CAPTION;
  FMenuItemAI.ImageIndex := TC4DWizardIDEImageListMain.GetInstance.ImgIndexC4D_Logo;
  FMenuItemC4D.Add(FMenuItemAI);
end;

procedure TC4DWizardIDEMainMenuAIAssistant.AddSubMenuOpenDialog;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Create(FMenuItemAI);
  LItem.Name := TC4DConsts.MENU_IDE_AI_ASSISTANT_OPEN_NAME;
  LItem.Caption := TC4DConsts.MENU_IDE_AI_ASSISTANT_OPEN_CAPTION;
  LItem.ImageIndex := TC4DWizardIDEImageListMain.GetInstance.ImgIndexC4D_Logo;
  LItem.OnClick := TC4DWizardIDEMainMenuClicks.AIAssistantClick;
  LItem.ShortCut := TextToShortCut(
    TC4DWizardUtils.RemoveSpacesAll(Self.GetShortcutAIAssistant));
  FMenuItemAI.Add(LItem);
end;

procedure TC4DWizardIDEMainMenuAIAssistant.AddSubMenuRefreshTools;
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Create(FMenuItemAI);
  LItem.Name := TC4DConsts.MENU_IDE_AI_ASSISTANT_REFRESH_NAME;
  LItem.Caption := TC4DConsts.MENU_IDE_AI_ASSISTANT_REFRESH_CAPTION;
  LItem.OnClick := TC4DWizardIDEMainMenuClicks.AIAssistantRefreshToolsClick;
  FMenuItemAI.Add(LItem);
end;

procedure TC4DWizardIDEMainMenuAIAssistant.AddSeparator(const AName: string);
var
  LItem: TMenuItem;
begin
  LItem := TMenuItem.Create(FMenuItemAI);
  LItem.Name := AName;
  LItem.Caption := '-';
  LItem.ImageIndex := -1;
  LItem.OnClick := nil;
  FMenuItemAI.Add(LItem);
end;

function TC4DWizardIDEMainMenuAIAssistant.GetShortcutAIAssistant: string;
begin
  Result := '';
  if C4DWizardSettingsModel.ShortcutAIAssistantUse and
     (not C4DWizardSettingsModel.ShortcutAIAssistant.Trim.IsEmpty) then
    Result := C4DWizardSettingsModel.ShortcutAIAssistant.Trim;
end;

end.
