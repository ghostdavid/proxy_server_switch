Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$tempRoot = Join-Path $PSScriptRoot ('.exit-test-' + [System.Guid]::NewGuid().ToString('N'))
$logPath = Join-Path $tempRoot 'exit-actions.log'
$eventName = 'Local\ProxyServerSwitch-ExitTest-' + [System.Guid]::NewGuid().ToString('N')
$process = $null

try {
    [void][System.IO.Directory]::CreateDirectory($tempRoot)
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
    $mocks = @"

    `$script:ExitTestEnabled = `$true
    function Get-SystemProxyState {
        return [pscustomobject]@{
            Enabled = `$script:ExitTestEnabled
            Server = '192.0.2.10:8080'
            Override = '<local>'
        }
    }
    function Disable-SystemProxy {
        Add-Content -LiteralPath '$logPath' -Value 'disable'
        `$script:ExitTestEnabled = `$false
    }
    function Send-ProxySettingsChangedNotification {
        Add-Content -LiteralPath '$logPath' -Value 'notify'
    }
"@
    if (-not $source.Contains($coreImport)) {
        throw 'Unable to insert proxy operation mocks.'
    }
    $source = $source.Replace($coreImport, $coreImport + $mocks)

    $runLine = '    [void][System.Windows.Forms.Application]::Run($form)'
    $autoExit = @"
    `$exitTestTimer = New-Object System.Windows.Forms.Timer
    `$exitTestTimer.Interval = 500
    `$exitTestTimer.add_Tick({
        `$exitTestTimer.Stop()
        Exit-Application
    })
    `$exitTestTimer.Start()
"@
    if (-not $source.Contains($runLine)) {
        throw 'Unable to insert the automatic exit action.'
    }
    $source = $source.Replace($runLine, $autoExit + "`n" + $runLine)

    $tempScript = Join-Path $tempRoot 'ProxySwitch.ps1'
    [System.IO.File]::WriteAllText($tempScript, $source, $utf8)

    $arguments = @(
        '-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA',
        '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $tempScript),
        '-ShowWindowEventName', ('"{0}"' -f $eventName)
    )
    $process = Start-Process -FilePath 'powershell.exe' -ArgumentList $arguments -PassThru

    if (-not $process.WaitForExit(15000)) {
        throw 'The test application did not exit within the expected time.'
    }

    $actions = @(Get-Content -LiteralPath $logPath -ErrorAction Stop)
    if ($actions.Count -ne 2 -or $actions[0] -ne 'disable' -or $actions[1] -ne 'notify') {
        throw "Unexpected exit action sequence: $($actions -join ', ')"
    }

    Write-Host 'PASS: Exit disabled the proxy, sent the refresh notification, and then exited.'
}
catch {
    Write-Host "FAIL: $($_.Exception.Message)"
    exit 1
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
