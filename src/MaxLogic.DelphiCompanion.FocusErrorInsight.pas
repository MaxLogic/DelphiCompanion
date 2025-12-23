unit maxLogic.DelphiCompanion.FocusErrorInsight;

interface

uses
  System.Classes, System.Types,
  Winapi.CommCtrl, Winapi.Messages, Winapi.Windows,
  Vcl.ComCtrls, Vcl.Forms, Vcl.StdCtrls,
  ToolsAPI;

type
  TMdcFocusErrorInsight = class
  public
    class procedure Install;
    class procedure Uninstall;
  end;

implementation

uses
  System.IOUtils, System.Rtti, System.StrUtils, System.SysUtils, System.TypInfo,
  Vcl.ClipBrd, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics,
  AutoFree, maxLogic.DelphiCompanion.IdeApi, maxLogic.DelphiCompanion.IdeUiInspector,
  maxLogic.DelphiCompanion.Logger, maxLogic.DelphiCompanion.Providers,
  maxLogic.DelphiCompanion.Settings;

type
  PHWND = ^hwnd;

type
  TMdcProblemKind = (pkErrorInsightError, pkErrorInsightWarning, pkBuildError, pkBuildWarning);

  TMdcProblemItem = class
  public
    kind: TMdcProblemKind;
    Text: string;
    FileName: string;
    LineNo: Integer; // 1-based
    ColNo: Integer; // 1-based
  end;

  TMdcProblemsForm = class(TForm)
  private
    fTimer: TTimer;

    fLbErrorInsight: TListBox;
    fLbBuildErrors: TListBox;
    fLbBuildWarnings: TListBox;

    fLblEi: TStaticText;
    fLblErr: TStaticText;
    fLblWarn: TStaticText;

    fBtnRefresh: TButton;
    fBtnClose: TButton;

    fLastEiSignature: string;
    fEiRefreshing: Boolean;

    fHooked: Boolean;

    procedure TimerTick(Sender: TObject);
    procedure FormClose(aSender: TObject; var aAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure FormResize(aSender: TObject);
    procedure UpdateLayout;

    procedure LbDblClick(Sender: TObject);
    procedure LbKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure BtnRefreshClick(Sender: TObject);
    procedure BtnCloseClick(Sender: TObject);

    procedure ClearListBoxItems(aLb: TListBox);
    function SelectedItem(aLb: TListBox): TMdcProblemItem;

    procedure JumpToItem(aItem: TMdcProblemItem);
    procedure RefreshAll;
    procedure RefreshErrorInsight;
    procedure RefreshBuildMessages;

    function TryGetActiveFileName(out aFileName: string): Boolean;
    function TryCollectModuleErrors(const aFileName: string; out aErrors: TOTAErrors): Boolean;

    function BuildEiSignature(const aErrors: TOTAErrors): string;

    function TryResolveFileName(const aFileName: string; out aResolved: string): Boolean;

    function FindMessageViewForm: TForm;
    procedure EnsureMessageViewShown;

    function TryCopyBuildMessagesToClipboard(out aText: string): Boolean;
    function TryParseBuildLine(const aLine: string; out aItem: TMdcProblemItem): Boolean;

    procedure PopulateFromBuildText(const aText: string);

    function AppHook(var aMsg: TMessage): Boolean;


    class procedure ShowSingleton;
  public
    constructor Create(aOwner: TComponent); override;
    destructor Destroy; override;
  end;

  TMdcProblemsKeyBinding = class(TNotifierObject, IOTAKeyboardBinding)
  private
    fShortcut: TShortCut;
    procedure KeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
  public
    constructor Create(aShortcut: TShortCut);
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
  end;

const
  CWinKeyProblems = 'Problems.Dialog';

var
  GBindingIndex: Integer = -1;
  GBindingIntf: IOTAKeyboardBinding = nil;
  GProblemsForm: TMdcProblemsForm = nil;

procedure SendKeyCombo(const aVkMod, aVkKey: Word);
var
  lInputs: array[0..3] of TInput;
begin
  ZeroMemory(@lInputs, SizeOf(lInputs));

  lInputs[0].Itype := INPUT_KEYBOARD;
  lInputs[0].ki.wVk := aVkMod;

  lInputs[1].Itype := INPUT_KEYBOARD;
  lInputs[1].ki.wVk := aVkKey;

  lInputs[2].Itype := INPUT_KEYBOARD;
  lInputs[2].ki.wVk := aVkKey;
  lInputs[2].ki.dwFlags := KEYEVENTF_KEYUP;

  lInputs[3].Itype := INPUT_KEYBOARD;
  lInputs[3].ki.wVk := aVkMod;
  lInputs[3].ki.dwFlags := KEYEVENTF_KEYUP;

  SendInput(length(lInputs), lInputs[0], SizeOf(TInput));
end;

function SafeInt(const s: string; const aDefault: Integer = 0): Integer;
begin
  if not TryStrToInt(Trim(s), Result) then
    Result := aDefault;
end;

{ TMdcProblemsForm }

constructor TMdcProblemsForm.Create(aOwner: TComponent);
begin
  inherited CreateNew(aOwner);

  OnDestroy := FormDestroy;
  OnClose := FormClose;
  OnResize := FormResize;
  caption := 'MaxLogic Delphi Companion - Problems';
  BorderStyle := bsSizeable;

  Font.Name := 'Segoe UI';
  Font.Size := 10;

  TMdcSettings.LoadWindowBounds(CWinKeyProblems, Self, ScaleValue(1100), ScaleValue(520));

  // --- LISTS ---
  fLbErrorInsight := TListBox.Create(self);
  fLbErrorInsight.Parent := self;
  fLbErrorInsight.Anchors := [akLeft, akTop, akBottom];
  fLbErrorInsight.IntegralHeight := False;
  fLbErrorInsight.OnDblClick := LbDblClick;
  fLbErrorInsight.OnKeyDown := LbKeyDown;
  fLbErrorInsight.TabStop := True;

  fLblEi := TStaticText.Create(self);
  fLblEi.Parent := self;
  fLblEi.caption := '&Error Insight  (F1)';
  fLblEi.ShowHint := True;
  fLblEi.hint := 'Hotkey: F1 focuses this list';
  fLblEi.FocusControl := fLbErrorInsight;

  fLbBuildErrors := TListBox.Create(self);
  fLbBuildErrors.Parent := self;
  fLbBuildErrors.Anchors := [akLeft, akTop, akBottom];
  fLbBuildErrors.IntegralHeight := False;
  fLbBuildErrors.OnDblClick := LbDblClick;
  fLbBuildErrors.OnKeyDown := LbKeyDown;
  fLbBuildErrors.TabStop := True;

  fLblErr := TStaticText.Create(self);
  fLblErr.Parent := self;
  fLblErr.caption := 'Build E&rrors  (F2)';
  fLblErr.ShowHint := True;
  fLblErr.hint := 'Hotkey: F2 focuses this list';
  fLblErr.FocusControl := fLbBuildErrors;

  fLbBuildWarnings := TListBox.Create(self);
  fLbBuildWarnings.Parent := self;
  fLbBuildWarnings.Anchors := [akLeft, akTop, akBottom, akRight];
  fLbBuildWarnings.IntegralHeight := False;
  fLbBuildWarnings.OnDblClick := LbDblClick;
  fLbBuildWarnings.OnKeyDown := LbKeyDown;
  fLbBuildWarnings.TabStop := True;

  fLblWarn := TStaticText.Create(self);
  fLblWarn.Parent := self;
  fLblWarn.caption := 'Build &Warnings  (F3)';
  fLblWarn.ShowHint := True;
  fLblWarn.hint := 'Hotkey: F3 focuses this list';
  fLblWarn.FocusControl := fLbBuildWarnings;

  // --- BUTTONS ---
  fBtnRefresh := TButton.Create(self);
  fBtnRefresh.Parent := self;
  fBtnRefresh.caption := 'Refresh (F5)';
  fBtnRefresh.Anchors := [akLeft, akBottom];
  fBtnRefresh.OnClick := BtnRefreshClick;
  fBtnRefresh.OnKeyDown := LbKeyDown;

  fBtnClose := TButton.Create(self);
  fBtnClose.Parent := self;
  fBtnClose.caption := 'Close (Esc)';
  fBtnClose.Anchors := [akLeft, akBottom];
  fBtnClose.OnClick := BtnCloseClick;
  fBtnClose.OnKeyDown := LbKeyDown;

  // Timer: refresh Error Insight periodically
  fTimer := TTimer.Create(self);
  fTimer.Interval := 750;
  fTimer.Enabled := True;
  fTimer.OnTimer := TimerTick;

  KeyPreview := True;
  OnKeyDown := LbKeyDown;

  UpdateLayout;
  ActiveControl := fLbErrorInsight;

  // Suppress IDE stealing our function keys (F3 search, etc.)
  try
    application.HookMainWindow(AppHook); // NOTE: HookMainWindow is a PROCEDURE in Delphi VCL docs
    fHooked := True;
    MdcLog('Create: HookMainWindow=OK');
  except
    fHooked := False;
    MdcLog('Create: HookMainWindow=FAILED');
  end;

  RefreshAll;
end;

destructor TMdcProblemsForm.Destroy;
begin
  try
    if fTimer <> nil then
      fTimer.Enabled := False;
  except
  end;

  if fHooked then
  begin
    try
      application.UnhookMainWindow(AppHook);
      MdcLog('Destroy: UnhookMainWindow=OK');
    except
      on e: Exception do
        if GMdcLoggingEnabled then
          MdcLog('Destroy: UnhookMainWindow=FAILED ' + e.ClassName + ': ' + e.Message);
    end;
    fHooked := False;
  end;

  ClearListBoxItems(fLbErrorInsight);
  ClearListBoxItems(fLbBuildErrors);
  ClearListBoxItems(fLbBuildWarnings);

  inherited Destroy;
end;

class procedure TMdcProblemsForm.ShowSingleton;
begin
  if GProblemsForm = nil then
  begin
    MdcLog('ShowSingleton: creating form');
    GProblemsForm := TMdcProblemsForm.Create(application);
    GProblemsForm.SHOW;
  end;

  if GProblemsForm.WindowState = wsMinimized then
    GProblemsForm.WindowState := wsNormal;

  GProblemsForm.SHOW;
  GProblemsForm.bringToFront;

  if GProblemsForm.HandleAllocated then
  begin
    winApi.Windows.ShowWindow(GProblemsForm.Handle, SW_RESTORE);
    winApi.Windows.SetWindowPos(
      GProblemsForm.Handle,
      HWND_TOP,
      0, 0, 0, 0,
      SWP_NOMOVE or SWP_NOSIZE);

    winApi.Windows.SetForegroundWindow(GProblemsForm.Handle);
    winApi.Windows.SetActiveWindow(GProblemsForm.Handle);
  end;

  GProblemsForm.SetFocus;
  MdcLog('ShowSingleton: done');
end;

procedure TMdcProblemsForm.FormDestroy(Sender: TObject);
begin
  MdcLog('FormDestroy');
  TMdcSettings.SaveWindowBounds(CWinKeyProblems, Self);
  try
    if fTimer <> nil then
      fTimer.Enabled := False;
  except
  end;

  GProblemsForm := nil;
end;

procedure TMdcProblemsForm.FormClose(aSender: TObject; var aAction: TCloseAction);
begin
  TMdcSettings.SaveWindowBounds(CWinKeyProblems, Self);
end;

procedure TMdcProblemsForm.FormResize(aSender: TObject);
begin
  UpdateLayout;
end;

procedure TMdcProblemsForm.UpdateLayout;
var
  lMargin, lGap, lLabelTop, lLabelHeight: Integer;
  lListTop, lListWidth, lListHeight: Integer;
  lButtonsTop, lButtonHeight, lButtonWidth: Integer;

  function SV(v: Integer): Integer;
  begin
    Result := ScaleValue(v);
  end;

begin
  if (fLbErrorInsight = nil) or (fLbBuildErrors = nil) or (fLbBuildWarnings = nil) or
     (fLblEi = nil) or (fLblErr = nil) or (fLblWarn = nil) or
     (fBtnRefresh = nil) or (fBtnClose = nil) then
    Exit;

  lMargin := SV(10);
  lGap := SV(10);
  lLabelTop := SV(10);
  lLabelHeight := SV(18);
  lListTop := SV(35);
  lButtonHeight := SV(30);
  lButtonWidth := SV(140);
  lButtonsTop := ClientHeight - SV(45);

  lListHeight := lButtonsTop - lListTop - lGap;
  if lListHeight < SV(1) then
    lListHeight := SV(1);

  lListWidth := (ClientWidth - (lMargin * 2) - (lGap * 2)) div 3;
  if lListWidth < SV(1) then
    lListWidth := SV(1);

  fLbErrorInsight.SetBounds(lMargin, lListTop, lListWidth, lListHeight);
  fLbBuildErrors.SetBounds(fLbErrorInsight.Left + lListWidth + lGap, lListTop, lListWidth, lListHeight);
  fLbBuildWarnings.SetBounds(fLbBuildErrors.Left + lListWidth + lGap, lListTop, lListWidth, lListHeight);

  fLblEi.SetBounds(fLbErrorInsight.Left, lLabelTop, lListWidth, lLabelHeight);
  fLblErr.SetBounds(fLbBuildErrors.Left, lLabelTop, lListWidth, lLabelHeight);
  fLblWarn.SetBounds(fLbBuildWarnings.Left, lLabelTop, lListWidth, lLabelHeight);

  fBtnRefresh.SetBounds(lMargin, lButtonsTop, lButtonWidth, lButtonHeight);
  fBtnClose.SetBounds(fBtnRefresh.Left + fBtnRefresh.Width + lGap, lButtonsTop, lButtonWidth, lButtonHeight);
end;

procedure TMdcProblemsForm.TimerTick(Sender: TObject);
begin
  RefreshErrorInsight;
end;

procedure TMdcProblemsForm.BtnRefreshClick(Sender: TObject);
begin
  RefreshAll;
end;


function TMdcProblemsForm.AppHook(var aMsg: TMessage): Boolean;
begin
  Result := False;

  // Only care while OUR dialog is the active form
  if Screen.ActiveForm <> self then
    exit;

  if (aMsg.msg = WM_KEYDOWN) or (aMsg.msg = WM_SYSKEYDOWN)
    or (aMsg.msg = WM_KEYUP) or (aMsg.msg = WM_SYSKEYUP) then
  begin
    case aMsg.WParam of
      VK_F1:
        begin
          ActiveControl := fLbErrorInsight;
          Result := True;
          exit;
        end;

      VK_F2:
        begin
          ActiveControl := fLbBuildErrors;
          Result := True;
          exit;
        end;

      VK_F3:
        begin
          ActiveControl := fLbBuildWarnings;
          Result := True;
          exit;
        end;

      VK_F5:
        begin
          if (aMsg.msg = WM_KEYDOWN) or (aMsg.msg = WM_SYSKEYDOWN) then
            RefreshAll;
          Result := True;
          exit;
        end;

      VK_ESCAPE:
        begin
          if (aMsg.msg = WM_KEYUP) or (aMsg.msg = WM_SYSKEYUP) then
            Close;
          Result := True;
          exit;
        end;
    end;
  end;
end;


procedure TMdcProblemsForm.BtnCloseClick(Sender: TObject);
begin
  Close;
end;

procedure TMdcProblemsForm.LbDblClick(Sender: TObject);
var
  lItem: TMdcProblemItem;
begin
  if Sender is TListBox then
  begin
    lItem := SelectedItem(TListBox(Sender));
    if lItem <> nil then
      JumpToItem(lItem);
  end;
end;

procedure TMdcProblemsForm.LbKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  lItem: TMdcProblemItem;
begin
  // Keep this as a fallback (AppHook usually handles these)
  if Key = VK_F1 then
  begin
    ActiveControl := fLbErrorInsight;
    Key := 0;
    exit;
  end;

  if Key = VK_F2 then
  begin
    ActiveControl := fLbBuildErrors;
    Key := 0;
    exit;
  end;

  if Key = VK_F3 then
  begin
    ActiveControl := fLbBuildWarnings;
    Key := 0;
    exit;
  end;

  if Key = VK_ESCAPE then
  begin
    Close;
    Key := 0;
    exit;
  end;

  if Key = VK_F5 then
  begin
    RefreshAll;
    Key := 0;
    exit;
  end;

  if (Key = VK_RETURN) and (Sender is TListBox) then
  begin
    lItem := SelectedItem(TListBox(Sender));
    if lItem <> nil then
      JumpToItem(lItem);

    Key := 0;
    exit;
  end;
end;

procedure TMdcProblemsForm.ClearListBoxItems(aLb: TListBox);
var
  i: Integer;
begin
  if aLb = nil then
    exit;

  for i := 0 to aLb.Items.Count - 1 do
    aLb.Items.Objects[i].Free;

  aLb.Items.Clear;
end;

function TMdcProblemsForm.SelectedItem(aLb: TListBox): TMdcProblemItem;
var
  lObj: TObject;
begin
  Result := nil;

  if (aLb = nil) or (aLb.ItemIndex < 0) then
    exit;

  lObj := aLb.Items.Objects[aLb.ItemIndex];
  if lObj = nil then
    exit;

  Result := TMdcProblemItem(lObj);
end;

procedure TMdcProblemsForm.RefreshAll;
begin
  MdcLog('RefreshAll: begin');
  RefreshErrorInsight;
  RefreshBuildMessages;
  MdcLog('RefreshAll: end');
end;

function TMdcProblemsForm.TryGetActiveFileName(out aFileName: string): Boolean;
var
  lEditor: IOTAEditorServices;
  lView: IOTAEditView;
  lBuf: IOTAEditBuffer;
begin
  aFileName := '';
  Result := False;

  if not Supports(BorlandIDEServices, IOTAEditorServices, lEditor) then
    exit;

  lView := lEditor.TopView;
  if lView = nil then
    exit;

  lBuf := lView.Buffer;
  if lBuf = nil then
    exit;

  aFileName := lBuf.FileName;
  Result := aFileName <> '';
end;

function TMdcProblemsForm.TryCollectModuleErrors(const aFileName: string; out aErrors: TOTAErrors): Boolean;
var
  lMods: IOTAModuleServices;
  lMod: IOTAModule;
  lModErr: IOTAModuleErrors;
begin
  aErrors := [];
  Result := False;

  if not Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
    exit;

  lMod := lMods.OpenModule(aFileName);
  if lMod = nil then
    exit;

  if not Supports(lMod, IOTAModuleErrors, lModErr) then
    exit;

  try
    aErrors := lModErr.GetErrors(aFileName);
    Result := True;
  except
    Result := False;
  end;
end;

function TMdcProblemsForm.TryResolveFileName(const aFileName: string; out aResolved: string): Boolean;
var
  lMods: IOTAModuleServices;
  lProj: IOTAProject;
  lGroup: IOTAProjectGroup;
  lNeedle: string;
  lNeedleFile: string;
  lNeedleNoExt: string;
  lNeedlePas: string;
  lNeedleHasExt: Boolean;
  i: Integer;

  function NameMatches(const aFile: string): Boolean;
  var
    lFile: string;
    lNoExt: string;
  begin
    lFile := ExtractFileName(aFile);
    if SameText(lFile, lNeedleFile) then
      Exit(True);

    if (lNeedlePas <> '') and SameText(lFile, lNeedlePas) then
      Exit(True);

    lNoExt := ChangeFileExt(lFile, '');
    if lNeedleHasExt then
      Exit(False);

    Result := SameText(lNoExt, lNeedleNoExt);
  end;

  function TryResolveRelative(const aPath, aBaseDir: string; out aFound: string): Boolean;
  var
    lFull: string;
  begin
    aFound := '';
    lFull := aPath;
    if lFull.Trim = '' then
      Exit(False);

    if (not TPath.IsPathRooted(lFull)) and (aBaseDir <> '') then
      lFull := TPath.Combine(aBaseDir, lFull);

    if FileExists(lFull) then
    begin
      aFound := ExpandFileName(lFull);
      Exit(True);
    end;

    Result := False;
  end;

  function TryOpenUnits(out aFound: string): Boolean;
  var
    lItems: TArray<TMaxLogicPickItem>;
    lItem: TMaxLogicPickItem;
  begin
    Result := False;
    aFound := '';

    lItems := TMaxLogicOpenUnitsProvider.GetItems;
    for lItem in lItems do
    begin
      if NameMatches(lItem.FileName) and TryResolveRelative(lItem.FileName, '', aFound) then
        Exit(True);
    end;
  end;

  function ExpandEnvVars(const aText: string): string;
  var
    lNeeded: DWORD;
  begin
    lNeeded := Winapi.Windows.ExpandEnvironmentStrings(PChar(aText), nil, 0);
    if lNeeded = 0 then
      Exit(aText);

    SetLength(Result, lNeeded - 1);
    if Winapi.Windows.ExpandEnvironmentStrings(PChar(aText), PChar(Result), lNeeded) = 0 then
      Result := aText;
  end;

  function EnvOrEmpty(const aName: string): string;
  begin
    Result := GetEnvironmentVariable(aName);
  end;

  function ExpandDollarMacros(const aText: string): string;
  var
    lOut: string;
    p1, p2: Integer;
    lVar, lVal: string;
  begin
    lOut := aText;

    while True do
    begin
      p1 := Pos('$(', lOut);
      if p1 = 0 then
        Break;

      p2 := PosEx(')', lOut, p1 + 2);
      if p2 = 0 then
        Break;

      lVar := Copy(lOut, p1 + 2, p2 - (p1 + 2));
      lVal := EnvOrEmpty(lVar);

      if lVal = '' then
        lVal := '$(' + lVar + ')';

      lOut := Copy(lOut, 1, p1 - 1) + lVal + Copy(lOut, p2 + 1, MaxInt);
    end;

    Result := lOut;
  end;

  function TryModulesInProject(const aProj: IOTAProject; out aFound: string): Boolean;
  var
    j, lCount: Integer;
    lInfo: IOTAModuleInfo;
    lFn: string;
    lBaseDir: string;
  begin
    Result := False;
    aFound := '';

    if aProj = nil then
      Exit;

    lBaseDir := '';
    if aProj.FileName.Trim <> '' then
      lBaseDir := ExtractFileDir(aProj.FileName);

    lCount := aProj.GetModuleCount;
    for j := 0 to lCount - 1 do
    begin
      lInfo := aProj.GetModule(j);
      if lInfo = nil then
        Continue;

      lFn := lInfo.FileName;
      if lFn.Trim = '' then
        Continue;

      if NameMatches(ExtractFileName(lFn)) then
      begin
        if TryResolveRelative(lFn, lBaseDir, aFound) then
          Exit(True);
      end;
    end;
  end;

  function TryFindInSearchPath(const aProj: IOTAProject; out aFound: string): Boolean;
  var
    lOpts: IOTAProjectOptions;
    lPaths: string;
    lParts: TArray<string>;
    lPart: string;
    lDir: string;
    lCandidate: string;
  begin
    Result := False;
    aFound := '';

    if aProj = nil then
      Exit;

    lOpts := aProj.ProjectOptions;
    if lOpts = nil then
      Exit;

    lPaths := lOpts.Values['DCC_UnitSearchPath'];
    if lPaths.Trim = '' then
      Exit;

    lParts := lPaths.Split([';']);
    for lPart in lParts do
    begin
      lDir := lPart.Trim;
      if lDir = '' then
        Continue;

      lDir := ExpandEnvVars(ExpandDollarMacros(lDir));

      if not DirectoryExists(lDir) then
        Continue;

      lCandidate := TPath.Combine(lDir, lNeedleFile);
      if FileExists(lCandidate) then
      begin
        aFound := ExpandFileName(lCandidate);
        Exit(True);
      end;

      if lNeedlePas <> '' then
      begin
        lCandidate := TPath.Combine(lDir, lNeedlePas);
        if FileExists(lCandidate) then
        begin
          aFound := ExpandFileName(lCandidate);
          Exit(True);
        end;
      end;
    end;
  end;

begin
  aResolved := '';
  lNeedle := aFileName.Trim;
  if lNeedle = '' then
  begin
    mdcLog('TryResolveFileName: file to resolve was empty -> exit');
    Exit(False);
  end;

  if GMdcLoggingEnabled then
    MdcLog('TryResolveFileName: lookup "' + lNeedle + '"');

  if FileExists(lNeedle) then
  begin
    aResolved := ExpandFileName(lNeedle);
    MdcLog('TryResolveFileName: direct file exists');
    Exit(True);
  end;

  lNeedleFile := ExtractFileName(lNeedle);
  lNeedleNoExt := ChangeFileExt(lNeedleFile, '');
  lNeedleHasExt := ExtractFileExt(lNeedleFile) <> '';
  if lNeedleHasExt then
    lNeedlePas := ''
  else
    lNeedlePas := lNeedleNoExt + '.pas';

  if not Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
  begin
    MdcLog('TryResolveFileName: IOTAModuleServices not supported');
    Exit(False);
  end;

  lProj := lMods.GetActiveProject;
  lGroup := lMods.MainProjectGroup;

  if TryOpenUnits(aResolved) then
  begin
    MdcLog('TryResolveFileName: resolved via open units');
    Exit(True);
  end;

  if TryModulesInProject(lProj, aResolved) then
  begin
    MdcLog('TryResolveFileName: resolved via active project modules');
    Exit(True);
  end;

  if lGroup <> nil then
  begin
    for i := 0 to lGroup.ProjectCount - 1 do
      if TryModulesInProject(lGroup.Projects[i], aResolved) then
      begin
        MdcLog('TryResolveFileName: resolved via project group modules');
        Exit(True);
      end;
  end;

  if TryFindInSearchPath(lProj, aResolved) then
  begin
    MdcLog('TryResolveFileName: resolved via project search path');
    Exit(True);
  end;

  Result := False;
end;

function TMdcProblemsForm.BuildEiSignature(const aErrors: TOTAErrors): string;
var
  lBuilder: TStringBuilder;
  g: IGarbo;
  lErr: TOTAError;
begin
  gc(lBuilder, TStringBuilder.Create(4096), g);

  for lErr in aErrors do
  begin
    lBuilder.Append(lErr.Severity);
    lBuilder.Append('|');
    lBuilder.Append(lErr.Text);
    lBuilder.Append('|');
    lBuilder.Append(lErr.start.Line);
    lBuilder.Append(':');
    lBuilder.Append(lErr.start.CharIndex);
    lBuilder.AppendLine;
  end;

  Result := lBuilder.ToString;
end;

procedure TMdcProblemsForm.RefreshErrorInsight;
var
  lFile: string;
  lErrors: TOTAErrors;
  lSig: string;
  lErr: TOTAError;
  lItem: TMdcProblemItem;
  lText: string;
  lCnt: Integer;
begin
  if fEiRefreshing then
    exit;

  fEiRefreshing := True;
  try
    if not TryGetActiveFileName(lFile) then
    begin
      MdcLog('RefreshErrorInsight: no active file');
      exit;
    end;

    if not TryCollectModuleErrors(lFile, lErrors) then
    begin
      if GMdcLoggingEnabled then
        MdcLog('RefreshErrorInsight: TryCollectModuleErrors failed for ' + lFile);
      exit;
    end;

    lSig := BuildEiSignature(lErrors);
    if SameText(lSig, fLastEiSignature) then
      exit;

    fLastEiSignature := lSig;

    ClearListBoxItems(fLbErrorInsight);

    lCnt := 0;
    for lErr in lErrors do
    begin
      case lErr.Severity of
        1: lText := 'Error: ' + lErr.Text;
        2: lText := 'Warning: ' + lErr.Text;
      else
        Continue;
      end;

      lItem := TMdcProblemItem.Create;
      lItem.kind := pkErrorInsightError;
      if lErr.Severity = 2 then
        lItem.kind := pkErrorInsightWarning;

      lItem.Text := lText;
      lItem.FileName := lFile;
      lItem.LineNo := lErr.start.Line;
      lItem.ColNo := lErr.start.CharIndex + 1;

      fLbErrorInsight.Items.addObject(lItem.Text, lItem);
      Inc(lCnt);
    end;

    if fLbErrorInsight.Items.Count = 0 then
      fLbErrorInsight.Items.Add('(No Error Insight errors/warnings)');

    if GMdcLoggingEnabled then
      MdcLog(Format('RefreshErrorInsight: %d items for %s', [lCnt, lFile]));
  finally
    fEiRefreshing := False;
  end;
end;

procedure TMdcProblemsForm.EnsureMessageViewShown;
var
  lTA: INTAServices;

  function FindActionByName(const aName: string): TBasicAction;
  var
    i: Integer;
    lAct: TBasicAction;
  begin
    Result := nil;

    if (lTA = nil) or (lTA.ActionList = nil) then
      exit;

    for i := 0 to lTA.ActionList.ActionCount - 1 do
    begin
      lAct := lTA.ActionList.Actions[i];
      if SameText(lAct.Name, aName) then
        exit(lAct);
    end;
  end;

var
  lAct: TBasicAction;
begin
  if not Supports(BorlandIDEServices, INTAServices, lTA) then
  begin
    MdcLog('EnsureMessageViewShown: INTAServices not supported');
    exit;
  end;

  lAct := FindActionByName('ViewMessagesCommand');
  if lAct <> nil then
  begin
    MdcLog('EnsureMessageViewShown: executing ViewMessagesCommand');
    lAct.Execute;
    exit;
  end;

  lAct := FindActionByName('ViewMessageViewCommand');
  if lAct <> nil then
  begin
    MdcLog('EnsureMessageViewShown: executing ViewMessageViewCommand');
    lAct.Execute;
    exit;
  end;

  lAct := FindActionByName('ViewMessageView');
  if lAct <> nil then
  begin
    MdcLog('EnsureMessageViewShown: executing ViewMessageView');
    lAct.Execute;
  end else begin
    MdcLog('EnsureMessageViewShown: message view action not found');
  end;
end;

function TMdcProblemsForm.FindMessageViewForm: TForm;
var
  i: Integer;
  lForm: TForm;
begin
  Result := nil;

  for i := 0 to Screen.FormCount - 1 do
  begin
    lForm := Screen.Forms[i];
    if lForm = nil then
      Continue;

    if ContainsText(lForm.ClassName, 'Message') and ContainsText(lForm.ClassName, 'View') then
      exit(lForm);

    if SameText(lForm.Caption, 'Messages') then
      exit(lForm);
  end;
end;

function TMdcProblemsForm.TryCopyBuildMessagesToClipboard(out aText: string): Boolean;
var
  lOldFocus: hwnd;
  lForm: TForm;
  lPageControl: TPageControl;
  lHostHandle: hwnd;
  lControl: TWinControl;

  function GetWinClassName(aHwnd: hwnd): string;
  var
    lBuf: array[0..255] of char;
  begin
    Result := '';
    if aHwnd = 0 then
      Exit;
    if GetClassName(aHwnd, lBuf, Length(lBuf)) > 0 then
      Result := lBuf;
  end;

  function IsVisibleAndEnabled(aHwnd: hwnd): Boolean;
  begin
    Result := (aHwnd <> 0) and IsWindowVisible(aHwnd) and IsWindowEnabled(aHwnd);
  end;

  function FindFirstListViewHandle(aRoot: hwnd): hwnd;
  var
    lFound: hwnd;

    function EnumProc(aWnd: hwnd; aParam: LPARAM): BOOL; stdcall;
    var
      lCls: string;
      lCnt: LRESULT;
    begin
      Result := True;

      if not IsVisibleAndEnabled(aWnd) then
        exit;

      lCls := GetWinClassName(aWnd);
      if SameText(lCls, 'SysListView32') then
      begin
        // Prefer a listview that actually has items
        lCnt := SendMessage(aWnd, LVM_GETITEMCOUNT, 0, 0);
        if lCnt > 0 then
        begin
          PHWND(aParam)^ := aWnd;
          Result := False; // stop enumeration
          exit;
        end;

        // keep as fallback if nothing else is found
        if PHWND(aParam)^ = 0 then
          PHWND(aParam)^ := aWnd;
      end;
    end;

  begin
    lFound := 0;
    if aRoot <> 0 then
      EnumChildWindows(aRoot, @EnumProc, LPARAM(@lFound));
    Result := lFound;
  end;

  function ReadListViewAllText(aList: hwnd): string;
  var
    lBuilder: TStringBuilder;
    lHeader: hwnd;
    lColCount: Integer;
    lItemCount: Integer;
    lItem: Integer;
    lCol: Integer;
    lBuf: array[0..2047] of char;
    lListViewItem: TLVItem;
    lText: string;
    lLineStarted: Boolean;
    lGarbo: IGarbo;
  begin
    Result := '';
    if aList = 0 then
      exit;

    lHeader := hwnd(SendMessage(aList, LVM_GETHEADER, 0, 0));
    if lHeader <> 0 then
      lColCount := SendMessage(lHeader, HDM_GETITEMCOUNT, 0, 0)
    else
      lColCount := 1;

    if lColCount <= 0 then
      lColCount := 1;

    lItemCount := SendMessage(aList, LVM_GETITEMCOUNT, 0, 0);
    if lItemCount <= 0 then
      exit;

    gc(lBuilder, TStringBuilder.Create(lItemCount * 128), lGarbo);

    ZeroMemory(@lListViewItem, SizeOf(lListViewItem));
    lListViewItem.Mask := LVIF_TEXT;
    lListViewItem.pszText := @lBuf[0];
    lListViewItem.cchTextMax := Length(lBuf);

    for lItem := 0 to lItemCount - 1 do
    begin
      lLineStarted := False;

      for lCol := 0 to lColCount - 1 do
      begin
        ZeroMemory(@lBuf[0], SizeOf(lBuf));
        lListViewItem.iItem := lItem;
        lListViewItem.iSubItem := lCol;

        SendMessage(aList, LVM_GETITEMTEXT, WParam(lItem), LPARAM(@lListViewItem));
        lText := Trim(string(lBuf));

        if lText = '' then
          Continue;

        if lLineStarted then
          lBuilder.Append(#9); // keep columns separable (tab)
        lBuilder.Append(lText);
        lLineStarted := True;
      end;

      if lLineStarted then
        lBuilder.AppendLine;
    end;

    Result := lBuilder.ToString;
  end;

  function FindPageControl(aParent: TWinControl): TPageControl;
  var
    i: Integer;
    lChild: TControl;
    lWin: TWinControl;
  begin
    Result := nil;
    if aParent = nil then
      exit;

    for i := 0 to aParent.ControlCount - 1 do
    begin
      lChild := aParent.Controls[i];

      if lChild is TPageControl then
        exit(TPageControl(lChild));

      if lChild is TWinControl then
      begin
        lWin := TWinControl(lChild);
        Result := FindPageControl(lWin);
        if Result <> nil then
          exit;
      end;
    end;
  end;

  procedure ActivateBuildTab(aPageControl: TPageControl);
  var
    i: Integer;
  begin
    if aPageControl = nil then
      exit;

    for i := 0 to aPageControl.PageCount - 1 do
    begin
      if ContainsText(aPageControl.Pages[i].Caption, 'Build') then
      begin
        aPageControl.ActivePage := aPageControl.Pages[i];
        exit;
      end;
    end;
  end;

  function GetBestHostHandle(aForm: TForm): hwnd;
  begin
    Result := 0;
    if aForm = nil then
      exit;

    lPageControl := FindPageControl(aForm);
    if lPageControl <> nil then
    begin
      ActivateBuildTab(lPageControl);
      if (lPageControl.ActivePage <> nil) and lPageControl.ActivePage.HandleAllocated then
        exit(lPageControl.ActivePage.Handle);
    end;

    if aForm.HandleAllocated then
      Result := aForm.Handle;
  end;

var
  lList: hwnd;
begin
  aText := '';
  Result := False;

  lOldFocus := GetFocus;
  try
    lForm := FindMessageViewForm;
    if lForm = nil then
    begin
      MdcLog('TryReadBuildMessages: message view not found, showing it');
      EnsureMessageViewShown;
      lForm := FindMessageViewForm;
    end;

    if lForm = nil then
    begin
      MdcLog('TryReadBuildMessages: still no message view form');
      exit;
    end;

    if GMdcLoggingEnabled then
    begin
      MdcLog('Messages form found: ' + lForm.ClassName + ' caption="' + lForm.Caption + '"');
      DumpControlTree(lForm);

      // Try to find the actual message list/tree/grid control (best-guess by class name)
      lControl := FindFirstByClassHint(lForm, [
          'VirtualStringTree', 'VirtualTree', 'ListView', 'TreeView', 'StringGrid', 'Memo', 'SynEdit'
          ]);

      if lControl <> nil then
        MdcLog('Candidate messages control: ' + lControl.ClassName + ' name="' + lControl.Name + '"')
      else
        MdcLog('No candidate messages control found (will likely copy wrong thing).');
      // --------
    end;

    // Make sure the Messages window is alive/visible
    lForm.SHOW;
    lForm.bringToFront;

    lHostHandle := GetBestHostHandle(lForm);
    if lHostHandle = 0 then
    begin
      MdcLog('TryReadBuildMessages: no host handle');
      exit;
    end;

    lList := FindFirstListViewHandle(lHostHandle);
    if lList = 0 then
    begin
      MdcLog('TryReadBuildMessages: no SysListView32 found under host');
      exit;
    end;

    aText := ReadListViewAllText(lList);
    Result := aText <> '';
    if GMdcLoggingEnabled then
      MdcLog(Format('TryReadBuildMessages: ok=%s len=%d', [BoolToStr(Result, True), Length(aText)]));
  finally
    if lOldFocus <> 0 then
      winApi.Windows.SetFocus(lOldFocus);
  end;
end;

function TMdcProblemsForm.TryParseBuildLine(const aLine: string; out aItem: TMdcProblemItem): Boolean;
var
  lLine: string;
  lRest: string;
  lHdrEnd: Integer;
  lParen1, lParen2: Integer;
  lFilePart: string;
  lLineNo: Integer;
  lMsg: string;
  lUnitName: string;
  lIsError, lIsWarning: Boolean;
  lAfterParen: Integer;
begin
  aItem := nil;
  Result := False;

  lLine := Trim(aLine);
  if lLine = '' then
    exit;

  // Detect severity only in real diagnostic headers:
  //  - [dcc32 Error] ...
  //  - [dcc32 Warning] ...
  //  - dcc32 Error: ...
  //  - dcc32 Warning: ...
  lIsError := (pos('[dcc', LowerCase(lLine)) = 1) and ContainsText(lLine, ' Error]');
  lIsWarning := (pos('[dcc', LowerCase(lLine)) = 1) and ContainsText(lLine, ' Warning]');

  if not (lIsError or lIsWarning) then
  begin
    if (pos('dcc', LowerCase(lLine)) = 1) and ContainsText(lLine, ' Error:') then
      lIsError := True
    else if (pos('dcc', LowerCase(lLine)) = 1) and ContainsText(lLine, ' Warning:') then
      lIsWarning := True;
  end;

  if not (lIsError or lIsWarning) then
    exit;

  // Strip header: [dcc32 Warning] ...
  lRest := lLine;
  if (lRest <> '') and (lRest[1] = '[') then
  begin
    lHdrEnd := pos(']', lRest);
    if lHdrEnd > 0 then
      lRest := Trim(copy(lRest, lHdrEnd + 1, MaxInt));
  end;

  // Now expect: <file>(<line>): <message>
  lParen1 := pos('(', lRest);
  lParen2 := pos(')', lRest);
  if (lParen1 <= 1) or (lParen2 <= lParen1) then
    exit;

  lFilePart := Trim(copy(lRest, 1, lParen1 - 1));
  lLineNo := SafeInt(copy(lRest, lParen1 + 1, lParen2 - lParen1 - 1), 0);
  if (lFilePart = '') or (lLineNo <= 0) then
    exit;

  lAfterParen := pos('):', lRest);
  if lAfterParen > 0 then
    lMsg := Trim(copy(lRest, lAfterParen + 2, MaxInt))
  else
    lMsg := Trim(copy(lRest, lParen2 + 1, MaxInt));

  if (lMsg <> '') and (lMsg[1] = ':') then
    lMsg := Trim(copy(lMsg, 2, MaxInt));

  aItem := TMdcProblemItem.Create;
  aItem.FileName := lFilePart;
  aItem.LineNo := lLineNo;
  aItem.ColNo := 1;
  lUnitName := ChangeFileExt(ExtractFileName(lFilePart), '');

  if lIsError then
  begin
    aItem.kind := pkBuildError;
    aItem.Text := lMsg + ' | ' + lUnitName + ' (' + IntToStr(lLineNo) + ')';
  end else begin
    aItem.kind := pkBuildWarning;
    aItem.Text := lMsg + ' | ' + lUnitName + ' (' + IntToStr(lLineNo) + ')';
  end;

  Result := True;
end;

procedure TMdcProblemsForm.PopulateFromBuildText(const aText: string);
var
  lLines: TArray<string>;
  lLine: string;
  lItem: TMdcProblemItem;
  lNorm: string;
  lErrCnt, lWarnCnt, lSkippedWarn, lSkippedErr: Integer;

  function StripDiagnosticPrefix(const s: string): string;
  var
    l: string;
    lPos: Integer;
  begin
    l := Trim(s);
    if l = '' then
      Exit('');

    if l[1] = '[' then
    begin
      lPos := pos(']', l);
      if lPos > 0 then
        l := Trim(Copy(l, lPos + 1, MaxInt));
    end;

    if StartsText('dcc', l) then
    begin
      lPos := pos(':', l);
      if lPos > 0 then
        l := Trim(Copy(l, lPos + 1, MaxInt));
    end;

    if StartsText('Warning:', l) then
      l := Trim(Copy(l, Length('Warning:') + 1, MaxInt))
    else if StartsText('Error:', l) then
      l := Trim(Copy(l, Length('Error:') + 1, MaxInt));

    Result := l;
  end;

  function LooksLikeLooseDiagnostic(const s: string; out aKind: TMdcProblemKind; out aMsg: string): Boolean;
  var
    l: string;
  begin
    Result := False;
    aMsg := '';
    aKind := pkBuildWarning;

    l := TrimLeft(s);
    if l = '' then
      exit;

    // Strict “loose” detection:
    // - must START with a known diagnostic header pattern, not just contain the word.
    if (l[1] = '[') and (pos('[dcc', LowerCase(l)) = 1) then
    begin
      if ContainsText(l, ' Error]') then
      begin
        aKind := pkBuildError;
        aMsg := StripDiagnosticPrefix(l);
        exit(True);
      end;

      if ContainsText(l, ' Warning]') then
      begin
        aKind := pkBuildWarning;
        aMsg := StripDiagnosticPrefix(l);
        exit(True);
      end;

      exit(False);
    end;

    if (pos('dcc', LowerCase(l)) = 1) then
    begin
      if ContainsText(l, ' Error:') then
      begin
        aKind := pkBuildError;
        aMsg := StripDiagnosticPrefix(l);
        exit(True);
      end;

      if ContainsText(l, ' Warning:') then
      begin
        aKind := pkBuildWarning;
        aMsg := StripDiagnosticPrefix(l);
        exit(True);
      end;
    end;

    // Also allow "Error:" / "Warning:" lines, but only if they START that way (no identifier matches).
    if StartsText('Error:', l) then
    begin
      aKind := pkBuildError;
      aMsg := StripDiagnosticPrefix(l);
      exit(True);
    end;

    if StartsText('Warning:', l) then
    begin
      aKind := pkBuildWarning;
      aMsg := StripDiagnosticPrefix(l);
      exit(True);
    end;
  end;

var
  lKind: TMdcProblemKind;
  lLooseMsg: string;
begin
  ClearListBoxItems(fLbBuildErrors);
  ClearListBoxItems(fLbBuildWarnings);

  lErrCnt := 0;
  lWarnCnt := 0;
  lSkippedWarn := 0;
  lSkippedErr := 0;

  lNorm := aText.Replace(#13, '');
  lLines := lNorm.Split([#10], TStringSplitOptions.ExcludeEmpty);

  for lLine in lLines do
  begin
    if TryParseBuildLine(lLine, lItem) then
    begin
      if lItem.kind = pkBuildError then
      begin
        fLbBuildErrors.Items.addObject(lItem.Text, lItem);
        Inc(lErrCnt);
      end else begin
        fLbBuildWarnings.Items.addObject(lItem.Text, lItem);
        Inc(lWarnCnt);
      end;
      Continue;
    end;

    // Loose diagnostics (no file/line), but STRICT detection (no substring traps).
    if LooksLikeLooseDiagnostic(lLine, lKind, lLooseMsg) then
    begin
      lItem := TMdcProblemItem.Create;
      lItem.kind := lKind;
      lItem.Text := lLooseMsg;
      lItem.FileName := '';
      lItem.LineNo := 0;
      lItem.ColNo := 0;

      if lKind = pkBuildError then
      begin
        fLbBuildErrors.Items.addObject(lItem.Text, lItem);
        Inc(lErrCnt);
        Inc(lSkippedErr);
      end else begin
        fLbBuildWarnings.Items.addObject(lItem.Text, lItem);
        Inc(lWarnCnt);
        Inc(lSkippedWarn);
      end;
    end;
  end;

  if fLbBuildErrors.Items.Count = 0 then
    fLbBuildErrors.Items.Add('(No build errors found or not accessible)');

  if fLbBuildWarnings.Items.Count = 0 then
    fLbBuildWarnings.Items.Add('(No build warnings found or not accessible)');

  if GMdcLoggingEnabled then
    MdcLog(Format('PopulateFromBuildText: errors=%d warnings=%d skippedErr=%d skippedWarn=%d',
      [lErrCnt, lWarnCnt, lSkippedErr, lSkippedWarn]));
end;

procedure TMdcProblemsForm.RefreshBuildMessages;
var
  lText: string;
  lMsgForm: TForm;
  lTree: TWinControl;
  lOpts: TMdcRttiDumpOptions;

  function TryReadMessagesViewText(out aText: string): Boolean;
  begin
    Result := False;
    aText := '';

    EnsureMessageViewShown;
    lMsgForm := FindMessageViewForm;

    if lMsgForm = nil then
    begin
      MdcLog('RefreshBuildMessages: MessageViewForm not found');
      Exit;
    end;

    ActivateBuildTabIfPresent(lMsgForm);

    // Prefer stable name first.
    lTree := FindWinControlByName(lMsgForm, 'MessageTreeView0');

    // Fallback: find something VirtualTree-ish (we keep this broad on purpose).
    if lTree = nil then
      lTree := FindFirstByClassNameContains(lMsgForm, 'Virtual');

    if lTree = nil then
      lTree := FindFirstByClassNameContains(lMsgForm, 'DrawTree');

    if lTree = nil then
    begin
      if GMdcLoggingEnabled then
      begin
        MdcLog('RefreshBuildMessages: message tree not found; dumping control tree');
        DumpControlTree(lMsgForm, '  ');
      end;
      Exit;
    end;

    if GMdcLoggingEnabled then
    begin
      MdcLog(Format('RefreshBuildMessages: tree found: %s  Name=%s  Handle=%d',
        [lTree.ClassName, lTree.Name, lTree.Handle]));

      MdcDumpClassHierarchy(lTree, 'RefreshBuildMessages: tree hierarchy');

      lOpts.MaxProps := 250;
      lOpts.MaxMethods := 400;
      lOpts.OnlyInteresting := True;
      MdcDumpRttiMembers(lTree, 'RefreshBuildMessages: tree RTTI (interesting)', lOpts);
    end;

    // First: try the old “ContentToText” (if the IDE control offers it).
    if TryInvokeNoArgStringMethod(lTree, 'ContentToText', aText) then
    begin
      if GMdcLoggingEnabled then
        MdcLog(Format('RefreshBuildMessages: ContentToText ok (chars=%d)', [Length(aText)]));
      Result := True;
      Exit;
    end;

    if TryInvokeContentToText(lTree, aText) then
    begin
      if GMdcLoggingEnabled then
        MdcLog(Format('RefreshBuildMessages: ContentToText fallback ok (chars=%d)', [Length(aText)]));
      Result := True;
      Exit;
    end;

    // Second: treat it as a virtual tree and enumerate nodes.
    if TryVirtualTreeToText(lTree, aText) then
    begin
      if GMdcLoggingEnabled then
        MdcLog(Format('RefreshBuildMessages: VirtualTree extraction ok (chars=%d)', [Length(aText)]));
      Result := True;
      Exit;
    end;

    MdcLog('RefreshBuildMessages: no supported extraction path worked');
  end;

begin
  MdcLog('RefreshBuildMessages: begin');

  if TryReadMessagesViewText(lText) then
  begin
    if GMdcLoggingEnabled then
      MdcLog('RefreshBuildMessages: got message-view text len=' + IntToStr(Length(lText)));
    PopulateFromBuildText(lText);
    MdcLog('RefreshBuildMessages: ok');
    exit;
  end;

  // If this fails, we show a clear status (no clipboard fallback anymore).
  ClearListBoxItems(fLbBuildErrors);
  ClearListBoxItems(fLbBuildWarnings);
  fLbBuildErrors.Items.Add('(Build messages not accessible right now)');
  fLbBuildWarnings.Items.Add('(Build messages not accessible right now)');
  MdcLog('RefreshBuildMessages: FAILED');
end;

procedure TMdcProblemsForm.JumpToItem(aItem: TMdcProblemItem);
var
  lEditor: IOTAEditorServices;
  lView: IOTAEditView;
  lView140: IOTAEditView140;
  lEditWin: INTAEditWindow;
  lPos: TOTAEditPos;
  lMods: IOTAModuleServices;
  lMod: IOTAModule;
  lTargetFile: string;
  lOpened: Boolean;
begin
  if aItem = nil then
    exit;

  if GMdcLoggingEnabled then
    MdcLog(Format('JumpToItem: kind=%d file="%s" line=%d col=%d text="%s"',
      [Ord(aItem.kind), aItem.FileName, aItem.LineNo, aItem.ColNo, aItem.Text]));

  // Guard: ignore non-jumpable items (fallback lines)
  if (Trim(aItem.FileName) = '') or (aItem.LineNo <= 0) then
  begin
    MdcLog('JumpToItem: non-jumpable item (no filename/line)');
    exit;
  end;

  lTargetFile := aItem.FileName;
  if (lTargetFile.Trim <> '') then
  begin
    if TryResolveFileName(aItem.FileName, lTargetFile) then
    begin
      aItem.FileName := lTargetFile;
      if GMdcLoggingEnabled then
        MdcLog('JumpToItem: resolved file to "' + lTargetFile + '"');
    end else begin
      MdcLog('JumpToItem: file not resolved, using original');
      lTargetFile := aItem.FileName;
    end;
  end;

  lOpened := TMdcIdeApi.OpenInIde(lTargetFile);
  if GMdcLoggingEnabled then
    MdcLog(Format('JumpToItem: OpenInIde ok=%s', [BoolToStr(lOpened, True)]));

  if (not lOpened) and Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
  begin
    try
      lMod := lMods.OpenModule(lTargetFile);
      lOpened := lMod <> nil;
      if lOpened then
      begin
        lMod.Show;
        MdcLog('JumpToItem: OpenModule ok');
      end else begin
        MdcLog('JumpToItem: OpenModule FAILED');
      end;
    except
      MdcLog('JumpToItem: OpenModule FAILED');
    end;
  end;

  if not lOpened then
  begin
    MdcLog('JumpToItem: open failed, aborting cursor move');
    Exit;
  end;

  if not Supports(BorlandIDEServices, IOTAEditorServices, lEditor) then
  begin
    MdcLog('JumpToItem: IOTAEditorServices not supported');
    exit;
  end;

  lView := lEditor.TopView;
  if lView = nil then
  begin
    MdcLog('JumpToItem: TopView=nil');
    exit;
  end;

  lPos.Line := aItem.LineNo;
  lPos.col := aItem.ColNo;
  try
    lView.CursorPos := lPos;
    lView.MoveViewToCursor;
    MdcLog('JumpToItem: CursorPos set + MoveViewToCursor ok');
  except
    MdcLog('JumpToItem: setting CursorPos FAILED');
  end;

  // Hard focus to editor window if possible (Delphi 12+)
  if Supports(lView, IOTAEditView140, lView140) then
  begin
    try
      lEditWin := lView140.GetEditWindow;
      if (lEditWin <> nil) and (lEditWin.Form <> nil) then
      begin
        lEditWin.Form.bringToFront;
        if lEditWin.Form.HandleAllocated then
        begin
          SetForegroundWindow(lEditWin.Form.Handle);
          SetActiveWindow(lEditWin.Form.Handle);
        end;
        lEditWin.Form.SetFocus;
        MdcLog('JumpToItem: focused INTAEditWindow.Form');
      end else begin
        MdcLog('JumpToItem: INTAEditWindow/Form missing');
      end;
    except
      MdcLog('JumpToItem: focusing editor window FAILED');
    end;
  end else begin
    // fallback: at least bring IDE front
    try
      if (application.MainForm <> nil) and application.MainForm.HandleAllocated then
        SetForegroundWindow(application.MainForm.Handle);
    except
    end;
    MdcLog('JumpToItem: IOTAEditView140 not supported, used fallback');
  end;
end;


{ TMdcProblemsKeyBinding }

constructor TMdcProblemsKeyBinding.Create(aShortcut: TShortCut);
begin
  inherited Create;
  fShortcut := aShortcut;
end;

procedure TMdcProblemsKeyBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices.AddKeyBinding([fShortcut], KeyProc, nil);
end;

function TMdcProblemsKeyBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TMdcProblemsKeyBinding.GetDisplayName: string;
begin
  Result := 'MaxLogic Delphi Companion: Problems Dialog';
end;

function TMdcProblemsKeyBinding.GetName: string;
begin
  Result := 'MaxLogicDelphiCompanion.ProblemsDialog';
end;

procedure TMdcProblemsKeyBinding.KeyProc(const Context: IOTAKeyContext; KeyCode: TShortCut;
  var BindingResult: TKeyBindingResult);
begin
  TMdcProblemsForm.ShowSingleton;
  BindingResult := krHandled;
end;

{ TMdcFocusErrorInsight }

class procedure TMdcFocusErrorInsight.Install;
var
  lKS: IOTAKeyboardServices;
  lShortcut: TShortCut;
begin
  if (GBindingIndex >= 0) then
    exit;

  if not Supports(BorlandIDEServices, IOTAKeyboardServices, lKS) then
    exit;

  TMdcSettings.LoadFocusErrorInsightShortcut(lShortcut);
  if lShortcut = 0 then
    exit;

  GBindingIntf := TMdcProblemsKeyBinding.Create(lShortcut);
  GBindingIndex := lKS.AddKeyboardBinding(GBindingIntf);

  if GMdcLoggingEnabled then
    MdcLog('Install: keyboard binding added idx=' + IntToStr(GBindingIndex));
end;

class procedure TMdcFocusErrorInsight.Uninstall;
var
  lKS: IOTAKeyboardServices;
begin
  MdcLog('Uninstall: begin');

  if (GBindingIndex >= 0) and Supports(BorlandIDEServices, IOTAKeyboardServices, lKS) then
  begin
    try
      lKS.RemoveKeyboardBinding(GBindingIndex);
      if GMdcLoggingEnabled then
        MdcLog('Uninstall: removed keyboard binding idx=' + IntToStr(GBindingIndex));
    except
      MdcLog('Uninstall: removing keyboard binding FAILED');
    end;
  end;

  GBindingIndex := -1;
  GBindingIntf := nil;

  // IMPORTANT: free the form NOW (avoid timer messages hitting unloaded code later)
  if GProblemsForm <> nil then
  begin
    try
      GProblemsForm.Free;
      MdcLog('Uninstall: freed problems form');
    except
      MdcLog('Uninstall: freeing problems form FAILED');
    end;
    GProblemsForm := nil;
  end;

  MdcLog('Uninstall: end');
end;

end.

