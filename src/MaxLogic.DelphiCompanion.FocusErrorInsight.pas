unit maxLogic.DelphiCompanion.FocusErrorInsight;

interface

uses
  winApi.Windows, winApi.CommCtrl, winApi.Messages,
  System.Classes, System.SysUtils,
  vcl.Menus, vcl.ComCtrls,
  ToolsAPI, System.Rtti, System.TypInfo;

type
  TMdcFocusErrorInsight = class
  public
    class procedure Install;
    class procedure Uninstall;
  end;

implementation

uses
  System.generics.collections, System.Math,
  System.StrUtils,
  System.DateUtils,
  System.IOUtils,
  vcl.Forms,
  vcl.Controls,
  vcl.StdCtrls,
  vcl.ExtCtrls,
  vcl.ClipBrd,
  vcl.Graphics,
  AutoFree,
  maxLogic.DelphiCompanion.Settings, maxLogic.DelphiCompanion.IdeUiInspector, maxLogic.DelphiCompanion.Logger;

type
  PHWND = ^hwnd;

type
  TMdcProblemKind = (pkErrorInsightError, pkErrorInsightWarning, pkBuildError, pkBuildWarning);

  TMdcProblemItem = class
  public
    kind: TMdcProblemKind;
    Text: string;
    FileName: string;
    LineNo: integer; // 1-based
    ColNo: integer; // 1-based
  end;

  TMdcProblemsForm = class(TForm)
  private
    fTimer: TTimer;

    fLbErrorInsight: TListBox;
    fLbBuildErrors: TListBox;
    fLbBuildWarnings: TListBox;

    fBtnRefresh: TButton;
    fBtnClose: TButton;

    fLastEiSignature: string;
    fEiRefreshing: boolean;

    fHooked: boolean;

    procedure TimerTick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);

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

    function TryGetActiveFileName(out aFileName: string): boolean;
    function TryCollectModuleErrors(const aFileName: string; out aErrors: TOTAErrors): boolean;

    function BuildEiSignature(const aErrors: TOTAErrors): string;

    function FindMessageViewForm: TForm;
    procedure EnsureMessageViewShown;

    function TryCopyBuildMessagesToClipboard(out aText: string): boolean;
    function TryParseBuildLine(const aLine: string; out aItem: TMdcProblemItem): boolean;

    procedure PopulateFromBuildText(const aText: string);

    function AppHook(var aMsg: TMessage): boolean;

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

var
  GBindingIndex: integer = -1;
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

function SafeInt(const s: string; const aDefault: integer = 0): integer;
begin
  if not TryStrToInt(Trim(s), Result) then
    Result := aDefault;
end;

{ TMdcProblemsForm }

constructor TMdcProblemsForm.Create(aOwner: TComponent);
var
  lLblEi, lLblErr, lLblWarn: TStaticText;

  function SV(aV: integer): integer;
  begin
    Result := ScaleValue(aV);
  end;

