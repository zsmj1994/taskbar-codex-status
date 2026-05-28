Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src/TrayIcon.ps1')

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

$icon = New-TrayStatusIcon `
    -BadgeText '12' `
    -BadgeColor '#2563EB' `
    -BadgeForegroundColor '#FFFFFF' `
    -DotColor '#EF4444' `
    -ShowDot $true

try {
    Assert-True -Condition ($icon -is [System.Drawing.Icon]) -Message 'New-TrayStatusIcon should return a System.Drawing.Icon.'
    Assert-True -Condition ($icon.Width -eq 32) -Message 'Tray icon width should be 32.'
    Assert-True -Condition ($icon.Height -eq 32) -Message 'Tray icon height should be 32.'
}
finally {
    $icon.Dispose()
}

Assert-True -Condition ((Get-TrayBadgeText -Value '1234') -eq '99+') -Message 'Long numeric badge text should compact to 99+.'
Assert-True -Condition ((Get-TrayBadgeText -Value 'Ready') -eq 'R') -Message 'Long text badge should compact to its first letter.'

$ringIcon = New-TrayStatusIcon `
    -BadgeText 'AI' `
    -BadgeColor '#2563EB' `
    -BadgeForegroundColor '#FFFFFF' `
    -DotColor '#EF4444' `
    -ShowDot $false `
    -RingPercent 99 `
    -RingColor '#22C55E' `
    -RingTrackColor '#334155'

try {
    Assert-True -Condition ($ringIcon -is [System.Drawing.Icon]) -Message 'Ring mode should return a System.Drawing.Icon.'
    Assert-True -Condition ($ringIcon.Width -eq 32) -Message 'Ring icon width should be 32.'
    Assert-True -Condition ($ringIcon.Height -eq 32) -Message 'Ring icon height should be 32.'
}
finally {
    $ringIcon.Dispose()
}

Assert-True -Condition ((Get-TrayRingLabel -Percent 99) -eq '99') -Message 'Ring label should show the remaining percent number.'
Assert-True -Condition ((Get-TrayRingLabel -Percent 100) -eq '100') -Message 'Ring label should allow 100.'
Assert-True -Condition ((Get-TrayRingLabel -Percent -4) -eq '0') -Message 'Ring label should clamp negative values.'
Assert-True -Condition ((Get-TrayRingFontSize -Label '99') -eq 12) -Message 'Two-digit ring labels should be readable.'
Assert-True -Condition ((Get-TrayRingFontSize -Label '100') -eq 9) -Message 'Three-digit ring labels should fit.'

Write-Host 'Tray icon tests passed.'
