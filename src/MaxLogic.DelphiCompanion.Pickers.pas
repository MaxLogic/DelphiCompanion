unit MaxLogic.DelphiCompanion.Pickers;

interface

uses
  System.SysUtils,
  System.Classes,
  system.Generics.Defaults,
  MaxLogic.DelphiCompanion.Providers;

type
  TMaxLogicProjectPicker = class
  public
    class function TryPickAndOpen: Boolean; static;
    class procedure ShowModalPickAndOpen; static;
  end;

  TMaxLogicUnitPicker = class
  public
    class function TryPickAndOpen: Boolean; static;
    class procedure ShowModalPickAndOpen; static;
  end;

implementation

uses
  Winapi.Windows,
  Winapi.Messages,
  Winapi.CommCtrl,
  vcl.ClipBrd,
  System.Math,
  System.StrUtils,
  System.IniFiles,
  vcl.graphics,
  System.Generics.Collections,
  System.IOUtils,
  Vcl.Controls,
  Vcl.ComCtrls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.StdCtrls,
  ToolsAPI,
  AutoFree,
  maxLogic.StrUtils,
  MaxLogic.DelphiCompanion.Settings,
  MaxLogic.DelphiCompanion.IdeApi;

resourcestring
  SProjectsTitle = 'MaxLogic: Projects';
  SUnitsTitle    = 'MaxLogic: Units';
  SFilterHint =
    'Type to filter (Everything-style). Enter opens. Esc closes. ' +
    'Ctrl+C copies selected file contents as Markdown.';
  SFilterHintProject = 'Type to filter (Everything-style). Enter opens. Esc closes. Ctrl+F toggles favorite. Del forgets.';

const
  CWinKeyProjects = 'Picker.Projects';
  CWinKeyUnits    = 'Picker.Units';

  CIniSectionPickerUnits = 'Picker.Units';
  CIniKeyScope           = 'Scope';
  CIniKeyIncSearchPaths  = 'IncludeSearchPaths';

type
  TMdcUnitScope = (usOpenEditors, usCurrentProject, usProjectGroup);

