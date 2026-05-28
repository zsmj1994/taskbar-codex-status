# Tray Icon Flyout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a dynamic tray icon and hover detail flyout to the taskbar status widget.

**Architecture:** Keep icon drawing in a small testable helper and bind tray/flyout UI from `config/status.json` in the main WPF script. Use WinForms `NotifyIcon` events for hover/click and a WPF borderless window for the custom panel.

**Tech Stack:** Windows PowerShell, WinForms `NotifyIcon`, WPF, System.Drawing.

---

### Task 1: Dynamic Tray Icon

**Files:**
- Create: `src/TrayIcon.ps1`
- Create: `tests/TrayIcon.Tests.ps1`

- [x] Write a failing test that expects `New-TrayStatusIcon` to return a 32x32 `System.Drawing.Icon`.
- [x] Implement badge text compaction and 32x32 icon drawing.
- [x] Verify the tray icon test passes.

### Task 2: Hover Flyout

**Files:**
- Modify: `src/TaskbarCodexStatus.ps1`
- Modify: `config/status.json`

- [x] Dot-source `TrayIcon.ps1`.
- [x] Add `tray` and `flyout` config sections while preserving existing floating-bar settings.
- [x] Update the tray icon during refresh.
- [x] Add a custom WPF flyout and show it on tray hover or left-click.
- [x] Hide the flyout after the mouse leaves.

### Task 3: Documentation and Verification

**Files:**
- Modify: `README.md`

- [x] Document tray and flyout config fields.
- [x] Run tray icon tests, taskbar geometry tests, validation, smoke test, and `git diff --check`.
