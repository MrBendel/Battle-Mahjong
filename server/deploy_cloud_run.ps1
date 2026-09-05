param (
    [string]$ProjectId = "",
    [string]$ServiceName = "battle-mahjong-backend",
    [string]$Region = "us-central1"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    $ProjectId = (gcloud config get-value project 2>$null)
}

if ([string]::IsNullOrWhiteSpace($ProjectId)) {
    Write-Error "No GCP project specified. Pass -ProjectId <ID> or run 'gcloud config set project <ID>'."
    exit 1
}

Write-Host "=== Deploying Battle Mahjong Backend to Cloud Run ===" -ForegroundColor Cyan
Write-Host "Project: $ProjectId"
Write-Host "Service: $ServiceName"
Write-Host "Region:  $Region"

$ServerDir = Split-Path -Parent $MyInvocation.MyCommand.Path

gcloud run deploy $ServiceName `
    --project=$ProjectId `
    --region=$Region `
    --source=$ServerDir `
    --allow-unauthenticated `
    --port=8080

$ServiceUrl = (gcloud run services describe $ServiceName --project=$ProjectId --region=$Region --format="value(status.url)")
Write-Host "`n=== Deployment Succeeded ===" -ForegroundColor Green
Write-Host "Startup Endpoint URL: $($ServiceUrl.Trim())/v1/startup" -ForegroundColor Yellow