begin
  inherited CreateNew(aOwner);

  OnDestroy := FormDestroy;
  caption := 'MaxLogic Delphi Companion - Problems';
  BorderStyle := bsSizeable;
  Position := poScreenCenter;
  Width := SV(1100);
  Height := SV(520);

  Font.Name := 'Segoe UI';
  Font.Size := 10;

  // --- LISTS ---
  fLbErrorInsight := TListBox.Create(self);
  fLbErrorInsight.Parent := self;
  fLbErrorInsight.Left := SV(10);
  fLbErrorInsight.Top := SV(35);
  fLbErrorInsight.Width := (ClientWidth - SV(40)) div 3;
  fLbErrorInsight.Height := ClientHeight - SV(90);
  fLbErrorInsight.Anchors := [akLeft, akTop, akBottom];
  fLbErrorInsight.IntegralHeight := False;
  fLbErrorInsight.OnDblClick := LbDblClick;
  fLbErrorInsight.OnKeyDown := LbKeyDown;
  fLbErrorInsight.TabStop := True;

  lLblEi := TStaticText.Create(self);
  lLblEi.Parent := self;
  lLblEi.Left := fLbErrorInsight.Left;
  lLblEi.Top := SV(10);
  lLblEi.Width := fLbErrorInsight.Width;
  lLblEi.Height := SV(18);
  lLblEi.caption := 'Error Insight  (F1)';
  lLblEi.ShowHint := True;
  lLblEi.hint := 'Hotkey: F1 focuses this list';
  lLblEi.FocusControl := fLbErrorInsight;

  fLbBuildErrors := TListBox.Create(self);
  fLbBuildErrors.Parent := self;
  fLbBuildErrors.Left := fLbErrorInsight.Left + fLbErrorInsight.Width + SV(10);
  fLbBuildErrors.Top := fLbErrorInsight.Top;
  fLbBuildErrors.Width := fLbErrorInsight.Width;
  fLbBuildErrors.Height := fLbErrorInsight.Height;
  fLbBuildErrors.Anchors := [akLeft, akTop, akBottom];
  fLbBuildErrors.IntegralHeight := False;
  fLbBuildErrors.OnDblClick := LbDblClick;
  fLbBuildErrors.OnKeyDown := LbKeyDown;
  fLbBuildErrors.TabStop := True;

  lLblErr := TStaticText.Create(self);
  lLblErr.Parent := self;
  lLblErr.Left := fLbBuildErrors.Left;
  lLblErr.Top := lLblEi.Top;
  lLblErr.Width := fLbBuildErrors.Width;
  lLblErr.Height := lLblEi.Height;
  lLblErr.caption := 'Build Errors  (F2)';
  lLblErr.ShowHint := True;
  lLblErr.hint := 'Hotkey: F2 focuses this list';
  lLblErr.FocusControl := fLbBuildErrors;

  fLbBuildWarnings := TListBox.Create(self);
  fLbBuildWarnings.Parent := self;
  fLbBuildWarnings.Left := fLbBuildErrors.Left + fLbBuildErrors.Width + SV(10);
  fLbBuildWarnings.Top := fLbErrorInsight.Top;
  fLbBuildWarnings.Width := fLbErrorInsight.Width;
  fLbBuildWarnings.Height := fLbErrorInsight.Height;
  fLbBuildWarnings.Anchors := [akLeft, akTop, akBottom, akRight];
  fLbBuildWarnings.IntegralHeight := False;
  fLbBuildWarnings.OnDblClick := LbDblClick;
  fLbBuildWarnings.OnKeyDown := LbKeyDown;
  fLbBuildWarnings.TabStop := True;

  lLblWarn := TStaticText.Create(self);
  lLblWarn.Parent := self;
  lLblWarn.Left := fLbBuildWarnings.Left;
  lLblWarn.Top := lLblEi.Top;
  lLblWarn.Width := fLbBuildWarnings.Width;
  lLblWarn.Height := lLblEi.Height;
  lLblWarn.caption := 'Build Warnings  (F3)';
  lLblWarn.ShowHint := True;
  lLblWarn.hint := 'Hotkey: F3 focuses this list';
  lLblWarn.FocusControl := fLbBuildWarnings;

  // --- BUTTONS ---
  fBtnRefresh := TButton.Create(self);
  fBtnRefresh.Parent := self;
  fBtnRefresh.caption := 'Refresh (F5)';
  fBtnRefresh.Left := SV(10);
  fBtnRefresh.Top := ClientHeight - SV(45);
  fBtnRefresh.Width := SV(140);
  fBtnRefresh.Height := SV(30);
  fBtnRefresh.Anchors := [akLeft, akBottom];
  fBtnRefresh.OnClick := BtnRefreshClick;
  fBtnRefresh.OnKeyDown := LbKeyDown;

  fBtnClose := TButton.Create(self);
  fBtnClose.Parent := self;
  fBtnClose.caption := 'Close (Esc)';
  fBtnClose.Left := fBtnRefresh.Left + fBtnRefresh.Width + SV(10);
  fBtnClose.Top := fBtnRefresh.Top;
  fBtnClose.Width := SV(140);
  fBtnClose.Height := fBtnRefresh.Height;
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
        MdcLog('Destroy: UnhookMainWindow=FAILED ' + e.classname + ': ' + e.Message);
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
  try
    if fTimer <> nil then
      fTimer.Enabled := False;
  except
  end;

  GProblemsForm := nil;
