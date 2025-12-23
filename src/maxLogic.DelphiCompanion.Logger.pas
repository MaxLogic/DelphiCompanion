unit maxLogic.DelphiCompanion.Logger;

interface

uses
  vcl.Controls;


type
  TMdcRttiDumpOptions = record
    MaxProps: Integer;
    MaxMethods: Integer;
    OnlyInteresting: Boolean;
  end;


var
  GMdcLoggingEnabled: Boolean = True;


procedure MdcLog(const aMsg: string);
procedure DumpControlTree(const aRoot: TWinControl; const aIndent: string = '');
procedure MdcDumpClassHierarchy(const aObj: TObject; const aTitle: string);
procedure MdcDumpControlParentChain(const aCtrl: TControl; const aTitle: string);
procedure MdcDumpPublishedProperties(const aObj: TObject; const aTitle: string; const aMaxCount: integer = 300);
procedure MdcDumpRttiMethods(const aObj: TObject; const aTitle: string; const aMaxCount: integer = 300);
procedure MdcDumpObjectDiagnostics(const aObj: TObject; const aTitle: string);
procedure MdcDumpRttiMembers(const aObj: TObject; const aTitle: string; const aOpts: TMdcRttiDumpOptions);

implementation

uses
  System.Math, System.IOUtils, System.Rtti, System.SyncObjs, System.SysUtils, System.TypInfo, System.StrUtils,
  MaxLogic.ioUtils,
  maxLogic.DelphiCompanion.Settings;

var
  GMdcLogFile : String;

procedure MdcLog(const aMsg: string);
begin
  if not GMdcLoggingEnabled then
    Exit;

  try
    ForceDirectories('F:\tmp');
    TFile.AppendAllText(
      GMdcLogFile,
      FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', now) + ' [Problems] ' + aMsg + sLineBreak,
      TEncoding.UTF8);
  except
    // never crash the IDE because of logging
  end;
end;

procedure DumpControlTree(const aRoot: TWinControl; const aIndent: string = '');
var
  lI: integer;
  lc: TControl;
  lW: TWinControl;
  lName: string;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aRoot = nil then exit;

  lName := aRoot.Name;
  if lName = '' then lName := '(no name)';

  MdcLog(Format('%s%s  Name=%s  Visible=%s  CanFocus=%s  Handle=%s',
    [aIndent, aRoot.classname, lName,
      BoolToStr(aRoot.Visible, True),
      BoolToStr(aRoot.CanFocus, True),
      BoolToStr(aRoot.HandleAllocated, True)]));

  for lI := 0 to aRoot.ControlCount - 1 do
  begin
    lc := aRoot.Controls[lI];
    if lc = nil then Continue;

    if lc is TWinControl then
    begin
      lW := TWinControl(lc);
      DumpControlTree(lW, aIndent + '  ');
    end else begin
      lName := lc.Name;
      if lName = '' then lName := '(no name)';
      MdcLog(Format('%s  %s  Name=%s  Visible=%s',
        [aIndent, lc.classname, lName, BoolToStr(lc.Visible, True)]));
    end;
  end;
end;

procedure MdcDumpClassHierarchy(const aObj: TObject; const aTitle: string);
var
  lCls: TClass;
  lDepth: integer;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aObj = nil then
  begin
    MdcLog(Format('%s: <nil>', [aTitle]));
    exit;
  end;

  MdcLog(Format('%s: Class=%s', [aTitle, aObj.classname]));

  lCls := aObj.ClassType;
  lDepth := 0;

  while lCls <> nil do
  begin
    MdcLog(Format('%s:  [%d] %s', [aTitle, lDepth, lCls.classname]));
    lCls := lCls.ClassParent;
    Inc(lDepth);
  end;
end;