type
  TMaxLogicPickerForm = class(TForm)
  private
    fEdit: TEdit;
    fHint: TStaticText;
    fList: TListView;

    fBottom: TPanel;
    fScopeBox: TGroupBox;
    fScopeFlow: TFlowPanel;

    fRbOpen: TRadioButton;
    fRbProject: TRadioButton;
    fRbGroup: TRadioButton;
    fCbSearchPath: TCheckBox;

    fItems: TArray<TMaxLogicPickItem>;
    fIsProjects: Boolean;

    fUnitScope: TMdcUnitScope;
    fIncludeSearchPaths: Boolean;

    fLastMainFocus: TWinControl;
    fWinKey: string;

    procedure BuildUi(const aTitle: string);
    procedure CopySelectedUnitsAsMarkdownToClipboard;
    procedure ApplyProjectsOptions(var aItems: TArray<TMaxLogicPickItem>);

    procedure LoadItems;
    procedure ApplyFilter;

    procedure UpdateScopeUi;
    procedure UpdateScopeLayout;

    procedure AdjustColumns;
    procedure FormResize(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormShow(Sender: TObject);

    function SelectedItemIdx: Integer;

    procedure EditChange(Sender: TObject);
    procedure EditEnter(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);

    procedure ListEnter(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);


    procedure ScopeClick(Sender: TObject);
    procedure RestoreMainFocus;

    procedure ToggleFavoriteSelected;

    procedure LoadUnitPickerPrefs;
    procedure SaveUnitPickerPrefs;
    procedure FilterOutNonFiles;
    procedure SortItemsAlphabetically(
      var aItems: TArray<TMaxLogicPickItem>);
    procedure ForgetSelected;
  private
    // Project picker options (only when fIsProjects=True)
    fSortBox: TGroupBox;
    fSortFlow: TFlowPanel;
    fRbSortAlpha: TRadioButton;
    fRbSortLast: TRadioButton;
    fCbFavoriteFirst: TCheckBox;

    fShowBox: TGroupBox;
    fShowFlow: TFlowPanel;
    fCbShowProjects: TCheckBox;
    fCbShowProjectGroups: TCheckBox;
    fCbShowFavorites: TCheckBox;
    fCbShowNonFavorites: TCheckBox;

    procedure CreateSortProjectsGroupGui;
    procedure CreateShowProjectsGroupGui;
    procedure ProjectsOptionsClick(Sender: TObject);

  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
  public
    constructor CreatePicker(aOwner: TComponent; const aTitle: string; aIsProjects: Boolean);
    function PickFileName(out aFileName: string): Boolean;
  end;

procedure SafeFocus(aCtrl: TWinControl);
begin
  try
    if (aCtrl <> nil) and aCtrl.CanFocus then
    begin
      aCtrl.SetFocus;
    end;
  except
    // ignore (IDE can have weird focus states)
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

procedure AddUniqueFile(const aFileName: string; aList: TList<TMaxLogicPickItem>; aSeen: TDictionary<string, Byte>);
var
  lKey: string;
  lItem: TMaxLogicPickItem;
begin
  if aFileName.Trim = '' then
    Exit;

  lKey := AnsiLowerCase(aFileName);
  if aSeen.ContainsKey(lKey) then
    Exit;

  aSeen.Add(lKey, 1);

  lItem.FileName := aFileName;
  lItem.Display := ChangeFileExt(ExtractFileName(aFileName), '');
  lItem.Detail := ExtractFilePath(aFileName);
  lItem.IsFavorite := False;

  aList.Add(lItem);
end;

procedure AddSearchPathUnits(const aProject: IOTAProject; aList: TList<TMaxLogicPickItem>; aSeen: TDictionary<string, Byte>);
var
  lOpts: IOTAProjectOptions;
  lPaths: string;
  lParts: TArray<string>;
  lPart: string;
  lDir: string;
  lFiles: TArray<string>;
  lFile: string;
begin
  if aProject = nil then
    Exit;

  lOpts := aProject.ProjectOptions;
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

    lDir := ExpandDollarMacros(lDir);
    lDir := ExpandEnvVars(lDir);

    if not TDirectory.Exists(lDir) then
      Continue;

    lFiles := TDirectory.GetFiles(lDir, '*.pas', TSearchOption.soTopDirectoryOnly);
    for lFile in lFiles do
      AddUniqueFile(lFile, aList, aSeen);
  end;
end;

procedure AddProjectUnits(const aProject: IOTAProject; aList: TList<TMaxLogicPickItem>; aSeen: TDictionary<string, Byte>);
var
  i, lCount: Integer;
  lInfo: IOTAModuleInfo;
  lFn: string;
begin
  if aProject = nil then
    Exit;

  lCount := aProject.GetModuleCount;
  for i := 0 to lCount - 1 do
  begin
    lInfo := aProject.GetModule(i);
    if lInfo = nil then
      Continue;

    lFn := lInfo.FileName;
    if lFn.Trim = '' then
      Continue;

    AddUniqueFile(lFn, aList, aSeen);
  end;
end;

function BuildUnitItems(aScope: TMdcUnitScope; aIncludeSearchPaths: Boolean): TArray<TMaxLogicPickItem>;
var
  lList: TList<TMaxLogicPickItem>;
  gList: IGarbo;
  lSeen: TDictionary<string, Byte>;
  gSeen: IGarbo;

  lMods: IOTAModuleServices;
  lProj: IOTAProject;
  lGroup: IOTAProjectGroup;
  i: Integer;
begin
  Result := [];

  GC(lList, TList<TMaxLogicPickItem>.Create, gList);
  GC(lSeen, TDictionary<string, Byte>.Create, gSeen);

  if not Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
    Exit;

  lProj := lMods.GetActiveProject;

  case aScope of
    usOpenEditors:
      begin
        Result := TMaxLogicOpenUnitsProvider.GetItems;
        Exit;
      end;

    usCurrentProject:
      begin
        AddProjectUnits(lProj, lList, lSeen);
        if aIncludeSearchPaths then
          AddSearchPathUnits(lProj, lList, lSeen);
      end;

    usProjectGroup:
      begin
        lGroup := lMods.MainProjectGroup;
        if lGroup <> nil then
        begin
          for i := 0 to lGroup.ProjectCount - 1 do
          begin
            AddProjectUnits(lGroup.Projects[i], lList, lSeen);
            if aIncludeSearchPaths then
              AddSearchPathUnits(lGroup.Projects[i], lList, lSeen);
          end;
        end else begin
          AddProjectUnits(lProj, lList, lSeen);
          if aIncludeSearchPaths then
            AddSearchPathUnits(lProj, lList, lSeen);
        end;
      end;
  end;

  Result := lList.ToArray;
end;

function StripAccel(const aText: string): string;
begin
  Result := StringReplace(aText, '&', '', [rfReplaceAll]);
end;

function ScopeToStr(aScope: TMdcUnitScope): string;
begin
  case aScope of
    usOpenEditors:    Result := 'OpenEditors';
    usCurrentProject: Result := 'CurrentProject';
    usProjectGroup:   Result := 'ProjectGroup';
  else
    Result := 'OpenEditors';
  end;
end;

function StrToScope(const aText: string): TMdcUnitScope;
var
  s: string;
begin
  s := Trim(aText);
  if SameText(s, 'CurrentProject') then
    Exit(usCurrentProject);
  if SameText(s, 'ProjectGroup') then
    Exit(usProjectGroup);
  Result := usOpenEditors;
end;

{ TMaxLogicPickerForm }

constructor TMaxLogicPickerForm.CreatePicker(aOwner: TComponent; const aTitle: string; aIsProjects: Boolean);
var
  lDefaultW, lDefaultH: Integer;
begin
  inherited CreateNew(aOwner);

  fIsProjects := aIsProjects;
  fLastMainFocus := nil;

  if fIsProjects then
    fWinKey := CWinKeyProjects
  else
    fWinKey := CWinKeyUnits;

  BuildUi(aTitle);

  if fIsProjects then
  begin
    lDefaultW := ScaleValue(1100);
    lDefaultH := ScaleValue(650);
  end else begin
    lDefaultW := ScaleValue(1200);
    lDefaultH := ScaleValue(720);
  end;

  TMdcSettings.LoadWindowBounds(fWinKey, Self, lDefaultW, lDefaultH);

  if not fIsProjects then
  begin
    LoadUnitPickerPrefs;
    UpdateScopeUi;
  end;

  LoadItems;
  ApplyFilter;

  KeyPreview := True;
  OnResize := FormResize;
  OnClose := FormClose;
  OnShow := FormShow;
end;

procedure TMaxLogicPickerForm.ApplyProjectsOptions(var aItems: TArray<TMaxLogicPickItem>);
var
  lFiltered: TList<TMaxLogicPickItem>;
  gFiltered: IGarbo;

  lFav: TList<TMaxLogicPickItem>;
  gFav: IGarbo;

  lNonFav: TList<TMaxLogicPickItem>;
  gNonFav: IGarbo;

  lItem: TMaxLogicPickItem;

  function ExtLower(const aFile: string): string;
  begin
    Result := LowerCase(ExtractFileExt(aFile));
  end;

  function IsProj(const aFile: string): Boolean;
  begin
    Result := ExtLower(aFile) = '.dproj';
  end;

  function IsGroup(const aFile: string): Boolean;
  begin
    Result := ExtLower(aFile) = '.groupproj';
  end;

  function PassShowFilters(const a: TMaxLogicPickItem): Boolean;
  var
    lIsFav: Boolean;
    lIsProj: Boolean;
    lIsGrp: Boolean;
  begin
    lIsFav := a.IsFavorite;

    if lIsFav then
    begin
      if not fCbShowFavorites.Checked then
        Exit(False);
    end
    else
    begin
      if not fCbShowNonFavorites.Checked then
        Exit(False);
    end;

    lIsProj := IsProj(a.FileName);
    lIsGrp := IsGroup(a.FileName);

    if lIsProj then
      Exit(fCbShowProjects.Checked);

    if lIsGrp then
      Exit(fCbShowProjectGroups.Checked);

    // Unknown type: keep only if at least one type category is enabled
    Result := fCbShowProjects.Checked or fCbShowProjectGroups.Checked;
  end;

  procedure SortAlpha(var arr: TArray<TMaxLogicPickItem>);
  begin
    SortItemsAlphabetically(arr);
  end;

  function ConcatArrays(const A, B: TArray<TMaxLogicPickItem>): TArray<TMaxLogicPickItem>;
  begin
    if Length(A) = 0 then Exit(B);
    if Length(B) = 0 then Exit(A);
    Result := A + B;
  end;

var
  lArr, lArrFav, lArrNon: TArray<TMaxLogicPickItem>;
begin

  if (fCbShowFavorites = nil) or (fCbShowNonFavorites = nil) or
     (fCbShowProjects = nil) or (fCbShowProjectGroups = nil) or
     (fRbSortAlpha = nil) or (fRbSortLast = nil) or (fCbFavoriteFirst = nil) then
    Exit;

  if not fIsProjects then
    Exit;

  if Length(aItems) = 0 then
    Exit;

  // 1) SHOW filtering (stable)
  GC(lFiltered, TList<TMaxLogicPickItem>.Create, gFiltered);
  for lItem in aItems do
    if PassShowFilters(lItem) then
      lFiltered.Add(lItem);

  lArr := lFiltered.ToArray;

  // 2) FAVORITE FIRST (stable partition, then sort within groups depending on sort mode)
  if fCbFavoriteFirst.Checked then
  begin
    GC(lFav, TList<TMaxLogicPickItem>.Create, gFav);
    GC(lNonFav, TList<TMaxLogicPickItem>.Create, gNonFav);

    for lItem in lArr do
      if lItem.IsFavorite then
        lFav.Add(lItem)
      else
        lNonFav.Add(lItem);

    lArrFav := lFav.ToArray;
    lArrNon := lNonFav.ToArray;

    if fRbSortAlpha.Checked then
    begin
      SortAlpha(lArrFav);
      SortAlpha(lArrNon);
    end;

    aItems := ConcatArrays(lArrFav, lArrNon);
    Exit;
  end;

  // 3) No favorite grouping: just sort or keep provider order
  if fRbSortAlpha.Checked then
    SortAlpha(lArr);

  aItems := lArr;
end;


procedure TMaxLogicPickerForm.CopySelectedUnitsAsMarkdownToClipboard;
const
  CMaxTotalChars = 2 * 1024 * 1024;  // keep clipboard sane
  CMaxFileChars  = 400 * 1024;       // per-file cap
var
  lMd: TStringBuilder;
  lTotal: Integer;
  lLi: TListItem;
  lIdx: Integer;
  lFn: string;
  lText: string;

  function FenceLang(const aFileName: string): string;
  var
    lExt: string;
  begin
    lExt := LowerCase(ExtractFileExt(aFileName));
    if (lExt = '.pas') or (lExt = '.dpr') or (lExt = '.dpk') or (lExt = '.inc') then
      Exit('pascal');
    if (lExt = '.dfm') then
      Exit('dfm');
    if (lExt = '.xml') then
      Exit('xml');
    if (lExt = '.json') then
      Exit('json');
    Result := '';
  end;

begin
  if fIsProjects then
    Exit;

  if (fList = nil) or (fList.SelCount <= 0) then
  begin
    MessageBeep(MB_ICONWARNING);
    Exit;
  end;

  lMd := TStringBuilder.Create(1024 * 16);
  try
    lTotal := 0;

    // iterate all selected items
    lLi := fList.GetNextItem(nil, sdAll, [isSelected]);
    while lLi <> nil do
    begin
      lIdx := NativeInt(lLi.Data);
      if (lIdx >= 0) and (lIdx <= High(fItems)) then
      begin
        lFn := fItems[lIdx].FileName;

        if (lFn.Trim <> '') and FileExists(lFn) then
        begin
          lMd.Append('# ').Append(ExtractFileName(lFn)).AppendLine;
          lMd.Append('`').Append(lFn).AppendLine('`');
          lMd.AppendLine;

          try
            // NOTE: default encoding (Delphi will auto-detect BOM; otherwise ANSI)
            lText := TFile.ReadAllText(lFn);
          except
            on E: Exception do
              lText := '<<FAILED TO READ FILE: ' + E.ClassName + ': ' + E.Message + '>>';
          end;

          if Length(lText) > CMaxFileChars then
            lText := Copy(lText, 1, CMaxFileChars) + sLineBreak + '<<TRUNCATED>>';

          lMd.Append('```').Append(FenceLang(lFn)).AppendLine;
          lMd.AppendLine(lText);
          lMd.AppendLine('```');
          lMd.AppendLine;

          Inc(lTotal, lMd.Length);
          if lTotal > CMaxTotalChars then
          begin
            lMd.AppendLine('<<TOTAL OUTPUT TRUNCATED (too many files / too much text)>>');
            Break;
          end;
        end;
      end;

      lLi := fList.GetNextItem(lLi, sdAll, [isSelected]);
    end;

    Clipboard.AsText := lMd.ToString;
    MessageBeep(MB_OK);
  finally
    lMd.Free;
  end;
end;

procedure TMaxLogicPickerForm.BuildUi(const aTitle: string);
begin
  Caption := aTitle;
  Position := poScreenCenter;
  BorderStyle := bsSizeToolWin;

  // Hint
  fHint := TStaticText.Create(Self);
  fHint.Parent := Self;
  fHint.Align := alTop;
  fHint.AutoSize := False;
  fHint.Height := ScaleValue(22);
  if fIsProjects then
    fHint.Caption := SFilterHintProject
  else
    fHint.Caption := SFilterHint;
  fHint.TabStop := False;
  fHint.AlignWithMargins := True;
  fHint.Margins.SetBounds(ScaleValue(10), ScaleValue(10), ScaleValue(10), ScaleValue(6));

  // Filter edit
  fEdit := TEdit.Create(Self);
  fEdit.Parent := Self;
  fEdit.Align := alTop;
  fEdit.TabOrder := 0;
  fEdit.OnChange := EditChange;
  fEdit.OnEnter := EditEnter;
  fEdit.OnKeyDown := EditKeyDown;
  fEdit.AlignWithMargins := True;
  fEdit.Margins.SetBounds(ScaleValue(10), ScaleValue(0), ScaleValue(10), ScaleValue(6));

  // List
  fList := TListView.Create(Self);
  fList.Parent := Self;
  // Unit picker: allow multi-select for Ctrl+C copy
  fList.MultiSelect := not fIsProjects;
  fList.Align := alClient;
  fList.ViewStyle := vsReport;
  fList.ReadOnly := True;
  fList.RowSelect := True;
  fList.HideSelection := False;
  fList.TabOrder := 1;
  fList.OnEnter := ListEnter;
  fList.OnDblClick := ListDblClick;
  fList.OnKeyDown := ListKeyDown;
  fList.AlignWithMargins := True;
  fList.Margins.SetBounds(ScaleValue(10), ScaleValue(0), ScaleValue(10), ScaleValue(10));

  fList.Columns.Add.Caption := 'Name';
  fList.Columns.Add.Caption := 'Path';

  // Bottom bar
  fBottom := TPanel.Create(Self);
  fBottom.Parent := Self;
  fBottom.Align := alBottom;
  fBottom.BevelOuter := bvNone;
  fBottom.AlignWithMargins := True;
  fBottom.Margins.SetBounds(ScaleValue(10), ScaleValue(0), ScaleValue(10), ScaleValue(10));

  if fIsProjects then
  begin
    // Project picker: two option groups (Sorting + Show)
    fBottom.Height := ScaleValue(56);

    CreateSortProjectsGroupGui;
    CreateShowProjectsGroupGui;
  end else begin
    // Unit picker: Scope group
    fBottom.Height := ScaleValue(50);

    fScopeBox := TGroupBox.Create(Self);
    fScopeBox.Parent := fBottom;
    fScopeBox.Align := alClient;
    fScopeBox.Caption := '&Scope';
    fScopeBox.TabStop := False;

    fScopeFlow := TFlowPanel.Create(Self);
    fScopeFlow.Parent := fScopeBox;
    fScopeFlow.Align := alClient;
    fScopeFlow.BevelOuter := bvNone;
    fScopeFlow.AutoWrap := False;
    fScopeFlow.TabStop := False;
    fScopeFlow.AlignWithMargins := True;
    fScopeFlow.Margins.SetBounds(ScaleValue(8), ScaleValue(6), ScaleValue(8), ScaleValue(6));

    fRbOpen := TRadioButton.Create(Self);
    fRbOpen.Parent := fScopeFlow;
    fRbOpen.Caption := '&Open editors';
    fRbOpen.OnClick := ScopeClick;

    fRbProject := TRadioButton.Create(Self);
    fRbProject.Parent := fScopeFlow;
    fRbProject.Caption := 'Current &project';
    fRbProject.OnClick := ScopeClick;

    fRbGroup := TRadioButton.Create(Self);
    fRbGroup.Parent := fScopeFlow;
    fRbGroup.Caption := 'Project &group';
    fRbGroup.OnClick := ScopeClick;

    fCbSearchPath := TCheckBox.Create(Self);
    fCbSearchPath.Parent := fScopeFlow;
    fCbSearchPath.Caption := 'Also scan &unit search paths';
    fCbSearchPath.OnClick := ScopeClick;
  end;
end;

procedure TMaxLogicPickerForm.FormShow(Sender: TObject);
begin
  SafeFocus(fEdit);

  UpdateScopeLayout;
  AdjustColumns;
end;

procedure TMaxLogicPickerForm.FormResize(Sender: TObject);
begin
  AdjustColumns;
  UpdateScopeLayout;
end;

procedure TMaxLogicPickerForm.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  TMdcSettings.SaveWindowBounds(fWinKey, Self);

  if not fIsProjects then
  begin
    SaveUnitPickerPrefs;
  end;
end;

procedure TMaxLogicPickerForm.EditEnter(Sender: TObject);
begin
  fLastMainFocus := fEdit;
end;

procedure TMaxLogicPickerForm.ListEnter(Sender: TObject);
begin
  fLastMainFocus := fList;
end;

procedure TMaxLogicPickerForm.RestoreMainFocus;
begin
  if fLastMainFocus <> nil then
  begin
    SafeFocus(fLastMainFocus);
    Exit;
  end;

  SafeFocus(fEdit);
end;



procedure TMaxLogicPickerForm.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);

  if (ssAlt in Shift) and (Key = Ord('F')) then
  begin
    SafeFocus(fEdit);
    Key := 0;
    Exit;
  end;

  if (ssAlt in Shift) and (Key = Ord('L')) then
  begin
    SafeFocus(fList);
    Key := 0;
    Exit;
  end;
