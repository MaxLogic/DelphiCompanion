unit maxLogic.DelphiCompanion.FocusErrorInsight;

interface

uses
  System.Classes, System.Types,
  Winapi.CommCtrl, Winapi.Messages, Winapi.Windows,
  Vcl.ComCtrls, Vcl.Forms, Vcl.StdCtrls,
  ToolsAPI, ToolsAPI.Editor;

type
  TMdcFocusErrorInsight = class
  public
    class procedure Install;
    class procedure Uninstall;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.Rtti, System.StrUtils, System.SysUtils, System.TypInfo,
  Vcl.ActnList, Vcl.ClipBrd, Vcl.Controls, Vcl.ExtCtrls, Vcl.Graphics,
  AutoFree, maxLogic.StrUtils, maxLogic.DelphiCompanion.IdeApi, maxLogic.DelphiCompanion.IdeUiInspector,
  maxLogic.DelphiCompanion.Logger, maxLogic.DelphiCompanion.Providers,
  maxLogic.DelphiCompanion.Settings;

resourcestring
  SEiTitleBase = '&Error Insight  (F1)';
  SBuildErrorsTitleBase = 'Build E&rrors  (F2)';
  SBuildWarningsTitleBase = 'Build &Warnings  (F3)';
  STitleWithCount = '%s (%d)';
  SNoErrorInsight = '(No Error Insight errors/warnings)';
  SNoBuildErrors = '(No build errors found or not accessible)';
  SNoBuildWarnings = '(No build warnings found or not accessible)';
  SBuildMessagesUnavailable = '(Build messages not accessible right now)';

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

    fEdBuildErrors: TEdit;
    fEdBuildWarnings: TEdit;

    fLblEi: TStaticText;
    fLblErr: TStaticText;
    fLblWarn: TStaticText;

    fBtnRefresh: TButton;
    fBtnClose: TButton;

    fLastEiSignature: string;
    fEiRefreshing: Boolean;
    fBuildMessagesAccessible: Boolean;

    fBuildErrorItems: TArray<TMdcProblemItem>;
    fBuildWarningItems: TArray<TMdcProblemItem>;

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

    procedure ClearListBoxItems(aLb: TListBox; aFreeObjects: Boolean = True);
    procedure ClearBuildItems(var aItems: TArray<TMdcProblemItem>);
    function SelectedItem(aLb: TListBox): TMdcProblemItem;

    procedure BuildFilterChange(Sender: TObject);
    procedure BuildFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ApplyBuildFilters;
    procedure ApplyBuildFilterToList(
      const aItems: TArray<TMdcProblemItem>; const aFilterText: string;
      aList: TListBox; const aEmptyText: string; out aVisibleCount: Integer);

    procedure JumpToItem(aItem: TMdcProblemItem);
    procedure RefreshAll;
    procedure RefreshErrorInsight;
    procedure RefreshBuildMessages;

    procedure UpdateErrorInsightTitle(aCount: Integer);
    procedure UpdateBuildTitles(aErrCount, aWarnCount: Integer);

    function TryGetActiveFileName(out aFileName: string): Boolean;
    function TryCollectModuleErrors(const aFileName: string; out aErrors: TOTAErrors): Boolean;

    function BuildEiSignature(const aErrors: TOTAErrors): string;

    function TryResolveFileName(const aFileName: string; out aResolved: string): Boolean;

    function FindMessageViewForm: TForm;
    procedure EnsureMessageViewShown;

    function TryCopyBuildMessagesToClipboard(out aText: string): Boolean;
    function TryParseBuildLine(const aLine: string; out aItem: TMdcProblemItem): Boolean;

    procedure PopulateFromBuildText(const aText: string);

    function TryGetSourceView(const aFileName: string; out aView: IOTAEditView): Boolean;

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

  TMdcProblemsActionHandler = class
  public
    procedure Execute(Sender: TObject);
  end;

  TMdcBuildMessagesNotifier = class(TNotifierObject, IOTAIDENotifier, IOTAIDENotifier50, IOTAIDENotifier80)
  private
    procedure HandleAfterCompile(aIsCodeInsight: Boolean);
    function CanRefresh: Boolean;
    procedure QueueRefresh;
  public
    { IOTAIDENotifier }
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    { IOTAIDENotifier50 }
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); overload;

    { IOTAIDENotifier80 }
    procedure AfterCompile(const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean); overload;
  end;

