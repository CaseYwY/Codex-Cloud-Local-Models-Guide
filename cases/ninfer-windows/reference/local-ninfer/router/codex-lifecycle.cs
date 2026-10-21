using System;
using System.Diagnostics;
using System.IO;
using System.Management;
using System.Runtime.InteropServices;
using System.Threading;

internal static class CodexLifecycle
{
    private const string ProductionTask = "Codex Cloud Local Router";
    private static readonly string DirectoryPath = AppDomain.CurrentDomain.BaseDirectory;
    private static string taskName = ProductionTask;
    private static int watchedPid;
    private static int idleSeconds = 15;

    [STAThread]
    private static int Main(string[] args)
    {
        try
        {
            for (int i = 0; i < args.Length; i += 2)
            {
                if (i + 1 == args.Length) return 2;
                if (args[i] == "--watch-pid") watchedPid = int.Parse(args[i + 1]);
                else if (args[i] == "--task-name") taskName = args[i + 1];
                else if (args[i] == "--idle-seconds") idleSeconds = int.Parse(args[i + 1]);
                else return 2;
            }
            if (idleSeconds < 1 || taskName.Contains("\\")) return 2;
            // A PID-bound instance is useful for other launch integrations and verification.
            // It must never control the shared production router.
            if (watchedPid != 0 && taskName == ProductionTask) return 2;
            using (var mutex = new Mutex(false, "Local\\CodexRouterLifecycle-"
                + Environment.UserName + "-" + taskName))
            {
                if (!mutex.WaitOne(0)) return 0;
                try { return Watch(); }
                finally { mutex.ReleaseMutex(); }
            }
        }
        catch (Exception error)
        {
            Log("failed: " + error.Message);
            return 1;
        }
    }

    private static int Watch()
    {
        dynamic scheduler = Activator.CreateInstance(Type.GetTypeFromProgID("Schedule.Service"));
        scheduler.Connect();
        dynamic folder = scheduler.GetFolder("\\");
        DateTime lastPresent = DateTime.UtcNow;
        DateTime lastStart = DateTime.MinValue;
        Log("watching application; idle grace " + idleSeconds + " seconds");
        try
        {
            while (true)
            {
                if (ApplicationPresent())
                {
                    lastPresent = DateTime.UtcNow;
                    // Re-read the registered task so later configuration updates are respected.
                    dynamic task = folder.GetTask(taskName);
                    try
                    {
                        int state = task.State;
                        if (state != 4 && state != 2 && (DateTime.UtcNow - lastStart).TotalSeconds >= 3)
                        {
                            task.Run(null);
                            lastStart = DateTime.UtcNow;
                            Log("router task started");
                        }
                    }
                    finally { Marshal.FinalReleaseComObject(task); }
                }
                else if ((DateTime.UtcNow - lastPresent).TotalSeconds >= idleSeconds)
                {
                    // Recheck immediately before stopping, including other app instances.
                    if (ApplicationPresent()) continue;
                    dynamic task = folder.GetTask(taskName);
                    try
                    {
                        int state = task.State;
                        if (state == 4 || state == 2) task.Stop(0);
                    }
                    finally { Marshal.FinalReleaseComObject(task); }
                    if (taskName == ProductionTask) StopDetachedRouterChildren();
                    Log("application exited; router stopped");
                    return 0;
                }
                Thread.Sleep(1000);
            }
        }
        finally
        {
            Marshal.FinalReleaseComObject(folder);
            Marshal.FinalReleaseComObject(scheduler);
        }
    }

    private static bool ApplicationPresent()
    {
        if (watchedPid != 0)
        {
            try { using (var process = Process.GetProcessById(watchedPid)) return !process.HasExited; }
            catch (ArgumentException) { return false; }
        }
        int session = Process.GetCurrentProcess().SessionId;
        foreach (var process in Process.GetProcessesByName("ChatGPT"))
        {
            using (process)
            {
                try
                {
                    if (process.SessionId != session) continue;
                    string path = process.MainModule.FileName;
                    if (path.IndexOf("\\WindowsApps\\OpenAI.Codex_", StringComparison.OrdinalIgnoreCase) >= 0
                        && path.EndsWith("\\app\\ChatGPT.exe", StringComparison.OrdinalIgnoreCase))
                        return true;
                }
                catch (InvalidOperationException) { }
                catch (System.ComponentModel.Win32Exception)
                {
                    // An inaccessible same-session process must not cause an unsafe shutdown.
                    if (!process.HasExited) return true;
                }
            }
        }
        return false;
    }

    private static void StopDetachedRouterChildren()
    {
        // Older task versions could leave Node children detached. Match exact script arguments,
        // in this session only, and stop supervisors before gateways to prevent respawning.
        foreach (string script in new[] { "supervisor.mjs", "gateway.mjs" })
        {
            string expected = Path.Combine(DirectoryPath, script);
            using (var query = new ManagementObjectSearcher("SELECT ProcessId, CommandLine, SessionId FROM Win32_Process WHERE Name='node.exe'"))
            using (var processes = query.Get())
            {
                foreach (ManagementObject item in processes)
                {
                    using (item)
                    {
                        if (Convert.ToInt32(item["SessionId"]) != Process.GetCurrentProcess().SessionId) continue;
                        string command = item["CommandLine"] as string;
                        if (!HasArgument(command, expected)) continue;
                        try { using (var process = Process.GetProcessById(Convert.ToInt32(item["ProcessId"]))) process.Kill(); }
                        catch (ArgumentException) { }
                        catch (InvalidOperationException) { }
                    }
                }
            }
        }
    }

    [DllImport("shell32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern IntPtr CommandLineToArgvW(string command, out int count);
    [DllImport("kernel32.dll")]
    private static extern IntPtr LocalFree(IntPtr memory);

    private static bool HasArgument(string command, string expected)
    {
        if (string.IsNullOrEmpty(command)) return false;
        int count;
        IntPtr arguments = CommandLineToArgvW(command, out count);
        if (arguments == IntPtr.Zero) return false;
        try
        {
            for (int i = 1; i < count; i++)
                if (string.Equals(Marshal.PtrToStringUni(Marshal.ReadIntPtr(arguments, i * IntPtr.Size)),
                    expected, StringComparison.OrdinalIgnoreCase)) return true;
            return false;
        }
        finally { LocalFree(arguments); }
    }

    private static void Log(string message)
    {
        try { File.AppendAllText(Path.Combine(DirectoryPath, "lifecycle.log"),
            DateTimeOffset.Now.ToString("o") + " [" + taskName + "] " + message + Environment.NewLine); }
        catch { }
    }
}