end;

procedure TMaxLogicPickerForm.EditChange(Sender: TObject);
begin
  ApplyFilter;
end;

procedure TMaxLogicPickerForm.EditKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_DOWN then
  begin
    SafeFocus(fList);
    Key := 0;
  end else if Key = VK_ESCAPE then
  begin
    ModalResult := mrCancel;
    Key := 0;
  end else if key = VK_RETURN then
  begin
    ModalResult := mrOk;
    Key := 0;
  end;
end;

procedure TMaxLogicPickerForm.ListDblClick(Sender: TObject);
begin
  ModalResult := mrOk;
end;


procedure TMaxLogicPickerForm.ListKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_RETURN then
  begin
    ModalResult := mrOk;
    Key := 0;
    Exit;
  end;

  if Key = VK_ESCAPE then
  begin
    ModalResult := mrCancel;
    Key := 0;
    Exit;
  end;

  // Unit picker: Ctrl+C copies selected files as Markdown
  if (not fIsProjects) and fList.Focused then
  begin
    if (Key = Ord('C')) and (ssCtrl in Shift) then
    begin
      CopySelectedUnitsAsMarkdownToClipboard;
      Key := 0;
      Exit;
    end;
  end;

  // Project picker keys
  if fIsProjects and fList.Focused then
  begin
    if (Key = Ord('F')) and (ssCtrl in Shift) then
    begin
      ToggleFavoriteSelected;
      ApplyFilter;
      Key := 0;
      Exit;
    end;

    if Key = VK_DELETE then
    begin
      ForgetSelected;
      LoadItems;     // refresh from registry
      ApplyFilter;
      Key := 0;
      Exit;
    end;
  end;