const
  CWinKeyProblems = 'Problems.Dialog';

var
  GBindingIndex: Integer = -1;
  GBindingIntf: IOTAKeyboardBinding = nil;
  GProblemsAction: TAction = nil;
  GProblemsActionHandler: TMdcProblemsActionHandler = nil;
  GProblemsForm: TMdcProblemsForm = nil;
  GBuildNotifierIndex: Integer = -1;
  GBuildNotifier: IOTAIDENotifier = nil;
  GLastBuildRefreshTick: Cardinal = 0;

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

  fBuildMessagesAccessible := False;

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
  fLblErr.ShowHint := True;
  fLblErr.hint := 'Hotkey: F2 focuses this list';

  fEdBuildErrors := TEdit.Create(self);
  fEdBuildErrors.Parent := self;
  fEdBuildErrors.OnChange := BuildFilterChange;
  fEdBuildErrors.OnKeyDown := BuildFilterKeyDown;
  fEdBuildErrors.TabStop := True;

  fLblErr.FocusControl := fEdBuildErrors;

  fLbBuildWarnings := TListBox.Create(self);
  fLbBuildWarnings.Parent := self;
  fLbBuildWarnings.Anchors := [akLeft, akTop, akBottom, akRight];
  fLbBuildWarnings.IntegralHeight := False;
  fLbBuildWarnings.OnDblClick := LbDblClick;
  fLbBuildWarnings.OnKeyDown := LbKeyDown;
  fLbBuildWarnings.TabStop := True;

  fLblWarn := TStaticText.Create(self);
  fLblWarn.Parent := self;
  fLblWarn.ShowHint := True;
  fLblWarn.hint := 'Hotkey: F3 focuses this list';

  fEdBuildWarnings := TEdit.Create(self);
  fEdBuildWarnings.Parent := self;
  fEdBuildWarnings.OnChange := BuildFilterChange;
  fEdBuildWarnings.OnKeyDown := BuildFilterKeyDown;
  fEdBuildWarnings.TabStop := True;

  fLblWarn.FocusControl := fEdBuildWarnings;

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

  fLbErrorInsight.TabOrder := 0;
  fEdBuildErrors.TabOrder := 1;
  fLbBuildErrors.TabOrder := 2;
  fEdBuildWarnings.TabOrder := 3;
  fLbBuildWarnings.TabOrder := 4;
  fBtnRefresh.TabOrder := 5;
  fBtnClose.TabOrder := 6;

  UpdateErrorInsightTitle(0);
  UpdateBuildTitles(0, 0);

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
  ClearListBoxItems(fLbBuildErrors, False);
  ClearListBoxItems(fLbBuildWarnings, False);
  ClearBuildItems(fBuildErrorItems);
  ClearBuildItems(fBuildWarningItems);

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

  GProblemsForm.RefreshAll;
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
  lLabelGap, lFilterGap, lFilterHeight: Integer;
  lListTopEi, lListTopBuild, lListWidth, lListHeightEi, lListHeightBuild: Integer;
  lFilterTop: Integer;
  lButtonsTop, lButtonHeight, lButtonWidth: Integer;

  function SV(v: Integer): Integer;
  begin
    Result := ScaleValue(v);
  end;

