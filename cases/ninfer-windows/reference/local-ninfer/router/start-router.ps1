$ErrorActionPreference = 'Stop'
$routerMutex = New-Object System.Threading.Mutex($false, ('Local\CodexCloudLocalRouter-' + $env:USERNAME))
$locked = $false
try {
    $locked = $routerMutex.WaitOne(20000)
    if (-not $locked) { throw 'Another router startup is still running.' }
    $settings = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'settings.json') -Raw | ConvertFrom-Json
    $healthUrl = 'http://127.0.0.1:' + $settings.port + '/health'
    $health = $null
    try { $health=Invoke-RestMethod -Uri $healthUrl -TimeoutSec 2 } catch {}
    if ($health) {
        if ($health.service -eq 'codex-cloud-local-router') { Write-Output 'Router is ready.'; return }
        throw 'The router port is used by another service.'
    }
    $taskName='Codex Cloud Local Router'
    if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
        & (Join-Path $PSScriptRoot 'install-background-task.ps1')
    }
    Start-ScheduledTask -TaskName $taskName
    for ($attempt=0; $attempt -lt 60; $attempt++) {
        Start-Sleep -Milliseconds 250
        try { $health=Invoke-RestMethod -Uri $healthUrl -TimeoutSec 1; if ($health.service -eq 'codex-cloud-local-router') { Write-Output 'Router is ready.'; return } } catch {}
    }
    throw 'Router failed to start. Inspect task-startup-error.log and the scheduled task status.'
} finally {
    if ($locked) { $routerMutex.ReleaseMutex() }
    $routerMutex.Dispose()
}