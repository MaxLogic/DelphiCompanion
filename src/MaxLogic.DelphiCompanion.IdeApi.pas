unit MaxLogic.DelphiCompanion.IdeApi;

interface

uses
  System.SysUtils,
  System.IOUtils,
  ToolsAPI;

type
  TMdcIdeApi = class
  public
    class function TryGetActionServices(out aSvc: IOTAActionServices): Boolean; static;
    class function GetBdsBaseRegKey: string; static;

    class function OpenInIde(const aFileName: string): Boolean; static;
  end;

implementation

class function TMdcIdeApi.TryGetActionServices(out aSvc: IOTAActionServices): Boolean;
begin
  aSvc := nil;
  Result := Supports(BorlandIDEServices, IOTAActionServices, aSvc) and (aSvc <> nil);
end;

class function TMdcIdeApi.GetBdsBaseRegKey: string;
var
  lSvc: IOTAServices50;
begin
  Result := '';
  if Supports(BorlandIDEServices, IOTAServices50, lSvc) and (lSvc <> nil) then
    Result := lSvc.GetBaseRegistryKey;
end;

class function TMdcIdeApi.OpenInIde(const aFileName: string): Boolean;
var
  lSvc: IOTAActionServices;
  lExt: string;
  lMods: IOTAModuleServices;
  lGroup: IOTAProjectGroup;
  lNeedNewGroup: Boolean;

  function NormalizeFileName(const aValue: string): string;
  begin
    if aValue.Trim = '' then
      Exit('');
    Result := ExpandFileName(aValue);
  end;

  function SameFile(const aLeft, aRight: string): Boolean;
  begin
    Result := SameText(NormalizeFileName(aLeft), NormalizeFileName(aRight));
  end;

  function TryCloseProjectGroup(const aGroup: IOTAProjectGroup): Boolean;
  begin
    Result := True;
    if aGroup = nil then
      Exit(True);

    try
      Result := aGroup.Close;
    except
      Result := False;
    end;
  end;

  function OpenSourceFileInIde(const aPath: string): Boolean;
  var
    lLocalMods: IOTAModuleServices;
    lMod: IOTAModule;
    lEditor: IOTAEditor;
    lSource: IOTASourceEditor;
    i, lCount: Integer;
  begin
    Result := False;

    if not Supports(BorlandIDEServices, IOTAModuleServices, lLocalMods) then
      Exit(False);

    lMod := lLocalMods.FindModule(aPath);
    if lMod = nil then
      lMod := lLocalMods.OpenModule(aPath);

    if lMod = nil then
      Exit(False);

    try
      lMod.ShowFilename(aPath);
    except
      // ignore
    end;

    lCount := lMod.ModuleFileCount;
    for i := 0 to lCount - 1 do
    begin
      lEditor := lMod.ModuleFileEditors[i];
      if Supports(lEditor, IOTASourceEditor, lSource) then
      begin
        lEditor.Show;
        Result := True;
        Exit;
      end;
    end;

    Result := True;
  end;
begin
  Result := False;

  if aFileName.Trim = '' then
    Exit(False);

  if not TryGetActionServices(lSvc) then
    Exit(False);

  lExt := LowerCase(ExtractFileExt(aFileName));

  // Projects / groups: OpenProject(ProjectName, NewProjectGroup)
  if (lExt = '.dproj') or (lExt = '.groupproj') then
  begin
    lGroup := nil;
    if (Supports(BorlandIDEServices, IOTAModuleServices, lMods)) and (lMods <> nil) then
      lGroup := lMods.MainProjectGroup;

    if lExt = '.groupproj' then
    begin
      if (lGroup <> nil) and (SameFile(lGroup.FileName, aFileName)) then
        Exit(True);

      if (lGroup <> nil) and (not TryCloseProjectGroup(lGroup)) then
        Exit(False);

      Exit(lSvc.OpenProject(aFileName, True));
    end;

    // .dproj
    lNeedNewGroup := False;
    if lGroup <> nil then
      lNeedNewGroup := (lGroup.FindProject(aFileName) = nil);

    if lNeedNewGroup then
    begin
      if not TryCloseProjectGroup(lGroup) then
        Exit(False);
      Exit(lSvc.OpenProject(aFileName, True));
    end;

    Exit(lSvc.OpenProject(aFileName, False));
  end;

  // Files: OpenFile returns Boolean
  if lExt = '.pas' then
  begin
    Result := OpenSourceFileInIde(aFileName);
    if not Result then
      Result := lSvc.OpenFile(aFileName);
    Exit;
  end;

  Result := lSvc.OpenFile(aFileName);
end;

end.
