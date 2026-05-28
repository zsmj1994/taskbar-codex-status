Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src/TaskbarGeometry.ps1')

function Assert-Equal {
    param(
        [object]$Actual,
        [object]$Expected,
        [string]$Message
    )

    if ($Actual -ne $Expected) {
        throw "$Message Expected '$Expected', got '$Actual'."
    }
}

$flyoutPosition = Get-FlyoutWindowPosition `
    -CursorX 790 `
    -CursorY 460 `
    -WorkingLeft 0 `
    -WorkingTop 0 `
    -WorkingRight 2560 `
    -WorkingBottom 1392 `
    -FlyoutWidth 360 `
    -FlyoutHeight 130 `
    -Gap 10 `
    -Margin 8 `
    -DpiScaleX 1 `
    -DpiScaleY 1

Assert-Equal -Actual $flyoutPosition.Left -Expected 610 -Message 'Flyout should center above the cursor.'
Assert-Equal -Actual $flyoutPosition.Top -Expected 320 -Message 'Flyout should open above the cursor instead of near the taskbar edge.'

Write-Host 'Taskbar geometry tests passed.'