begin
  if (fLbErrorInsight = nil) or (fLbBuildErrors = nil) or (fLbBuildWarnings = nil) or
     (fEdBuildErrors = nil) or (fEdBuildWarnings = nil) or
     (fLblEi = nil) or (fLblErr = nil) or (fLblWarn = nil) or
     (fBtnRefresh = nil) or (fBtnClose = nil) then
    Exit;

  lMargin := SV(10);
  lGap := SV(10);
  lLabelTop := SV(10);
  lLabelHeight := SV(18);
  lLabelGap := SV(7);
  lFilterGap := SV(6);
  lFilterHeight := SV(22);
  lButtonHeight := SV(30);
  lButtonWidth := SV(140);
  lButtonsTop := ClientHeight - SV(45);

  lListTopEi := lLabelTop + lLabelHeight + lLabelGap;
  lFilterTop := lLabelTop + lLabelHeight + lLabelGap;
  lListTopBuild := lFilterTop + lFilterHeight + lFilterGap;

  lListHeightEi := lButtonsTop - lListTopEi - lGap;
  if lListHeightEi < SV(1) then
    lListHeightEi := SV(1);

  lListHeightBuild := lButtonsTop - lListTopBuild - lGap;
  if lListHeightBuild < SV(1) then
    lListHeightBuild := SV(1);

  lListWidth := (ClientWidth - (lMargin * 2) - (lGap * 2)) div 3;
  if lListWidth < SV(1) then
    lListWidth := SV(1);

  fLbErrorInsight.SetBounds(lMargin, lListTopEi, lListWidth, lListHeightEi);
  fLbBuildErrors.SetBounds(fLbErrorInsight.Left + lListWidth + lGap, lListTopBuild, lListWidth, lListHeightBuild);
  fLbBuildWarnings.SetBounds(fLbBuildErrors.Left + lListWidth + lGap, lListTopBuild, lListWidth, lListHeightBuild);

  fLblEi.SetBounds(fLbErrorInsight.Left, lLabelTop, lListWidth, lLabelHeight);
  fLblErr.SetBounds(fLbBuildErrors.Left, lLabelTop, lListWidth, lLabelHeight);
  fLblWarn.SetBounds(fLbBuildWarnings.Left, lLabelTop, lListWidth, lLabelHeight);

  fEdBuildErrors.SetBounds(fLbBuildErrors.Left, lFilterTop, lListWidth, lFilterHeight);
  fEdBuildWarnings.SetBounds(fLbBuildWarnings.Left, lFilterTop, lListWidth, lFilterHeight);

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

procedure TMdcProblemsForm.BuildFilterChange(Sender: TObject);
begin
  ApplyBuildFilters;
end;

procedure TMdcProblemsForm.BuildFilterKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DOWN then
  begin
    if Sender = fEdBuildErrors then
      ActiveControl := fLbBuildErrors
    else if Sender = fEdBuildWarnings then
      ActiveControl := fLbBuildWarnings;

    Key := 0;
    Exit;
  end;

  LbKeyDown(Sender, Key, Shift);
end;

procedure TMdcProblemsForm.ClearListBoxItems(aLb: TListBox; aFreeObjects: Boolean = True);
var
  i: Integer;
begin
  if aLb = nil then
    exit;

  if aFreeObjects then
    for i := 0 to aLb.Items.Count - 1 do
      aLb.Items.Objects[i].Free;

  aLb.Items.Clear;
end;

procedure TMdcProblemsForm.ClearBuildItems(var aItems: TArray<TMdcProblemItem>);
var
  lItem: TMdcProblemItem;
begin
  for lItem in aItems do
    lItem.Free;

  aItems := [];
end;

procedure TMdcProblemsForm.ApplyBuildFilterToList(
  const aItems: TArray<TMdcProblemItem>; const aFilterText: string;
  aList: TListBox; const aEmptyText: string; out aVisibleCount: Integer);
var
  lFilter: TFilterEx;
  lItem: TMdcProblemItem;
  lText: string;
