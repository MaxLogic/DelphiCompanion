# MaxLogic Delphi Companion

MaxLogic Delphi Companion (MDC) is a RAD Studio Delphi 12+ IDE add-in focused on fast navigation and build feedback. It provides pickers for projects and units, a problems dialog for Error Insight/build messages, and a small options dialog for shortcuts and behavior.

## Features

### Projects Picker

- Default shortcut: `Ctrl+Shift+P` (configurable).
- Recent and favorite projects with Everything-style filtering (for example: `forms|!test`).
- Enter or double-click opens the selected project.
- `Ctrl+F` toggles favorite; `Delete` forgets an entry.
- Sorting and visibility options (Favorites first, projects vs. project groups) live in the dialog.

### Units Picker

- Default shortcut: `Ctrl+Shift+O` (configurable).
- Scope options: open editors, current project, or project group.
- Optional scanning of the project unit search paths (`DCC_UnitSearchPath`).
- Everything-style filtering; Enter or double-click opens the unit.
- `Ctrl+C` copies selected unit paths as Markdown.

### Problems Dialog 

- Default shortcut: `Ctrl+Shift+F1` (configurable).
- Shows Error Insight issues and build errors/warnings in separate lists.
- Double-click (or Enter) jumps to the line in the editor.
- `F1/F2/F3` focuses a list, `F5` refreshes, `Esc` closes.

### Options Dialog

- Available from the IDE **Tools** menu.
- Configure shortcuts for Projects, Units, and Problems.
- Enable compile sounds and set success/failure WAV files.
- Enable or disable MDC logging.
- Optional developer tool: register the Debug Control Inspector.

### Persistence

- Settings are stored in `%APPDATA%\MaxLogic\DelphiCompanion\MDC.ini` (UTF-8 INI file).
- Window size/position is saved for pickers and the Problems dialog.

## Installation

1. Build and install `MaxLogicFoundationR.bpl` from the [MaxLogicFoundation](https://github.com/maxlogic/maxlogicfoundation) project.
2. Open `projects/MaxLogicDelphiCompanion.dpk` in Delphi 12.
3. Build and install the package.
4. Use the defaults or configure shortcuts under **Tools > MaxLogic Delphi Companion Options**.

## Notes

- Logging (when enabled) is written to `%AppData%\MaxLogic\DelphiCompanion\mdc.log`.
- Clearing a hotkey in Options disables that command's binding.

## Support and Contributing

Please report issues or suggestions in the [MaxLogic repository](https://github.com/maxlogic). Contributions are welcome.

## License

MaxLogic Delphi Companion is released under a permissive license. See the repository for details. Embarcadero, RAD Studio, and Delphi are trademarks of their respective owners.

