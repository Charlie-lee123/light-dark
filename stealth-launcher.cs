// stealth-launcher.cs — 编译为 winexe 模式，完全无窗口启动 PowerShell 脚本
// 编译：csc /nologo /target:winexe /out:stealth-launcher.exe stealth-launcher.cs
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

class Program
{
    [DllImport("kernel32.dll")]
    static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("kernel32.dll")]
    static extern bool AttachConsole(int dwProcessId);
    [DllImport("kernel32.dll")]
    static extern bool FreeConsole();
    [DllImport("user32.dll")]
    static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

    const int ATTACH_PARENT_PROCESS = -1;
    const int SW_HIDE = 0;
    const int SW_SHOW = 5;
    static readonly IntPtr HWND_BOTTOM = new IntPtr(1);

    static void Main(string[] args)
    {
        // 方案 A：尝试 attach 到父控制台并隐藏
        bool attached = AttachConsole(ATTACH_PARENT_PROCESS);
        if (attached)
        {
            IntPtr h = GetConsoleWindow();
            if (h != IntPtr.Zero)
            {
                ShowWindow(h, SW_HIDE);
                SetWindowPos(h, HWND_BOTTOM, 0, 0, 0, 0, 0x0001 | 0x0002);
            }
            FreeConsole();
        }

        // 构造脚本路径（与 stealth-launcher.exe 同目录）
        string dir = AppDomain.CurrentDomain.BaseDirectory;
        string scriptPath = System.IO.Path.Combine(dir, "auto-theme.ps1");

        // 拼装参数
        string scriptArgs = "";
        if (args.Length > 0)
            scriptArgs = " " + string.Join(" ", args);

        var psi = new ProcessStartInfo
        {
            FileName = "powershell.exe",
            Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -NonInteractive -File \"" + scriptPath + "\"" + scriptArgs,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        Process proc = Process.Start(psi);
        proc.WaitForExit();
    }
}