begin
  aVisibleCount := 0;

  if aList = nil then
    Exit;

  aList.Items.BeginUpdate;
  try
    ClearListBoxItems(aList, False);

    if Length(aItems) = 0 then
    begin
      if aEmptyText <> '' then
        aList.Items.Add(aEmptyText);
      Exit;
    end;

    lFilter := TFilterEx.Create(aFilterText); // record, no free required

    for lItem in aItems do
    begin
      lText := lItem.Text;
      if lItem.FileName <> '' then
        lText := lText + ' ' + lItem.FileName;

      if lFilter.Matches(lText) then
      begin
        aList.Items.AddObject(lItem.Text, lItem);
        Inc(aVisibleCount);
      end;
    end;

    if aList.Items.Count > 0 then
      aList.ItemIndex := 0;
  finally
    aList.Items.EndUpdate;
  end;
end;

procedure TMdcProblemsForm.ApplyBuildFilters;
var
  lErrCount, lWarnCount: Integer;
begin
  if (fLbBuildErrors = nil) or (fLbBuildWarnings = nil) or
     (fEdBuildErrors = nil) or (fEdBuildWarnings = nil) then
    Exit;

  if not fBuildMessagesAccessible then
  begin
    ClearListBoxItems(fLbBuildErrors, False);
    ClearListBoxItems(fLbBuildWarnings, False);

    fLbBuildErrors.Items.Add(SBuildMessagesUnavailable);
    fLbBuildWarnings.Items.Add(SBuildMessagesUnavailable);

    UpdateBuildTitles(0, 0);
    Exit;
  end;

  ApplyBuildFilterToList(fBuildErrorItems, fEdBuildErrors.Text, fLbBuildErrors, SNoBuildErrors, lErrCount);
  ApplyBuildFilterToList(fBuildWarningItems, fEdBuildWarnings.Text, fLbBuildWarnings, SNoBuildWarnings, lWarnCount);
  UpdateBuildTitles(lErrCount, lWarnCount);
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

procedure TMdcProblemsForm.UpdateErrorInsightTitle(aCount: Integer);
begin
  if fLblEi = nil then
    Exit;

  fLblEi.Caption := Format(STitleWithCount, [SEiTitleBase, aCount]);
end;

procedure TMdcProblemsForm.UpdateBuildTitles(aErrCount, aWarnCount: Integer);
begin
  if fLblErr <> nil then
    fLblErr.Caption := Format(STitleWithCount, [SBuildErrorsTitleBase, aErrCount]);

  if fLblWarn <> nil then
    fLblWarn.Caption := Format(STitleWithCount, [SBuildWarningsTitleBase, aWarnCount]);
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
      fLbErrorInsight.Items.Add(SNoErrorInsight);

    UpdateErrorInsightTitle(lCnt);

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
  lErrItems: TList<TMdcProblemItem>;
  lWarnItems: TList<TMdcProblemItem>;
  gE, gW: IGarbo;

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
  ClearBuildItems(fBuildErrorItems);
  ClearBuildItems(fBuildWarningItems);

  GC(lErrItems, TList<TMdcProblemItem>.Create, gE);
  GC(lWarnItems, TList<TMdcProblemItem>.Create, gW);

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
        lErrItems.Add(lItem);
        Inc(lErrCnt);
      end else begin
        lWarnItems.Add(lItem);
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
        lErrItems.Add(lItem);
        Inc(lErrCnt);
        Inc(lSkippedErr);
      end else begin
        lWarnItems.Add(lItem);
        Inc(lWarnCnt);
        Inc(lSkippedWarn);
      end;
    end;
  end;

  fBuildErrorItems := lErrItems.ToArray;
  fBuildWarningItems := lWarnItems.ToArray;

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
    fBuildMessagesAccessible := True;
    PopulateFromBuildText(lText);
    ApplyBuildFilters;
    MdcLog('RefreshBuildMessages: ok');
    exit;
  end;

  // If this fails, we show a clear status (no clipboard fallback anymore).
  fBuildMessagesAccessible := False;
  ClearBuildItems(fBuildErrorItems);
  ClearBuildItems(fBuildWarningItems);
  ApplyBuildFilters;
  MdcLog('RefreshBuildMessages: FAILED');
end;

