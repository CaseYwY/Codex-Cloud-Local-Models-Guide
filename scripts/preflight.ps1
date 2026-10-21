# Optional Windows-host helper. Backend selection and ports come from target inventory.
param([string]$ReportPath, [int[]]$Ports = @())
$ErrorActionPreference = 'Stop'
$codexHomeObserved = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$commands = @('node', 'python', 'git') | ForEach-Object {
    $command = Get-Command $_ -ErrorAction SilentlyContinue | Select-Object -First 1
    [pscustomobject]@{name=$_;found=($null -ne $command);path=$command.Source}
}
$packages = @(Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue |
    Select-Object Version, PackageFamilyName, InstallLocation)
$tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
    Where-Object TaskName -like 'Codex*' | Select-Object TaskName, State)
$observedPorts = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object { $Ports -contains $_.LocalPort } | Select-Object LocalAddress,LocalPort,OwningProcess)
$report = [pscustomobject]@{
    observed_at=(Get-Date -Format o)
    codex_home_from_current_shell=$codexHomeObserved
    desktop_codex_home_must_be_verified_separately=$true
    config_present=(Test-Path -LiteralPath (Join-Path $codexHomeObserved 'config.toml'))
    packages=$packages
    commands=$commands
    tasks=$tasks
    requested_ports=$Ports
    listening_ports=$observedPorts
    read_only=$true
    credential_files_read=$false
}
$json = $report | ConvertTo-Json -Depth 6
if ($ReportPath) { [System.IO.File]::WriteAllText($ReportPath, $json) }
$json
