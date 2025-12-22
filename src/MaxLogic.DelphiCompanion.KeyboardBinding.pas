unit MaxLogic.DelphiCompanion.KeyboardBinding;

interface

uses
  ToolsAPI,
  System.Classes;

type
  TMdcKeyboardBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
    fProjectsShortCut: TShortCut;
    fUnitsShortCut: TShortCut;

    procedure KeyProjects(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure KeyUnits(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
  protected
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  public
    constructor Create; overload;
    constructor CreateWithShortCuts(aProjects: TShortCut; aUnits: TShortCut); overload;
  end;

implementation

uses
  System.SysUtils,
  Vcl.Menus,
  MaxLogic.DelphiCompanion.Settings,
  MaxLogic.DelphiCompanion.Pickers;

constructor TMdcKeyboardBinding.Create;
begin
  inherited Create;
  TMdcSettings.LoadShortCuts(fProjectsShortCut, fUnitsShortCut);
end;

constructor TMdcKeyboardBinding.CreateWithShortCuts(aProjects: TShortCut; aUnits: TShortCut);
begin
  inherited Create;
  fProjectsShortCut := aProjects;
  fUnitsShortCut := aUnits;
end;

procedure TMdcKeyboardBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  // AddKeyBinding returns Boolean. :contentReference[oaicite:3]{index=3}
  if fProjectsShortCut <> 0 then
  begin
    if not BindingServices.AddKeyBinding([fProjectsShortCut], KeyProjects, nil) then
      raise Exception.CreateFmt('Could not register Projects shortcut: %s', [ShortCutToText(fProjectsShortCut)]);
  end;

  if fUnitsShortCut <> 0 then
  begin
    if not BindingServices.AddKeyBinding([fUnitsShortCut], KeyUnits, nil) then
      raise Exception.CreateFmt('Could not register Units shortcut: %s', [ShortCutToText(fUnitsShortCut)]);
  end;
end;

function TMdcKeyboardBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TMdcKeyboardBinding.GetDisplayName: string;
begin
  Result := 'MaxLogic Delphi Companion';
end;

function TMdcKeyboardBinding.GetName: string;
begin
  Result := 'MaxLogic.MDC.KeyBinding';
end;

procedure TMdcKeyboardBinding.KeyProjects(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  TMaxLogicProjectPicker.TryPickAndOpen;
  BindingResult := krHandled;
end;

procedure TMdcKeyboardBinding.KeyUnits(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
begin
  TMaxLogicUnitPicker.TryPickAndOpen;
  BindingResult := krHandled;
end;

end.

