unit maxLogic.DelphiCompanion.IdeUiInspector;

interface

uses
  Vcl.Controls, Vcl.ComCtrls;

function FindFirstByClassHint(const aRoot: TWinControl; const aNeedles: array of string): TWinControl;
function FindWinControlByName(aParent: TWinControl; const aName: string): TWinControl;
function FindFirstVirtualTreeLike(aParent: TWinControl): TWinControl;
function FindFirstByClassNameContains(aParent: TWinControl; const aNeedle: string): TWinControl;
function TryInvokeContentToText(const aObj: TObject; out aText: string): Boolean;
function TryInvokeNoArgStringMethod(const aObj: TObject; const aMethodName: string; out aText: string): Boolean;
function TryVirtualTreeToText(const aTree: TObject; out aText: string): Boolean;
function ActivateBuildTabIfPresent(aParent: TWinControl): Boolean;

implementation

uses
  System.Rtti, System.StrUtils, System.SysUtils, System.TypInfo, System.Types,
  Vcl.Graphics,
  maxLogic.DelphiCompanion.Logger;

function FindFirstByClassHint(const aRoot: TWinControl; const aNeedles: array of string): TWinControl;
var
  i, j: Integer;
  lControl: TControl;
  lWinControl: TWinControl;
  lClassName: string;
begin
  if aRoot = nil then
    Exit(nil);

  for i := 0 to aRoot.ControlCount - 1 do
  begin
    lControl := aRoot.Controls[i];
    if not (lControl is TWinControl) then
      Continue;

    lWinControl := TWinControl(lControl);
    lClassName := lWinControl.ClassName;

    for j := Low(aNeedles) to High(aNeedles) do
      if ContainsText(lClassName, aNeedles[j]) then
        Exit(lWinControl);

    Result := FindFirstByClassHint(lWinControl, aNeedles);
    if Result <> nil then
      Exit(Result);
  end;

  Result := nil;
end;

function FindWinControlByName(aParent: TWinControl; const aName: string): TWinControl;
var
  i: Integer;
  lControl: TControl;
  lWinControl: TWinControl;
begin
  if aParent = nil then
    Exit(nil);

  for i := 0 to aParent.ControlCount - 1 do
  begin
    lControl := aParent.Controls[i];
    if lControl is TWinControl then
    begin
      lWinControl := TWinControl(lControl);

      if SameText(lWinControl.Name, aName) then
        Exit(lWinControl);

      Result := FindWinControlByName(lWinControl, aName);
      if Result <> nil then
        Exit(Result);
    end;
  end;

  Result := nil;
end;

function FindFirstVirtualTreeLike(aParent: TWinControl): TWinControl;
var
  i: Integer;
  lControl: TControl;
  lWinControl: TWinControl;
  lClassName: string;
begin
  if aParent = nil then
    Exit(nil);

  for i := 0 to aParent.ControlCount - 1 do
  begin
    lControl := aParent.Controls[i];
    if lControl is TWinControl then
    begin
      lWinControl := TWinControl(lControl);
      lClassName := lWinControl.ClassName;

      // Your inspector showed: MessageTreeView0: TBetterHintWindowVirtualDrawTree
      if (ContainsText(lClassName, 'Virtual')) and (ContainsText(lClassName, 'Tree')) then
        Exit(lWinControl);

      Result := FindFirstVirtualTreeLike(lWinControl);
      if Result <> nil then
        Exit(Result);
    end;
  end;

  Result := nil;
end;

function FindFirstByClassNameContains(aParent: TWinControl; const aNeedle: string): TWinControl;
var
  i: Integer;
  lControl: TControl;
  lWinControl: TWinControl;