end;



procedure TMaxLogicPickerForm.FilterOutNonFiles;
var
  lOut: TList<TMaxLogicPickItem>;
  gOut: IGarbo;
  lItem: TMaxLogicPickItem;
  lFn: string;
  lExt: string;

  function IsRealEditorFile(const aFileName: string): Boolean;
  begin
    lFn := aFileName.Trim;
    if lFn = '' then
      Exit(False);

    // This kills "rtl", "vcl", "designide", etc.
    if not TPath.IsPathRooted(lFn) then
      Exit(False);

    lExt := LowerCase(TPath.GetExtension(lFn));
    if lExt = '' then
      Exit(False);

    Result := FileExists(lFn);
  end;

begin
  if Length(fItems) = 0 then
    Exit;

  GC(lOut, TList<TMaxLogicPickItem>.Create, gOut);

  for lItem in fItems do
  begin
    if IsRealEditorFile(lItem.FileName) then
      lOut.Add(lItem);
  end;

  fItems := lOut.ToArray;
end;

procedure TMaxLogicPickerForm.ToggleFavoriteSelected;
var
  lIdx: Integer;
begin
  lIdx := SelectedItemIdx;
  if lIdx < 0 then
    Exit;

  TMaxLogicProjectsProvider.ToggleFavorite(fItems[lIdx].FileName);
