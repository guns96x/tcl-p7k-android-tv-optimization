<#
.SYNOPSIS
    Apply TCL P7K TorrServer cache settings without discarding other settings.
.DESCRIPTION
    TorrServer treats action=set as a complete replacement. Read and back up the
    current object, change only cache fields, then verify. A change restarts torrents.
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^https?://[^/]+/?$')]
    [string]$TorrServerUrl,
    [string]$BackupDirectory = (Join-Path $PSScriptRoot '..\state')
)

$ErrorActionPreference = 'Stop'
$settingsUrl = $TorrServerUrl.TrimEnd('/') + '/settings'

try {
    $current = Invoke-RestMethod -Uri $settingsUrl -Method Post -Body '{"action":"get"}' -ContentType 'application/json' -TimeoutSec 10
    if ($null -eq $current -or $null -eq $current.CacheSize -or $null -eq $current.PreloadCache) {
        throw 'TorrServer returned an incomplete settings object.'
    }

    $desired = [ordered]@{
        CacheSize = 80MB
        ReaderReadAHead = 95
        PreloadCache = 25
        UseDisk = $false
        RemoveCacheOnDrop = $true
        ConnectionsLimit = 30
        ResponsiveMode = $true
    }
    $changes = @($desired.Keys | Where-Object { $current.$_ -ne $desired[$_] })
    if ($changes.Count -eq 0) {
        Write-Host 'TorrServer cache settings already match; no session restart needed.'
        return
    }

    New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
    $backupPath = Join-Path $BackupDirectory ('torrserver-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.json')
    $current | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $backupPath -Encoding UTF8

    foreach ($key in $desired.Keys) {
        $current.$key = $desired[$key]
    }
    $payload = @{ action = 'set'; sets = $current } | ConvertTo-Json -Depth 30 -Compress
    Invoke-RestMethod -Uri $settingsUrl -Method Post -Body $payload -ContentType 'application/json' -TimeoutSec 30 | Out-Null

    $actual = Invoke-RestMethod -Uri $settingsUrl -Method Post -Body '{"action":"get"}' -ContentType 'application/json' -TimeoutSec 10
    foreach ($key in $desired.Keys) {
        if ($actual.$key -ne $desired[$key]) {
            throw "Verification failed for $key. Original settings saved at $backupPath"
        }
    }
    Write-Host "Updated $($changes -join ', '). Original settings: $backupPath"
} catch {
    throw "TorrServer configuration failed: $_"
}
