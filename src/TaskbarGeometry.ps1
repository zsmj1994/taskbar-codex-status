Set-StrictMode -Version 3.0

function Get-FlyoutWindowPosition {
    param(
        [double]$CursorX,
        [double]$CursorY,
        [double]$WorkingLeft,
        [double]$WorkingTop,
        [double]$WorkingRight,
        [double]$WorkingBottom,
        [double]$FlyoutWidth,
        [double]$FlyoutHeight,
        [double]$Gap,
        [double]$Margin,
        [double]$DpiScaleX = 1,
        [double]$DpiScaleY = 1
    )

    if ($DpiScaleX -le 0) {
        $DpiScaleX = 1
    }

    if ($DpiScaleY -le 0) {
        $DpiScaleY = 1
    }

    $dipCursorX = $CursorX / $DpiScaleX
    $dipCursorY = $CursorY / $DpiScaleY
    $dipWorkingLeft = $WorkingLeft / $DpiScaleX
    $dipWorkingTop = $WorkingTop / $DpiScaleY
    $dipWorkingRight = $WorkingRight / $DpiScaleX
    $dipWorkingBottom = $WorkingBottom / $DpiScaleY

    $preferredLeft = $dipCursorX - ($FlyoutWidth / 2)
    $preferredTop = $dipCursorY - $FlyoutHeight - $Gap
    $minLeft = $dipWorkingLeft + $Margin
    $maxLeft = $dipWorkingRight - $FlyoutWidth - $Margin
    $minTop = $dipWorkingTop + $Margin
    $maxTop = $dipWorkingBottom - $FlyoutHeight - $Margin

    return @{
        Left = [Math]::Min([Math]::Max($preferredLeft, $minLeft), $maxLeft)
        Top = [Math]::Min([Math]::Max($preferredTop, $minTop), $maxTop)
    }
}
