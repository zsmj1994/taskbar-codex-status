# Taskbar Floating Status Design

## Goal

Build a Windows 11 taskbar-adjacent status widget that can display custom user-defined information with a visual style similar to the built-in taskbar weather widget.

## Scope

The first version uses a borderless, topmost floating window positioned over the taskbar area. It does not inject into Explorer or use private taskbar APIs. This keeps the tool stable and easy to run while preserving a path for later taskbar-host experiments.

## User Experience

- A compact floating strip shows a circular badge plus two lines of text.
- The strip is positioned inside or directly over the taskbar area, near the right side by default.
- A system tray icon keeps the app reachable while it runs.
- The tray menu supports refresh, reposition, opening the config file, and exit.
- Display content is controlled by `config/status.json`.

## Architecture

- `src/TaskbarCodexStatus.ps1` is the single executable app script.
- `config/status.json` stores status text, colors, dimensions, and refresh behavior.
- WPF renders the floating strip; WinForms provides screen and tray APIs.
- Taskbar position is inferred from the difference between the primary screen bounds and working area.

## Error Handling

If config loading fails, the widget remains visible and shows a concise error state. Repositioning is retried on refresh so taskbar changes can be corrected without restarting.

## Verification

- Run the script in validation mode to parse the config without opening UI.
- Run `git diff --check` before completion.