begin
  if aParent = nil then
    Exit(nil);

  for i := 0 to aParent.ControlCount - 1 do
  begin
    lControl := aParent.Controls[i];
    if lControl is TWinControl then
    begin
      lWinControl := TWinControl(lControl);

      if ContainsText(lWinControl.ClassName, aNeedle) then
        Exit(lWinControl);

      Result := FindFirstByClassNameContains(lWinControl, aNeedle);
      if Result <> nil then
        Exit(Result);
    end;
  end;

  Result := nil;
end;

function ActivateBuildTabIfPresent(aParent: TWinControl): Boolean;
  function FindPageControl(aParentControl: TWinControl): TPageControl;
  var
    i: Integer;
    lChild: TControl;
    lWin: TWinControl;
  begin
    if aParentControl = nil then
      Exit(nil);

    for i := 0 to aParentControl.ControlCount - 1 do
    begin
      lChild := aParentControl.Controls[i];

      if lChild is TPageControl then
        Exit(TPageControl(lChild));

      if lChild is TWinControl then
      begin
        lWin := TWinControl(lChild);
        Result := FindPageControl(lWin);
        if Result <> nil then
          Exit(Result);
      end;
    end;

    Result := nil;
  end;

  procedure ActivateBuildTab(aPageControl: TPageControl);
  var
    i: Integer;
  begin
    if aPageControl = nil then
      Exit;

    for i := 0 to aPageControl.PageCount - 1 do
    begin
      if ContainsText(aPageControl.Pages[i].Caption, 'Build') then
      begin
        aPageControl.ActivePage := aPageControl.Pages[i];
        Exit;
      end;
    end;
  end;

var
  lPageControl: TPageControl;
begin
  Result := False;
  lPageControl := FindPageControl(aParent);
  if lPageControl = nil then
    Exit(False);

  ActivateBuildTab(lPageControl);
  Result := True;
end;

function TryInvokeContentToText(const aObj: TObject; out aText: string): Boolean;
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMethod: TRttiMethod;

  function TryCall(const aArgs: array of TValue; out aOut: string): Boolean;
  var
    lRes: TValue;
  begin
    Result := False;

    try
      lRes := lMethod.Invoke(aObj, aArgs);
      if lRes.Kind in [tkUString, tkLString, tkWString, tkString] then
      begin
        aOut := lRes.AsString;
        Result := aOut <> '';
      end else begin
        aOut := lRes.ToString;
        Result := aOut <> '';
      end;
    except
      on E: Exception do
        if GMdcLoggingEnabled then
          MdcLog(Format('TryInvokeContentToText: invoke failed: %s: %s', [E.ClassName, E.Message]));
    end;
  end;

begin
  aText := '';
  Result := False;

  if aObj = nil then
    Exit;

  lCtx := TRttiContext.Create;
  try
    lType := lCtx.GetType(aObj.ClassType);
    if lType = nil then
      Exit;

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
      Exit;

    // try no-arg
    if Length(lMethod.GetParameters) = 0 then
    begin
      Result := TryCall([], aText);
      Exit;
    end;

    // try one boolean arg (False/True)
    if (Length(lMethod.GetParameters) = 1) and (lMethod.GetParameters[0].ParamType <> nil) and
      (SameText(lMethod.GetParameters[0].ParamType.ToString, 'Boolean')) then
    begin
      if TryCall([False], aText) then
      begin
        Result := True;
        Exit;
      end;

      if TryCall([True], aText) then
      begin
        Result := True;
        Exit;
      end;

      Exit;
    end;

    // unknown signature
    if GMdcLoggingEnabled then
      MdcLog(Format('TryInvokeContentToText: ContentToText has unsupported signature on %s', [aObj.ClassName]));
  finally
    lCtx.Free;
  end;
end;

function TryInvokeNoArgStringMethod(const aObj: TObject; const aMethodName: string; out aText: string): Boolean;
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMeth: TRttiMethod;
  lValue: TValue;
