unit MaxLogic.DelphiCompanion.Settings;

interface

uses
  System.Classes,
  Vcl.Forms;

type
  TMdcSettings = class
  public
    class function GetConfigDir: string; static;
    class function GetConfigFileName: string; static;

    class function DefaultProjects: TShortCut; static;
    class function DefaultUnits: TShortCut; static;

    class procedure LoadShortCuts(out aProjects: TShortCut; out aUnits: TShortCut); static;
    class procedure SaveShortCuts(aProjects: TShortCut; aUnits: TShortCut); static;

    class procedure LoadWindowBounds(const aKey: string; aForm: TForm; aDefaultWidth: Integer; aDefaultHeight: Integer); static;
    class procedure SaveWindowBounds(const aKey: string; aForm: TForm); static;

    class procedure LoadUnitsPickerOptions(out aScope: Integer; out aIncludeSearchPaths: Boolean); static;
    class procedure SaveUnitsPickerOptions(aScope: Integer; aIncludeSearchPaths: Boolean); static;

    class procedure LoadProjectsPickerOptions(out aSortAlpha: Boolean; out aFavoritesFirst: Boolean; out aFilterIncludePath: Boolean); static;
    class procedure SaveProjectsPickerOptions(aSortAlpha: Boolean; aFavoritesFirst: Boolean; aFilterIncludePath: Boolean); static;

    class procedure LoadCompileSounds(out aEnabled: Boolean; out aOkSound: string; out aFailSound: string); static;
    class procedure SaveCompileSounds(aEnabled: Boolean; const aOkSound: string; const aFailSound: string); static;

    class function DefaultLoggingEnabled: Boolean; static;
    class procedure LoadLoggingEnabled(out aEnabled: Boolean); static;
    class procedure SaveLoggingEnabled(aEnabled: Boolean); static;

    class function DefaultFocusErrorInsight: TShortCut; static;
    class procedure LoadFocusErrorInsightShortcut(out aSc: TShortCut); static;
    class procedure SaveFocusErrorInsightShortcut(aSc: TShortCut); static;

  end;

implementation

uses
  System.IniFiles, System.IOUtils, System.SysUtils,
  Vcl.Menus,
  AutoFree;

const
  CIniSectionShortCuts = 'Shortcuts';
  CIniKeyProjects = 'ProjectsShortcut';
  CIniKeyUnits = 'UnitsShortcut';

  CIniSectionWindows = 'Windows';

  CDefaultProjectsText = 'Ctrl+Shift+P';
  CDefaultUnitsText = 'Ctrl+Shift+O';

  CMissing = '#__MDC_MISSING__#';

  CDefaultLoggingEnabled = True;


  CIniSectionUnitsPicker = 'UnitsPicker'; // legacy
  CIniSectionPickerUnits = 'Picker.Units';
  CIniKeyScope = 'Scope';
  CIniKeyIncludeSearchPaths = 'IncludeSearchPaths';

  CIniSectionProjectsPicker = 'Picker.Projects';
  CIniKeyProjectsSortAlpha = 'SortAlpha';
  CIniKeyProjectsFavoritesFirst = 'FavoritesFirst';
  CIniKeyProjectsFilterIncludePath = 'FilterIncludePath';


  CIniSectionCompileSounds = 'CompileSounds';
  CIniKeyEnabled = 'Enabled';
  CIniKeyOkSound = 'OkSound';
  CIniKeyFailSound = 'FailSound';

  CIniSectionLogging = 'Logging';
  CIniKeyLoggingEnabled = 'Enabled';


  CIniSectionAccessibility = 'Accessibility';
  CIniKeyFocusErrorInsight = 'FocusErrorInsightShortcut';



class function TMdcSettings.DefaultFocusErrorInsight: TShortCut;
begin
  Result := TextToShortCut('Ctrl+Shift+F1');
end;

class procedure TMdcSettings.LoadFocusErrorInsightShortcut(out aSc: TShortCut);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  s: string;
begin
  aSc := DefaultFocusErrorInsight;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  s := lIni.ReadString(CIniSectionAccessibility, CIniKeyFocusErrorInsight, '');
  if s.Trim <> '' then
    aSc := TextToShortCut(s);
end;

class procedure TMdcSettings.SaveFocusErrorInsightShortcut(aSc: TShortCut);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;
begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  if aSc = 0 then
    lIni.WriteString(CIniSectionAccessibility, CIniKeyFocusErrorInsight, '')
  else
    lIni.WriteString(CIniSectionAccessibility, CIniKeyFocusErrorInsight, ShortCutToText(aSc));

  lIni.UpdateFile;
end;


