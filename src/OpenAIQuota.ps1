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
