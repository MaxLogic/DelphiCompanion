# MaxLogic Delphi Companion

Welcome to **MaxLogic Delphi Companion (MDC)** – a plug‑in for RAD Studio Delphi 12 that helps you quickly switch between projects and units.  MDC provides a **Projects picker** and an **Units picker** with a fast type‑to‑filter search, a simple configuration dialog and persistent shortcuts.

## Features

### Quick Projects List

- Press **Ctrl + Shift + P** to display a list of recent and favourite projects.
- Type part of the project name or path to filter the list using Everything‑style search (e.g. `forms|!test` matches items containing “forms” and excluding “test”).
- Navigate with arrow keys, press **Enter** or double‑click to open the selected project.
- Press **Ctrl + F** when an item is highlighted to toggle the favourite flag.  Favourites appear at the top of the list and are saved across sessions.

### Quick Units Navigation

- Press **Ctrl + Shift + O** to show the Units picker.
- Choose a **Scope** on the bottom row:
  - **Open editors** – lists all currently open `.pas` files.
  - **Active project** – shows units belonging to the active project and optional search paths.
  - **Project group** – lists units from every project in the group.
  - Check **Include search paths** to scan the unit search paths (`DCC_UnitSearchPath`).
- Use type‑to‑filter; press **Enter** or double‑click to open the selected unit in the IDE.

### Options Dialog

- Find **MaxLogic Delphi Companion Options…** in the **Tools** menu.
- Set your preferred shortcuts for the Projects and Units pickers.
- Click **Restore defaults** to revert to `Ctrl+Shift+P` and `Ctrl+Shift+O`.
- If a chosen shortcut conflicts with the IDE or another extension, a message will appear and the dialog will stay open.

### Persistent Settings

MDC stores its settings in `%APPDATA%\MaxLogic\MDC.ini`.  You can edit this file manually to adjust shortcuts, clear the MRU list or tweak the units picker scope.  The file is UTF‑8 encoded and uses simple INI syntax.

## Installation

1. Ensure you have **MaxLogicFoundationR.bpl** compiled and on your system path.  Follow the instructions in the [MaxLogicFoundation](https://github.com/maxlogic/maxlogicfoundation) project to build the runtime package.
2. Open **projects/MaxLogicDelphiCompanion.dpk** in Delphi 12.
3. Build and **Install** the package via the IDE.  The expert will register itself automatically.
4. After installation you will find **MaxLogic Delphi Companion Options…** under **Tools** and can use the default shortcuts immediately.

## Usage Tips

- Use **Alt+F** to jump to the filter box and **Alt+L** to jump to the list within the pickers.
- To enlarge or shrink the picker windows, resize them and they will remember their positions next time.
- If you disable a shortcut in Options by clearing the HotKey box, that command will no longer be bound.  Leave the other blank if you only want one picker.

## Support and Contributing

This project is open source.  Report issues or suggest improvements via the [GitHub repository](https://github.com/maxlogic).  Contributions are welcome – please follow the coding conventions described in `spec.md` and ensure you test your changes on Delphi 12 or later.

## License

MaxLogic Delphi Companion is released under a permissive license.  See the repository for details.  Embarcadero®, RAD Studio® and Delphi® are trademarks of their respective owners.
