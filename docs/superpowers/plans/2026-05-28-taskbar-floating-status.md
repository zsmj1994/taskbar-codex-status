# Taskbar Floating Status Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a runnable Windows 11 taskbar-adjacent floating status widget.

**Architecture:** Use a PowerShell script that creates a WPF borderless floating window and a WinForms tray icon. Load all display content from JSON so the first version is useful without recompiling or requiring a .NET SDK.

**Tech Stack:** Windows PowerShell, WPF, WinForms, JSON config.

---

### Task 1: App Script

**Files:**
- Create: `src/TaskbarCodexStatus.ps1`

- [ ] **Step 1: Create a script with config loading**

Add a `-Validate` switch, resolve `config/status.json`, create a default config when missing, and parse JSON before any UI is shown.

- [ ] **Step 2: Create the floating WPF window**

Render a rounded strip with a badge and two text lines. Bind the displayed values to the loaded config.

- [ ] **Step 3: Position the window near the taskbar**

Infer taskbar edge from `Screen.PrimaryScreen.Bounds` and `WorkingArea`. Position bottom taskbars inside the taskbar band, with configurable offsets.

- [ ] **Step 4: Add tray controls**

Add Refresh, Reposition, Open Config, and Exit menu items through `System.Windows.Forms.NotifyIcon`.

### Task 2: Configuration and Launch Documentation

**Files:**
- Create: `config/status.json`
- Create: `README.md`

- [ ] **Step 1: Add default config**

Provide visible default values for line text, badge text, colors, size, and refresh interval.

- [ ] **Step 2: Document running the app**

Describe how to run with `powershell.exe -STA`, how to edit the config, and how to exit from the tray menu.

### Task 3: Verification

**Files:**
- Modify only if validation reveals a defect.

- [ ] **Step 1: Run validation mode**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\TaskbarCodexStatus.ps1 -Validate`

Expected: exits successfully and reports that validation passed.

- [ ] **Step 2: Run whitespace validation**

Run: `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\TaskbarCodexStatus.ps1 -SmokeTest`

Expected: exits successfully and reports that the WPF status window initialized.

- [ ] **Step 3: Run whitespace validation**

Run: `git diff --check`

Expected: no output and exit code 0.
