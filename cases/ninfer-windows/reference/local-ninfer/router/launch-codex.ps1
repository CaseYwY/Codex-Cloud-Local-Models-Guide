$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'start-router.ps1')
Start-Process -FilePath 'explorer.exe' -ArgumentList 'shell:AppsFolder\OpenAI.Codex_2p2nqsd0c76g0!App'