begin
  Result := False;
  aText := '';

  if aObj = nil then
    Exit;

  try
    lCtx := TRttiContext.Create;
    try
      lType := lCtx.GetType(aObj.ClassType);
      if lType = nil then
        Exit;

      lMeth := lType.GetMethod(aMethodName);
      if lMeth = nil then
        Exit;

      if Length(lMeth.GetParameters) <> 0 then
        Exit;

      lValue := lMeth.Invoke(aObj, []);
      aText := lValue.ToString;
      Result := aText <> '';
    finally
      lCtx.Free;
    end;
  except
    on E: Exception do
      if GMdcLoggingEnabled then
        MdcLog(Format('TryInvokeNoArgStringMethod(%s) failed: %s: %s', [aMethodName, E.ClassName, E.Message]));
  end;
end;

function TryInvokePtrMethod(const aObj: TObject; const aMethodName: string; const aArgs: array of TValue; out aPtr: Pointer): Boolean;
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMeth: TRttiMethod;
  lValue: TValue;
begin
  Result := False;
  aPtr := nil;

  if aObj = nil then
    Exit;

  try
    lCtx := TRttiContext.Create;
    try
      lType := lCtx.GetType(aObj.ClassType);
      if lType = nil then
        Exit;

      lMeth := lType.GetMethod(aMethodName);
      if lMeth = nil then
        Exit;

      lValue := lMeth.Invoke(aObj, aArgs);

      if lValue.Kind = tkPointer then
      begin
        try
          aPtr := lValue.AsType<Pointer>;
        except
          aPtr := nil;
        end;
        Result := True;
        Exit;
      end;

      if lValue.Kind in [tkInteger, tkInt64] then
      begin
        aPtr := Pointer(lValue.AsInt64);
        Result := True;
        Exit;
      end;
    finally
      lCtx.Free;
    end;
  except
    on E: Exception do
      if GMdcLoggingEnabled then
        MdcLog(Format('TryInvokePtrMethod(%s) failed: %s: %s', [aMethodName, E.ClassName, E.Message]));
  end;
end;

function TryInvokeStringMethod2(const aObj: TObject; const aMethodName: string; const aArgs: array of TValue; out aText: string): Boolean;
var
  lCtx: TRttiContext;
  lType: TRttiType;
  lMeth: TRttiMethod;
  lValue: TValue;
begin
  Result := False;
  aText := '';

  if aObj = nil then
    Exit;

  try
    lCtx := TRttiContext.Create;
    try
      lType := lCtx.GetType(aObj.ClassType);
      if lType = nil then
        Exit;

      lMeth := lType.GetMethod(aMethodName);
      if lMeth = nil then
        Exit;

      lValue := lMeth.Invoke(aObj, aArgs);
      aText := lValue.ToString;
      Result := aText <> '';
    finally
      lCtx.Free;
    end;
  except
    on E: Exception do
      if GMdcLoggingEnabled then
        MdcLog(Format('TryInvokeStringMethod2(%s) failed: %s: %s', [aMethodName, E.ClassName, E.Message]));
  end;
end;

