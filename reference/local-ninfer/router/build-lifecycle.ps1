$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
foreach ($name in @('codex-lifecycle', 'desktop-launcher')) {
    $source = Join-Path $PSScriptRoot ($name + '.cs')
    $output = Join-Path $PSScriptRoot ($name + '.exe')
    if ((Test-Path -LiteralPath $output) -and
        (Get-Item -LiteralPath $output).LastWriteTimeUtc -ge (Get-Item -LiteralPath $source).LastWriteTimeUtc) { continue }
    & $compiler /nologo /target:winexe /optimize+ /reference:Microsoft.CSharp.dll /reference:System.Management.dll ('/out:' + $output) $source
    if ($LASTEXITCODE -ne 0) { throw ('Building ' + $name + ' failed.') }
}
