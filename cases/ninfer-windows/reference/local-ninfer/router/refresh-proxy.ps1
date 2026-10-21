$ErrorActionPreference = 'Stop'
$settingsPath = Join-Path $PSScriptRoot 'settings.json'
$settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
$proxy = Get-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
if ($proxy.ProxyEnable -eq 1 -and $proxy.ProxyServer) {
    $address = [string]$proxy.ProxyServer
    if ($address.Contains('=')) {
        $entries = @{}
        foreach ($part in $address.Split(';')) { if ($part.Contains('=')) { $pair=$part.Split('=',2); $entries[$pair[0]]=$pair[1] } }
        if ($entries['https']) { $address=$entries['https'] } else { $address=$entries['http'] }
    }
    if (-not $address) { throw 'Unsupported system proxy configuration.' }
    if (-not $address.Contains('://')) { $address='http://' + $address }
    $settings | Add-Member -Force -NotePropertyName cloud_proxy -NotePropertyValue $address
} else { $settings.PSObject.Properties.Remove('cloud_proxy') }
[System.IO.File]::WriteAllText($settingsPath, ($settings | ConvertTo-Json -Compress), (New-Object System.Text.UTF8Encoding($false)))