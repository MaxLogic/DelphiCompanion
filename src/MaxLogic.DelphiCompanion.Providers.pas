unit MaxLogic.DelphiCompanion.Providers;

interface

uses
  System.Generics.Collections;

type
  TMaxLogicPickItem = record
    Display: string;
    Detail: string;
    FileName: string;
    IsFavorite: Boolean;
  end;

  TMaxLogicProjectsProvider = class
  public
    class function GetItems: TArray<TMaxLogicPickItem>; static;
    class procedure AddRecent(const aProjectFile: string); static;
    class procedure ToggleFavorite(const aProjectFile: string); static;
    class procedure ForgetProject(const aProjectFile: string); static;
  end;

  TMaxLogicOpenUnitsProvider = class
  public
    class function GetItems: TArray<TMaxLogicPickItem>; static;
  end;

implementation

uses
  Winapi.Windows,
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.IOUtils,
  System.Math,
  System.Win.Registry,
  System.Generics.Defaults,
  ToolsAPI,
  AutoFree,
  MaxLogic.DelphiCompanion.IdeApi;

const
  // These subkeys match what you exported.
  CSubKeyClosedProjects   = 'Closed Projects';
  CSubKeyFavoriteProjects = 'Favorite Projects';
  CValuePrefixFile        = 'File_';

  // Safety limits (Delphi has its own "Max Closed Files" value, but we won’t touch it here).
  CMaxRecentProjects      = 50;
  CMaxFavoriteProjects    = 200;

type
  TMdcRegEntry = record
    FileName: string;   // extracted path
    RawValue: string;   // value stored in registry (often quoted path)
    Index: Integer;     // numeric suffix from File_N
  end;

function CompareFileValueNames(aList: TStringList; aIndex1, aIndex2: Integer): Integer;
var
  lN1: Integer;
  lN2: Integer;
begin
  // expects items like "File_0", "File_10", ...
  lN1 := StrToIntDef(Copy(aList[aIndex1], Length(CValuePrefixFile) + 1, MaxInt), 0);
  lN2 := StrToIntDef(Copy(aList[aIndex2], Length(CValuePrefixFile) + 1, MaxInt), 0);
  Result := lN1 - lN2;
end;

function ExtractQuotedPath(const aValue: string): string;
var
  lP1, lP2: Integer;
  lQuote: Char;
  lRaw: string;