end;

function TMdcProblemsForm.AppHook(var aMsg: TMessage): boolean;
begin
  Result := False;

  // Only care while OUR dialog is the active form
  if Screen.ActiveForm <> self then
    exit;

  if (aMsg.msg = WM_KEYDOWN) or (aMsg.msg = WM_SYSKEYDOWN) then
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
          RefreshAll;
          Result := True;
          exit;
        end;

      VK_ESCAPE:
        begin
          Close;
          Result := True;
          exit;
        end;
    end;
  end;
end;

procedure TMdcProblemsForm.TimerTick(Sender: TObject);
begin
  RefreshErrorInsight;
end;

procedure TMdcProblemsForm.BtnRefreshClick(Sender: TObject);
begin
  RefreshAll;
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
  i: integer;
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

function TMdcProblemsForm.TryGetActiveFileName(out aFileName: string): boolean;
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

function TMdcProblemsForm.TryCollectModuleErrors(const aFileName: string; out aErrors: TOTAErrors): boolean;
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

function TMdcProblemsForm.BuildEiSignature(const aErrors: TOTAErrors): string;
var
  lSb: TStringBuilder;
  g: IGarbo;
  lErr: TOTAError;
begin
  gc(lSb, TStringBuilder.Create(4096), g);

  for lErr in aErrors do
  begin
    lSb.append(lErr.Severity);
    lSb.append('|');
    lSb.append(lErr.Text);
    lSb.append('|');
    lSb.append(lErr.start.Line);
    lSb.append(':');
    lSb.append(lErr.start.CharIndex);
    lSb.AppendLine;
  end;

  Result := lSb.ToString;
end;

procedure TMdcProblemsForm.RefreshErrorInsight;
var
  lFile: string;
  lErrors: TOTAErrors;
  lSig: string;
  lErr: TOTAError;
  lItem: TMdcProblemItem;
  lText: string;
  lCnt: integer;
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

    MdcLog(Format('RefreshErrorInsight: %d items for %s', [lCnt, lFile]));
  finally
    fEiRefreshing := False;
  end;
end;

procedure TMdcProblemsForm.EnsureMessageViewShown;
var
  lTA: INTAServices;

  function FindActionByName(const AName: string): TBasicAction;
  var
    i: integer;
    lAct: TBasicAction;
  begin
    Result := nil;

    if (lTA = nil) or (lTA.ActionList = nil) then
      exit;

    for i := 0 to lTA.ActionList.ActionCount - 1 do
    begin
      lAct := lTA.ActionList.Actions[i];
      if SameText(lAct.Name, AName) then
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
  i: integer;
  lForm: TForm;
begin
  Result := nil;

  for i := 0 to Screen.FormCount - 1 do
  begin
    lForm := Screen.Forms[i];
    if lForm = nil then
      Continue;

    if ContainsText(lForm.classname, 'Message') and ContainsText(lForm.classname, 'View') then
      exit(lForm);

    if SameText(lForm.caption, 'Messages') then
      exit(lForm);
  end;
end;

