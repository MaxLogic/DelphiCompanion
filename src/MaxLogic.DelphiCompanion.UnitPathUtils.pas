unit MaxLogic.DelphiCompanion.UnitPathUtils;

interface

function NormalizeUnitFileName(const aFileName: string): string;
function BuildUnitDedupKey(const aFileName: string): string;

implementation

uses
  System.SysUtils;

function NormalizeUnitFileName(const aFileName: string): string;
var
  lFileName: string;
begin
  lFileName := aFileName.Trim;
  if lFileName = '' then
    Exit('');

  lFileName := StringReplace(lFileName, '/', '\', [rfReplaceAll]);
  Result := ExpandFileName(lFileName);
end;

function BuildUnitDedupKey(const aFileName: string): string;
begin
  Result := AnsiLowerCase(NormalizeUnitFileName(aFileName));
end;

end.
