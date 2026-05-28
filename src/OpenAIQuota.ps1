Set-StrictMode -Version 3.0

function Get-QuotaPercentRemaining {
    param(
        [double]$Used,
        [double]$Limit
    )

    if ($Limit -le 0) {
        return 0
    }

    $remaining = (($Limit - $Used) / $Limit) * 100
    return [Math]::Min(100, [Math]::Max(0, [Math]::Round($remaining, 0)))
}

function ConvertTo-QuotaCard {
    param(
        [string]$Title,
        [double]$Used,
        [double]$Limit,
        [string]$ResetText
    )

    return [pscustomobject]@{
        title = $Title
        percentRemaining = Get-QuotaPercentRemaining -Used $Used -Limit $Limit
        resetText = $ResetText
    }
}

function ConvertFrom-OpenAICostResponse {
    param(
        [object]$Response,
        [double]$MonthlyBudgetUsd
    )

    $totalCost = 0.0
    if ($null -ne $Response -and $Response.PSObject.Properties.Name -contains 'data') {
        foreach ($bucket in @($Response.data)) {
            foreach ($result in @($bucket.results)) {
                if ($null -ne $result.amount -and $null -ne $result.amount.value) {
                    $totalCost += [double]$result.amount.value
                }
            }
        }
    }

    return ConvertTo-QuotaCard `
        -Title 'OpenAI API 本月预算' `
        -Used $totalCost `
        -Limit $MonthlyBudgetUsd `
        -ResetText ('已使用 ${0:N2} / ${1:N2}' -f $totalCost, $MonthlyBudgetUsd)
}

function Get-QuotaRefreshSeconds {
    param([object]$Config)

    $seconds = 300
    if ($null -ne $Config -and $Config.PSObject.Properties.Name -contains 'quotaRefreshSeconds') {
        $seconds = [int]$Config.quotaRefreshSeconds
    }
    elseif ($null -ne $Config -and $Config.PSObject.Properties.Name -contains 'openai' -and $Config.openai.PSObject.Properties.Name -contains 'refreshSeconds') {
        $seconds = [int]$Config.openai.refreshSeconds
    }
    elseif ($null -ne $Config -and $Config.PSObject.Properties.Name -contains 'openai' -and $Config.openai.PSObject.Properties.Name -contains 'refreshMinutes') {
        $seconds = [int]$Config.openai.refreshMinutes * 60
    }

    if ($seconds -lt 5) {
        return 5
    }

    return $seconds
}

function ConvertTo-LocalResetText {
    param(
        [object]$ResetAt,
        [bool]$IncludeDate
    )

    if ($null -eq $ResetAt -or "$ResetAt".Length -eq 0) {
        return ''
    }

    try {
        $date = [DateTimeOffset]::FromUnixTimeSeconds([int64]$ResetAt).LocalDateTime
        if ($IncludeDate) {
            return 'Reset: {0:yyyy-MM-dd HH:mm}' -f $date
        }

        return 'Reset: {0:HH:mm}' -f $date
    }
    catch {
        return ''
    }
}

function ConvertFrom-ChatGPTUsageWindow {
    param(
        [string]$Title,
        [object]$Window,
        [bool]$IncludeDate
    )

    if ($null -eq $Window) {
        return $null
    }

    $usedPercent = 0
    if ($Window.PSObject.Properties.Name -contains 'used_percent' -and $null -ne $Window.used_percent) {
        $usedPercent = [double]$Window.used_percent
    }

    $resetAt = $null
    if ($Window.PSObject.Properties.Name -contains 'reset_at') {
        $resetAt = $Window.reset_at
    }

    return [pscustomobject]@{
        title = $Title
        percentRemaining = [Math]::Min(100, [Math]::Max(0, [Math]::Round(100 - $usedPercent, 0)))
        resetText = ConvertTo-LocalResetText -ResetAt $resetAt -IncludeDate $IncludeDate
    }
}

function ConvertFrom-ChatGPTUsageResponse {
    param([object]$Response)

    $cards = @()

    if ($null -ne $Response -and $Response.PSObject.Properties.Name -contains 'rate_limit' -and $null -ne $Response.rate_limit) {
        $cards += ConvertFrom-ChatGPTUsageWindow -Title '5h usage limit' -Window $Response.rate_limit.primary_window -IncludeDate:$false
        $cards += ConvertFrom-ChatGPTUsageWindow -Title 'Weekly usage limit' -Window $Response.rate_limit.secondary_window -IncludeDate:$true
    }

    if ($null -ne $Response -and $Response.PSObject.Properties.Name -contains 'code_review_rate_limit' -and $null -ne $Response.code_review_rate_limit) {
        $cards += ConvertFrom-ChatGPTUsageWindow -Title 'GPT-5.3-Codex-Spark 5h usage limit' -Window $Response.code_review_rate_limit.primary_window -IncludeDate:$false
        $cards += ConvertFrom-ChatGPTUsageWindow -Title 'GPT-5.3-Codex-Spark weekly usage limit' -Window $Response.code_review_rate_limit.secondary_window -IncludeDate:$true
    }

    return @($cards | Where-Object { $null -ne $_ })
}

function Resolve-ConfigPathValue {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $Path
    }

    if ($Path.StartsWith('~')) {
        return Join-Path $env:USERPROFILE $Path.Substring(2)
    }

    return $Path
}

