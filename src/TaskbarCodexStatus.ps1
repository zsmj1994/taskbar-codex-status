param(
    [string]$ConfigPath,
    [switch]$Validate,
    [switch]$SmokeTest,
    [switch]$FlyoutSmokeTest
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'TaskbarGeometry.ps1')
. (Join-Path $PSScriptRoot 'TrayIcon.ps1')
. (Join-Path $PSScriptRoot 'OpenAIQuota.ps1')

$LogPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'logs/taskbar-status.log'

function Write-AppLog {
    param([string]$Message)

    try {
        $logDirectory = Split-Path -Parent $LogPath
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory | Out-Null
        }

        $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
        Add-Content -LiteralPath $LogPath -Value "[$timestamp] $Message" -Encoding UTF8
    }
    catch {
    }
}

[AppDomain]::CurrentDomain.add_UnhandledException({
    param($sender, $eventArgs)
    Write-AppLog -Message "Unhandled exception: $($eventArgs.ExceptionObject)"
})

if (-not $ConfigPath) {
    $appRoot = Split-Path -Parent $PSScriptRoot
    $ConfigPath = Join-Path $appRoot 'config/status.json'
}

$ConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)

function Ensure-ConfigFile {
    param([string]$Path)

    if (Test-Path -LiteralPath $Path) {
        return
    }

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    $defaultConfig = @{
        refreshSeconds = 5
        tray = @{
            mode = 'quotaRing'
            quotaCardIndex = 0
            badgeText = 'AI'
            badgeColor = '#111827'
            badgeForegroundColor = '#FFFFFF'
            dotColor = '#EF4444'
            showDot = $false
            ringColor = '#22C55E'
            ringTrackColor = '#334155'
            tooltip = 'Codex quota'
        }
        flyout = @{
            title = 'Quota'
            description = 'Codex usage is deducted from your shared agentic usage limits.'
        }
        quotaCards = @(
            @{ title = '5h usage limit'; percentRemaining = 99; resetText = 'Reset: 19:18' },
            @{ title = 'Weekly usage limit'; percentRemaining = 90; resetText = 'Reset: 2026-06-02 13:43' },
            @{ title = 'GPT-5.3-Codex-Spark 5h usage limit'; percentRemaining = 100; resetText = '' },
            @{ title = 'GPT-5.3-Codex-Spark weekly usage limit'; percentRemaining = 100; resetText = '' }
        )
        openai = @{
            enabled = $false
            adminKeyEnv = 'OPENAI_ADMIN_KEY'
            baseUrl = 'https://api.openai.com'
            costWindowDays = 30
            monthlyBudgetUsd = 20
            refreshMinutes = 15
        }
    }

    $defaultConfig | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name,
        [object]$DefaultValue
    )

    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains $Name) {
        $value = $Config.$Name
        if ($null -ne $value -and "$value".Length -gt 0) {
            return $value
        }
    }

    return $DefaultValue
}

function Read-StatusConfig {
    param([string]$Path)

    Ensure-ConfigFile -Path $Path
    $json = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    return $json | ConvertFrom-Json
}

