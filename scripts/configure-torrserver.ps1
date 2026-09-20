<#
.SYNOPSIS
    TorrServer Configuration Script for Android TV (2GB RAM devices).
.DESCRIPTION
    Applies high-speed RAM buffering (80MB cache, 25% preload = 20MB) to ensure instant
    startup within 8-12 seconds and prevent LowMemoryKiller crashes during 4K streaming.
#>
param(
    [string]$TorrServerUrl = "http://192.168.0.22:8090"
)

Write-Host "Configuring TorrServer at $TorrServerUrl..." -ForegroundColor Cyan

$payload = @{
    action = "set"
    sets = @{
        UseDisk = $false
        CacheSize = 83886080          # 80 MB RAM buffer
        ReaderReadAHead = 95          # 95% lookahead
        PreloadCache = 25             # 25% of 80MB = 20 MB (starts in 8-12s)
        RemoveCacheOnDrop = $true
        ConnectionsLimit = 30
        DisableTCP = $false
        DisableUTP = $false
        DisablePEX = $false
        DisableDHT = $false
        DisableUpload = $false
    }
} | ConvertTo-Json -Depth 5

try {
    Invoke-RestMethod -Uri "$TorrServerUrl/settings" -Method Post -Body $payload -ContentType "application/json" -TimeoutSec 10
    Write-Host "Successfully configured TorrServer!" -ForegroundColor Green
    
    $current = Invoke-RestMethod -Uri "$TorrServerUrl/settings" -Method Post -Body '{"action":"get"}' -ContentType "application/json"
    Write-Host "Current Cache Size: $([math]::Round($current.CacheSize / 1MB)) MB" -ForegroundColor Yellow
    Write-Host "Preload Percentage: $($current.PreloadCache)%" -ForegroundColor Yellow
    Write-Host "Use Disk: $($current.UseDisk)" -ForegroundColor Yellow
} catch {
    Write-Error "Failed to update TorrServer settings: $_"
}