function Get-ChatGPTAuthFromFile {
    param([string]$AuthPath)

    $resolvedPath = Resolve-ConfigPathValue -Path $AuthPath
    if (-not (Test-Path -LiteralPath $resolvedPath)) {
        throw "ChatGPT auth file was not found: $resolvedPath"
    }

    $auth = Get-Content -LiteralPath $resolvedPath -Raw | ConvertFrom-Json
    if ($null -eq $auth.tokens -or [string]::IsNullOrWhiteSpace([string]$auth.tokens.access_token)) {
        throw "ChatGPT auth file does not contain tokens.access_token: $resolvedPath"
    }

    if ([string]::IsNullOrWhiteSpace([string]$auth.tokens.account_id)) {
        throw "ChatGPT auth file does not contain tokens.account_id: $resolvedPath"
    }

    return [pscustomobject]@{
        AccessToken = [string]$auth.tokens.access_token
        AccountId = [string]$auth.tokens.account_id
    }
}

function Invoke-ChatGPTUsageRequest {
    param(
        [string]$AccessToken,
        [string]$AccountId,
        [string]$BaseUrl
    )

    if ([string]::IsNullOrWhiteSpace($AccessToken)) {
        throw 'ChatGPT access token is not set.'
    }

    if ([string]::IsNullOrWhiteSpace($AccountId)) {
        throw 'ChatGPT account id is not set.'
    }

    $uri = '{0}/backend-api/wham/usage' -f $BaseUrl.TrimEnd('/')
    return Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 30 -Headers @{
        'user-agent' = 'codex_cli_rs/0.89.0 (Windows 10.0.26100; x86_64) WindowsTerminal'
        authorization = "Bearer $AccessToken"
        'chatgpt-account-id' = $AccountId
        accept = '*/*'
    }
}

function Get-ChatGPTQuotaCards {
    param([object]$Config)

    if ($null -eq $Config -or -not ($Config.PSObject.Properties.Name -contains 'chatgpt')) {
        return @()
    }

    $chatgptConfig = $Config.chatgpt
    $enabled = $false
    if ($chatgptConfig.PSObject.Properties.Name -contains 'enabled') {
        $enabled = [bool]$chatgptConfig.enabled
    }

    if (-not $enabled) {
        return @()
    }

    $baseUrl = 'https://chatgpt.com'
    if ($chatgptConfig.PSObject.Properties.Name -contains 'baseUrl') {
        $baseUrl = [string]$chatgptConfig.baseUrl
    }

    $authPath = '~\.codex\auth.json'
    if ($chatgptConfig.PSObject.Properties.Name -contains 'authPath') {
        $authPath = [string]$chatgptConfig.authPath
    }

    $auth = Get-ChatGPTAuthFromFile -AuthPath $authPath
    $response = Invoke-ChatGPTUsageRequest -AccessToken $auth.AccessToken -AccountId $auth.AccountId -BaseUrl $baseUrl
    return @(ConvertFrom-ChatGPTUsageResponse -Response $response)
}

function Invoke-OpenAICostsRequest {
    param(
        [string]$AdminKey,
        [string]$BaseUrl,
        [int]$Days
    )

    if ([string]::IsNullOrWhiteSpace($AdminKey)) {
        throw 'OPENAI_ADMIN_KEY is not set. Organization usage/cost APIs require an admin key.'
    }

    $startTime = [DateTimeOffset]::UtcNow.AddDays(-1 * [Math]::Max(1, $Days)).ToUnixTimeSeconds()
    $uri = '{0}/v1/organization/costs?start_time={1}&bucket_width=1d' -f $BaseUrl.TrimEnd('/'), $startTime
    return Invoke-RestMethod -Method Get -Uri $uri -Headers @{
        Authorization = "Bearer $AdminKey"
    }
}

function Get-OpenAIQuotaCards {
    param(
        [object]$Config
    )

    if ($null -eq $Config -or -not ($Config.PSObject.Properties.Name -contains 'openai')) {
        return @()
    }

    $apiConfig = $Config.openai
    $enabled = $false
    if ($null -ne $apiConfig -and $apiConfig.PSObject.Properties.Name -contains 'enabled') {
        $enabled = [bool]$apiConfig.enabled
    }

    if (-not $enabled) {
        return @()
    }

    $adminKeyEnv = 'OPENAI_ADMIN_KEY'
    if ($apiConfig.PSObject.Properties.Name -contains 'adminKeyEnv') {
        $adminKeyEnv = [string]$apiConfig.adminKeyEnv
    }

    $baseUrl = 'https://api.openai.com'
    if ($apiConfig.PSObject.Properties.Name -contains 'baseUrl') {
        $baseUrl = [string]$apiConfig.baseUrl
    }

    $days = 30
    if ($apiConfig.PSObject.Properties.Name -contains 'costWindowDays') {
        $days = [int]$apiConfig.costWindowDays
    }

    $monthlyBudgetUsd = 0
    if ($apiConfig.PSObject.Properties.Name -contains 'monthlyBudgetUsd') {
        $monthlyBudgetUsd = [double]$apiConfig.monthlyBudgetUsd
    }

    $adminKey = [Environment]::GetEnvironmentVariable($adminKeyEnv, 'User')
    if ([string]::IsNullOrWhiteSpace($adminKey)) {
        $adminKey = [Environment]::GetEnvironmentVariable($adminKeyEnv, 'Process')
    }
    if ([string]::IsNullOrWhiteSpace($adminKey)) {
        $adminKey = [Environment]::GetEnvironmentVariable($adminKeyEnv, 'Machine')
    }

    $response = Invoke-OpenAICostsRequest -AdminKey $adminKey -BaseUrl $baseUrl -Days $days
    return @((ConvertFrom-OpenAICostResponse -Response $response -MonthlyBudgetUsd $monthlyBudgetUsd))
}