function TMdcProblemsForm.TryCopyBuildMessagesToClipboard(out aText: string): boolean;
var
  lOldFocus: hwnd;
  lForm: TForm;
  lPc: TPageControl;
  lHostHandle: hwnd;

  function GetWinClassName(aH: hwnd): string;
  var
    lBuf: array[0..255] of char;
  begin
    Result := '';
    if aH = 0 then
      exit;
    if GetClassName(aH, lBuf, length(lBuf)) > 0 then
      Result := lBuf;
  end;

  function IsVisibleAndEnabled(aH: hwnd): boolean;
  begin
    Result := (aH <> 0) and IsWindowVisible(aH) and IsWindowEnabled(aH);
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
    lSb: TStringBuilder;
    lHeader: hwnd;
    lColCount: integer;
    lItemCount: integer;
    lItem: integer;
    lCol: integer;
    lBuf: array[0..2047] of char;
    lLv: TLVItem;
    lText: string;
    lLineStarted: boolean;
    lG: IGarbo;
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

    gc(lSb, TStringBuilder.Create(lItemCount * 128), lG);

    ZeroMemory(@lLv, SizeOf(lLv));
    lLv.Mask := LVIF_TEXT;
    lLv.pszText := @lBuf[0];
    lLv.cchTextMax := length(lBuf);

    for lItem := 0 to lItemCount - 1 do
    begin
      lLineStarted := False;

      for lCol := 0 to lColCount - 1 do
      begin
        ZeroMemory(@lBuf[0], SizeOf(lBuf));
        lLv.iItem := lItem;
        lLv.iSubItem := lCol;

        SendMessage(aList, LVM_GETITEMTEXT, WParam(lItem), LPARAM(@lLv));
        lText := Trim(string(lBuf));

        if lText = '' then
          Continue;

        if lLineStarted then
          lSb.append(#9); // keep columns separable (tab)
        lSb.append(lText);
        lLineStarted := True;
      end;

      if lLineStarted then
        lSb.AppendLine;
    end;

    Result := lSb.ToString;
  end;

  function FindPageControl(aParent: TWinControl): TPageControl;
  var
    i: integer;
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

  procedure ActivateBuildTab(aPc: TPageControl);
  var
    i: integer;
  begin
    if aPc = nil then
      exit;

    for i := 0 to aPc.PageCount - 1 do
    begin
      if ContainsText(aPc.Pages[i].caption, 'Build') then
      begin
        aPc.ActivePage := aPc.Pages[i];
        exit;
      end;
    end;
  end;

  function GetBestHostHandle(aForm: TForm): hwnd;
  begin
    Result := 0;
    if aForm = nil then
      exit;

    lPc := FindPageControl(aForm);
    if lPc <> nil then
    begin
      ActivateBuildTab(lPc);
      if (lPc.ActivePage <> nil) and lPc.ActivePage.HandleAllocated then
        exit(lPc.ActivePage.Handle);
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

    MdcLog('Messages form found: ' + lForm.classname + ' caption="' + lForm.caption + '"');
    DumpControlTree(lForm);

    // Try to find the actual message list/tree/grid control (best-guess by class name)
    var lCtrl := FindFirstByClassHint(lForm, [
        'VirtualStringTree', 'VirtualTree', 'ListView', 'TreeView', 'StringGrid', 'Memo', 'SynEdit'
        ]);

    if lCtrl <> nil then
      MdcLog('Candidate messages control: ' + lCtrl.classname + ' name="' + lCtrl.Name + '"')
    else
      MdcLog('No candidate messages control found (will likely copy wrong thing).');
    // --------

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
    MdcLog(Format('TryReadBuildMessages: ok=%s len=%d', [BoolToStr(Result, True), length(aText)]));
  finally
    if lOldFocus <> 0 then
      winApi.Windows.SetFocus(lOldFocus);
  end;
end;

function TMdcProblemsForm.TryParseBuildLine(const aLine: string; out aItem: TMdcProblemItem): boolean;
var
  lLine: string;
  lRest: string;
  lHdrEnd: integer;
  lParen1, lParen2: integer;
  lFilePart: string;
  lLineNo: integer;
  lMsg: string;
  lIsError, lIsWarning: boolean;
  lAfterParen: integer;
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

  if lIsError then
  begin
    aItem.kind := pkBuildError;
    aItem.Text := 'Error: ' + lMsg;
  end else begin
    aItem.kind := pkBuildWarning;
    aItem.Text := 'Warning: ' + lMsg;
  end;

  Result := True;
end;

procedure TMdcProblemsForm.PopulateFromBuildText(const aText: string);
var
  lLines: TArray<string>;
  lLine: string;
  lItem: TMdcProblemItem;
  lNorm: string;
  lErrCnt, lWarnCnt, lSkippedWarn, lSkippedErr: integer;

  function LooksLikeLooseDiagnostic(const s: string; out aKind: TMdcProblemKind; out aMsg: string): boolean;
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
        aMsg := l;
        exit(True);
      end;

      if ContainsText(l, ' Warning]') then
      begin
        aKind := pkBuildWarning;
        aMsg := l;
        exit(True);
      end;

      exit(False);
    end;

    if (pos('dcc', LowerCase(l)) = 1) then
    begin
      if ContainsText(l, ' Error:') then
      begin
        aKind := pkBuildError;
        aMsg := l;
        exit(True);
      end;

      if ContainsText(l, ' Warning:') then
      begin
        aKind := pkBuildWarning;
        aMsg := l;
        exit(True);
      end;
    end;

    // Also allow "Error:" / "Warning:" lines, but only if they START that way (no identifier matches).
    if StartsText('Error:', l) then
    begin
      aKind := pkBuildError;
      aMsg := l;
      exit(True);
    end;

    if StartsText('Warning:', l) then
    begin
      aKind := pkBuildWarning;
      aMsg := l;
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

  MdcLog(Format('PopulateFromBuildText: errors=%d warnings=%d skippedErr=%d skippedWarn=%d',
    [lErrCnt, lWarnCnt, lSkippedErr, lSkippedWarn]));
end;

procedure TMdcProblemsForm.RefreshBuildMessages;
var
  lText: string;

  function TryReadMessagesViewText(out aOut: string): boolean;
  var
    lMsgForm: TForm;
    lTree: TWinControl;
  begin
    aOut := '';
    Result := False;

    lMsgForm := FindMessageViewForm;
    if lMsgForm = nil then
    begin
      MdcLog('RefreshBuildMessages: message view form not found, calling EnsureMessageViewShown');
      EnsureMessageViewShown;
      lMsgForm := FindMessageViewForm;
    end;

    if lMsgForm = nil then
    begin
      MdcLog('RefreshBuildMessages: still no message view form');
      exit;
    end;

    // Prefer the known name from your inspector output.
    lTree := FindWinControlByName(lMsgForm, 'MessageTreeView0');
    if lTree = nil then
      lTree := FindFirstVirtualTreeLike(lMsgForm);

    if lTree = nil then
    begin
      MdcLog('RefreshBuildMessages: message tree not found');
      exit;
    end;

    if not TryInvokeContentToText(lTree, aOut) then
    begin
      MdcLog(Format('ContentToText failed/unsupported for %s', [lTree.classname]));
      MdcDumpObjectDiagnostics(lTree, 'MessageTreeView0');
      exit;
    end;

    Result := aOut <> '';
  end;

begin
  MdcLog('RefreshBuildMessages: begin');

  if TryReadMessagesViewText(lText) then
  begin
    MdcLog('RefreshBuildMessages: got message-view text len=' + IntToStr(length(lText)));
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
  lAction: IOTAActionServices;
  lEditor: IOTAEditorServices;
  lView: IOTAEditView;
  lView140: IOTAEditView140;
  lEditWin: INTAEditWindow;
  lPos: TOTAEditPos;
begin
  if aItem = nil then
    exit;

  MdcLog(Format('JumpToItem: kind=%d file="%s" line=%d col=%d text="%s"',
    [Ord(aItem.kind), aItem.FileName, aItem.LineNo, aItem.ColNo, aItem.Text]));

  // Guard: ignore non-jumpable items (fallback lines)
  if (Trim(aItem.FileName) = '') or (aItem.LineNo <= 0) then
  begin
    MdcLog('JumpToItem: non-jumpable item (no filename/line)');
    exit;
  end;

  if Supports(BorlandIDEServices, IOTAActionServices, lAction) then
  begin
    try
      lAction.OpenFile(aItem.FileName);
      MdcLog('JumpToItem: OpenFile ok');
    except
      MdcLog('JumpToItem: OpenFile FAILED');
    end;
  end else begin
    MdcLog('JumpToItem: IOTAActionServices not supported');
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

procedure produceWarning;
var
  ansi: AnsiString;
  s: string;
  i: integer;
  c: Cardinal;
begin
  s := 'SCZ';
  ansi := s;
  i := 1;
  c := 1;
  i := c + i;
end;

initialization
  produceWarning;

end.