function New-Brush {
    param(
        [string]$Color,
        [string]$Fallback
    )

    try {
        $converted = [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
        return [System.Windows.Media.SolidColorBrush]::new($converted)
    }
    catch {
        $converted = [System.Windows.Media.ColorConverter]::ConvertFromString($Fallback)
        return [System.Windows.Media.SolidColorBrush]::new($converted)
    }
}

try {
    $initialConfig = Read-StatusConfig -Path $ConfigPath
    if ($Validate) {
        Write-Host "Validation passed: $ConfigPath"
        exit 0
    }
}
catch {
    if ($Validate) {
        Write-Error $_
        exit 1
    }

    throw
}

if ([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
    $quotedScript = '"' + $PSCommandPath + '"'
    $quotedConfig = '"' + $ConfigPath + '"'
    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-STA',
        '-File',
        $quotedScript,
        '-ConfigPath',
        $quotedConfig
    )

    if ($SmokeTest) {
        $arguments += '-SmokeTest'
    }

    if ($FlyoutSmokeTest) {
        $arguments += '-FlyoutSmokeTest'
    }

    Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments
    exit 0
}

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

[System.Windows.Threading.Dispatcher]::CurrentDispatcher.add_UnhandledException({
    param($sender, $eventArgs)
    Write-AppLog -Message "Dispatcher exception: $($eventArgs.Exception.Message)"
    $eventArgs.Handled = $true
})

$flyoutWindow = [System.Windows.Window]::new()
$flyoutWindow.WindowStyle = [System.Windows.WindowStyle]::None
$flyoutWindow.ResizeMode = [System.Windows.ResizeMode]::NoResize
$flyoutWindow.AllowsTransparency = $true
$flyoutWindow.Background = [System.Windows.Media.Brushes]::Transparent
$flyoutWindow.Topmost = $true
$flyoutWindow.ShowInTaskbar = $false
$flyoutWindow.ShowActivated = $false
$flyoutWindow.Width = 620
$flyoutWindow.Height = 430

$flyoutRoot = [System.Windows.Controls.Border]::new()
$flyoutRoot.CornerRadius = [System.Windows.CornerRadius]::new(12)
$flyoutRoot.Padding = [System.Windows.Thickness]::new(22, 18, 22, 20)
$flyoutRoot.Background = New-Brush -Color '#050505' -Fallback '#050505'
$flyoutRoot.BorderBrush = New-Brush -Color '#242424' -Fallback '#242424'
$flyoutRoot.BorderThickness = [System.Windows.Thickness]::new(1)

$flyoutGrid = [System.Windows.Controls.Grid]::new()
$headerRow = [System.Windows.Controls.RowDefinition]::new()
$headerRow.Height = [System.Windows.GridLength]::Auto
$flyoutGrid.RowDefinitions.Add($headerRow) | Out-Null
$cardsRow = [System.Windows.Controls.RowDefinition]::new()
$cardsRow.Height = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
$flyoutGrid.RowDefinitions.Add($cardsRow) | Out-Null

$flyoutHeader = [System.Windows.Controls.Grid]::new()
$flyoutHeader.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) | Out-Null
$flyoutHeader.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) | Out-Null

$flyoutTitle = [System.Windows.Controls.TextBlock]::new()
$flyoutTitle.FontSize = 24
$flyoutTitle.FontWeight = [System.Windows.FontWeights]::Bold
$flyoutTitle.Foreground = New-Brush -Color '#F9FAFB' -Fallback '#F9FAFB'
$flyoutTitle.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
[System.Windows.Controls.Grid]::SetRow($flyoutTitle, 0)
$flyoutHeader.Children.Add($flyoutTitle) | Out-Null

$flyoutDescription = [System.Windows.Controls.TextBlock]::new()
$flyoutDescription.FontSize = 13
$flyoutDescription.Foreground = New-Brush -Color '#F3F4F6' -Fallback '#F3F4F6'
$flyoutDescription.Margin = [System.Windows.Thickness]::new(0, 6, 0, 0)
$flyoutDescription.TextWrapping = [System.Windows.TextWrapping]::Wrap
[System.Windows.Controls.Grid]::SetRow($flyoutDescription, 1)
$flyoutHeader.Children.Add($flyoutDescription) | Out-Null
[System.Windows.Controls.Grid]::SetRow($flyoutHeader, 0)
$flyoutGrid.Children.Add($flyoutHeader) | Out-Null

$quotaCardsGrid = [System.Windows.Controls.Grid]::new()
$quotaCardsGrid.Margin = [System.Windows.Thickness]::new(0, 22, 0, 0)
$quotaCardsGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new()) | Out-Null
$quotaCardsGrid.ColumnDefinitions.Add([System.Windows.Controls.ColumnDefinition]::new()) | Out-Null
$quotaCardsGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) | Out-Null
$quotaCardsGrid.RowDefinitions.Add([System.Windows.Controls.RowDefinition]::new()) | Out-Null
[System.Windows.Controls.Grid]::SetRow($quotaCardsGrid, 1)
$flyoutGrid.Children.Add($quotaCardsGrid) | Out-Null
$flyoutRoot.Child = $flyoutGrid
$flyoutWindow.Content = $flyoutRoot
$script:lastFlyoutTouch = [DateTime]::MinValue
$script:trayIconImage = $null
$script:quotaCards = @()
$script:quotaError = $null
$script:lastQuotaRefresh = [DateTime]::MinValue

