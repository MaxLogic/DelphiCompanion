# Changelog

All notable user-visible changes to this project will be documented in this file.

## [Unreleased]

### Added
- Problems dialog now copies selected entries with Ctrl+C in an AI-friendly text format. (T-007)
- Problems dialog now supports selectable copy path formats (full/repo-relative/project-relative, Windows/WSL). (T-008)

### Changed
- Project/group opening now avoids merging into the current project group when the target is not part of it. (T-002)

### Fixed
- Units picker opens `.pas` in the source editor view instead of the form designer. (T-001)
- Picker shortcuts now work outside the editor; units picker only opens when a project is available. (T-003)
- Problems dialog jump-to-code now consistently focuses the editor and positions the cursor. (T-004)
- Problems dialog shortcut now works from any IDE pane and editor focus is enforced after jumps. (T-005)
- Problems dialog column positions now respect tabs, placing the caret on the exact reported character. (T-006)
