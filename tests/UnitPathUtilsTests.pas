unit UnitPathUtilsTests;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TUnitPathUtilsTests = class
  public
    [Test]
    procedure BuildUnitDedupKey_NormalizesDoubleSeparators;

    [Test]
    procedure NormalizeUnitFileName_CollapsesDuplicateSeparators;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  MaxLogic.DelphiCompanion.UnitPathUtils;

function CreateTestFileNames(out aNormalFileName: string; out aDuplicatedFileName: string): string;
var
  lLibraryDir: string;
  lTempDir: string;
begin
  lTempDir := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  lLibraryDir := TPath.Combine(lTempDir, 'Library');

  ForceDirectories(lLibraryDir);

  aNormalFileName := TPath.Combine(lLibraryDir, 'DemoUnit.pas');
  TFile.WriteAllText(aNormalFileName, 'unit DemoUnit;');
  aDuplicatedFileName := IncludeTrailingPathDelimiter(lTempDir) + '\Library\DemoUnit.pas';

  Result := lTempDir;
end;

procedure TUnitPathUtilsTests.BuildUnitDedupKey_NormalizesDoubleSeparators;
var
  lDuplicatedFileName: string;
  lNormalFileName: string;
  lTempDir: string;
begin
  lTempDir := CreateTestFileNames(lNormalFileName, lDuplicatedFileName);
  try
    Assert.AreEqual(BuildUnitDedupKey(lNormalFileName), BuildUnitDedupKey(lDuplicatedFileName));
  finally
    TDirectory.Delete(lTempDir, True);
  end;
end;

procedure TUnitPathUtilsTests.NormalizeUnitFileName_CollapsesDuplicateSeparators;
var
  lDuplicatedFileName: string;
  lNormalFileName: string;
  lTempDir: string;
begin
  lTempDir := CreateTestFileNames(lNormalFileName, lDuplicatedFileName);
  try
    Assert.AreEqual(lNormalFileName, NormalizeUnitFileName(lDuplicatedFileName));
  finally
    TDirectory.Delete(lTempDir, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitPathUtilsTests);

end.
