# Tasks

## In Progress

## Next – Today

## Next – This Week

## Next – Later

## Blocked

## Done

### T-009 [UNITS] Normalize unit picker paths before dedup
Outcome: The units picker canonicalizes file paths before it builds the dedup key, so the same unit is shown only once even when `DCC_UnitSearchPath` expansion produces doubled separators like `\\`.
Proof: `dcc32 -B -Q -Ebin -Ndcu -U".;..\\src;C:\\Program Files (x86)\\Embarcadero\\Studio\\23.0\\source\\DUnitX" MaxLogicDelphiCompanionTests.dpr` succeeds; `tests\\bin\\MaxLogicDelphiCompanionTests.exe --exitbehavior:Continue` passes 2/2 tests; `DelphiAIKit build --project projects/MaxLogicDelphiCompanion.dproj --delphi 23.0 --platform Win32 --config Debug` succeeds.

### T-008 Add copy path modes to Problems dialog
Summary: Provide selectable copy path formats (full/repo-relative/project-relative, Windows/WSL) and persist the selection.

Likely files to touch/read: src/MaxLogic.DelphiCompanion.FocusErrorInsight.pas, src/MaxLogic.DelphiCompanion.Settings.pas

### T-001 Open units in source view
Summary: Ensure the units picker opens the .pas source editor instead of the form designer.

### T-002 Avoid project-group merges on open
Summary: When opening a project or group that is not part of the current group, close the current group first.

### T-003 Make picker shortcuts global
Summary: Ensure the projects picker shortcut works anywhere and the units picker shortcut works when a project is open.

### T-004 Harden Problems dialog jump-to-code
Summary: Ensure the Problems dialog consistently focuses the code editor and places the cursor on the reported line.

### T-005 Make Problems dialog shortcut global
Summary: Ensure the Problems dialog shortcut works from any IDE pane and focuses the editor after jumps.

### T-006 Fix Problems dialog column jumps
Summary: Convert character columns from build/error insight into editor columns so jumps land on the correct position, even with tabs.

### T-007 Copy Problems items
Summary: Allow copying selected Problems dialog entries to the clipboard (Ctrl+C) in an AI-friendly format.
