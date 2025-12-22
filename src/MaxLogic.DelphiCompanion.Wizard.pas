unit MaxLogic.DelphiCompanion.Wizard;

interface

uses
  ToolsAPI,
  MaxLogic.DelphiCompanion.Integration;

type
  TMdcWizard = class(TNotifierObject, IOTAWizard)
  private
    fIntegration: TMdcIdeIntegration;
  protected
    function GetIDString: string;
    function GetName: string;
    function GetState: TWizardState;
    procedure Execute;
  public
    constructor Create;
    destructor Destroy; override;
  end;

implementation

constructor TMdcWizard.Create;
begin
  inherited Create;
  fIntegration := TMdcIdeIntegration.Create;
end;

destructor TMdcWizard.Destroy;
begin
  fIntegration.Free;
  inherited Destroy;
end;

procedure TMdcWizard.Execute;
begin
  // nothing - we install keyboard + menu on construction
end;

function TMdcWizard.GetIDString: string;
begin
  Result := 'MaxLogic.MDC';
end;

function TMdcWizard.GetName: string;
begin
  Result := 'MaxLogic Delphi Companion';
end;

function TMdcWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

end.