end;

function TMaxLogicPickerForm.SelectedItemIdx: Integer;
begin
  if fList.Selected = nil then
    Exit(-1);

  Result := NativeInt(fList.Selected.Data);
  if (Result < 0) or (Result > High(fItems)) then
    Result := -1;
end;

procedure TMaxLogicPickerForm.AdjustColumns;
var
  lClientW: Integer;
  lNameW: Integer;
  lPathW: Integer;
begin
  if (fList = nil) or (fList.Columns.Count < 2) then
    Exit;

  if not fList.HandleAllocated then
    Exit;

  lClientW := fList.ClientWidth;
  if lClientW <= 0 then
    Exit;

  lNameW := Max(ScaleValue(420), (lClientW * 45) div 100);
  lPathW := Max(ScaleValue(200), lClientW - lNameW - ScaleValue(8));

  SendMessage(fList.Handle, LVM_SETCOLUMNWIDTH, 0, lNameW);
  SendMessage(fList.Handle, LVM_SETCOLUMNWIDTH, 1, lPathW);
end;

procedure TMaxLogicPickerForm.UpdateScopeUi;
begin
  if fIsProjects then
    Exit;

  case fUnitScope of
    usOpenEditors:
      fRbOpen.Checked := True;
    usCurrentProject:
      fRbProject.Checked := True;
    usProjectGroup:
      fRbGroup.Checked := True;
  end;

  fCbSearchPath.Checked := fIncludeSearchPaths;

  // checkbox only makes sense when we build from project/group
  fCbSearchPath.Visible := (fUnitScope <> usOpenEditors);