$currentConfig = $initialConfig

function Update-AppState {
    try {
        $script:currentConfig = Read-StatusConfig -Path $ConfigPath
        Update-TrayIcon -Config $script:currentConfig
        Update-TrayFlyout -Config $script:currentConfig
    }
    catch {
        Write-AppLog -Message "Update failed: $($_.Exception.Message)"
    }
}

function Get-NestedConfigValue {
    param(
        [object]$Config,
        [string]$Section,
        [string]$Name,
        [object]$DefaultValue
    )

    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains $Section) {
        return Get-ConfigValue -Config $Config.$Section -Name $Name -DefaultValue $DefaultValue
    }

    return $DefaultValue
}

function Update-TrayIcon {
    param([object]$Config)

    if (-not (Get-Variable -Name notifyIcon -Scope Script -ErrorAction SilentlyContinue)) {
        return
    }

    $trayMode = [string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'mode' -DefaultValue 'badge')
    $ringPercent = $null
    $tooltip = [string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'tooltip' -DefaultValue (Get-ConfigValue -Config $Config -Name 'tooltip' -DefaultValue 'Taskbar Codex Status'))

    if ($trayMode -eq 'quotaRing') {
        Update-QuotaData -Config $Config
        $quotaIndex = [int](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'quotaCardIndex' -DefaultValue 0)
        $cards = @($script:quotaCards)
        if ($cards.Count -gt 0) {
            if ($quotaIndex -lt 0 -or $quotaIndex -ge $cards.Count) {
                $quotaIndex = 0
            }

            $quotaCard = $cards[$quotaIndex]
            $ringPercent = [double](Get-ConfigValue -Config $quotaCard -Name 'percentRemaining' -DefaultValue 0)
            $quotaTitle = [string](Get-ConfigValue -Config $quotaCard -Name 'title' -DefaultValue 'Quota')
            $tooltip = '{0}: {1}% remaining' -f $quotaTitle, (Get-TrayRingLabel -Percent $ringPercent)
        }
    }

    $newIcon = New-TrayStatusIcon `
        -BadgeText ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'badgeText' -DefaultValue (Get-ConfigValue -Config $Config -Name 'badgeText' -DefaultValue 'AI'))) `
        -BadgeColor ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'badgeColor' -DefaultValue '#2563EB')) `
        -BadgeForegroundColor ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'badgeForegroundColor' -DefaultValue '#FFFFFF')) `
        -DotColor ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'dotColor' -DefaultValue '#EF4444')) `
        -ShowDot ([bool](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'showDot' -DefaultValue $false)) `
        -RingPercent $ringPercent `
        -RingColor ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'ringColor' -DefaultValue '#22C55E')) `
        -RingTrackColor ([string](Get-NestedConfigValue -Config $Config -Section 'tray' -Name 'ringTrackColor' -DefaultValue '#334155'))

    $oldIcon = $script:trayIconImage
    $script:trayIconImage = $newIcon
    $notifyIcon.Icon = $newIcon
    if ($tooltip.Length -gt 63) {
        $tooltip = $tooltip.Substring(0, 60) + '...'
    }
    $notifyIcon.Text = $tooltip

    if ($null -ne $oldIcon) {
        $oldIcon.Dispose()
    }
}