function TryVirtualTreeToText(const aTree: TObject; out aText: string): Boolean;
var
  lNode: Pointer;
  lNext: Pointer;
  lLine: string;
  lBuilder: TStringBuilder;
  lCount: Integer;
  lCtx: TRttiContext;
  lTreeType: TRttiType;
  lZombieMethod: TRttiMethod;
  lZombieParams: TArray<TRttiParameter>;
  lTextMethod: TRttiMethod;
  lTextParams: TArray<TRttiParameter>;
  lTextInfoMethod: TRttiMethod;
  lTextInfoParams: TArray<TRttiParameter>;
  lColumnValue: Integer;
  lFontObj: TObject;
  lTempFont: TFont;
  lFontProp: TRttiProperty;
  lFontValue: TValue;
  lFocusedColumnProp: TRttiProperty;
  lValidateMethod: TRttiMethod;
  lValidateParams: TArray<TRttiParameter>;

  function TryGetFirst(out aFirst: Pointer): Boolean;
  begin
    Result :=
      TryInvokePtrMethod(aTree, 'GetFirstVisible', [], aFirst) or
      TryInvokePtrMethod(aTree, 'GetFirst', [], aFirst);
  end;

  function TryGetNext(const aCur: Pointer; out aN: Pointer): Boolean;
  var
    lArg: TValue;
  begin
    TValue.Make(@aCur, TypeInfo(Pointer), lArg);
    Result :=
      TryInvokePtrMethod(aTree, 'GetNextVisible', [lArg], aN) or
      TryInvokePtrMethod(aTree, 'GetNext', [lArg], aN);
  end;

  function TryGetNodeText(const aCur: Pointer; out aText: string): Boolean;
  var
    lArgNode: TValue;
    lArgColumn: TValue;
    lRect: TRect;
    lTextWide: WideString;
    lArgs: TArray<TValue>;
    lValidateArgs: TArray<TValue>;
    lRecursive: Boolean;
  begin
    Result := False;
    aText := '';

    if (lValidateMethod <> nil) and (Length(lValidateParams) = 2) then
    begin
      SetLength(lValidateArgs, 2);
      TValue.Make(@aCur, lValidateParams[0].ParamType.Handle, lValidateArgs[0]);
      lRecursive := False;
      TValue.Make(@lRecursive, lValidateParams[1].ParamType.Handle, lValidateArgs[1]);
      try
        lValidateMethod.Invoke(aTree, lValidateArgs);
      except
        on E: Exception do
          if GMdcLoggingEnabled then
            MdcLog(Format('TryVirtualTreeToText: ValidateNode failed: %s: %s', [E.ClassName, E.Message]));
      end;
    end;

    if (lZombieMethod <> nil) and (Length(lZombieParams) = 2) then
    begin
      TValue.Make(@aCur, lZombieParams[0].ParamType.Handle, lArgNode);
      TValue.Make(@lColumnValue, lZombieParams[1].ParamType.Handle, lArgColumn);
      try
        aText := lZombieMethod.Invoke(aTree, [lArgNode, lArgColumn]).ToString;
        if aText <> '' then
          Exit(True);
      except
        on E: Exception do
          if GMdcLoggingEnabled then
            MdcLog(Format('TryVirtualTreeToText: ZombieGetText failed: %s: %s', [E.ClassName, E.Message]));
      end;
    end;

    if (lTextInfoMethod <> nil) and (Length(lTextInfoParams) = 5) then
    begin
      SetLength(lArgs, 5);
      TValue.Make(@aCur, lTextInfoParams[0].ParamType.Handle, lArgs[0]);
      TValue.Make(@lColumnValue, lTextInfoParams[1].ParamType.Handle, lArgs[1]);

      TValue.Make(@lFontObj, lTextInfoParams[2].ParamType.Handle, lArgs[2]);

      lRect := Rect(0, 0, 0, 0);
      TValue.Make(@lRect, lTextInfoParams[3].ParamType.Handle, lArgs[3]);

      lTextWide := '';
      TValue.Make(@lTextWide, lTextInfoParams[4].ParamType.Handle, lArgs[4]);
      try
        lTextInfoMethod.Invoke(aTree, lArgs);
        aText := lArgs[4].ToString;
        if aText <> '' then
          Exit(True);
      except
        on E: Exception do
          if GMdcLoggingEnabled then
            MdcLog(Format('TryVirtualTreeToText: GetTextInfo failed: %s: %s', [E.ClassName, E.Message]));
      end;
    end;

    if (lTextMethod <> nil) and (Length(lTextParams) = 2) then
    begin
      TValue.Make(@aCur, lTextParams[0].ParamType.Handle, lArgNode);
      TValue.Make(@lColumnValue, lTextParams[1].ParamType.Handle, lArgColumn);
      try
        aText := lTextMethod.Invoke(aTree, [lArgNode, lArgColumn]).ToString;
        Result := aText <> '';
      except
        on E: Exception do
          if GMdcLoggingEnabled then
            MdcLog(Format('TryVirtualTreeToText: GetText failed: %s: %s', [E.ClassName, E.Message]));
      end;
    end;
  end;

