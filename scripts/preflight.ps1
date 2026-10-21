param([string]$ReportPath)
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
$ports = @(Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
    Where-Object LocalPort -in 7777,18767 | Select-Object LocalAddress,LocalPort,OwningProcess)
$report = [pscustomobject]@{
    observed_at=(Get-Date -Format o)
    codex_home_from_current_shell=$codexHomeObserved
    desktop_codex_home_must_be_verified_separately=$true
    config_present=(Test-Path -LiteralPath (Join-Path $codexHomeObserved 'config.toml'))
    packages=$packages
    commands=$commands
    tasks=$tasks
    listening_ports=$ports
    read_only=$true
    credential_files_read=$false
}
$json = $report | ConvertTo-Json -Depth 6
if ($ReportPath) { [System.IO.File]::WriteAllText($ReportPath, $json) }
$json
