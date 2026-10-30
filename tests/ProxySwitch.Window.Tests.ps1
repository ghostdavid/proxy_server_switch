param([string]$Action = 'All')

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -Namespace ProxySwitch.WindowTests -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool PostMessage(System.IntPtr hWnd, uint msg, System.IntPtr wParam, System.IntPtr lParam);
[DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr hWnd);
'@

$scriptPath = Join-Path $PSScriptRoot '..\ProxySwitch.ps1'
$script:Failed = 0

function Test-WindowAction {
    param([string]$Name)

    $process = $null
    try {
        $arguments = @(
            '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA',
            '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $scriptPath)
        )
        $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru

        $handle = [System.IntPtr]::Zero
        for ($attempt = 0; $attempt -lt 50; $attempt++) {
            Start-Sleep -Milliseconds 200
            $process.Refresh()
            if ($process.HasExited) {
                throw 'The application exited before its window was ready.'
            }
            if ($process.MainWindowHandle -ne [System.IntPtr]::Zero) {
                $handle = $process.MainWindowHandle
                break
            }
        }

        if ($handle -eq [System.IntPtr]::Zero) {
            throw 'The main window was not found.'
        }

        if ($Name -eq 'Minimize') {
            [void][ProxySwitch.WindowTests.NativeMethods]::ShowWindow($handle, 6)
        }
        else {
            [void][ProxySwitch.WindowTests.NativeMethods]::PostMessage($handle, 0x0010, [System.IntPtr]::Zero, [System.IntPtr]::Zero)
        }

        Start-Sleep -Milliseconds 1200
        $process.Refresh()
        if ($process.HasExited) {
            Write-Host "FAIL: $Name caused the application to exit."
            $script:Failed++
        }
        elseif ([ProxySwitch.WindowTests.NativeMethods]::IsWindowVisible($handle)) {
            Write-Host "FAIL: $Name kept the application running but did not hide the window."
            $script:Failed++
        }
        else {
            Write-Host "PASS: $Name kept the application running and hid the window."
        }
    }
    catch {
        Write-Host "FAIL: $Name test error: $($_.Exception.Message)"
        $script:Failed++
    }
    finally {
        if ($null -ne $process) {
            $process.Refresh()
            if (-not $process.HasExited) {
                Stop-Process -Id $process.Id -Force
                Wait-Process -Id $process.Id -ErrorAction SilentlyContinue
            }
            $process.Dispose()
        }
    }
}

if ($Action -eq 'All' -or $Action -eq 'Minimize') {
    Test-WindowAction -Name 'Minimize'
}
if ($Action -eq 'All' -or $Action -eq 'Close') {
    Test-WindowAction -Name 'Close'
}

if ($script:Failed -gt 0) {
    exit 1
}