end;

type
  TOpenFlowPanel = class(TFlowPanel)
    // a small hack to be able to access protected members of a TFlowPanel
  end;

procedure TMaxLogicPickerForm.UpdateScopeLayout;
var
  lCanvas: TCanvas;
  lPadRadio: Integer;
  lPadCheck: Integer;

  function CalcW(const aCaption: string; aPad: Integer): Integer;
  begin
    Result := lCanvas.TextWidth(StripAccel(aCaption)) + aPad;
  end;

begin
  if fIsProjects then
    Exit;

  if (fScopeFlow = nil) then
    Exit;

  // ensure we have a valid canvas font
  fScopeFlow.HandleNeeded;
  lCanvas := TOpenFlowPanel(fScopeFlow).Canvas;

  // decent approximations for glyph + spacing
  lPadRadio := ScaleValue(28);
  lPadCheck := ScaleValue(34);

  fRbOpen.Width := CalcW(fRbOpen.Caption, lPadRadio);
  fRbProject.Width := CalcW(fRbProject.Caption, lPadRadio);
  fRbGroup.Width := CalcW(fRbGroup.Caption, lPadRadio);

  if fCbSearchPath.Visible then
    fCbSearchPath.Width := CalcW(fCbSearchPath.Caption, lPadCheck);
end;

procedure TMaxLogicPickerForm.ScopeClick(Sender: TObject);
begin
  if fIsProjects then
    Exit;

  if fRbOpen.Checked then
    fUnitScope := usOpenEditors
  else if fRbProject.Checked then
    fUnitScope := usCurrentProject
  else
    fUnitScope := usProjectGroup;

  fIncludeSearchPaths := fCbSearchPath.Checked;

  UpdateScopeUi;
  UpdateScopeLayout;

  LoadItems;
  ApplyFilter;

  RestoreMainFocus;
end;

procedure TMaxLogicPickerForm.SortItemsAlphabetically(var aItems: TArray<TMaxLogicPickItem>);
begin
  TArray.Sort<TMaxLogicPickItem>(aItems,
    TComparer<TMaxLogicPickItem>.Construct(
      function(const L, R: TMaxLogicPickItem): Integer
      var
        a, b: string;
      begin
        a := L.Display;
        b := R.Display;

        Result := CompareText(a, b);
        if Result <> 0 then
          Exit;

        // stable-ish tie-breaker
        Result := CompareText(L.FileName, R.FileName);
      end
    )
  );