procedure MdcDumpControlParentChain(const aCtrl: TControl; const aTitle: string);
var
  lCtrl: TControl;
  lDepth: integer;
  lName: string;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aCtrl = nil then
  begin
    MdcLog(Format('%s: <nil control>', [aTitle]));
    exit;
  end;

  lCtrl := aCtrl;
  lDepth := 0;

  while lCtrl <> nil do
  begin
    lName := lCtrl.Name;
    if lName = '' then
      lName := '<no name>';

    var lParentInfo: string;
    if lCtrl.Parent <> nil then
      lParentInfo := lCtrl.Parent.classname
    else
      lParentInfo := '<nil>';
    MdcLog(Format(
      '%s:  [%d] %s Name=%s Parent=%s',
      [aTitle, lDepth, lCtrl.classname, lName,
        lParentInfo]
      ));

    lCtrl := lCtrl.Parent;
    Inc(lDepth);
  end;
end;

procedure MdcDumpPublishedProperties(const aObj: TObject; const aTitle: string; const aMaxCount: integer = 300);
var
  lCount, i: integer;
  lPropList: PPropList;
  lPropInfo: PPropInfo;
  lKind: TTypeKind;
  lTypeName: string;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aObj = nil then
    exit;

  if aObj.ClassInfo = nil then
  begin
    MdcLog(Format('%s: no ClassInfo (no published props?)', [aTitle]));
    exit;
  end;

  lCount := GetPropList(aObj.ClassInfo, tkAny, nil);
  MdcLog(Format('%s: Published props=%d', [aTitle, lCount]));

  if lCount <= 0 then
    exit;

  GetMem(lPropList, lCount * SizeOf(PPropInfo));
  try
    GetPropList(aObj.ClassInfo, tkAny, lPropList);

    for i := 0 to MIN(lCount, aMaxCount) - 1 do
    begin
      lPropInfo := lPropList^[i];
      if lPropInfo = nil then
        Continue;

      lKind := lPropInfo^.PropType^.kind;
      lTypeName := string(lPropInfo^.PropType^.Name);

      MdcLog(Format('%s:  Prop %s: %s (%s)',
        [aTitle, string(lPropInfo^.Name), lTypeName, GetEnumName(TypeInfo(TTypeKind), Ord(lKind))]
        ));
    end;

    if lCount > aMaxCount then
      MdcLog(Format('%s:  ... (%d more props omitted)', [aTitle, lCount - aMaxCount]));
  finally
    FreeMem(lPropList);
  end;
end;

procedure MdcDumpRttiMethods(const aObj: TObject; const aTitle: string; const aMaxCount: integer = 300);
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMethods: TArray<TRttiMethod>;
  lMethod: TRttiMethod;
  i: integer;
  lSig: string;
  lRet: string;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aObj = nil then
    exit;

  lCtx := TRttiContext.Create;
  try
    lType := lCtx.GetType(aObj.ClassType);
    if lType = nil then
    begin
      MdcLog(Format('%s: RTTI type not available', [aTitle]));
      exit;
    end;

    lMethods := lType.GetMethods;
    MdcLog(Format('%s: RTTI methods=%d', [aTitle, length(lMethods)]));

    i := 0;
    for lMethod in lMethods do
    begin
      if i >= aMaxCount then
        break;

      if lMethod.ReturnType <> nil then
        lRet := lMethod.ReturnType.ToString
      else
        lRet := 'procedure';

      lSig := lMethod.ToString; // includes params (best-effort)

      MdcLog(Format('%s:  %s -> %s', [aTitle, lSig, lRet]));
      Inc(i);
    end;

    if length(lMethods) > aMaxCount then
      MdcLog(Format('%s:  ... (%d more methods omitted)', [aTitle, length(lMethods) - aMaxCount]));
  finally
    lCtx.Free;
  end;
end;

procedure MdcDumpObjectDiagnostics(const aObj: TObject; const aTitle: string);
begin
  if not GMdcLoggingEnabled then
    Exit;

  MdcLog(Format('%s: ===== DIAGNOSTICS START =====', [aTitle]));
  MdcDumpClassHierarchy(aObj, aTitle);

  if aObj is TControl then
    MdcDumpControlParentChain(TControl(aObj), aTitle);

  MdcDumpPublishedProperties(aObj, aTitle);
  MdcDumpRttiMethods(aObj, aTitle);
  MdcLog(Format('%s: ===== DIAGNOSTICS END =====', [aTitle]));
