param(
    [ValidateRange(0, 180)][int]$Seconds = 0,
    [string]$OutputPath,
    [switch]$AssertNoWindow
)
$ErrorActionPreference = 'Stop'
if (-not ('RouterWindowProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class RouterWindowProbe {
    public delegate bool EnumProc(IntPtr h, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder b, int n);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
}
'@
}
$seen = @{}
$watch = [System.Diagnostics.Stopwatch]::StartNew()
do {
    [RouterWindowProbe]::EnumWindows({
        param($handle, $unused)
        if ([RouterWindowProbe]::IsWindowVisible($handle)) {
            [uint32]$windowProcessId = 0
            [void][RouterWindowProbe]::GetWindowThreadProcessId($handle, [ref]$windowProcessId)
            $process = Get-Process -Id $windowProcessId -ErrorAction SilentlyContinue
            if ($process.ProcessName -in @('WindowsTerminal', 'powershell')) {
                $title = [System.Text.StringBuilder]::new(512)
                [void][RouterWindowProbe]::GetWindowText($handle, $title, 512)
                $key = $handle.ToInt64().ToString()
                if (-not $seen.ContainsKey($key)) {
                    $seen[$key] = [pscustomobject]@{
                        Handle = $handle.ToInt64()
                        ProcessId = $windowProcessId
                        Process = $process.ProcessName
                        Title = $title.ToString()
                        FirstSeenSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
                    }
                }
            }
        }
        return $true
    }, [IntPtr]::Zero) | Out-Null
    if ($watch.Elapsed.TotalSeconds -ge $Seconds) { break }
    Start-Sleep -Milliseconds 100
} while ($true)
$health = $null
try { $health = Invoke-RestMethod -Uri 'http://127.0.0.1:18767/health' -TimeoutSec 3 } catch {}
$report = [pscustomobject]@{
    CheckedAt = (Get-Date -Format o)
    ObservedSeconds = [math]::Round($watch.Elapsed.TotalSeconds, 2)
    VisibleWindowCount = $seen.Count
    Windows = @($seen.Values)
    RouterHealthy = ($health.service -eq 'codex-cloud-local-router')
    RouterProcessId = $health.pid
}
$json = $report | ConvertTo-Json -Depth 5
if ($OutputPath) { [System.IO.File]::WriteAllText($OutputPath, $json) }
$json
if ($AssertNoWindow -and ($seen.Count -gt 0 -or -not $report.RouterHealthy)) { exit 1 }
