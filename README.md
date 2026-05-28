# Taskbar Codex Status

Windows 11 tray status widget for Codex quota. It renders a dynamic notification-area icon as a circular remaining-quota gauge, then shows a quota dashboard when you hover the icon.

Current behavior:

- The tray icon shows the remaining percentage for the 5-hour quota card.
- Hovering or left-clicking the tray icon opens the quota dashboard.
- Right-clicking the tray icon opens the menu: Refresh, Open Config, Exit.
- There is no taskbar-adjacent floating bar anymore.

## Run

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\TaskbarCodexStatus.ps1
```

If you run without `-STA`, the script relaunches itself in STA mode.

## Configure

Edit `config/status.json`. `refreshSeconds` controls how often the app reloads the config. `quotaRefreshSeconds` controls how often quota data is force-refreshed. `quotaFailureRetrySeconds` controls how soon the app retries after a quota request fails.

The most important fields:

- `tray.mode`: use `quotaRing` for the circular gauge icon.
- `tray.quotaCardIndex`: which quota card drives the tray icon. `0` means the 5-hour card.
- `tray.ringColor`: active ring color.
- `tray.ringTrackColor`: inactive ring color.
- `quotaCards[].percentRemaining`: remaining percentage shown in the dashboard and tray icon.
- `quotaCards[].resetText`: footer text shown in each dashboard card.
- `quotaRefreshSeconds`: interval for forcing a quota refresh. Minimum is 5 seconds.
- `quotaFailureRetrySeconds`: retry interval after a quota request fails. Minimum is 5 seconds.
- `chatgpt.enabled`: when `true`, fetches live Codex quota from `https://chatgpt.com/backend-api/wham/usage`.
- `chatgpt.authPath`: path to the Codex/ChatGPT auth file. Defaults to `~\.codex\auth.json`.

## Tray Icon

The tray icon is generated from the `tray` section:

- `tray.badgeText`: fallback short value drawn inside the tray icon when not using `quotaRing`.
- `tray.badgeColor`: inner circle color.
- `tray.badgeForegroundColor`: number/text color.
- `tray.showDot`: whether to draw a small notification dot.
- `tray.tooltip`: native Windows tray tooltip text.
- `tray.mode`: set to `quotaRing` to draw a circular remaining-quota gauge.
- `tray.quotaCardIndex`: quota card index used by `quotaRing`.
- `tray.ringColor` and `tray.ringTrackColor`: gauge colors.

Hover the tray icon to show the custom flyout. The quota dashboard title and description come from `flyout`; the cards come from `quotaCards`.

## Quota Dashboard

The flyout can show quota-style cards from `quotaCards`:

- `title`: card title.
- `percentRemaining`: number from `0` to `100`.
- `resetText`: footer text, such as a reset time.

Live Codex quota uses the unofficial ChatGPT backend endpoint `https://chatgpt.com/backend-api/wham/usage` with the access token and account id from the local Codex auth file. Tokens are read at runtime and are not written to `config/status.json` or logs.

OpenAI's public API supports organization usage and cost reporting, but ChatGPT/Codex client quota percentages are not exposed through normal project API keys. To add an API cost card, set `openai.enabled` to `true`, configure `openai.monthlyBudgetUsd`, and set a user environment variable named `OPENAI_ADMIN_KEY`.

```powershell
[Environment]::SetEnvironmentVariable('OPENAI_ADMIN_KEY', '<your-admin-key>', 'User')
```

Do not put API keys in `config/status.json`.

## Troubleshooting

Logs are written to `logs/taskbar-status.log`. The `logs/` directory is ignored by Git.

To restart the widget after editing scripts, exit from the tray menu and run the command in the Run section again. If the tray icon disappears unexpectedly, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\TaskbarCodexStatus.ps1 -SmokeTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\TaskbarCodexStatus.ps1 -FlyoutSmokeTest
```

## Validate

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\src\TaskbarCodexStatus.ps1 -Validate
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\src\TaskbarCodexStatus.ps1 -SmokeTest
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\TaskbarGeometry.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\TrayIcon.Tests.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\OpenAIQuota.Tests.ps1
git diff --check
```

## Notes

Windows 11 does not expose a stable public API for third-party text widgets directly inside the taskbar. This project uses the stable notification-area icon and custom hover flyout approach.