begin
  Result := False;
  aText := '';

  if aTree = nil then
    Exit;

  lTreeType := nil;
  lZombieMethod := nil;
  lTextInfoMethod := nil;
  lTextMethod := nil;
  lFontObj := nil;
  lTempFont := nil;
  lFocusedColumnProp := nil;
  lValidateMethod := nil;

  lCtx := TRttiContext.Create;
  try
    lTreeType := lCtx.GetType(aTree.ClassType);
    if lTreeType <> nil then
    begin
      lZombieMethod := lTreeType.GetMethod('ZombieGetText');
      if lZombieMethod <> nil then
        lZombieParams := lZombieMethod.GetParameters;
      lTextInfoMethod := lTreeType.GetMethod('GetTextInfo');
      if lTextInfoMethod <> nil then
        lTextInfoParams := lTextInfoMethod.GetParameters;
      lTextMethod := lTreeType.GetMethod('GetText');
      if lTextMethod <> nil then
        lTextParams := lTextMethod.GetParameters;
      lValidateMethod := lTreeType.GetMethod('ValidateNode');
      if lValidateMethod <> nil then
        lValidateParams := lValidateMethod.GetParameters;

      lFontProp := lTreeType.GetProperty('Font');
      if (lFontProp <> nil) and lFontProp.IsReadable then
      begin
        try
          lFontValue := lFontProp.GetValue(aTree);
          if lFontValue.IsObject then
            lFontObj := lFontValue.AsObject;
        except
          on E: Exception do
            if GMdcLoggingEnabled then
              MdcLog(Format('TryVirtualTreeToText: read Font failed: %s: %s', [E.ClassName, E.Message]));
        end;
      end;
    end;

    lColumnValue := 0;
    if lTreeType <> nil then
    begin
      lFocusedColumnProp := lTreeType.GetProperty('FocusedColumn');
      if (lFocusedColumnProp <> nil) and lFocusedColumnProp.IsReadable then
      begin
        try
          lColumnValue := lFocusedColumnProp.GetValue(aTree).AsInteger;
        except
          on E: Exception do
            if GMdcLoggingEnabled then
              MdcLog(Format('TryVirtualTreeToText: read FocusedColumn failed: %s: %s', [E.ClassName, E.Message]));
        end;
      end;
    end;
    if lFontObj = nil then
    begin
      lTempFont := TFont.Create;
      lFontObj := lTempFont;
    end;

    lBuilder := TStringBuilder.Create(16 * 1024);
    try
      if not TryGetFirst(lNode) then
      begin
        if GMdcLoggingEnabled then
          MdcLog('TryVirtualTreeToText: no GetFirst/GetFirstVisible method found');
        Exit;
      end;

      lCount := 0;
      while lNode <> nil do
      begin
        Inc(lCount);
        if lCount > 50000 then
        begin
          if GMdcLoggingEnabled then
            MdcLog('TryVirtualTreeToText: aborting after 50000 nodes (safety cap)');
          Break;
        end;

        if TryGetNodeText(lNode, lLine) then
        begin
          if lLine <> '' then
            lBuilder.AppendLine(lLine);
        end;

        if not TryGetNext(lNode, lNext) then
          Break;

        lNode := lNext;
      end;

      aText := lBuilder.ToString;
      Result := aText <> '';

      if GMdcLoggingEnabled then
        MdcLog(Format('TryVirtualTreeToText: nodes=%d chars=%d ok=%s', [lCount, Length(aText), BoolToStr(Result, True)]));
    finally
      lBuilder.Free;
    end;
  finally
    if lTempFont <> nil then
      lTempFont.Free;
    lCtx.Free;
  end;
end;

end.

