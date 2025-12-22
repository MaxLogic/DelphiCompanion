unit MaxLogic.DelphiCompanion.Register;

interface

procedure Register;

implementation

uses
  ToolsAPI,
  MaxLogic.DelphiCompanion.Wizard,
  MaxLogic.DelphiCompanion.CompileSounds,
  MaxLogic.DelphiCompanion.FocusErrorInsight;

procedure Register;
begin
  RegisterPackageWizard(TMdcWizard.Create);
  TMdcCompileSounds.Install;
  TMdcFocusErrorInsight.Install;
end;

initialization

finalization
  try
    if BorlandIDEServices <> nil then
    begin
      TMdcCompileSounds.Uninstall;
      TMdcFocusErrorInsight.Uninstall;
    end;
  except
    // do nothing
  end;

end.
