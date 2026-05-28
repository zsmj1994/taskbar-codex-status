Set-StrictMode -Version 3.0
Add-Type -AssemblyName System.Drawing

if (-not ('TaskbarCodexStatus.NativeIcon' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace TaskbarCodexStatus {
    public static class NativeIcon {
        [DllImport("user32.dll", SetLastError = true)]
        public static extern bool DestroyIcon(IntPtr hIcon);
    }
}
'@
}

function ConvertTo-DrawingColor {
    param(
        [string]$Color,
        [string]$Fallback
    )

    try {
        return [System.Drawing.ColorTranslator]::FromHtml($Color)
    }
    catch {
        return [System.Drawing.ColorTranslator]::FromHtml($Fallback)
    }
}

function Get-TrayBadgeText {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ''
    }

    $trimmed = $Value.Trim()
    $number = 0
    if ([int]::TryParse($trimmed, [ref]$number)) {
        if ($number -gt 99) {
            return '99+'
        }

        return $trimmed
    }

    if ($trimmed.Length -gt 2) {
        return $trimmed.Substring(0, 1).ToUpperInvariant()
    }

    return $trimmed.ToUpperInvariant()
}

function Get-TrayRingLabel {
    param([double]$Percent)

    $clamped = [Math]::Min(100, [Math]::Max(0, [Math]::Round($Percent, 0)))
    return ('{0:N0}' -f $clamped)
}

function Get-TrayRingFontSize {
    param([string]$Label)

    if ($Label.Length -ge 3) {
        return 9
    }

    if ($Label.Length -eq 2) {
        return 12
    }

    return 14
}

function New-TrayStatusIcon {
    param(
        [string]$BadgeText,
        [string]$BadgeColor,
        [string]$BadgeForegroundColor,
        [string]$DotColor,
        [bool]$ShowDot,
        [object]$RingPercent = $null,
        [string]$RingColor,
        [string]$RingTrackColor
    )

    $bitmap = [System.Drawing.Bitmap]::new(32, 32, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $badgeBrush = $null
    $textBrush = $null
    $dotBrush = $null
    $shadowBrush = $null
    $ringPen = $null
    $ringTrackPen = $null
    $font = $null
    $format = $null

    try {
        $badgeBrush = [System.Drawing.SolidBrush]::new((ConvertTo-DrawingColor -Color $BadgeColor -Fallback '#2563EB'))
        $textBrush = [System.Drawing.SolidBrush]::new((ConvertTo-DrawingColor -Color $BadgeForegroundColor -Fallback '#FFFFFF'))
        $dotBrush = [System.Drawing.SolidBrush]::new((ConvertTo-DrawingColor -Color $DotColor -Fallback '#EF4444'))
        $shadowBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(50, 0, 0, 0))
        $ringColorValue = ConvertTo-DrawingColor -Color $RingColor -Fallback '#22C55E'
        $ringTrackColorValue = ConvertTo-DrawingColor -Color $RingTrackColor -Fallback '#334155'
        $ringPen = [System.Drawing.Pen]::new($ringColorValue, 5)
        $ringTrackPen = [System.Drawing.Pen]::new($ringTrackColorValue, 5)
        $ringPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $ringPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $ringTrackPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $ringTrackPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $fontSize = 13
        $hasRingPercent = $null -ne $RingPercent -and "$RingPercent".Length -gt 0
        $ringPercentValue = if ($hasRingPercent) { [double]$RingPercent } else { 0 }
        $text = if ($hasRingPercent) {
            Get-TrayRingLabel -Percent $ringPercentValue
        }
        else {
            Get-TrayBadgeText -Value $BadgeText
        }

        if ($hasRingPercent) {
            $fontSize = Get-TrayRingFontSize -Label $text
        }
        elseif ($text.Length -ge 3) {
            $fontSize = 8
        }
        elseif ($text.Length -eq 2) {
            $fontSize = 11
        }

        $font = [System.Drawing.Font]::new('Segoe UI', $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        $format = [System.Drawing.StringFormat]::new()
        $format.Alignment = [System.Drawing.StringAlignment]::Center
        $format.LineAlignment = [System.Drawing.StringAlignment]::Center

        if ($hasRingPercent) {
            $percent = [Math]::Min(100, [Math]::Max(0, $ringPercentValue))
            $graphics.FillEllipse($shadowBrush, 2, 3, 28, 28)
            $graphics.FillEllipse($badgeBrush, 4, 4, 24, 24)
            $graphics.DrawArc($ringTrackPen, 3, 3, 26, 26, -90, 360)
            $graphics.DrawArc($ringPen, 3, 3, 26, 26, -90, [single](360 * ($percent / 100)))
        }
        else {
            $graphics.FillEllipse($shadowBrush, 3, 4, 25, 25)
            $graphics.FillEllipse($badgeBrush, 2, 2, 26, 26)
        }

        if ($text.Length -gt 0) {
            $graphics.DrawString($text, $font, $textBrush, [System.Drawing.RectangleF]::new(1, 2, 30, 28), $format)
        }

        if ($ShowDot) {
            $graphics.FillEllipse([System.Drawing.Brushes]::White, 20, 1, 11, 11)
            $graphics.FillEllipse($dotBrush, 22, 3, 7, 7)
        }

        $handle = $bitmap.GetHicon()
        try {
            $icon = [System.Drawing.Icon]::FromHandle($handle)
            return $icon.Clone()
        }
        finally {
            [TaskbarCodexStatus.NativeIcon]::DestroyIcon($handle) | Out-Null
        }
    }
    finally {
        if ($null -ne $format) { $format.Dispose() }
        if ($null -ne $font) { $font.Dispose() }
        if ($null -ne $shadowBrush) { $shadowBrush.Dispose() }
        if ($null -ne $dotBrush) { $dotBrush.Dispose() }
        if ($null -ne $textBrush) { $textBrush.Dispose() }
        if ($null -ne $badgeBrush) { $badgeBrush.Dispose() }
        if ($null -ne $ringTrackPen) { $ringTrackPen.Dispose() }
        if ($null -ne $ringPen) { $ringPen.Dispose() }
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}
