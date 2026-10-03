<#
.SYNOPSIS
    Uploads a Money Forward CSV export to S3 and loads it into Snowflake (COPY INTO + MERGE).
    See .steering/20261003-ingestion-pipeline/design.md for details.

.PARAMETER CsvPath
    Path to the local CSV file (a real Money Forward export, or the sample_data/ dummy file).

.PARAMETER Env
    "prod" or "dev".

.EXAMPLE
    .\upload_and_load_moneyforward.ps1 -CsvPath "C:\path\to\export.csv" -Env dev
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$CsvPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet("prod", "dev")]
    [string]$Env
)

$ErrorActionPreference = "Stop"
chcp 65001 | Out-Null
$env:PYTHONUTF8 = "1"

$AwsExe = "C:\Program Files\Amazon\AWSCLIV2\aws.exe"
$Bucket = "practice-data-platform-raw"
$Timestamp = Get-Date -Format "yyyyMMddHHmmss"
$S3FileName = "transactions_$Timestamp.csv"
$InboxKey = "$Env/moneyforward/transactions/inbox/$S3FileName"
$ArchiveKey = "$Env/moneyforward/transactions/archive/$S3FileName"
$LoadSqlFile = Join-Path $PSScriptRoot "load_moneyforward_transactions_$Env.sql"

if (-not (Test-Path $CsvPath)) {
    throw "CSV file not found: $CsvPath"
}

Write-Host "Step 1/3: Uploading to s3://$Bucket/$InboxKey"
& $AwsExe s3 cp "$CsvPath" "s3://$Bucket/$InboxKey"
if ($LASTEXITCODE -ne 0) { throw "Upload to S3 failed." }

Write-Host "Step 2/3: Loading into Snowflake (COPY INTO + MERGE)..."
snow sql -f "$LoadSqlFile"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Snowflake load failed. Removing the uploaded file from inbox to avoid leaving a stale duplicate for the next run..."
    & $AwsExe s3 rm "s3://$Bucket/$InboxKey"
    throw "Snowflake load failed. The uploaded file was removed from inbox; re-run this script with the original CSV once the issue is fixed."
}

Write-Host "Step 3/3: Load succeeded. Moving file from inbox to archive..."
& $AwsExe s3 mv "s3://$Bucket/$InboxKey" "s3://$Bucket/$ArchiveKey"
if ($LASTEXITCODE -ne 0) { throw "Move to archive failed (load itself succeeded)." }

Write-Host "Done: $S3FileName loaded into the $Env environment."
