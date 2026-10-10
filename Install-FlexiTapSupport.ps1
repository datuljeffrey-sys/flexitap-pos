<#
.SYNOPSIS
    FlexiTap Remote Support Helper (Windows)
    Automatically downloads and configures RustDesk for the FlexiTap self-hosted relay.
#>
$ErrorActionPreference = 'Stop'
$ServerId = "rustdesk.flexitapapp.com"
$ServerKey = "DupmnPdDGeoTy26tsw0JqfcU9rmh5hBotMp8mQMsqAg="

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "   FlexiTap POS Support Helper Setup     " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

$RustDeskUrl = "https://github.com/rustdesk/rustdesk/releases/latest/download/rustdesk-x86_64.exe"
$TempPath = Join-Path $env:TEMP "RustDesk-FlexiTap.exe"

try {
    Write-Host "Downloading support client..." -ForegroundColor Yellow
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $RustDeskUrl -OutFile $TempPath -UseBasicParsing

    Write-Host "Configuring and launching RustDesk..." -ForegroundColor Green
    Start-Process -FilePath $TempPath -ArgumentList "--server", $ServerId, "--key", $ServerKey

    Write-Host "Success! Please look at your RustDesk screen and share your 9-digit ID with your agent." -ForegroundColor Cyan
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    Write-Host "Please install RustDesk from https://rustdesk.com and configure Settings -> ID/Relay Server to: $ServerId" -ForegroundColor Yellow
}
