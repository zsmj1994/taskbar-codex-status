# Tray Icon Flyout Design

## Goal

Add a tray-first display mode that shows compact dynamic information directly on the Windows notification-area icon, then shows a richer detail panel when the user hovers over the icon.

## Scope

The implementation stays within public WinForms and WPF APIs. It does not inject into Explorer or replace Windows notification flyout behavior.

## User Experience

- The tray icon is generated dynamically from config and can show a short badge plus a notification dot.
- Hovering or left-clicking the tray icon opens a custom WPF flyout near the notification area.
- The flyout displays a title, a right-side action label, a small accent badge, and configurable label/value rows.
- The existing taskbar-adjacent floating bar remains available and can be hidden with `showFloatingBar`.

## Architecture

- `src/TrayIcon.ps1` owns dynamic icon drawing and badge text compaction.
- `src/TaskbarCodexStatus.ps1` owns the tray lifecycle, flyout window, timers, and config binding.
- `tests/TrayIcon.Tests.ps1` verifies icon generation without opening UI.

## Verification

- Run tray icon tests.
- Run existing taskbar geometry tests.
- Run validation and smoke-test modes.
- Run `git diff --check`.
