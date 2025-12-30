unit MaxLogic.DelphiCompanion.Integration;

interface

uses
  System.Classes,
  System.SysUtils,
  ToolsAPI,
  Vcl.ActnList,
  Vcl.Menus;

type
  TMdcMenuHolder = class(TComponent)
  public
    actOptions: TAction;
    miOptions: TMenuItem;
    constructor CreateWithHandler(aOwner: TComponent; aOnExecute: TNotifyEvent);
  end;

  TMdcIdeIntegration = class
  private
    fMenuHolder: TMdcMenuHolder;

    fKeyboardBindingIndex: Integer;
    fKeyboardBinding: IInterface;

    fProjectsAction: TAction;
    fUnitsAction: TAction;

    procedure InstallKeyboardBinding;
    procedure InstallKeyboardBindingWithShortCuts(aProjects: TShortCut; aUnits: TShortCut);
    procedure UninstallKeyboardBinding;

    procedure InstallGlobalActions;
    procedure UninstallGlobalActions;
    procedure UpdateGlobalShortCuts(aProjects: TShortCut; aUnits: TShortCut);

    procedure InstallMenu;
    procedure UninstallMenu;

    procedure ProjectsExecute(Sender: TObject);
    procedure UnitsExecute(Sender: TObject);
    procedure OptionsExecute(Sender: TObject);

    function TryApplyShortCuts(aProjects: TShortCut; aUnits: TShortCut; out aError: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

uses
  Vcl.Dialogs,
  MaxLogic.DelphiCompanion.KeyboardBinding,
  MaxLogic.DelphiCompanion.OptionsForm,
  MaxLogic.DelphiCompanion.FocusErrorInsight,
  MaxLogic.DelphiCompanion.Pickers,
  MaxLogic.DelphiCompanion.Settings;

{ TMdcMenuHolder }

constructor TMdcMenuHolder.CreateWithHandler(aOwner: TComponent; aOnExecute: TNotifyEvent);
begin
  inherited Create(aOwner);

  actOptions := TAction.Create(Self);
  actOptions.Caption := 'MaxLogic Delphi Companion Options...';
  actOptions.OnExecute := aOnExecute;

  miOptions := TMenuItem.Create(Self);
  miOptions.Action := actOptions;
end;

{ TMdcIdeIntegration }

constructor TMdcIdeIntegration.Create;
begin
  inherited Create;

  fKeyboardBindingIndex := -1;
  fMenuHolder := nil;
  fProjectsAction := nil;
  fUnitsAction := nil;

  InstallKeyboardBinding;
  InstallMenu;
  InstallGlobalActions;
end;

destructor TMdcIdeIntegration.Destroy;
begin
  UninstallGlobalActions;
  UninstallMenu;
  UninstallKeyboardBinding;

  inherited Destroy;
end;

procedure TMdcIdeIntegration.InstallKeyboardBinding;
var
  lKbd: IOTAKeyboardServices;
  lBinding: IOTAKeyboardBinding;
begin
  if Supports(BorlandIDEServices, IOTAKeyboardServices, lKbd) then
  begin
    lBinding := TMdcKeyboardBinding.Create;
    fKeyboardBinding := lBinding;
    fKeyboardBindingIndex := lKbd.AddKeyboardBinding(lBinding);
  end;
end;

procedure TMdcIdeIntegration.InstallKeyboardBindingWithShortCuts(aProjects: TShortCut; aUnits: TShortCut);
var
  lKbd: IOTAKeyboardServices;
  lBinding: IOTAKeyboardBinding;
begin
  if Supports(BorlandIDEServices, IOTAKeyboardServices, lKbd) then
  begin
    lBinding := TMdcKeyboardBinding.CreateWithShortCuts(aProjects, aUnits);
    fKeyboardBinding := lBinding;
    fKeyboardBindingIndex := lKbd.AddKeyboardBinding(lBinding);
  end;
end;

procedure TMdcIdeIntegration.UninstallKeyboardBinding;
var
  lKbd: IOTAKeyboardServices;
begin
  if (fKeyboardBindingIndex >= 0) and Supports(BorlandIDEServices, IOTAKeyboardServices, lKbd) then
  begin
    lKbd.RemoveKeyboardBinding(fKeyboardBindingIndex);
    fKeyboardBindingIndex := -1;
  end;

  fKeyboardBinding := nil;
end;

function TMdcIdeIntegration.TryApplyShortCuts(aProjects: TShortCut; aUnits: TShortCut; out aError: string): Boolean;
begin
  aError := '';
  try
    UninstallKeyboardBinding;
    InstallKeyboardBindingWithShortCuts(aProjects, aUnits);
    UpdateGlobalShortCuts(aProjects, aUnits);
    Result := True;
  except
    on E: Exception do
    begin
      aError := E.Message;

      // restore persisted binding (best effort)
      try
        UninstallKeyboardBinding;
        InstallKeyboardBinding;
      except
        // ignore
      end;

      Result := False;
    end;
  end;
end;

procedure TMdcIdeIntegration.InstallMenu;
var
  lNta: INTAServices;
begin
  UninstallMenu;

  if Supports(BorlandIDEServices, INTAServices, lNta) then
  begin
    fMenuHolder := TMdcMenuHolder.CreateWithHandler(nil, OptionsExecute);

    // Add under Tools menu via AddActionMenu :contentReference[oaicite:4]{index=4}
    lNta.AddActionMenu('ToolsMenu', fMenuHolder.actOptions, fMenuHolder.miOptions, True, True);
  end;
end;

procedure TMdcIdeIntegration.UninstallMenu;
begin
  if fMenuHolder <> nil then
  begin
    if (fMenuHolder.miOptions <> nil) and (fMenuHolder.miOptions.Parent <> nil) then
      fMenuHolder.miOptions.Parent.Remove(fMenuHolder.miOptions);

    FreeAndNil(fMenuHolder);
  end;
end;

procedure TMdcIdeIntegration.InstallGlobalActions;
var
  lNta: INTAServices;
  lProjects, lUnits: TShortCut;
begin
  if Supports(BorlandIDEServices, INTAServices, lNta) and (lNta.ActionList <> nil) then
  begin
    if fProjectsAction = nil then
    begin
      fProjectsAction := TAction.Create(nil);
      fProjectsAction.Caption := 'MaxLogic Projects Picker';
      fProjectsAction.OnExecute := ProjectsExecute;
      fProjectsAction.ActionList := lNta.ActionList;
    end;

    if fUnitsAction = nil then
    begin
      fUnitsAction := TAction.Create(nil);
      fUnitsAction.Caption := 'MaxLogic Units Picker';
      fUnitsAction.OnExecute := UnitsExecute;
      fUnitsAction.ActionList := lNta.ActionList;
    end;

    TMdcSettings.LoadShortCuts(lProjects, lUnits);
    UpdateGlobalShortCuts(lProjects, lUnits);
  end;
end;

procedure TMdcIdeIntegration.UninstallGlobalActions;
begin
  if fProjectsAction <> nil then
  begin
    fProjectsAction.ActionList := nil;
    FreeAndNil(fProjectsAction);
  end;

  if fUnitsAction <> nil then
  begin
    fUnitsAction.ActionList := nil;
    FreeAndNil(fUnitsAction);
  end;
end;

procedure TMdcIdeIntegration.UpdateGlobalShortCuts(aProjects: TShortCut; aUnits: TShortCut);
begin
  if fProjectsAction <> nil then
    fProjectsAction.ShortCut := aProjects;

  if fUnitsAction <> nil then
    fUnitsAction.ShortCut := aUnits;
end;

procedure TMdcIdeIntegration.OptionsExecute(Sender: TObject);
var
  lErr: string;
  lNewProjects, lNewUnits: TShortCut;
begin
  while True do
  begin
    if not TMdcOptionsForm.ExecuteModal(nil) then
      Exit;

    TMdcSettings.LoadShortCuts(lNewProjects, lNewUnits);
    if TryApplyShortCuts(lNewProjects, lNewUnits, lErr) then
    begin
      try
        TMdcFocusErrorInsight.Uninstall;
        TMdcFocusErrorInsight.Install;
      except
        // ignore
      end;
      Exit;
    end else begin
      MessageDlg('Shortcuts could not be registered:' + sLineBreak + lErr, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMdcIdeIntegration.ProjectsExecute(Sender: TObject);
begin
  TMaxLogicProjectPicker.TryPickAndOpen;
end;

procedure TMdcIdeIntegration.UnitsExecute(Sender: TObject);
begin
  TMaxLogicUnitPicker.TryPickAndOpen;
end;

end.
