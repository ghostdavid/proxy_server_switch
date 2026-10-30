using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Windows Proxy Switch")]
[assembly: AssemblyProduct("Windows Proxy Switch")]
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

namespace ProxySwitchLauncher
{
    internal static class Program
    {
        [STAThread]
        private static void Main(string[] args)
        {
            string instanceKey = "Default";
            for (int index = 0; index < args.Length - 1; index++)
            {
                if (args[index] == "--instance-key")
                {
                    instanceKey = args[index + 1];
                }
            }

            bool validKey = instanceKey.Length >= 1 && instanceKey.Length <= 64;
            foreach (char character in instanceKey)
            {
                if (!char.IsLetterOrDigit(character) && character != '-' && character != '_')
                {
                    validKey = false;
                }
            }
            if (!validKey)
            {
                MessageBox.Show(
                    "实例标识无效。",
                    "Windows 代理开关",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
                return;
            }

            string mutexName = @"Local\ProxyServerSwitch-" + instanceKey + ".SingleInstance";
            string eventName = @"Local\ProxyServerSwitch-" + instanceKey + ".ShowWindow";
            System.Threading.EventWaitHandle showWindowEvent = null;
            System.Threading.Mutex instanceMutex = null;
            bool ownsMutex = false;

            try
            {
                showWindowEvent = new System.Threading.EventWaitHandle(
                    false,
                    System.Threading.EventResetMode.AutoReset,
                    eventName);

                bool createdNew;
                instanceMutex = new System.Threading.Mutex(true, mutexName, out createdNew);
                if (!createdNew)
                {
                    showWindowEvent.Set();
                    return;
                }
                ownsMutex = true;

                string baseDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                string scriptPath = Path.Combine(baseDirectory, "ProxySwitch.ps1");
                if (!File.Exists(scriptPath))
                {
                    MessageBox.Show(
                        "无法找到主程序文件：\n" + scriptPath,
                        "Windows 代理开关",
                        MessageBoxButtons.OK,
                        MessageBoxIcon.Error);
                    return;
                }

                string windowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                string powerShellPath = Path.Combine(
                    windowsDirectory,
                    @"System32\WindowsPowerShell\v1.0\powershell.exe");

                var startInfo = new ProcessStartInfo
                {
                    FileName = powerShellPath,
                    Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \"" + scriptPath + "\" -ShowWindowEventName \"" + eventName + "\"",
                    WorkingDirectory = baseDirectory,
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden
                };

                using (Process process = Process.Start(startInfo))
                {
                    if (process != null)
                    {
                        process.WaitForExit();
                    }
                }
            }
            catch (Exception exception)
            {
                MessageBox.Show(
                    "无法启动代理开关：\n" + exception.Message,
                    "Windows 代理开关",
                    MessageBoxButtons.OK,
                    MessageBoxIcon.Error);
            }
            finally
            {
                if (ownsMutex && instanceMutex != null)
                {
                    try
                    {
                        instanceMutex.ReleaseMutex();
                    }
                    catch
                    {
                    }
                }
                if (instanceMutex != null)
                {
                    instanceMutex.Dispose();
                }
                if (showWindowEvent != null)
                {
                    showWindowEvent.Dispose();
                }
            }
        }
    }
}
