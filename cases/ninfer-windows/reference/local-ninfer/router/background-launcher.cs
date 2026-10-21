using System;
using System.Diagnostics;
using System.IO;

internal static class BackgroundLauncher
{
    [STAThread]
    private static int Main(string[] args)
    {
        string directory = AppDomain.CurrentDomain.BaseDirectory;
        string script = args.Length == 0 ? "run-background.ps1" : args[0];
        if (args.Length > 1 || (script != "run-background.ps1" && script != "run-manager.ps1"))
            return 2;

        try
        {
            var start = new ProcessStartInfo
            {
                FileName = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System),
                    @"WindowsPowerShell\v1.0\powershell.exe"),
                Arguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File \""
                    + Path.Combine(directory, script) + "\"",
                WorkingDirectory = directory,
                UseShellExecute = false,
                CreateNoWindow = true,
                WindowStyle = ProcessWindowStyle.Hidden,
                RedirectStandardInput = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };
            using (var child = new Process { StartInfo = start })
            {
                child.OutputDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Log(directory, script + ".launcher.stdout.log", e.Data);
                };
                child.ErrorDataReceived += delegate(object sender, DataReceivedEventArgs e)
                {
                    if (e.Data != null) Log(directory, script + ".launcher.stderr.log", e.Data);
                };
                child.Start();
                child.StandardInput.Close();
                child.BeginOutputReadLine();
                child.BeginErrorReadLine();
                child.WaitForExit();
                return child.ExitCode;
            }
        }
        catch (Exception error)
        {
            Log(directory, "task-startup-error.log", DateTimeOffset.Now.ToString("o")
                + " Background launcher failed: " + error.Message);
            return 1;
        }
    }

    private static void Log(string directory, string file, string message)
    {
        try { File.AppendAllText(Path.Combine(directory, file), message + Environment.NewLine); }
        catch { /* Logging must not terminate the background service. */ }
    }
}