end;

function MdcIsInterestingMemberName(const aName: string): Boolean;
begin
  Result :=
    ContainsText(aName, 'Text') or
    ContainsText(aName, 'Node') or
    ContainsText(aName, 'Column') or
    ContainsText(aName, 'Content') or
    ContainsText(aName, 'Hint') or
    ContainsText(aName, 'Get');
end;

procedure MdcDumpRttiMembers(const aObj: TObject; const aTitle: string; const aOpts: TMdcRttiDumpOptions);
var
  lCtx: TRttiContext;
  lCls: TClass;
  lType: TRttiType;
  lProp: TRttiProperty;
  lMeth: TRttiMethod;
  lPropCount: Integer;
  lMethCount: Integer;
  lTotalProps: Integer;
  lTotalMeths: Integer;
begin
  if not GMdcLoggingEnabled then
    Exit;

  if aObj = nil then
    Exit;

  MdcLog(aTitle + ': RTTI dump begin');

  lCtx := TRttiContext.Create;
  try
    lTotalProps := 0;
    lTotalMeths := 0;

    lCls := aObj.ClassType;
    while lCls <> nil do
    begin
      lType := lCtx.GetType(lCls);
      if lType = nil then
      begin
        lCls := lCls.ClassParent;
        Continue;
      end;

      var lTypeName: string;
      lTypeName := lType.Name;
      try
        lTypeName := lType.QualifiedName;
      except
        on E: Exception do
          MdcLog(Format('%s: RTTI type qualified name failed: %s: %s', [aTitle, E.ClassName, E.Message]));
      end;

      MdcLog(Format('%s: RTTI type=%s', [aTitle, lTypeName]));

      lPropCount := 0;
      for lProp in lType.GetProperties do
      begin
        if aOpts.OnlyInteresting and (not MdcIsInterestingMemberName(lProp.Name)) then
          Continue;

        Inc(lPropCount);
        Inc(lTotalProps);

        if (aOpts.MaxProps > 0) and (lPropCount > aOpts.MaxProps) then
        begin
          MdcLog(Format('%s: (props truncated for %s)', [aTitle, lType.Name]));
          Break;
        end;

        MdcLog(Format('%s:  prop %s: %s  readable=%s writable=%s',
          [aTitle, lProp.Name, lProp.PropertyType.Name,
           BoolToStr(lProp.IsReadable, True),
           BoolToStr(lProp.IsWritable, True)]));
      end;

      lMethCount := 0;
      for lMeth in lType.GetMethods do
      begin
        if aOpts.OnlyInteresting and (not MdcIsInterestingMemberName(lMeth.Name)) then
          Continue;

        Inc(lMethCount);
        Inc(lTotalMeths);

        if (aOpts.MaxMethods > 0) and (lMethCount > aOpts.MaxMethods) then
        begin
          MdcLog(Format('%s: (methods truncated for %s)', [aTitle, lType.Name]));
          Break;
        end;

        MdcLog(Format('%s:  meth %s  kind=%s  params=%d',
          [aTitle, lMeth.Name, GetEnumName(TypeInfo(TMethodKind), Ord(lMeth.MethodKind)),
           Length(lMeth.GetParameters)]));
      end;

      lCls := lCls.ClassParent;
    end;

    MdcLog(Format('%s: RTTI dump end (props=%d, methods=%d)', [aTitle, lTotalProps, lTotalMeths]));
  finally
    lCtx.Free;
  end;
end;

initialization
  TMdcSettings.LoadLoggingEnabled(GMdcLoggingEnabled);
  GMdcLogFile := CombinePath([ GetEnvironmentVariable('AppData'),
    'MaxLogic', 'mdc.log']);

end.