function New-QuotaCardView {
    param(
        [object]$Card
    )

    $cardRoot = [System.Windows.Controls.Border]::new()
    $cardRoot.CornerRadius = [System.Windows.CornerRadius]::new(16)
    $cardRoot.Padding = [System.Windows.Thickness]::new(18, 14, 18, 14)
    $cardRoot.Background = New-Brush -Color '#232323' -Fallback '#232323'
    $cardRoot.BorderBrush = New-Brush -Color '#303030' -Fallback '#303030'
    $cardRoot.BorderThickness = [System.Windows.Thickness]::new(1)
    $cardRoot.Margin = [System.Windows.Thickness]::new(0, 0, 14, 14)

    $stack = [System.Windows.Controls.StackPanel]::new()
    $stack.Orientation = [System.Windows.Controls.Orientation]::Vertical

    $cardTitle = [System.Windows.Controls.TextBlock]::new()
    $cardTitle.Text = [string](Get-ConfigValue -Config $Card -Name 'title' -DefaultValue 'Quota')
    $cardTitle.FontSize = 14
    $cardTitle.Foreground = New-Brush -Color '#CBD5E1' -Fallback '#CBD5E1'
    $cardTitle.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $stack.Children.Add($cardTitle) | Out-Null

    $percentRow = [System.Windows.Controls.StackPanel]::new()
    $percentRow.Orientation = [System.Windows.Controls.Orientation]::Horizontal
    $percentRow.Margin = [System.Windows.Thickness]::new(0, 9, 0, 0)

    $percentText = [System.Windows.Controls.TextBlock]::new()
    $percent = [double](Get-ConfigValue -Config $Card -Name 'percentRemaining' -DefaultValue 0)
    $percentText.Text = ('{0:N0}%' -f $percent)
    $percentText.FontSize = 24
    $percentText.FontWeight = [System.Windows.FontWeights]::Bold
    $percentText.Foreground = New-Brush -Color '#F9FAFB' -Fallback '#F9FAFB'

    $remainingText = [System.Windows.Controls.TextBlock]::new()
    $remainingText.Text = ' remaining'
    $remainingText.FontSize = 14
    $remainingText.FontWeight = [System.Windows.FontWeights]::SemiBold
    $remainingText.Foreground = New-Brush -Color '#F9FAFB' -Fallback '#F9FAFB'
    $remainingText.VerticalAlignment = [System.Windows.VerticalAlignment]::Center

    $percentRow.Children.Add($percentText) | Out-Null
    $percentRow.Children.Add($remainingText) | Out-Null
    $stack.Children.Add($percentRow) | Out-Null

    $track = [System.Windows.Controls.Grid]::new()
    $track.Height = 10
    $track.Margin = [System.Windows.Thickness]::new(0, 16, 0, 0)
    $track.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Stretch

    $trackBackground = [System.Windows.Controls.Border]::new()
    $trackBackground.CornerRadius = [System.Windows.CornerRadius]::new(5)
    $trackBackground.Background = New-Brush -Color '#E5E7EB' -Fallback '#E5E7EB'
    $track.Children.Add($trackBackground) | Out-Null

    $trackForeground = [System.Windows.Controls.Border]::new()
    $trackForeground.CornerRadius = [System.Windows.CornerRadius]::new(5)
    $trackForeground.Background = New-Brush -Color '#22C55E' -Fallback '#22C55E'
    $trackForeground.HorizontalAlignment = [System.Windows.HorizontalAlignment]::Left
    $trackForeground.Width = [Math]::Max(0, [Math]::Min(1, $percent / 100)) * 236
    $track.Children.Add($trackForeground) | Out-Null
    $stack.Children.Add($track) | Out-Null

    $resetText = [System.Windows.Controls.TextBlock]::new()
    $resetText.Text = [string](Get-ConfigValue -Config $Card -Name 'resetText' -DefaultValue '')
    $resetText.FontSize = 12
    $resetText.Foreground = New-Brush -Color '#CBD5E1' -Fallback '#CBD5E1'
    $resetText.Margin = [System.Windows.Thickness]::new(0, 16, 0, 0)
    $resetText.TextTrimming = [System.Windows.TextTrimming]::CharacterEllipsis
    $stack.Children.Add($resetText) | Out-Null

    $cardRoot.Child = $stack
    return $cardRoot
}

function Get-ConfiguredQuotaCards {
    param([object]$Config)

    $cards = @()
    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains 'quotaCards') {
        $cards = @($Config.quotaCards)
    }

    if ($cards.Count -eq 0) {
        $cards = @(
            [pscustomobject]@{ title = '5h usage limit'; percentRemaining = 99; resetText = 'Reset: 19:18' },
            [pscustomobject]@{ title = 'Weekly usage limit'; percentRemaining = 90; resetText = 'Reset: 2026-06-02 13:43' },
            [pscustomobject]@{ title = 'GPT-5.3-Codex-Spark 5h usage limit'; percentRemaining = 100; resetText = '' },
            [pscustomobject]@{ title = 'GPT-5.3-Codex-Spark weekly usage limit'; percentRemaining = 100; resetText = '' }
        )
    }

    return $cards
}

