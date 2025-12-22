unit maxLogic.DelphiCompanion.IdeUiInspector;

interface

uses
  vcl.Controls;

function FindFirstByClassHint(const aRoot: TWinControl; const aNeedles: array of string): TWinControl;
function FindWinControlByName(aParent: TWinControl; const AName: string): TWinControl;
function FindFirstVirtualTreeLike(aParent: TWinControl): TWinControl;
function TryInvokeContentToText(const aObj: TObject; out aText: string): boolean;

implementation

uses
  System.Math, System.IOUtils, System.Rtti, System.SyncObjs, System.SysUtils, System.TypInfo, System.StrUtils,
  maxLogic.DelphiCompanion.Settings,

  maxLogic.DelphiCompanion.Logger;

function FindFirstByClassHint(const aRoot: TWinControl; const aNeedles: array of string): TWinControl;
var
  lI, lJ: integer;
  lc: TControl;
  lW: TWinControl;
  lCn: string;
begin
  Result := nil;
  if aRoot = nil then exit;

  for lI := 0 to aRoot.ControlCount - 1 do
  begin
    lc := aRoot.Controls[lI];
    if not (lc is TWinControl) then Continue;

    lW := TWinControl(lc);
    lCn := lW.classname;

    for lJ := Low(aNeedles) to High(aNeedles) do
      if ContainsText(lCn, aNeedles[lJ]) then
        exit(lW);

    Result := FindFirstByClassHint(lW, aNeedles);
    if Result <> nil then exit;
  end;
end;

function FindWinControlByName(aParent: TWinControl; const AName: string): TWinControl;
var
  i: integer;
  c: TControl;
  w: TWinControl;
begin
  Result := nil;
  if aParent = nil then
    exit;

  for i := 0 to aParent.ControlCount - 1 do
  begin
    c := aParent.Controls[i];
    if c is TWinControl then
    begin
      w := TWinControl(c);

      if SameText(w.Name, AName) then
        exit(w);

      Result := FindWinControlByName(w, AName);
      if Result <> nil then
        exit;
    end;
  end;
end;

function FindFirstVirtualTreeLike(aParent: TWinControl): TWinControl;
var
  i: integer;
  c: TControl;
  w: TWinControl;
  cn: string;
begin
  Result := nil;
  if aParent = nil then
    exit;

  for i := 0 to aParent.ControlCount - 1 do
  begin
    c := aParent.Controls[i];
    if c is TWinControl then
    begin
      w := TWinControl(c);
      cn := w.classname;

      // Your inspector showed: MessageTreeView0: TBetterHintWindowVirtualDrawTree
      if ContainsText(cn, 'Virtual') and ContainsText(cn, 'Tree') then
        exit(w);

      Result := FindFirstVirtualTreeLike(w);
      if Result <> nil then
        exit;
    end;
  end;
end;

function TryInvokeContentToText(const aObj: TObject; out aText: string): boolean;
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMethod: TRttiMethod;

  function TryCall(const aArgs: array of TValue; out aOut: string): boolean;
  var
    lRes: TValue;
  begin
    Result := False;

    try
      lRes := lMethod.Invoke(aObj, aArgs);
      if lRes.kind in [tkUString, tkLString, tkWString, tkString] then
      begin
        aOut := lRes.AsString;
        Result := aOut <> '';
      end else begin
        aOut := lRes.ToString;
        Result := aOut <> '';
      end;
    except
      on e: Exception do
        MdcLog(Format('TryInvokeContentToText: invoke failed: %s: %s', [e.classname, e.Message]));
    end;
  end;

begin
  aText := '';
  Result := False;

  if aObj = nil then
    exit;

  lCtx := TRttiContext.Create;
  try
    lType := lCtx.GetType(aObj.ClassType);
    if lType = nil then
      exit;

    lMethod := nil;
    for var m in lType.GetMethods do
    begin
      if SameText(m.Name, 'ContentToText') then
      begin
        lMethod := m;
        break;
      end;
    end;

    if lMethod = nil then
      exit;

    // try no-arg
    if length(lMethod.GetParameters) = 0 then
    begin
      Result := TryCall([], aText);
      exit;
    end;

    // try one boolean arg (False/True)
    if (length(lMethod.GetParameters) = 1) and (lMethod.GetParameters[0].ParamType <> nil) and
      SameText(lMethod.GetParameters[0].ParamType.ToString, 'Boolean') then
    begin
      if TryCall([False], aText) then
      begin
        Result := True;
        exit;
      end;

      if TryCall([True], aText) then
      begin
        Result := True;
        exit;
      end;

      exit;
    end;

    // unknown signature
    MdcLog(Format('TryInvokeContentToText: ContentToText has unsupported signature on %s', [aObj.classname]));
  finally
    lCtx.Free;
  end;
end;

end.