class procedure TMdcSettings.LoadCompileSounds(out aEnabled: Boolean; out aOkSound: string; out aFailSound: string);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
begin
  aEnabled := False;
  aOkSound := '';
  aFailSound := '';

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  aEnabled := lIni.ReadBool(CIniSectionCompileSounds, CIniKeyEnabled, False);
  aOkSound := lIni.ReadString(CIniSectionCompileSounds, CIniKeyOkSound, '');
  aFailSound := lIni.ReadString(CIniSectionCompileSounds, CIniKeyFailSound, '');
end;

class procedure TMdcSettings.SaveCompileSounds(aEnabled: Boolean; const aOkSound: string; const aFailSound: string);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;
begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteBool(CIniSectionCompileSounds, CIniKeyEnabled, aEnabled);
  lIni.WriteString(CIniSectionCompileSounds, CIniKeyOkSound, aOkSound);
  lIni.WriteString(CIniSectionCompileSounds, CIniKeyFailSound, aFailSound);
  lIni.UpdateFile;
end;

class function TMdcSettings.DefaultLoggingEnabled: Boolean;
begin
  Result := CDefaultLoggingEnabled;
end;

class procedure TMdcSettings.LoadLoggingEnabled(out aEnabled: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
begin
  aEnabled := DefaultLoggingEnabled;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  aEnabled := lIni.ReadBool(CIniSectionLogging, CIniKeyLoggingEnabled, aEnabled);
end;

class procedure TMdcSettings.SaveLoggingEnabled(aEnabled: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;
begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteBool(CIniSectionLogging, CIniKeyLoggingEnabled, aEnabled);
  lIni.UpdateFile;
end;

class procedure TMdcSettings.LoadUnitsPickerOptions(out aScope: Integer; out aIncludeSearchPaths: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  s: string;

  function TryReadString(const aSection: string; const aKey: string; out aValue: string): Boolean;
  begin
    aValue := lIni.ReadString(aSection, aKey, CMissing);
    Result := (aValue <> CMissing);
  end;

  function ScopeFromText(const aText: string): Integer;
  begin
    if SameText(aText, 'CurrentProject') then
      Exit(1);
    if SameText(aText, 'ProjectGroup') then
      Exit(2);
    Result := 0;
  end;

  function BoolFromText(const aText: string; aDefault: Boolean): Boolean;
  begin
    if (SameText(aText, '1')) or (SameText(aText, 'True')) then
      Exit(True);
    if (SameText(aText, '0')) or (SameText(aText, 'False')) then
      Exit(False);
    Result := aDefault;
  end;

  procedure ReadScope;
  begin
    if TryReadString(CIniSectionPickerUnits, CIniKeyScope, s) or
       TryReadString(CIniSectionUnitsPicker, CIniKeyScope, s) then
    begin
      if not TryStrToInt(s, aScope) then
        aScope := ScopeFromText(s);
    end;
  end;

  procedure ReadIncludeSearchPaths;
  begin
    if TryReadString(CIniSectionPickerUnits, CIniKeyIncludeSearchPaths, s) or
       TryReadString(CIniSectionUnitsPicker, CIniKeyIncludeSearchPaths, s) then
      aIncludeSearchPaths := BoolFromText(s, aIncludeSearchPaths);
  end;
begin
  aScope := 0; // default: Open editors
  aIncludeSearchPaths := False;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  ReadScope;
  ReadIncludeSearchPaths;
end;

class procedure TMdcSettings.SaveUnitsPickerOptions(aScope: Integer; aIncludeSearchPaths: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;

  function ScopeToText(aScopeValue: Integer): string;
  begin
    case aScopeValue of
      1: Result := 'CurrentProject';
      2: Result := 'ProjectGroup';
    else
      Result := 'OpenEditors';
    end;
  end;
begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteString(CIniSectionPickerUnits, CIniKeyScope, ScopeToText(aScope));
  lIni.WriteBool(CIniSectionPickerUnits, CIniKeyIncludeSearchPaths, aIncludeSearchPaths);
  lIni.UpdateFile;
end;

class procedure TMdcSettings.LoadProjectsPickerOptions(out aSortAlpha: Boolean; out aFavoritesFirst: Boolean; out aFilterIncludePath: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
begin
  aSortAlpha := False;
  aFavoritesFirst := True;
  aFilterIncludePath := False;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  aSortAlpha := lIni.ReadBool(CIniSectionProjectsPicker, CIniKeyProjectsSortAlpha, aSortAlpha);
  aFavoritesFirst := lIni.ReadBool(CIniSectionProjectsPicker, CIniKeyProjectsFavoritesFirst, aFavoritesFirst);
  aFilterIncludePath := lIni.ReadBool(CIniSectionProjectsPicker, CIniKeyProjectsFilterIncludePath, aFilterIncludePath);
end;

class procedure TMdcSettings.SaveProjectsPickerOptions(aSortAlpha: Boolean; aFavoritesFirst: Boolean; aFilterIncludePath: Boolean);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;
begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteBool(CIniSectionProjectsPicker, CIniKeyProjectsSortAlpha, aSortAlpha);
  lIni.WriteBool(CIniSectionProjectsPicker, CIniKeyProjectsFavoritesFirst, aFavoritesFirst);
  lIni.WriteBool(CIniSectionProjectsPicker, CIniKeyProjectsFilterIncludePath, aFilterIncludePath);
  lIni.UpdateFile;
end;


class function TMdcSettings.DefaultProjects: TShortCut;
begin
  Result := TextToShortCut(CDefaultProjectsText);
end;

class function TMdcSettings.DefaultUnits: TShortCut;
begin
  Result := TextToShortCut(CDefaultUnitsText);
end;

class function TMdcSettings.GetConfigDir: string;
var
  lBase: string;
begin
  lBase := GetEnvironmentVariable('APPDATA');
  if lBase = '' then
  begin
    lBase := TPath.GetHomePath;
  end;

  Result := TPath.Combine(TPath.Combine(lBase, 'MaxLogic'), 'DelphiCompanion');
end;

class function TMdcSettings.GetConfigFileName: string;
begin
  Result := TPath.Combine(GetConfigDir, 'MDC.ini');
end;


class procedure TMdcSettings.LoadShortCuts(out aProjects: TShortCut; out aUnits: TShortCut);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  s: string;

  function ParseOrDefault(const aText: string; aDefault: TShortCut): TShortCut;
  begin
    if aText.Trim = '' then
      Exit(0); // explicit disable

    Result := TextToShortCut(aText);

    // Non-empty but invalid -> keep our default, don't silently disable.
    if Result = 0 then
      Result := aDefault;
  end;

begin
  aProjects := DefaultProjects;
  aUnits := DefaultUnits;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  s := lIni.ReadString(CIniSectionShortCuts, CIniKeyProjects, CMissing);
  if s <> CMissing then
    aProjects := ParseOrDefault(s, DefaultProjects);

  s := lIni.ReadString(CIniSectionShortCuts, CIniKeyUnits, CMissing);
  if s <> CMissing then
    aUnits := ParseOrDefault(s, DefaultUnits);
end;


class procedure TMdcSettings.SaveShortCuts(aProjects: TShortCut; aUnits: TShortCut);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;

  function SaveText(aValue: TShortCut): string;
  begin
    if aValue = 0 then
      Exit('');
    Result := ShortCutToText(aValue);
  end;

begin
  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteString(CIniSectionShortCuts, CIniKeyProjects, SaveText(aProjects));
  lIni.WriteString(CIniSectionShortCuts, CIniKeyUnits, SaveText(aUnits));
  lIni.UpdateFile;
end;

class procedure TMdcSettings.LoadWindowBounds(const aKey: string; aForm: TForm; aDefaultWidth: Integer; aDefaultHeight: Integer);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lLeft, lTop, lWidth, lHeight: Integer;
begin
  if aForm = nil then
    Exit;

  aForm.Position := poScreenCenter;
  aForm.Width := aDefaultWidth;
  aForm.Height := aDefaultHeight;

  lIniName := GetConfigFileName;
  if not FileExists(lIniName) then
    Exit;

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lLeft := lIni.ReadInteger(CIniSectionWindows, aKey + '.Left', -1);
  lTop := lIni.ReadInteger(CIniSectionWindows, aKey + '.Top', -1);
  lWidth := lIni.ReadInteger(CIniSectionWindows, aKey + '.Width', -1);
  lHeight := lIni.ReadInteger(CIniSectionWindows, aKey + '.Height', -1);

  if (lWidth > 200) and (lHeight > 150) then
  begin
    aForm.Width := lWidth;
    aForm.Height := lHeight;
  end;

  if (lLeft >= 0) and (lTop >= 0) then
  begin
    aForm.Position := poDesigned;
    aForm.Left := lLeft;
    aForm.Top := lTop;
  end;
end;

class procedure TMdcSettings.SaveWindowBounds(const aKey: string; aForm: TForm);
var
  lIni: TMemIniFile;
  g: IGarbo;
  lIniName: string;
  lDir: string;
begin
  if aForm = nil then
    Exit;

  lIniName := GetConfigFileName;
  lDir := ExtractFilePath(lIniName);
  if lDir <> '' then
    ForceDirectories(lDir);

  GC(lIni, TMemIniFile.Create(lIniName, TEncoding.UTF8), g);
  lIni.CaseSensitive := False;

  lIni.WriteInteger(CIniSectionWindows, aKey + '.Left', aForm.Left);
  lIni.WriteInteger(CIniSectionWindows, aKey + '.Top', aForm.Top);
  lIni.WriteInteger(CIniSectionWindows, aKey + '.Width', aForm.Width);
  lIni.WriteInteger(CIniSectionWindows, aKey + '.Height', aForm.Height);

  lIni.UpdateFile;
end;

end.

