$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot 'background-launcher.cs'
$output = Join-Path $PSScriptRoot 'background-launcher.exe'
if ((Test-Path -LiteralPath $output) -and
    (Get-Item -LiteralPath $output).LastWriteTimeUtc -ge (Get-Item -LiteralPath $source).LastWriteTimeUtc) {
    return
}
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
& $compiler /nologo /target:winexe /optimize+ ('/out:' + $output) $source
if ($LASTEXITCODE -ne 0) { throw 'Building the background launcher failed.' }