procedure TMdcProblemsForm.JumpToItem(aItem: TMdcProblemItem);
var
  lEditor: IOTAEditorServices;
  lView: IOTAEditView;
  lView140: IOTAEditView140;
  lCodeSvc: INTACodeEditorServices;
  lPos: TOTAEditPos;
  lMods: IOTAModuleServices;
  lMod: IOTAModule;
  lTargetFile: string;
  lOpened: Boolean;

  function NormalizeFileName(const aFileName: string): string;
  begin
    Result := aFileName.Trim;
    if Result = '' then
      Exit('');

    if TPath.IsPathRooted(Result) then
      Result := ExpandFileName(Result);
  end;

  function SameFileName(const aLeft, aRight: string): Boolean;
  begin
    Result := SameText(NormalizeFileName(aLeft), NormalizeFileName(aRight));
  end;

  function TryGetTopViewForFile(out aView: IOTAEditView): Boolean;
  var
    lSvc: IOTAEditorServices;
    lTop: IOTAEditView;
    lTopBuf: IOTAEditBuffer;
  begin
    aView := nil;
    Result := False;

    if not Supports(BorlandIDEServices, IOTAEditorServices, lSvc) then
      Exit;

    lTop := lSvc.TopView;
    if lTop = nil then
      Exit;

    lTopBuf := lTop.Buffer;
    if (lTopBuf <> nil) and SameFileName(lTopBuf.FileName, lTargetFile) then
    begin
      aView := lTop;
      Result := True;
    end;
  end;

  function TryGetKnownViewForFile(out aView: IOTAEditView): Boolean;
  var
    lViews: TList<IOTAEditView>;
    lKnownView: IOTAEditView;
    lBuf: IOTAEditBuffer;
  begin
    aView := nil;
    Result := False;

    if not Supports(BorlandIDEServices, INTACodeEditorServices, lCodeSvc) then
      Exit;

    lViews := lCodeSvc.GetKnownViews;
    if lViews = nil then
      Exit;

    try
      for lKnownView in lViews do
      begin
        if lKnownView = nil then
          Continue;

        lBuf := lKnownView.Buffer;
        if (lBuf <> nil) and SameFileName(lBuf.FileName, lTargetFile) then
        begin
          aView := lKnownView;
          Result := True;
          Exit;
        end;
      end;
    finally
      lViews.Free;
    end;
  end;

  function TryGetViewForFile(out aView: IOTAEditView): Boolean;
  begin
    if TryGetKnownViewForFile(aView) then
      Exit(True);

    if TryGetSourceView(lTargetFile, aView) then
      Exit(True);

    Result := TryGetTopViewForFile(aView);
  end;

  procedure FocusView(const aView: IOTAEditView);
  var
    lCtrl: TWinControl;
    lView140Local: IOTAEditView140;
    lWin: INTAEditWindow;
  begin
    if Supports(aView, IOTAEditView140, lView140Local) then
    begin
      try
        lView140Local.MoveCursorToView;
      except
        MdcLog('JumpToItem: MoveCursorToView FAILED');
      end;
    end;

    if Supports(BorlandIDEServices, INTACodeEditorServices, lCodeSvc) then
    begin
      lCtrl := lCodeSvc.GetEditorForView(aView);
      if (lCtrl <> nil) and lCtrl.CanFocus then
      begin
        try
          lCtrl.SetFocus;
          MdcLog('JumpToItem: focused editor control');
        except
          MdcLog('JumpToItem: focusing editor control FAILED');
        end;
      end else begin
        try
          lCodeSvc.FocusTopEditor;
          MdcLog('JumpToItem: FocusTopEditor called');
        except
          MdcLog('JumpToItem: FocusTopEditor FAILED');
        end;
      end;
    end;

    if Supports(aView, IOTAEditView140, lView140Local) then
    begin
      try
        lWin := lView140Local.GetEditWindow;
        if (lWin <> nil) and (lWin.Form <> nil) then
        begin
          lWin.Form.BringToFront;
          if lWin.Form.HandleAllocated then
          begin
            SetForegroundWindow(lWin.Form.Handle);
            SetActiveWindow(lWin.Form.Handle);
          end;
          if lWin.Form.CanFocus then
            lWin.Form.SetFocus;
          MdcLog('JumpToItem: focused INTAEditWindow.Form');
        end else begin
          MdcLog('JumpToItem: INTAEditWindow/Form missing');
        end;
      except
        MdcLog('JumpToItem: focusing editor window FAILED');
      end;
    end else begin
      try
        if (application.MainForm <> nil) and application.MainForm.HandleAllocated then
          SetForegroundWindow(application.MainForm.Handle);
      except
      end;
      MdcLog('JumpToItem: IOTAEditView140 not supported, used fallback');
    end;

    if Supports(BorlandIDEServices, INTACodeEditorServices, lCodeSvc) then
    begin
      try
        lCodeSvc.FocusTopEditor;
        MdcLog('JumpToItem: FocusTopEditor (final) called');
      except
        MdcLog('JumpToItem: FocusTopEditor (final) FAILED');
      end;
    end;
  end;
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

  lView := nil;
  if not TryGetViewForFile(lView) then
  begin
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
  end;

  lPos.Line := aItem.LineNo;
  lPos.col := aItem.ColNo;
  if lPos.Line < 1 then
    lPos.Line := 1;
  if lPos.Col < 1 then
    lPos.Col := 1;

  try
    lView.CursorPos := lPos;
    if Supports(lView, IOTAEditView140, lView140) then
      lView140.MoveCursorToView;
    lView.MoveViewToCursor;
    MdcLog('JumpToItem: CursorPos set + MoveViewToCursor ok');
  except
    MdcLog('JumpToItem: setting CursorPos FAILED');
  end;

  FocusView(lView);
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

