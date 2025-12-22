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
begin
  Result := False;

  if aFileName.Trim = '' then
    Exit(False);

  if not TryGetActionServices(lSvc) then
    Exit(False);

  lExt := LowerCase(ExtractFileExt(aFileName));

  // Projects / groups: OpenProject(ProjectName, NewProjectGroup)
  if (lExt = '.dproj') or (lExt = '.groupproj') then
    Exit(lSvc.OpenProject(aFileName, False));

  // Files: OpenFile returns Boolean
  Result := lSvc.OpenFile(aFileName);
end;

end.

