unit MaxLogic.DelphiCompanion.CompileSounds;

interface

uses
  System.SysUtils,
  Winapi.Windows,
  ToolsAPI;

type
  TMdcCompileSounds = class
  public
    class procedure Install;
    class procedure Uninstall;
  end;

implementation

uses
  Winapi.MMSystem,
  System.IOUtils,
  System.Classes,
  MaxLogic.DelphiCompanion.Settings;

type
  { TNotifierObject is used to allow the IDE to manage lifetime without ref-count interference }
  TMdcIdeNotifier = class(TNotifierObject, IOTAIDENotifier, IOTAIDENotifier50, IOTAIDENotifier80)
  private
    procedure HandleAfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean);
  public
    { IOTAIDENotifier }
    procedure FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean);
    procedure BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean); overload;
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    { IOTAIDENotifier50 }
    procedure BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean); overload;
    procedure AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean); overload;

    { IOTAIDENotifier80 }
    procedure AfterCompile(const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean); overload;
  end;

var
  GNotifierIndex: Integer = -1;
  GNotifier: IOTAIDENotifier = nil;
  GLastPlayTick: Cardinal = 0;

procedure PlayConfigured(const aFileName: string; aFallbackBeep: UINT);
var
  lPath: string;
begin
  lPath := aFileName.Trim;
  if (lPath <> '') and TFile.Exists(lPath) then
  begin
    { SND_FILENAME: path is a file; SND_ASYNC: don't block the IDE UI }
    if PlaySound(PChar(lPath), 0, SND_FILENAME or SND_ASYNC) then
      Exit;
  end;

  Winapi.Windows.MessageBeep(aFallbackBeep);
end;

{ TMdcIdeNotifier }

procedure TMdcIdeNotifier.HandleAfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean);
var
  lEnabled: Boolean;
  lOk, lFail: string;
  lNow: Cardinal;
begin
  if IsCodeInsight then Exit;

  { Prevent double-triggering if the IDE calls multiple AfterCompile overloads }
  lNow := GetTickCount;
  if (GLastPlayTick <> 0) and (lNow - GLastPlayTick < 800) then
    Exit;
  GLastPlayTick := lNow;

  TMdcSettings.LoadCompileSounds(lEnabled, lOk, lFail);
  if not lEnabled then Exit;

  if Succeeded then
    PlayConfigured(lOk, MB_OK)
  else
    PlayConfigured(lFail, MB_ICONHAND);
end;

procedure TMdcIdeNotifier.BeforeCompile(const Project: IOTAProject; IsCodeInsight: Boolean; var Cancel: Boolean);
begin
  if not IsCodeInsight then
    GLastPlayTick := 0;
end;

procedure TMdcIdeNotifier.AfterCompile(const Project: IOTAProject; Succeeded: Boolean; IsCodeInsight: Boolean);
begin
  HandleAfterCompile(Succeeded, IsCodeInsight);
end;

{ Required Overloads / Interface stubs }
procedure TMdcIdeNotifier.AfterCompile(Succeeded: Boolean; IsCodeInsight: Boolean);
begin
  HandleAfterCompile(Succeeded, IsCodeInsight);
end;

procedure TMdcIdeNotifier.FileNotification(NotifyCode: TOTAFileNotification; const FileName: string; var Cancel: Boolean); begin end;
procedure TMdcIdeNotifier.BeforeCompile(const Project: IOTAProject; var Cancel: Boolean); begin end;
procedure TMdcIdeNotifier.AfterCompile(Succeeded: Boolean); begin end;
procedure TMdcIdeNotifier.AfterSave; begin end;
procedure TMdcIdeNotifier.BeforeSave; begin end;
procedure TMdcIdeNotifier.Destroyed; begin end;
procedure TMdcIdeNotifier.Modified; begin end;

{ TMdcCompileSounds }

class procedure TMdcCompileSounds.Install;
var
  lServices: IOTAServices;
begin
  if (GNotifierIndex >= 0) or not Supports(BorlandIDEServices, IOTAServices, lServices) then
    Exit;

  GNotifier := TMdcIdeNotifier.Create;
  GNotifierIndex := lServices.AddNotifier(GNotifier);
end;

class procedure TMdcCompileSounds.Uninstall;
var
  lServices: IOTAServices;
begin
  if (GNotifierIndex < 0) or not Supports(BorlandIDEServices, IOTAServices, lServices) then
    Exit;

  lServices.RemoveNotifier(GNotifierIndex);
  GNotifierIndex := -1;
  GNotifier := nil;
end;

end.

