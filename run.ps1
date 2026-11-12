# Usage:  .\run.ps1 -Environment dev  -Action plan|apply|destroy
param(
    [Parameter(Mandatory = $true)][ValidateSet('dev', 'prod')][string]$Environment,
    [ValidateSet('plan', 'apply', 'destroy')][string]$Action = 'plan'
)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not $env:ARM_SUBSCRIPTION_ID) {
    $env:ARM_SUBSCRIPTION_ID = (az account show --query id -o tsv)
    if (-not $env:ARM_SUBSCRIPTION_ID) { throw "Not logged in. Run: az login" }
}
Write-Host "==> $Action $($Environment.ToUpper()) | subscription $env:ARM_SUBSCRIPTION_ID" -ForegroundColor Cyan

terraform init -input=false
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Separate state file per environment, so dev and prod never touch each other.
terraform $Action "-var-file=$Environment.tfvars" "-state=$Environment.tfstate"
exit $LASTEXITCODE
