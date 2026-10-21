$ErrorActionPreference = 'Stop'
$taskName = 'Codex Cloud Local Router'
$identity = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
& (Join-Path $PSScriptRoot 'build-background-launcher.ps1')
& (Join-Path $PSScriptRoot 'build-lifecycle.ps1')
$program = Join-Path $PSScriptRoot 'background-launcher.exe'
$arguments = 'run-background.ps1'
$action = New-ScheduledTaskAction -Execute $program -Argument $arguments -WorkingDirectory $PSScriptRoot
$principal = New-ScheduledTaskPrincipal -UserId $identity -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
$task = New-ScheduledTask -Action $action -Principal $principal -Settings $settings -Description 'On-demand cloud/local router. Codex Router App Lifecycle owns startup, shutdown and recovery while the desktop app is running.'
Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

# The package activation event covers Start, taskbar, protocol activation and desktop shortcuts.
# ApplicationName is stable across app updates; there is no login or periodic trigger.
$subscription = @'
<QueryList><Query Id="0" Path="Microsoft-Windows-AppModel-Runtime/Admin"><Select Path="Microsoft-Windows-AppModel-Runtime/Admin">*[System[Provider[@Name='Microsoft-Windows-AppModel-Runtime'] and EventID=201]] and *[EventData[Data[@Name='ApplicationName']='OpenAI.Codex_2p2nqsd0c76g0!App']]</Select></Query></QueryList>
'@
$trigger = New-CimInstance -ClientOnly -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ClassName 'MSFT_TaskEventTrigger' -Property @{Enabled=$true; Subscription=$subscription}
$lifecycleAction = New-ScheduledTaskAction -Execute (Join-Path $PSScriptRoot 'codex-lifecycle.exe') -WorkingDirectory $PSScriptRoot
$lifecycleSettings = New-ScheduledTaskSettingsSet -Hidden -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$lifecycleTask = New-ScheduledTask -Action $lifecycleAction -Principal $principal -Settings $lifecycleSettings -Description 'Starts the router on Codex package activation; stops it 15 seconds after the last desktop app process exits. No login startup or periodic polling while Codex is closed.'
$lifecycleTask.Triggers = @($trigger)
Register-ScheduledTask -TaskName 'Codex Router App Lifecycle' -InputObject $lifecycleTask -Force | Out-Null
Write-Output 'On-demand router and app-activation lifecycle tasks registered for the current user.'
