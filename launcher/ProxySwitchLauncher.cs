using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Windows.Forms;

[assembly: AssemblyTitle("Windows Proxy Switch")]
[assembly: AssemblyProduct("Windows Proxy Switch")]
[assembly: AssemblyVersion("1.1.0.0")]
[assembly: AssemblyFileVersion("1.1.0.0")]

namespace ProxySwitchLauncher
{
    internal static class Program
    {
        private static void ExtractPayload(string runtimeDirectory)
        {
            Assembly assembly = Assembly.GetExecutingAssembly();
            string[] resourceNames =
            {
                "ProxySwitch.ps1",
                "ProxySwitch.Core.ps1",
                "VERSION",
                "assets/proxy-on.ico",
                "assets/proxy-off.ico"
            };

            foreach (string resourceName in resourceNames)
            {
                string relativePath = resourceName.Replace('/', Path.DirectorySeparatorChar);
                string destinationPath = Path.Combine(runtimeDirectory, relativePath);
                string destinationDirectory = Path.GetDirectoryName(destinationPath);
                if (!Directory.Exists(destinationDirectory))
                {
                    Directory.CreateDirectory(destinationDirectory);
                }

                using (Stream input = assembly.GetManifestResourceStream(resourceName))
                {
                    if (input == null)
                    {
                        throw new InvalidOperationException("缺少内嵌资源：" + resourceName);
                    }

                    using (FileStream output = File.Create(destinationPath))
                    {
                        input.CopyTo(output);
                    }
                }
            }
        }

        [STAThread]
        private static void Main(string[] args)
        {
            string instanceKey = "Default";
            bool smokeTest = false;
            for (int index = 0; index < args.Length; index++)
            {
                if (args[index] == "--instance-key" && index + 1 < args.Length)
                {
                    instanceKey = args[index + 1];
                    index++;
                }
                else if (args[index] == "--smoke-test")
                {
                    smokeTest = true;
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

            string runtimeDirectory = null;
            try
            {
                string baseDirectory = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
                runtimeDirectory = Path.Combine(
                    Path.GetTempPath(),
                    "ProxyServerSwitch-" + Guid.NewGuid().ToString("N"));
                Directory.CreateDirectory(runtimeDirectory);
                ExtractPayload(runtimeDirectory);

                string scriptPath = Path.Combine(runtimeDirectory, "ProxySwitch.ps1");
                string configPath = Path.Combine(baseDirectory, "config.json");
                string eventName = @"Local\ProxyServerSwitch-" + instanceKey + ".ShowWindow";
                string mutexName = @"Local\ProxyServerSwitch-" + instanceKey + ".SingleInstance";
                string windowsDirectory = Environment.GetFolderPath(Environment.SpecialFolder.Windows);
                string powerShellPath = Path.Combine(
                    windowsDirectory,
                    @"System32\WindowsPowerShell\v1.0\powershell.exe");

                string arguments =
                    "-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden" +
                    " -File \"" + scriptPath + "\"" +
                    " -ShowWindowEventName \"" + eventName + "\"" +
                    " -SingleInstanceMutexName \"" + mutexName + "\"" +
                    " -ConfigurationPath \"" + configPath + "\"";
                if (smokeTest)
                {
                    arguments += " -SmokeTest";
                }

                var startInfo = new ProcessStartInfo
                {
                    FileName = powerShellPath,
                    Arguments = arguments,
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
                if (runtimeDirectory != null)
                {
                    try
                    {
                        Directory.Delete(runtimeDirectory, true);
                    }
                    catch
                    {
                        // 临时目录清理失败不影响已经退出的程序。
                    }
                }
            }
        }
    }
}
