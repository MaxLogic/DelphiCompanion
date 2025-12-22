unit MaxLogic.DelphiCompanion.OptionsForm;

interface

uses
  System.Classes,
  Vcl.Menus,   Vcl.Forms, Vcl.StdCtrls,  Vcl.ExtCtrls,  Vcl.ComCtrls,  Vcl.Controls,  Vcl.Dialogs;

type
  TMdcOptionsForm = class
  private
    class procedure CreateBtnRegisterDebugControlInspector(
      const aParent: TWinControl; const aLeft, aTop, aWidth,
      aHeight: Integer);
  public
    class function ExecuteModal(aOwner: TComponent): Boolean; static;
  end;

implementation

uses
  MaxLogic.Debug.ControlInspector,
  System.SysUtils,
  AutoFree,
  MaxLogic.DelphiCompanion.Settings,
  maxLogic.DelphiCompanion.Logger;

var
  GDebugControlInspectorInjected: Boolean = False;

type
  TMdcBrowseHandler = class
  private
    fEdit: TEdit;
    fDialog: TOpenDialog;
    fTitle: string;
  public
    constructor Create(aEdit: TEdit; aDialog: TOpenDialog; const aTitle: string);
    procedure BrowseClick(Sender: TObject);
  end;

  TMdcDefaultsClickHandler = class
  private
    fHotProjects, fHotUnits, fHotFocus: THotKey;
    fCbSounds, fCbLogging: TCheckBox;
    fEdOk, fEdFail: TEdit;
  public
    constructor Create(aHP, aHU, aHF: THotKey; aCB: TCheckBox; aEO, aEF: TEdit; aCBLogging: TCheckBox);
    procedure DefaultsClick(Sender: TObject);
  end;
  TControlInspectorClickHandler = class(TComponent)
  public
    procedure BtnRegisterDebugControlInspectorClick(Sender: TObject);
  end;

constructor TMdcBrowseHandler.Create(aEdit: TEdit; aDialog: TOpenDialog; const aTitle: string);
begin
  inherited Create;
  fEdit := aEdit;
  fDialog := aDialog;
  fTitle := aTitle;
end;

procedure TMdcBrowseHandler.BrowseClick(Sender: TObject);
begin
  if (fDialog <> nil) and (fEdit <> nil) then
  begin
    fDialog.Title := fTitle;
    fDialog.FileName := fEdit.Text;
    if fDialog.Execute then
      fEdit.Text := fDialog.FileName;
  end;
end;

constructor TMdcDefaultsClickHandler.Create(aHP, aHU, aHF: THotKey; aCB: TCheckBox; aEO, aEF: TEdit; aCBLogging: TCheckBox);
begin
  inherited Create;
  fHotProjects := aHP; fHotUnits := aHU; fHotFocus := aHF;
  fCbSounds := aCB; fEdOk := aEO; fEdFail := aEF; fCbLogging := aCBLogging;
end;

procedure TMdcDefaultsClickHandler.DefaultsClick(Sender: TObject);
begin
  if fHotProjects <> nil then fHotProjects.HotKey := TMdcSettings.DefaultProjects;
  if fHotUnits <> nil then fHotUnits.HotKey := TMdcSettings.DefaultUnits;
  if fHotFocus <> nil then fHotFocus.HotKey := TMdcSettings.DefaultFocusErrorInsight;
  if fCbSounds <> nil then fCbSounds.Checked := False;
  if fEdOk <> nil then fEdOk.Text := '';
  if fEdFail <> nil then fEdFail.Text := '';
  if fCbLogging <> nil then fCbLogging.Checked := TMdcSettings.DefaultLoggingEnabled;
end;

class function TMdcOptionsForm.ExecuteModal(aOwner: TComponent): Boolean;
var
  lForm: TForm;
  g: IGarbo;
  lHotProjects, lHotUnits, lHotFocus: THotKey;
  lLblProjects, lLblUnits, lLblFocus: TStaticText;
  lGrpSounds: TGroupBox;
  lCbEnableSounds: TCheckBox;
  lEdOk, lEdFail: TEdit;
  lLblOk, lLblFail: TStaticText;
  lBtnBrowseOk, lBtnBrowseFail: TButton;
  lDlg: TOpenDialog;
  lCbEnableLogging: TCheckBox;
  lButtons: TPanel;
  lOk, lCancel, lDefaults: TButton;
  lDefaultsHandler: TMdcDefaultsClickHandler;
  gDefaults: IGarbo;
  lBrowseOk, lBrowseFail: TMdcBrowseHandler;
  gBrowses: TGarbos;
  lUnitsSc, lProjectsSc: TShortCut;
  lFocusSC: TShortCut;
  lSndEnable, lLogEnabled: Boolean;
  lBtnRegControlInspector, lOkSnd, lFailSnd: string;

  function SV(aV: Integer): Integer; begin Result := lForm.ScaleValue(aV); end;

