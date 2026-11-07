Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -Namespace ProxySwitch.LauncherTests -Name NativeMethods -MemberDefinition @'
public delegate bool EnumWindowsProc(System.IntPtr hWnd, System.IntPtr lParam);
[DllImport("user32.dll")]
public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, System.IntPtr lParam);
[DllImport("user32.dll")]
public static extern uint GetWindowThreadProcessId(System.IntPtr hWnd, out uint lpdwProcessId);
[DllImport("user32.dll")]
public static extern bool IsWindowVisible(System.IntPtr hWnd);
[DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int GetWindowText(System.IntPtr hWnd, System.Text.StringBuilder text, int count);
[DllImport("user32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int GetClassName(System.IntPtr hWnd, System.Text.StringBuilder text, int count);
'@

function Get-VisibleWindows {
    param([int]$ProcessId)

    $windows = New-Object 'System.Collections.Generic.List[object]'
    $callback = [ProxySwitch.LauncherTests.NativeMethods+EnumWindowsProc]{
        param($handle, $lParam)

        [uint32]$windowProcessId = 0
        [void][ProxySwitch.LauncherTests.NativeMethods]::GetWindowThreadProcessId($handle, [ref]$windowProcessId)
        if ($windowProcessId -eq $ProcessId -and [ProxySwitch.LauncherTests.NativeMethods]::IsWindowVisible($handle)) {
            $title = New-Object System.Text.StringBuilder(512)
            $className = New-Object System.Text.StringBuilder(256)
            [void][ProxySwitch.LauncherTests.NativeMethods]::GetWindowText($handle, $title, $title.Capacity)
            [void][ProxySwitch.LauncherTests.NativeMethods]::GetClassName($handle, $className, $className.Capacity)
            $windows.Add([pscustomobject]@{
                Handle = $handle
                Title = $title.ToString()
                ClassName = $className.ToString()
            })
        }
        return $true
    }

    [void][ProxySwitch.LauncherTests.NativeMethods]::EnumWindows($callback, [System.IntPtr]::Zero)
    return $windows.ToArray()
}

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$launcherPath = Join-Path $root 'release\Start-ProxySwitch.exe'
$instanceKey = [System.Guid]::NewGuid().ToString('N')
$eventName = "Local\ProxyServerSwitch-$instanceKey.ShowWindow"
$firstLauncher = $null
$secondLauncher = $null
$child = $null
$failed = 0

try {
    $firstLauncher = Start-Process -FilePath $launcherPath -ArgumentList @('--instance-key', $instanceKey) -PassThru

    $processInfo = $null
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        Start-Sleep -Milliseconds 200
        $candidates = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
            $null -ne $_.CommandLine -and
            $_.CommandLine.IndexOf($eventName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        })
        if ($candidates.Count -gt 0) {
            $processInfo = $candidates[0]
            break
        }
    }

    if ($null -eq $processInfo) {
        throw 'The launcher did not start the expected PowerShell process.'
    }
    $child = Get-Process -Id $processInfo.ProcessId

    $handle = [System.IntPtr]::Zero
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        Start-Sleep -Milliseconds 200
        $child.Refresh()
        if ($child.HasExited) {
            throw 'The application exited before its window was ready.'
        }
        if ($child.MainWindowHandle -ne [System.IntPtr]::Zero) {
            $handle = $child.MainWindowHandle
            break
        }
    }
    if ($handle -eq [System.IntPtr]::Zero) {
        throw 'The main application window was not found.'
    }

    $consoleWindows = @(Get-VisibleWindows -ProcessId $child.Id | Where-Object { $_.ClassName -eq 'ConsoleWindowClass' })
    if ($consoleWindows.Count -gt 0) {
        Write-Host 'FAIL: A visible console window exists while the application is running.'
        $failed++
    }
    else {
        Write-Host 'PASS: No visible console window exists while the application is running.'
    }

    [void][ProxySwitch.LauncherTests.NativeMethods]::ShowWindow($handle, 6)
    Start-Sleep -Milliseconds 1200
    $consoleWindows = @(Get-VisibleWindows -ProcessId $child.Id | Where-Object { $_.ClassName -eq 'ConsoleWindowClass' })

    if ([ProxySwitch.LauncherTests.NativeMethods]::IsWindowVisible($handle)) {
        Write-Host 'FAIL: The main window is still visible after minimize.'
        $failed++
    }
    elseif ($consoleWindows.Count -gt 0) {
        Write-Host 'FAIL: A visible console window remains after minimize.'
        $failed++
    }
    else {
        Write-Host 'PASS: No main or console window is visible after minimize.'
    }

    $secondLauncher = Start-Process -FilePath $launcherPath -ArgumentList @('--instance-key', $instanceKey) -PassThru
    if (-not $secondLauncher.WaitForExit(10000)) {
        Write-Host 'FAIL: The second launcher did not exit after signaling the existing instance.'
        $failed++
    }

    $restored = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 200
        $visibleWindows = @(Get-VisibleWindows -ProcessId $child.Id | Where-Object { $_.ClassName -ne 'ConsoleWindowClass' })
        if ($visibleWindows.Count -gt 0) {
            $restored = $true
            break
        }
    }

    $matchingProcesses = @(Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" | Where-Object {
        $null -ne $_.CommandLine -and
        $_.CommandLine.IndexOf($eventName, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
    })

    if (-not $restored) {
        Write-Host 'FAIL: The second launch did not restore the existing window.'
        $failed++
    }
    elseif ($matchingProcesses.Count -ne 1) {
        Write-Host "FAIL: The second launch created another main process (count: $($matchingProcesses.Count))."
        $failed++
    }
    else {
        Write-Host 'PASS: The second launch restored the existing window without creating another main process.'
    }
}
catch {
    Write-Host "FAIL: $($_.Exception.Message)"
    $failed++
}
finally {
    if ($null -ne $child) {
        $child.Refresh()
        if (-not $child.HasExited) {
            Stop-Process -Id $child.Id -Force
            Wait-Process -Id $child.Id -ErrorAction SilentlyContinue
        }
        $child.Dispose()
    }
    foreach ($launcher in @($firstLauncher, $secondLauncher)) {
        if ($null -ne $launcher) {
            $launcher.Refresh()
            if (-not $launcher.HasExited) {
                if (-not $launcher.WaitForExit(5000)) {
                    Stop-Process -Id $launcher.Id -Force
                }
            }
            $launcher.Dispose()
        }
    }
}

if ($failed -gt 0) {
    exit 1
}
