Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
Add-Type -Namespace ProxySwitch.Capture -Name NativeMethods -MemberDefinition @'
[DllImport("user32.dll")]
public static extern bool GetWindowRect(System.IntPtr hWnd, out RECT lpRect);
[DllImport("user32.dll")]
public static extern bool SetForegroundWindow(System.IntPtr hWnd);
[DllImport("user32.dll")]
public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
[DllImport("user32.dll")]
public static extern bool PrintWindow(System.IntPtr hWnd, System.IntPtr hdcBlt, uint nFlags);
public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
'@

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tempRoot = Join-Path $root '.release-updater\screenshot'
$outputDirectory = Join-Path $root 'docs\images'
$outputPath = Join-Path $outputDirectory 'main-window.png'
$process = $null

try {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
    [void][System.IO.Directory]::CreateDirectory($outputDirectory)
    [void][System.IO.Directory]::CreateDirectory((Join-Path $tempRoot 'assets'))

    Copy-Item -LiteralPath (Join-Path $root 'ProxySwitch.Core.ps1') -Destination $tempRoot
    Copy-Item -LiteralPath (Join-Path $root 'VERSION') -Destination $tempRoot
    Copy-Item -LiteralPath (Join-Path $root 'config.example.json') -Destination $tempRoot
    Copy-Item -LiteralPath (Join-Path $root 'assets\proxy-on.ico') -Destination (Join-Path $tempRoot 'assets')
    Copy-Item -LiteralPath (Join-Path $root 'assets\proxy-off.ico') -Destination (Join-Path $tempRoot 'assets')

    $utf8 = New-Object System.Text.UTF8Encoding($true)
    $source = [System.IO.File]::ReadAllText((Join-Path $root 'ProxySwitch.ps1'), $utf8)
    $source = $source.Replace("Join-Path `$PSScriptRoot 'config.json'", "Join-Path `$PSScriptRoot 'config.example.json'")

    $coreImport = "    . (Join-Path `$PSScriptRoot 'ProxySwitch.Core.ps1')"
    $mockState = @'

    function Get-SystemProxyState {
        return [pscustomobject]@{
            Enabled = $false
            Server = '192.0.2.10:8080'
            Override = 'localhost;127.*;192.168.*;*.example.com;<local>'
        }
    }
'@
    if (-not $source.Contains($coreImport)) {
        throw 'Unable to insert the documentation-only proxy state mock.'
    }
    $source = $source.Replace($coreImport, $coreImport + $mockState)

    $tempScript = Join-Path $tempRoot 'ProxySwitch.ps1'
    [System.IO.File]::WriteAllText($tempScript, $source, $utf8)

    $instanceKey = [System.Guid]::NewGuid().ToString('N')
    $arguments = @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA',
        '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $tempScript),
        '-ShowWindowEventName', "Local\ProxyServerSwitch-$instanceKey.ShowWindow",
        '-SingleInstanceMutexName', "Local\ProxyServerSwitch-$instanceKey.SingleInstance"
    )
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru

    $handle = [System.IntPtr]::Zero
    for ($attempt = 0; $attempt -lt 50; $attempt++) {
        Start-Sleep -Milliseconds 200
        $process.Refresh()
        if ($process.HasExited) {
            throw 'The documentation screenshot instance exited before capture.'
        }
        if ($process.MainWindowHandle -ne [System.IntPtr]::Zero) {
            $handle = $process.MainWindowHandle
            break
        }
    }
    if ($handle -eq [System.IntPtr]::Zero) {
        throw 'The main window was not found.'
    }

    [void][ProxySwitch.Capture.NativeMethods]::ShowWindow($handle, 9)
    [void][ProxySwitch.Capture.NativeMethods]::SetForegroundWindow($handle)
    Start-Sleep -Milliseconds 1200

    $rect = New-Object ProxySwitch.Capture.NativeMethods+RECT
    if (-not [ProxySwitch.Capture.NativeMethods]::GetWindowRect($handle, [ref]$rect)) {
        throw 'Unable to read the main window bounds.'
    }

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top
    $bitmap = New-Object System.Drawing.Bitmap($width, $height)
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $hdc = $graphics.GetHdc()
            try {
                $captured = [ProxySwitch.Capture.NativeMethods]::PrintWindow($handle, $hdc, 2)
            }
            finally {
                $graphics.ReleaseHdc($hdc)
            }
            if (-not $captured) {
                throw 'Unable to render the main window for capture.'
            }
        }
        finally {
            $graphics.Dispose()
        }
        $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    }
    finally {
        $bitmap.Dispose()
    }

    Write-Host "Screenshot saved to docs/images/main-window.png"
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
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
