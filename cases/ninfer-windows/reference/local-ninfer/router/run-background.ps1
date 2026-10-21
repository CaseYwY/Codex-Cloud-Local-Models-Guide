$ErrorActionPreference = 'Stop'
try {
    & (Join-Path $PSScriptRoot 'refresh-proxy.ps1')
    $nodePath = Join-Path $env:ProgramFiles 'nodejs\node.exe'
    Set-Location -LiteralPath $PSScriptRoot
    $supervisorPath=Join-Path $PSScriptRoot 'supervisor.mjs'
    $existing=@(Get-CimInstance Win32_Process -Filter "Name='node.exe'" | Where-Object { $_.CommandLine -like ('*'+$supervisorPath+'*') } | Sort-Object CreationDate)
    if($existing.Count -gt 0) {
        # A stopped task can leave its detached child alive. Adopt it instead of
        # creating another supervisor which would compete for the same port.
        Wait-Process -Id $existing[0].ProcessId -ErrorAction SilentlyContinue
        exit 0
    }
    & $nodePath $supervisorPath 1>> (Join-Path $PSScriptRoot 'supervisor.stdout.log') 2>> (Join-Path $PSScriptRoot 'supervisor.stderr.log')
    exit $LASTEXITCODE
} catch {
    [System.IO.File]::AppendAllText((Join-Path $PSScriptRoot 'task-startup-error.log'), ((Get-Date -Format o) + ' Background startup failed: ' + $_.Exception.Message + [Environment]::NewLine))
    exit 1
}