begin
  // 1. Load data first
  lFocusSC := 0;
  TMdcSettings.LoadFocusErrorInsightShortcut(lFocusSC);
  TMdcSettings.LoadCompileSounds(lSndEnable, lOkSnd, lFailSnd);
  TMdcSettings.LoadShortCuts(lProjectsSC, lUnitsSC);
  TMdcSettings.LoadLoggingEnabled(lLogEnabled);

  GC(lForm, TForm.Create(aOwner), g);
  lForm.Caption := 'MaxLogic Delphi Companion - Options';
  lForm.BorderStyle := bsDialog;
  lForm.Position := poScreenCenter;
  lForm.ClientWidth := SV(640);
  lForm.ClientHeight := SV(380);

  // --- SHORTCUTS ---
  lHotProjects := THotKey.Create(lForm);
  lHotProjects.Parent := lForm;
  lHotProjects.SetBounds(SV(260), SV(16), SV(300), SV(25));
  lHotProjects.HotKey := lProjectsSC;

  lLblProjects := TStaticText.Create(lForm);
  lLblProjects.Parent := lForm;
  lLblProjects.SetBounds(SV(16), SV(20), SV(240), SV(22));
  lLblProjects.Caption := '&Projects picker shortcut:';
  lLblProjects.FocusControl := lHotProjects;

  lHotUnits := THotKey.Create(lForm);
  lHotUnits.Parent := lForm;
  lHotUnits.SetBounds(SV(260), SV(56), SV(300), SV(25));
  lHotUnits.HotKey := lUnitsSC;

  lLblUnits := TStaticText.Create(lForm);
  lLblUnits.Parent := lForm;
  lLblUnits.SetBounds(SV(16), SV(60), SV(240), SV(22));
  lLblUnits.Caption := '&Units picker shortcut:';
  lLblUnits.FocusControl := lHotUnits;

  lHotFocus := THotKey.Create(lForm);
  lHotFocus.Parent := lForm;
  lHotFocus.SetBounds(SV(260), SV(96), SV(300), SV(25));
  lHotFocus.HotKey := lFocusSC;

  lLblFocus := TStaticText.Create(lForm);
  lLblFocus.Parent := lForm;
  lLblFocus.SetBounds(SV(16), SV(100), SV(240), SV(22));
  lLblFocus.Caption := '&Focus Error Insight shortcut:';
  lLblFocus.FocusControl := lHotFocus;

  // --- SOUNDS ---
  lGrpSounds := TGroupBox.Create(lForm);
  lGrpSounds.Parent := lForm;
  lGrpSounds.SetBounds(SV(16), SV(140), lForm.ClientWidth - SV(32), SV(150));
  lGrpSounds.Caption := 'Compile sounds';

  lCbEnableSounds := TCheckBox.Create(lForm);
  lCbEnableSounds.Parent := lGrpSounds;
  lCbEnableSounds.SetBounds(SV(12), SV(25), SV(400), SV(22));
  lCbEnableSounds.Caption := '&Enable sounds when compilation finishes';
  lCbEnableSounds.Checked := lSndEnable;

  lEdOk := TEdit.Create(lForm);
  lEdOk.Parent := lGrpSounds;
  lEdOk.SetBounds(SV(120), SV(65), lGrpSounds.Width - SV(180), SV(23));
  lEdOk.Text := lOkSnd;

  lLblOk := TStaticText.Create(lForm);
  lLblOk.Parent := lGrpSounds;
  lLblOk.SetBounds(SV(12), SV(69), SV(100), SV(22));
  lLblOk.Caption := '&Success WAV:';
  lLblOk.FocusControl := lEdOk;

  lBtnBrowseOk := TButton.Create(lForm);
  lBtnBrowseOk.Parent := lGrpSounds;
  lBtnBrowseOk.SetBounds(lEdOk.Left + lEdOk.Width + SV(8), SV(63), SV(32), SV(27));
  lBtnBrowseOk.Caption := '...';

  lEdFail := TEdit.Create(lForm);
  lEdFail.Parent := lGrpSounds;
  lEdFail.SetBounds(SV(120), SV(105), lGrpSounds.Width - SV(180), SV(23));
  lEdFail.Text := lFailSnd;

  lLblFail := TStaticText.Create(lForm);
  lLblFail.Parent := lGrpSounds;
  lLblFail.SetBounds(SV(12), SV(109), SV(100), SV(22));
  lLblFail.Caption := '&Failure WAV:';
  lLblFail.FocusControl := lEdFail;

  lBtnBrowseFail := TButton.Create(lForm);
  lBtnBrowseFail.Parent := lGrpSounds;
  lBtnBrowseFail.SetBounds(lEdFail.Left + lEdFail.Width + SV(8), SV(103), SV(32), SV(27));
  lBtnBrowseFail.Caption := '...';

  lDlg := TOpenDialog.Create(lForm);
  lDlg.Filter := 'WAV files (*.wav)|*.wav|All files (*.*)|*.*';

  GC(lBrowseOk, TMdcBrowseHandler.Create(lEdOk, lDlg, 'Select Success Sound'), gBrowses);
  GC(lBrowseFail, TMdcBrowseHandler.Create(lEdFail, lDlg, 'Select Failure Sound'), gBrowses);
  lBtnBrowseOk.OnClick := lBrowseOk.BrowseClick;
  lBtnBrowseFail.OnClick := lBrowseFail.BrowseClick;

  lCbEnableLogging := TCheckBox.Create(lForm);
  lCbEnableLogging.Parent := lForm;
  lCbEnableLogging.SetBounds(SV(16), lGrpSounds.Top + lGrpSounds.Height + SV(12), lForm.ClientWidth - SV(32), SV(22));
  lCbEnableLogging.Caption := 'Enable &logging to file';
  lCbEnableLogging.Checked := lLogEnabled;

  // --- BUTTONS ---
  lButtons := TPanel.Create(lForm);
  lButtons.Parent := lForm;
  lButtons.Align := alBottom;
  lButtons.Height := SV(50);
  lButtons.BevelOuter := bvNone;

  lDefaults := TButton.Create(lForm);
  lDefaults.Parent := lButtons;
  lDefaults.SetBounds(SV(16), SV(10), SV(140), SV(30));
  lDefaults.Caption := 'Restore defaults';
  GC(lDefaultsHandler, TMdcDefaultsClickHandler.Create(lHotProjects, lHotUnits, lHotFocus, lCbEnableSounds, lEdOk, lEdFail, lCbEnableLogging), gDefaults);
  lDefaults.OnClick := lDefaultsHandler.DefaultsClick;

  CreateBtnRegisterDebugControlInspector(
    lButtons,
    lDefaults.left + lDefaults.Width +sv(6),
    lDefaults.Top, lDefaults.Width, lDefaults.Height);

  lCancel := TButton.Create(lForm);
  lCancel.Parent := lButtons;
  lCancel.SetBounds(lForm.ClientWidth - SV(100), SV(10), SV(85), SV(30));
  lCancel.Caption := 'Cancel';
  lCancel.ModalResult := mrCancel;
  lCancel.Cancel := True;

  lOk := TButton.Create(lForm);
  lOk.Parent := lButtons;
  lOk.SetBounds(lCancel.Left - SV(95), SV(10), SV(85), SV(30));
  lOk.Caption := 'OK';
  lOk.ModalResult := mrOk;
  lOk.Default := True;

  Result := (lForm.ShowModal = mrOk);
  if Result then
  begin
    lProjectsSc := lHotProjects.HotKey;
    lUnitsSc := lHotUnits.HotKey;
    TMdcSettings.SaveShortCuts(lProjectsSc, lUnitsSc);
    TMdcSettings.SaveFocusErrorInsightShortcut(lHotFocus.HotKey);
    TMdcSettings.SaveCompileSounds(lCbEnableSounds.Checked, lEdOk.Text, lEdFail.Text);
    TMdcSettings.SaveLoggingEnabled(lCbEnableLogging.Checked);
    GMdcLoggingEnabled := lCbEnableLogging.Checked;
  end;