function Update-QuotaData {
    param(
        [object]$Config,
        [switch]$Force
    )

    $refreshMinutes = 15
    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains 'openai' -and $Config.openai.PSObject.Properties.Name -contains 'refreshMinutes') {
        $refreshMinutes = [int]$Config.openai.refreshMinutes
    }

    if (-not $Force -and $script:lastQuotaRefresh -gt [DateTime]::MinValue -and (([DateTime]::Now - $script:lastQuotaRefresh).TotalMinutes -lt $refreshMinutes)) {
        return
    }

    $script:lastQuotaRefresh = [DateTime]::Now
    $script:quotaError = $null
    $configuredCards = @(Get-ConfiguredQuotaCards -Config $Config)

    try {
        $apiCards = @(Get-OpenAIQuotaCards -Config $Config)
        if ($apiCards.Count -gt 0) {
            $script:quotaCards = @($apiCards + $configuredCards)
            return
        }
    }
    catch {
        $script:quotaError = $_.Exception.Message
        Write-AppLog -Message "OpenAI quota refresh failed: $script:quotaError"
    }

    $script:quotaCards = $configuredCards
}

function Update-TrayFlyout {
    param([object]$Config)

    Update-QuotaData -Config $Config
    $flyoutTitle.Text = [string](Get-NestedConfigValue -Config $Config -Section 'flyout' -Name 'title' -DefaultValue 'Quota')
    $description = [string](Get-NestedConfigValue -Config $Config -Section 'flyout' -Name 'description' -DefaultValue 'Codex usage is deducted from your shared agentic usage limits.')
    if (-not [string]::IsNullOrWhiteSpace($script:quotaError)) {
        $description = "$description`nOpenAI API: $script:quotaError"
    }
    $flyoutDescription.Text = $description

    $quotaCardsGrid.Children.Clear()
    $cards = @($script:quotaCards | Select-Object -First 4)
    for ($index = 0; $index -lt $cards.Count; $index++) {
        $cardView = New-QuotaCardView -Card $cards[$index]
        [System.Windows.Controls.Grid]::SetColumn($cardView, $index % 2)
        [System.Windows.Controls.Grid]::SetRow($cardView, [Math]::Floor($index / 2))
        $quotaCardsGrid.Children.Add($cardView) | Out-Null
    }

    $flyoutWindow.Height = 430
}

function Show-TrayFlyout {
    Write-AppLog -Message 'Show-TrayFlyout entered.'
    $script:lastFlyoutTouch = [DateTime]::Now
    Update-TrayFlyout -Config $script:currentConfig

    $cursor = [System.Windows.Forms.Cursor]::Position
    $screen = [System.Windows.Forms.Screen]::FromPoint($cursor)
    $work = $screen.WorkingArea
    $dpi = [System.Windows.Media.VisualTreeHelper]::GetDpi($flyoutWindow)
    $scaleX = if ($dpi.DpiScaleX -gt 0) { $dpi.DpiScaleX } else { 1 }
    $scaleY = if ($dpi.DpiScaleY -gt 0) { $dpi.DpiScaleY } else { 1 }

    $position = Get-FlyoutWindowPosition `
        -CursorX $cursor.X `
        -CursorY $cursor.Y `
        -WorkingLeft $work.Left `
        -WorkingTop $work.Top `
        -WorkingRight $work.Right `
        -WorkingBottom $work.Bottom `
        -FlyoutWidth $flyoutWindow.Width `
        -FlyoutHeight $flyoutWindow.Height `
        -Gap 10 `
        -Margin 8 `
        -DpiScaleX $scaleX `
        -DpiScaleY $scaleY

    Write-AppLog -Message "Flyout position cursor=($($cursor.X),$($cursor.Y)) work=($($work.Left),$($work.Top),$($work.Right),$($work.Bottom)) scale=($scaleX,$scaleY) size=($($flyoutWindow.Width),$($flyoutWindow.Height)) pos=($($position.Left),$($position.Top))."
    $flyoutWindow.Left = $position.Left
    $flyoutWindow.Top = $position.Top

    if (-not $flyoutWindow.IsVisible) {
        $flyoutWindow.Show()
    }

    Write-AppLog -Message "Flyout shown IsVisible=$($flyoutWindow.IsVisible) actual=($($flyoutWindow.ActualWidth),$($flyoutWindow.ActualHeight)) left/top=($($flyoutWindow.Left),$($flyoutWindow.Top))."
}