end;



procedure TMaxLogicPickerForm.LoadItems;
begin
  if fIsProjects then
  begin
    fItems := TMaxLogicProjectsProvider.GetItems;
    ApplyProjectsOptions(fItems);
    Exit;
  end;

  fItems := BuildUnitItems(fUnitScope, fIncludeSearchPaths);
  FilterOutNonFiles;

  // Always sort alphabetically for unit picker
  SortItemsAlphabetically(fItems);
end;

procedure TMaxLogicPickerForm.ApplyFilter;
var
  lFilter: TFilterEx; // this is a record
  li: TListItem;
  i: Integer;
  lItem: TMaxLogicPickItem;
  s: string;
begin
  fList.Items.BeginUpdate;
  try
    fList.Items.Clear;

    lFilter := TFilterEx.Create(fEdit.Text); // this is a record, no free required

    for i := 0 to High(fItems) do
    begin
      lItem := fItems[i];
      s := lItem.Display + ' ' + lItem.Detail + ' ' + lItem.FileName;

      if lFilter.Matches(s) then
      begin
        li := fList.Items.Add;

        if lItem.IsFavorite then
          li.Caption := lItem.Display + ' ★'
        else
          li.Caption := lItem.Display;

        li.SubItems.Add(lItem.Detail);
        li.Data := Pointer(NativeInt(i));
      end;
    end;

    if fList.Items.Count > 0 then
      fList.Items[0].Selected := True;
  finally
    fList.Items.EndUpdate;
  end;

  AdjustColumns;
end;

function TMaxLogicPickerForm.PickFileName(out aFileName: string): Boolean;
var
  lIdx: Integer;
begin
  aFileName := '';
  Result := (ShowModal = mrOk);
  if not Result then
    Exit(False);

  lIdx := SelectedItemIdx;
  if lIdx < 0 then
    Exit(False);

  aFileName := fItems[lIdx].FileName;
  Result := (aFileName.Trim <> '');
end;

procedure TMaxLogicPickerForm.LoadUnitPickerPrefs;
var
  lIni: TMemIniFile;
  gIni: IGarbo;
  lName: string;
  s: string;
begin
  fUnitScope := usOpenEditors;
  fIncludeSearchPaths := False;

  lName := TMdcSettings.GetConfigFileName;
  if not FileExists(lName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lName, TEncoding.UTF8), gIni);
  lIni.CaseSensitive := False;

  s := lIni.ReadString(CIniSectionPickerUnits, CIniKeyScope, ScopeToStr(usOpenEditors));
  fUnitScope := StrToScope(s);

  fIncludeSearchPaths := lIni.ReadBool(CIniSectionPickerUnits, CIniKeyIncSearchPaths, False);
end;

procedure TMaxLogicPickerForm.SaveUnitPickerPrefs;
var
  lIni: TMemIniFile;
  gIni: IGarbo;
  lName: string;
  lDir: string;
begin
  lName := TMdcSettings.GetConfigFileName;

  lDir := ExtractFilePath(lName);
  if lDir <> '' then
  begin
    ForceDirectories(lDir);
  end;

  GC(lIni, TMemIniFile.Create(lName, TEncoding.UTF8), gIni);
  lIni.CaseSensitive := False;

  lIni.WriteString(CIniSectionPickerUnits, CIniKeyScope, ScopeToStr(fUnitScope));
  lIni.WriteBool(CIniSectionPickerUnits, CIniKeyIncSearchPaths, fIncludeSearchPaths);
  lIni.UpdateFile;
end;

{ TMaxLogicProjectPicker }

class function TMaxLogicProjectPicker.TryPickAndOpen: Boolean;
var
  f: TMaxLogicPickerForm;
  g: IGarbo;
  fn: string;
begin
  Result := False;

  GC(f, TMaxLogicPickerForm.CreatePicker(nil, SProjectsTitle, True), g);

  if not f.PickFileName(fn) then
    Exit(False);

Result := TMdcIdeApi.OpenInIde(fn);
  if Result then
    TMaxLogicProjectsProvider.AddRecent(fn);
end;


class procedure TMaxLogicProjectPicker.ShowModalPickAndOpen;
begin
  TryPickAndOpen;
end;

{ TMaxLogicUnitPicker }

class function TMaxLogicUnitPicker.TryPickAndOpen: Boolean;
var
  f: TMaxLogicPickerForm;
  g: IGarbo;
  fn: string;
begin
  Result := False;

  GC(f, TMaxLogicPickerForm.CreatePicker(nil, SUnitsTitle, False), g);

  if not f.PickFileName(fn) then
    Exit(False);

  Result := TMdcIdeApi.OpenInIde(fn);
end;

class procedure TMaxLogicUnitPicker.ShowModalPickAndOpen;
begin
  TryPickAndOpen;
