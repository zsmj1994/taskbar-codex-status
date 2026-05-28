Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $repoRoot 'src/OpenAIQuota.ps1')

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

Assert-Equal -Actual (Get-QuotaPercentRemaining -Used 1 -Limit 10) -Expected 90 -Message 'Remaining percentage should be based on used and limit.'
Assert-Equal -Actual (Get-QuotaPercentRemaining -Used 12 -Limit 10) -Expected 0 -Message 'Remaining percentage should not be negative.'
Assert-Equal -Actual (Get-QuotaPercentRemaining -Used 0 -Limit 0) -Expected 0 -Message 'Zero limit should return 0.'

$response = [pscustomobject]@{
    data = @(
        [pscustomobject]@{
            results = @(
                [pscustomobject]@{ amount = [pscustomobject]@{ value = 1.25 } },
                [pscustomobject]@{ amount = [pscustomobject]@{ value = 0.75 } }
            )
        }
    )
}

$card = ConvertFrom-OpenAICostResponse -Response $response -MonthlyBudgetUsd 20
Assert-Equal -Actual $card.title -Expected 'OpenAI API 本月预算' -Message 'Cost response should map to API budget card.'
Assert-Equal -Actual $card.percentRemaining -Expected 90 -Message 'Cost card should compute budget remaining.'
Assert-Equal -Actual $card.resetText -Expected '已使用 $2.00 / $20.00' -Message 'Cost card should include spend summary.'

$refreshConfig = [pscustomobject]@{ quotaRefreshSeconds = 120 }
Assert-Equal -Actual (Get-QuotaRefreshSeconds -Config $refreshConfig) -Expected 120 -Message 'Top-level quota refresh interval should be used.'

$legacyRefreshConfig = [pscustomobject]@{ openai = [pscustomobject]@{ refreshMinutes = 15 } }
Assert-Equal -Actual (Get-QuotaRefreshSeconds -Config $legacyRefreshConfig) -Expected 900 -Message 'Legacy minute interval should still work.'

$tooFastRefreshConfig = [pscustomobject]@{ quotaRefreshSeconds = 1 }
Assert-Equal -Actual (Get-QuotaRefreshSeconds -Config $tooFastRefreshConfig) -Expected 5 -Message 'Quota refresh interval should have a minimum.'

$chatGptResponse = [pscustomobject]@{
    rate_limit = [pscustomobject]@{
        primary_window = [pscustomobject]@{ used_percent = 10; reset_at = 1780000000 }
        secondary_window = [pscustomobject]@{ used_percent = 11; reset_at = 1780422180 }
    }
    code_review_rate_limit = [pscustomobject]@{
        primary_window = [pscustomobject]@{ used_percent = 0; reset_at = $null }
        secondary_window = [pscustomobject]@{ used_percent = 0; reset_at = $null }
    }
}

$chatGptCards = @(ConvertFrom-ChatGPTUsageResponse -Response $chatGptResponse)
Assert-Equal -Actual $chatGptCards.Count -Expected 4 -Message 'ChatGPT usage response should map to four quota cards.'
Assert-Equal -Actual $chatGptCards[0].percentRemaining -Expected 90 -Message 'Primary window should convert used percent to remaining percent.'
Assert-Equal -Actual $chatGptCards[1].percentRemaining -Expected 89 -Message 'Secondary window should convert used percent to remaining percent.'
Assert-Equal -Actual $chatGptCards[2].percentRemaining -Expected 100 -Message 'Code review primary window should map to Spark card.'

Write-Host 'OpenAI quota tests passed.'