begin
  lRaw := Trim(aValue);
  if lRaw = '' then
    Exit('');

  // try single quotes first
  lP1 := Pos('''', lRaw);
  lQuote := '''';

  // else try double quotes
  if lP1 <= 0 then
  begin
    lP1 := Pos('"', lRaw);
    lQuote := '"';
  end;

  // no quotes -> assume the whole value is the path
  if lP1 <= 0 then
    Exit(lRaw);

  lP2 := PosEx(lQuote, lRaw, lP1 + 1);
  if lP2 <= lP1 then
    Exit('');

  Result := Copy(lRaw, lP1 + 1, lP2 - lP1 - 1).Trim;
end;

function TryFindRawValueByFileNameLower(
  const aFileNameLower: string;
  const aEntries: TArray<TMdcRegEntry>;
  out aRawValue: string): Boolean;
var
  lE: TMdcRegEntry;
begin
  aRawValue := '';
  for lE in aEntries do
  begin
    if AnsiLowerCase(lE.FileName) = aFileNameLower then
    begin
      aRawValue := lE.RawValue;
      Exit(True);
    end;
  end;
  Result := False;
end;


function EnsureQuotedPath(const aFileName: string): string;
begin
  Result := AnsiQuotedStr(aFileName, '''');
end;


function BuildDelphiProjectRawValue(const aProjectFile: string): string;
var
  lFn: string;
  lExt: string;
begin
  lFn := aProjectFile.Trim;
  lExt := LowerCase(ExtractFileExt(lFn));

  // Match the formats you exported from the registry
  if lExt = '.groupproj' then
    Result := 'TProjectGroup,' + EnsureQuotedPath(lFn) + ',1'
  else
    Result := 'TBaseProject,' + EnsureQuotedPath(lFn) + ',1,1,1,1,1';
end;


function TryGetBaseKey(out aBase: string): Boolean;
begin
  aBase := TMdcIdeApi.GetBdsBaseRegKey;
  Result := aBase.Trim <> '';
end;

function ReadEntries(const aSubKey: string): TArray<TMdcRegEntry>;
var
  lBase: string;
  lReg: TRegistry;
  lNames: TStringList;
  lTmp: TStringList;
  lI: Integer;
  lName: string;
  lRaw: string;
  lPath: string;
  lEntry: TMdcRegEntry;
begin
  Result := [];

  if not TryGetBaseKey(lBase) then
    Exit;

  lReg := TRegistry.Create(KEY_READ);
  try
    lReg.RootKey := HKEY_CURRENT_USER;

    if not lReg.OpenKeyReadOnly(lBase + '\' + aSubKey) then
      Exit;

    lNames := TStringList.Create;
    try
      lReg.GetValueNames(lNames);

      lTmp := TStringList.Create;
      try
        // keep only File_*
        for lI := 0 to lNames.Count - 1 do
        begin
          if SameText(Copy(lNames[lI], 1, Length(CValuePrefixFile)), CValuePrefixFile) then
            lTmp.Add(lNames[lI]);
        end;

        // sort by numeric suffix
        lTmp.CustomSort(CompareFileValueNames);

        for lI := 0 to lTmp.Count - 1 do
        begin
          lName := lTmp[lI];
          lRaw := lReg.ReadString(lName);
          lPath := ExtractQuotedPath(lRaw);
          if lPath.Trim = '' then
            Continue;

          lEntry.FileName := lPath;
          lEntry.RawValue := lRaw;
          lEntry.Index := StrToIntDef(Copy(lName, Length(CValuePrefixFile) + 1, MaxInt), 0);

          Result := Result + [lEntry];
        end;
      finally
        lTmp.Free;
      end;
    finally
      lNames.Free;
    end;
  finally
    lReg.Free;
  end;
end;

procedure WriteEntries(const aSubKey: string; const aEntries: TArray<TMdcRegEntry>);
var
  lBase: string;
  lReg: TRegistry;
  lNames: TStringList;
  lI: Integer;
  lName: string;
begin
  if not TryGetBaseKey(lBase) then
    Exit;

  lReg := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    lReg.RootKey := HKEY_CURRENT_USER;

    if not lReg.OpenKey(lBase + '\' + aSubKey, True) then
      Exit;

    // delete existing File_*
    lNames := TStringList.Create;
    try
      lReg.GetValueNames(lNames);
      for lI := 0 to lNames.Count - 1 do
      begin
        if SameText(Copy(lNames[lI], 1, Length(CValuePrefixFile)), CValuePrefixFile) then
          lReg.DeleteValue(lNames[lI]);
      end;
    finally
      lNames.Free;
    end;

    // write File_0..File_n
    for lI := 0 to High(aEntries) do
    begin
      lName := CValuePrefixFile + lI.ToString;
      lReg.WriteString(lName, aEntries[lI].RawValue);
    end;
  finally
    lReg.Free;
  end;
end;

function DedupKeepOrder(const aEntries: TArray<TMdcRegEntry>; const aMax: Integer): TArray<TMdcRegEntry>;
var
  lSeen: TDictionary<string, Byte>;
  lOut: TList<TMdcRegEntry>;
  lGs: TGarbos;
  lE: TMdcRegEntry;
  lKey: string;
begin
  GC(lSeen, TDictionary<string, Byte>.Create, lGs);
  GC(lOut, TList<TMdcRegEntry>.Create, lGs);

  for lE in aEntries do
  begin
    lKey := lE.FileName.ToLower;
    if lKey.Trim = '' then
      Continue;

    if lSeen.ContainsKey(lKey) then
      Continue;

    lSeen.Add(lKey, 1);
    lOut.Add(lE);

    if (aMax > 0) and (lOut.Count >= aMax) then
      Break;
  end;

  Result := lOut.ToArray;
end;

function MakePickItem(const aFileName: string; aIsFavorite: Boolean): TMaxLogicPickItem;
begin
  Result.FileName := aFileName;
  Result.Display := ExtractFileName(aFileName);
  Result.Detail := ExtractFilePath(aFileName);
  Result.IsFavorite := aIsFavorite;
end;

{ TMaxLogicProjectsProvider }

class function TMaxLogicProjectsProvider.GetItems: TArray<TMaxLogicPickItem>;
var
  lRecent: TArray<TMdcRegEntry>;
  lFav: TArray<TMdcRegEntry>;

  lFavSet: TDictionary<string, Byte>;
  lAll: TList<TMaxLogicPickItem>;
  lGs: TGarbos;

  lE: TMdcRegEntry;
  lKey: string;
begin
  // Read from registry each time the dialog opens (as agreed).
  lRecent := ReadEntries(CSubKeyClosedProjects);
  lFav := ReadEntries(CSubKeyFavoriteProjects);

  GC(lFavSet, TDictionary<string, Byte>.Create, lGs);
  for lE in lFav do
  begin
    lKey := lE.FileName.ToLower;
    if (lKey <> '') and not lFavSet.ContainsKey(lKey) then
      lFavSet.Add(lKey, 1);
  end;

  GC(lAll, TList<TMaxLogicPickItem>.Create, lGs);

  // favorites first
  for lE in lFav do
  begin
    if FileExists(lE.FileName) then
      lAll.Add(MakePickItem(lE.FileName, True));
  end;

  // then recents (excluding favorites)
  for lE in lRecent do
  begin
    lKey := lE.FileName.ToLower;
    if (lKey <> '') and lFavSet.ContainsKey(lKey) then
      Continue;

    if FileExists(lE.FileName) then
      lAll.Add(MakePickItem(lE.FileName, False));
  end;

  Result := lAll.ToArray;
end;

class procedure TMaxLogicProjectsProvider.AddRecent(const aProjectFile: string);
var
  lPath: string;
  lTarget: string;

  lRecent: TArray<TMdcRegEntry>;
  lOut: TList<TMdcRegEntry>;
  lGs: TGarbos;

  lHead: TMdcRegEntry;
  lExistingRaw: string;
  lE: TMdcRegEntry;
begin
  lPath := aProjectFile.Trim;
  if lPath = '' then
    Exit;

  lTarget := AnsiLowerCase(lPath);

  lRecent := ReadEntries(CSubKeyClosedProjects);

  // Prefer preserving RawValue if it already exists in registry
  if not TryFindRawValueByFileNameLower(lTarget, lRecent, lExistingRaw) then
    lExistingRaw := BuildDelphiProjectRawValue(lPath);

  lHead.FileName := lPath;
  lHead.RawValue := lExistingRaw;
  lHead.Index := 0;

  GC(lOut, TList<TMdcRegEntry>.Create, lGs);

  // Head first
  lOut.Add(lHead);

  // Then keep prior order (excluding the target)
  for lE in lRecent do
    if AnsiLowerCase(lE.FileName) <> lTarget then
      lOut.Add(lE);

  WriteEntries(CSubKeyClosedProjects, DedupKeepOrder(lOut.ToArray, CMaxRecentProjects));
end;


class procedure TMaxLogicProjectsProvider.ToggleFavorite(const aProjectFile: string);
var
  lPath: string;
  lFav: TArray<TMdcRegEntry>;
  lList: TList<TMdcRegEntry>;
  lGs: TGarbos;

  lTarget: string;
  lE: TMdcRegEntry;
  lFound: Boolean;
  lNewE: TMdcRegEntry;
begin
  lPath := aProjectFile.Trim;
  if lPath = '' then
    Exit;

  lTarget := lPath.ToLower;

  lFav := ReadEntries(CSubKeyFavoriteProjects);
  GC(lList, TList<TMdcRegEntry>.Create, lGs);

  lFound := False;

  // keep everything except the target
  for lE in lFav do
  begin
    if lE.FileName.ToLower = lTarget then
      lFound := True
    else
      lList.Add(lE);
  end;

  // if it wasn't there -> append
  if not lFound then
  begin
    lNewE.FileName := lPath;
    lNewE.RawValue := EnsureQuotedPath(lPath);
    lNewE.Index := 0;
    lList.Add(lNewE); // <-- APPEND (not Insert(0))
  end;

  WriteEntries(CSubKeyFavoriteProjects, DedupKeepOrder(lList.ToArray, CMaxFavoriteProjects));
end;
class procedure TMaxLogicProjectsProvider.ForgetProject(const aProjectFile: string);
var
  lPath: string;
  lTarget: string;

  lRecent: TArray<TMdcRegEntry>;
  lFav: TArray<TMdcRegEntry>;

  lRecentOut: TList<TMdcRegEntry>;
  lFavOut: TList<TMdcRegEntry>;
  lGs: TGarbos;

  lE: TMdcRegEntry;
begin
  lPath := aProjectFile.Trim;
  if lPath = '' then
    Exit;

  lTarget := lPath.ToLower;

  lRecent := ReadEntries(CSubKeyClosedProjects);
  lFav := ReadEntries(CSubKeyFavoriteProjects);

  GC(lRecentOut, TList<TMdcRegEntry>.Create, lGs);
  for lE in lRecent do
    if lE.FileName.ToLower <> lTarget then
      lRecentOut.Add(lE);

  GC(lFavOut, TList<TMdcRegEntry>.Create, lGs);
  for lE in lFav do
    if lE.FileName.ToLower <> lTarget then
      lFavOut.Add(lE);

  WriteEntries(CSubKeyClosedProjects, DedupKeepOrder(lRecentOut.ToArray, CMaxRecentProjects));
  WriteEntries(CSubKeyFavoriteProjects, DedupKeepOrder(lFavOut.ToArray, CMaxFavoriteProjects));
end;

{ TMaxLogicOpenUnitsProvider }

class function TMaxLogicOpenUnitsProvider.GetItems: TArray<TMaxLogicPickItem>;
var
  lMods: IOTAModuleServices;
  lAll: TList<TMaxLogicPickItem>;
  lGs: TGarbos;
  lI: Integer;
  lM: IOTAModule;
  lFn: string;
begin
  Result := nil;

  if not Supports(BorlandIDEServices, IOTAModuleServices, lMods) then
    Exit(nil);

  GC(lAll, TList<TMaxLogicPickItem>.Create, lGs);

  for lI := 0 to lMods.ModuleCount - 1 do
  begin
    lM := lMods.Modules[lI];
    if lM = nil then
      Continue;

    lFn := lM.FileName;
    if lFn.Trim = '' then
      Continue;

    if not SameText(ExtractFileExt(lFn), '.pas') then
      Continue;

    lAll.Add(MakePickItem(lFn, False));
  end;

  Result := lAll.ToArray;
end;

end.