end;

class procedure TMdcOptionsForm.CreateBtnRegisterDebugControlInspector(
  const aParent: TWinControl;
  const aLeft, aTop, aWidth, aHeight: Integer);
var
  lBtn : TButton;
begin
  lBtn := TButton.Create(aParent);
  lBtn.Parent := aParent;
  lBtn.Left := aLeft;
  lBtn.Top := aTop;
  lBtn.Width := aWidth;
  lBtn.Height := aHeight;

  lBtn.Caption := 'Register Debug Control Inspector';
  lBtn.ShowHint := True;

  // Hint text matches the Usage section from MaxLogic.Debug.ControlInspector.pas
  lBtn.Hint :=
    'Registers the Debug Control Inspector into the IDE.' + sLineBreak +
    'Usage:' + sLineBreak +
    '- Press Ctrl+Shift+Q to get info about focused control.' + sLineBreak +
    '- Press Ctrl+Shift+W to get the component hierarchy and show it in a dialog.' + sLineBreak +
    '- Press Ctrl+Shift+E to copy a dump of all VCL controls to clipboard.' + sLineBreak +
    '- Press Ctrl+Shift+T to inspect a specific control / window handle.' + sLineBreak +
    '- The inspector also reacts when active form changes (it hooks Screen.OnActiveFormChange).';

  var lHandler:= TControlInspectorClickHandler .Create(lBtn);
  lBtn.OnClick := lHandler.BtnRegisterDebugControlInspectorClick;
end;

procedure TControlInspectorClickHandler .BtnRegisterDebugControlInspectorClick(Sender: TObject);
begin
  // Safe to call multiple times, but we keep a guard anyway.
  if GDebugControlInspectorInjected then
    Exit;

  if (Application <> nil) and (Application.MainForm <> nil) then
  begin
    TDebugControlInspector.Inject(Application.MainForm);
    GDebugControlInspectorInjected := True;
  end;
end;

end.