procedure TMdcProblemsActionHandler.Execute(Sender: TObject);
begin
  TMdcProblemsForm.ShowSingleton;
end;

procedure UpdateProblemsActionShortCut;
var
  lShortcut: TShortCut;
begin
  if GProblemsAction = nil then
    Exit;

  TMdcSettings.LoadFocusErrorInsightShortcut(lShortcut);
  GProblemsAction.ShortCut := lShortcut;
end;

procedure InstallProblemsAction;
var
  lNta: INTAServices;
begin
  if Supports(BorlandIDEServices, INTAServices, lNta) and (lNta.ActionList <> nil) then
  begin
    if GProblemsAction = nil then
    begin
      GProblemsAction := TAction.Create(nil);
      GProblemsAction.Caption := 'MaxLogic Problems Dialog';
      GProblemsAction.ActionList := lNta.ActionList;
    end;

    if GProblemsActionHandler = nil then
      GProblemsActionHandler := TMdcProblemsActionHandler.Create;

    GProblemsAction.OnExecute := GProblemsActionHandler.Execute;

    UpdateProblemsActionShortCut;
  end;
end;

procedure UninstallProblemsAction;
begin
  if GProblemsAction <> nil then
  begin
    GProblemsAction.OnExecute := nil;
    GProblemsAction.ActionList := nil;
    FreeAndNil(GProblemsAction);
  end;

  FreeAndNil(GProblemsActionHandler);
end;

function TMdcProblemsForm.TryGetSourceView(const aFileName: string; out aView: IOTAEditView): Boolean;
var
  lMods: IOTAModuleServices;
  lMod: IOTAModule;
  lEditor: IOTAEditor;
  lSource: IOTASourceEditor;
  i: Integer;
  lCount: Integer;
begin
  Result := False;
  aView := nil;

  if not Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
    Exit;

  lMod := lMods.FindModule(aFileName);
  if lMod = nil then
    lMod := lMods.OpenModule(aFileName);

  if lMod = nil then
    Exit;

  try
    lMod.ShowFilename(aFileName);
  except
  end;

  lCount := lMod.ModuleFileCount;
  for i := 0 to lCount - 1 do
  begin
    lEditor := lMod.ModuleFileEditors[i];
    if Supports(lEditor, IOTASourceEditor, lSource) then
    begin
      lEditor.Show;
      if lSource.EditViewCount > 0 then
        aView := lSource.EditViews[0];
      Result := aView <> nil;
      Exit;
    end;
  end;
