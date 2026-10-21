param([string]$ReportPath)
$ErrorActionPreference = 'Stop'
$testId = [Guid]::NewGuid().ToString('N')
$testTask = 'Codex Router Lifecycle Test ' + $testId
$testDirectory = Join-Path $env:TEMP ('codex-lifecycle-test-' + $testId)
$sentinel = $null
$controller = $null
$checks = [ordered]@{}

function Wait-Condition([scriptblock]$Condition, [int]$Seconds = 15) {
    $deadline = (Get-Date).AddSeconds($Seconds)
    do {
        if (& $Condition) { return }
        Start-Sleep -Milliseconds 200
    } while ((Get-Date) -lt $deadline)
    throw 'Timed out waiting for lifecycle integration check.'
}

function Start-Hidden([string]$Path, [string]$Arguments = '') {
    $start = New-Object System.Diagnostics.ProcessStartInfo
    $start.FileName = $Path
    $start.Arguments = $Arguments
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    return [System.Diagnostics.Process]::Start($start)
}

function Get-TestTaskInstance {
    $fixturePath = Join-Path $testDirectory 'background-launcher.exe'
    $running = Get-CimInstance Win32_Process -Filter "Name='background-launcher.exe'" |
        Where-Object { $_.ExecutablePath -eq $fixturePath -and $_.ProcessId -ne $sentinel.Id } |
        Select-Object -First 1
    if ($running) { return $running.ProcessId }
    return $null
}

try {
    New-Item -ItemType Directory -Path $testDirectory | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'background-launcher.exe') -Destination $testDirectory
    'Start-Sleep -Seconds 600' | Set-Content -LiteralPath (Join-Path $testDirectory 'run-background.ps1') -Encoding ascii
    $fixture = Join-Path $testDirectory 'background-launcher.exe'
    $action = New-ScheduledTaskAction -Execute $fixture -WorkingDirectory $testDirectory
    $principal = New-ScheduledTaskPrincipal -UserId ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
    $settings = New-ScheduledTaskSettingsSet -Hidden -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
    Register-ScheduledTask -TaskName $testTask -InputObject (New-ScheduledTask -Action $action -Principal $principal -Settings $settings) -Force | Out-Null

    $sentinel = Start-Hidden $fixture
    $controller = Start-Hidden (Join-Path $PSScriptRoot 'codex-lifecycle.exe') ('--watch-pid ' + $sentinel.Id + ' --task-name "' + $testTask + '" --idle-seconds 2')
    Wait-Condition { (Get-ScheduledTask -TaskName $testTask).State -eq 'Running' -and (Get-TestTaskInstance) }
    $firstInstance = Get-TestTaskInstance
    if (-not $firstInstance) { throw 'Task has no running instance.' }
    $checks.start_when_client_alive = $true

    Stop-ScheduledTask -TaskName $testTask
    Wait-Condition { $instance = Get-TestTaskInstance; $instance -and $instance -ne $firstInstance }
    $checks.restart_after_router_failure = $true

    $sentinel.Kill()
    Wait-Condition { $controller.HasExited -and (Get-ScheduledTask -TaskName $testTask).State -eq 'Ready' }
    if ($controller.ExitCode -ne 0) { throw ('Controller exited with ' + $controller.ExitCode) }
    $checks.stop_after_client_exit = $true
    Start-Sleep -Seconds 4
    if (Get-TestTaskInstance) { throw 'Router restarted without a client.' }
    $checks.remain_stopped_without_client = $true

    $controller.Dispose()
    $controller = Start-Hidden (Join-Path $PSScriptRoot 'codex-lifecycle.exe') ('--watch-pid ' + $sentinel.Id + ' --task-name "' + $testTask + '" --idle-seconds 1')
    Wait-Condition { $controller.HasExited }
    if ($controller.ExitCode -ne 0 -or (Get-TestTaskInstance)) { throw 'An absent client should leave the stopped task untouched.' }
    $checks.do_not_start_without_client = $true
}
finally {
    if ($controller -and -not $controller.HasExited) { $controller.Kill() }
    if (Get-ScheduledTask -TaskName $testTask -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $testTask -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $testTask -Confirm:$false
    }
    if ($sentinel -and -not $sentinel.HasExited) { $sentinel.Kill() }
    # Only the disposable fixture's own launchers and PowerShell scripts are eligible.
    Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -eq (Join-Path $testDirectory 'background-launcher.exe') -or
        ($_.Name -eq 'powershell.exe' -and $_.CommandLine -like ('*"' + (Join-Path $testDirectory 'run-background.ps1') + '"*'))
    } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
    $report = [pscustomobject]@{time=(Get-Date -Format o);fixture_directory=$testDirectory;checks=$checks;production_router_untouched=$true}
    if ($ReportPath) { $report | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ReportPath -Encoding utf8 }
    $report | ConvertTo-Json -Depth 4
}