function Hide-TrayFlyout {
    if ($flyoutWindow.IsVisible) {
        Write-AppLog -Message 'Hide-TrayFlyout hiding visible flyout.'
        $flyoutWindow.Hide()
    }
}

if ($SmokeTest) {
    Update-AppState
    Write-Host "Smoke test passed: tray app initialized."
    exit 0
}

if ($FlyoutSmokeTest) {
    Update-AppState
    Show-TrayFlyout
    $flyoutWindow.Hide()
    Write-Host "Flyout smoke test passed: flyout show path executed."
    exit 0
}

$notifyIcon = [System.Windows.Forms.NotifyIcon]::new()
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
$notifyIcon.Text = [string](Get-ConfigValue -Config $currentConfig -Name 'tooltip' -DefaultValue 'Taskbar Codex Status')
$notifyIcon.Visible = $true

$menu = [System.Windows.Forms.ContextMenuStrip]::new()
$refreshItem = [System.Windows.Forms.ToolStripMenuItem]::new('Refresh')
$openConfigItem = [System.Windows.Forms.ToolStripMenuItem]::new('Open Config')
$exitItem = [System.Windows.Forms.ToolStripMenuItem]::new('Exit')

$refreshItem.Add_Click({ Update-AppState })
$openConfigItem.Add_Click({ Start-Process -FilePath 'notepad.exe' -ArgumentList @($ConfigPath) })

$menu.Items.Add($refreshItem) | Out-Null
$menu.Items.Add($openConfigItem) | Out-Null
$menu.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$menu.Items.Add($exitItem) | Out-Null
$notifyIcon.ContextMenuStrip = $menu
$notifyIcon.Add_DoubleClick({ Update-AppState })
$notifyIcon.Add_MouseMove({ Show-TrayFlyout })
$notifyIcon.Add_MouseClick({
    param($sender, $eventArgs)
    if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        Show-TrayFlyout
    }
})

$timer = [System.Windows.Threading.DispatcherTimer]::new()
$timer.Interval = [TimeSpan]::FromSeconds([double](Get-ConfigValue -Config $currentConfig -Name 'refreshSeconds' -DefaultValue 5))
$timer.Add_Tick({
    Update-AppState
    $seconds = [double](Get-ConfigValue -Config $script:currentConfig -Name 'refreshSeconds' -DefaultValue 5)
    if ($seconds -lt 1) {
        $seconds = 1
    }
    $timer.Interval = [TimeSpan]::FromSeconds($seconds)
})

$flyoutTimer = [System.Windows.Threading.DispatcherTimer]::new()
$flyoutTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$flyoutTimer.Add_Tick({
    if ($flyoutWindow.IsVisible -and (([DateTime]::Now - $script:lastFlyoutTouch).TotalMilliseconds -gt 1600)) {
        $point = [System.Windows.Input.Mouse]::GetPosition($flyoutWindow)
        $insideFlyout = $point.X -ge 0 -and $point.Y -ge 0 -and $point.X -le $flyoutWindow.ActualWidth -and $point.Y -le $flyoutWindow.ActualHeight
        if (-not $insideFlyout) {
            Hide-TrayFlyout
        }
    }
})

function Stop-App {
    $timer.Stop()
    $flyoutTimer.Stop()
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    if ($null -ne $script:trayIconImage) {
        $script:trayIconImage.Dispose()
    }
    $flyoutWindow.Close()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.InvokeShutdown()
}

$exitItem.Add_Click({ Stop-App })

Update-AppState
$timer.Start()
$flyoutTimer.Start()
[System.Windows.Threading.Dispatcher]::Run()
