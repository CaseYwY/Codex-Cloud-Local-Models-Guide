using System;
using System.Diagnostics;
using System.IO;

internal static class DesktopLauncher
{
    [STAThread]
    private static int Main()
    {
        string directory = AppDomain.CurrentDomain.BaseDirectory;
        using (var child = Process.Start(new ProcessStartInfo
        {
            FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
            Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File \"" + Path.Combine(directory, "launch-codex.ps1") + "\"",
            WorkingDirectory = directory,
            UseShellExecute = false,
            CreateNoWindow = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true
        }))
        {
            child.OutputDataReceived += delegate { };
            child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
            {
                if (e.Data != null) File.AppendAllText(Path.Combine(directory, "desktop-launcher.stderr.log"), e.Data + Environment.NewLine);
            };
            child.BeginOutputReadLine();
            child.BeginErrorReadLine();
            child.WaitForExit();
            return child.ExitCode;
        }
    }
}
