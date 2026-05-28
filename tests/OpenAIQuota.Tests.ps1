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

Write-Host 'OpenAI quota tests passed.'