end;

{ TMdcBuildMessagesNotifier }

function TMdcBuildMessagesNotifier.CanRefresh: Boolean;
begin
  Result := (GProblemsForm <> nil)
    and GProblemsForm.Visible
    and (GProblemsForm.WindowState <> wsMinimized);
end;

procedure TMdcBuildMessagesNotifier.HandleAfterCompile(aIsCodeInsight: Boolean);
var
  lNow: Cardinal;
begin
  if aIsCodeInsight then
    Exit;

  lNow := GetTickCount;
  if (GLastBuildRefreshTick <> 0) and (lNow - GLastBuildRefreshTick < 800) then
    Exit;
  GLastBuildRefreshTick := lNow;

  if not CanRefresh then
    Exit;

  TThread.Queue(nil, QueueRefresh);
end;

procedure TMdcBuildMessagesNotifier.QueueRefresh;
begin
  if (GProblemsForm <> nil) and GProblemsForm.Visible and (GProblemsForm.WindowState <> wsMinimized) then
    GProblemsForm.RefreshBuildMessages;
end;

procedure TMdcBuildMessagesNotifier.BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean);
begin
  if not IsCodeInsight then
    GLastBuildRefreshTick := 0;
end;

procedure TMdcBuildMessagesNotifier.AfterCompile(const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean);
begin
  HandleAfterCompile(IsCodeInsight);
end;

procedure TMdcBuildMessagesNotifier.AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean);
begin
  HandleAfterCompile(IsCodeInsight);
end;

procedure TMdcBuildMessagesNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string;
  var Cancel: Boolean); begin end;
procedure TMdcBuildMessagesNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); begin end;
procedure TMdcBuildMessagesNotifier.AfterCompile(Succeeded: Boolean); begin end;
procedure TMdcBuildMessagesNotifier.AfterSave; begin end;
procedure TMdcBuildMessagesNotifier.BeforeSave; begin end;
procedure TMdcBuildMessagesNotifier.Destroyed; begin end;
procedure TMdcBuildMessagesNotifier.Modified; begin end;

{ TMdcFocusErrorInsight }

class procedure TMdcFocusErrorInsight.Install;
var
  lKS: IOTAKeyboardServices;
  lShortcut: TShortCut;
  lServices: IOTAServices;
begin
  InstallProblemsAction;

  if (GBindingIndex < 0) and Supports(BorlandIDEServices, IOTAKeyboardServices, lKS) then
  begin
    TMdcSettings.LoadFocusErrorInsightShortcut(lShortcut);
    if lShortcut <> 0 then
    begin
      GBindingIntf := TMdcProblemsKeyBinding.Create(lShortcut);
      GBindingIndex := lKS.AddKeyboardBinding(GBindingIntf);

      if GMdcLoggingEnabled then
        MdcLog('Install: keyboard binding added idx=' + IntToStr(GBindingIndex));
    end;
  end;

  if (GBuildNotifierIndex < 0) and Supports(BorlandIDEServices, IOTAServices, lServices) then
  begin
    GBuildNotifier := TMdcBuildMessagesNotifier.Create;
    GBuildNotifierIndex := lServices.AddNotifier(GBuildNotifier);
  end;
end;

class procedure TMdcFocusErrorInsight.Uninstall;
var
  lKS: IOTAKeyboardServices;
  lServices: IOTAServices;
begin
  MdcLog('Uninstall: begin');

  UninstallProblemsAction;

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

  if (GBuildNotifierIndex >= 0) and Supports(BorlandIDEServices, IOTAServices, lServices) then
  begin
    try
      lServices.RemoveNotifier(GBuildNotifierIndex);
    except
      MdcLog('Uninstall: removing build notifier FAILED');
    end;
  end;

  GBuildNotifierIndex := -1;
  GBuildNotifier := nil;

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