end;


procedure TMaxLogicPickerForm.ProjectsOptionsClick(Sender: TObject);
begin
  if not fIsProjects then
    Exit;

  // Next step: apply show/sort options to fItems
  // For now: just re-run filter to reflect caption/hide logic once you add it.
  LoadItems;
  ApplyFilter;

  RestoreMainFocus;
end;


procedure TMaxLogicPickerForm.CreateSortProjectsGroupGui;
begin
  fSortBox := TGroupBox.Create(Self);
  fSortBox.Parent := fBottom;
  fSortBox.Align := alLeft;
  fSortBox.alignWithMargins := True;
  fSortBox.Width := ScaleValue(420);
  fSortBox.Caption := '&Sorting';
  fSortBox.TabStop := False;

  fSortFlow := TFlowPanel.Create(Self);
  fSortFlow.Parent := fSortBox;
  fSortFlow.Align := alClient;
  fSortFlow.BevelOuter := bvNone;
  fSortFlow.AutoWrap := False;
  fSortFlow.TabStop := False;
  fSortFlow.AlignWithMargins := True;
  fSortFlow.Margins.SetBounds(ScaleValue(8), ScaleValue(6), ScaleValue(8), ScaleValue(6));

  fRbSortAlpha := TRadioButton.Create(Self);
  fRbSortAlpha.Parent := fSortFlow;
  fRbSortAlpha.Caption := '&Alphanumeric'; // Alt+A

  fRbSortLast := TRadioButton.Create(Self);
  fRbSortLast.Parent := fSortFlow;
  fRbSortLast.Caption := 'Last &opened'; // Alt+O (avoid Alt+L conflict with your "focus list")

  fCbFavoriteFirst := TCheckBox.Create(Self);
  fCbFavoriteFirst.Parent := fSortFlow;
  fCbFavoriteFirst.Caption := 'Favorite f&irst'; // Alt+I (avoid Alt+F conflict with your "focus filter")

  // ---- defaults FIRST (can trigger click in VCL if handlers are already wired)
  fRbSortLast.Checked := True;
  fCbFavoriteFirst.Checked := True;

  // ---- wire handlers LAST
  fRbSortAlpha.OnClick := ProjectsOptionsClick;
  fRbSortLast.OnClick := ProjectsOptionsClick;
  fCbFavoriteFirst.OnClick := ProjectsOptionsClick;
end;

procedure TMaxLogicPickerForm.CreateShowProjectsGroupGui;
begin
  fShowBox := TGroupBox.Create(Self);
  fShowBox.Parent := fBottom;
  fShowBox.Align := alClient;
  fShowBox.AlignWithMargins := True;
  fShowBox.Caption := '&Show';
  fShowBox.TabStop := False;

  fShowFlow := TFlowPanel.Create(Self);
  fShowFlow.Parent := fShowBox;
  fShowFlow.Align := alClient;
  fShowFlow.BevelOuter := bvNone;
  fShowFlow.AutoWrap := False;
  fShowFlow.TabStop := False;
  fShowFlow.AlignWithMargins := True;
  fShowFlow.Margins.SetBounds(ScaleValue(8), ScaleValue(6), ScaleValue(8), ScaleValue(6));

  fCbShowProjects := TCheckBox.Create(Self);
  fCbShowProjects.Parent := fShowFlow;
  fCbShowProjects.Caption := '&Projects'; // Alt+P

  fCbShowProjectGroups := TCheckBox.Create(Self);
  fCbShowProjectGroups.Parent := fShowFlow;
  fCbShowProjectGroups.Caption := 'Project &groups'; // Alt+G

  fCbShowFavorites := TCheckBox.Create(Self);
  fCbShowFavorites.Parent := fShowFlow;
  fCbShowFavorites.Caption := 'Fa&vorite'; // Alt+V (avoid Alt+F conflict)

  fCbShowNonFavorites := TCheckBox.Create(Self);
  fCbShowNonFavorites.Parent := fShowFlow;
  fCbShowNonFavorites.Caption := 'Non-favo&rite'; // Alt+R (avoid Alt+F/Alt+V conflicts)

  // ---- defaults FIRST
  fCbShowProjects.Checked := True;
  fCbShowProjectGroups.Checked := True;
  fCbShowFavorites.Checked := True;
  fCbShowNonFavorites.Checked := True;

  // ---- wire handlers LAST
  fCbShowProjects.OnClick := ProjectsOptionsClick;
  fCbShowProjectGroups.OnClick := ProjectsOptionsClick;
  fCbShowFavorites.OnClick := ProjectsOptionsClick;
  fCbShowNonFavorites.OnClick := ProjectsOptionsClick;
end;


procedure TMaxLogicPickerForm.ForgetSelected;
var
  lIdx: Integer;
begin
  lIdx := SelectedItemIdx;
  if lIdx < 0 then
    Exit;

  TMaxLogicProjectsProvider.ForgetProject(fItems[lIdx].FileName);
end;


end.

