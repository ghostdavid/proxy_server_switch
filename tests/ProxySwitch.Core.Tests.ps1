Set-StrictMode -Version 2.0

. (Join-Path $PSScriptRoot '..\ProxySwitch.Core.ps1')

$script:Passed = 0
$script:Failed = 0

function Assert-Equal {
    param($Expected, $Actual, [string]$Name)

    if ([string]$Expected -ceq [string]$Actual) {
        $script:Passed++
        Write-Host "PASS: $Name"
    }
    else {
        $script:Failed++
        Write-Host "FAIL: $Name (expected '$Expected', actual '$Actual')"
    }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Name)

    try {
        & $Action
        $script:Failed++
        Write-Host "FAIL: $Name (no exception was thrown)"
    }
    catch {
        $script:Passed++
        Write-Host "PASS: $Name"
    }
}

$ipv4 = New-ProxyConfig -ProxyAddress ' 192.168.1.20 ' -ProxyPort 8080 -BypassAddresses @('localhost', '127.*', 'localhost', '<local>') -BypassLocal $true
Assert-Equal '192.168.1.20' $ipv4.ProxyAddress 'IPv4 地址会去除首尾空格'
Assert-Equal '192.168.1.20:8080' (Format-ProxyServer $ipv4) 'IPv4 代理地址格式正确'
Assert-Equal 'localhost;127.*;<local>' (ConvertTo-ProxyOverride $ipv4) '例外列表去重并添加 local 标记'
Assert-Equal 2 $ipv4.BypassAddresses.Count '配置文件不重复保存 local 标记'

$noLocal = New-ProxyConfig -ProxyAddress '10.0.0.2' -ProxyPort 1080 -BypassAddresses @('*.example.com') -BypassLocal $false
Assert-Equal '*.example.com' (ConvertTo-ProxyOverride $noLocal) '未勾选时不添加 local 标记'

$ipv6 = New-ProxyConfig -ProxyAddress '[::1]' -ProxyPort 7890 -BypassAddresses @() -BypassLocal $true
Assert-Equal '::1' $ipv6.ProxyAddress 'IPv6 地址会去除方括号'
Assert-Equal '[::1]:7890' (Format-ProxyServer $ipv6) 'IPv6 代理地址添加必要方括号'
Assert-Equal '<local>' (ConvertTo-ProxyOverride $ipv6) '空例外列表仍可包含 local 标记'

Assert-Throws { New-ProxyConfig -ProxyAddress 'not-an-ip' -ProxyPort 8080 -BypassLocal $true } '拒绝无效 IP 地址'
Assert-Throws { New-ProxyConfig -ProxyAddress '127.0.0.1' -ProxyPort 0 -BypassLocal $true } '拒绝过小的端口'
Assert-Throws { New-ProxyConfig -ProxyAddress '127.0.0.1' -ProxyPort 65536 -BypassLocal $true } '拒绝过大的端口'

$testConfigPath = Join-Path $PSScriptRoot 'config.test.tmp.json'
try {
    $roundTrip = New-ProxyConfig -ProxyAddress '2001:db8::1' -ProxyPort 3128 -BypassAddresses @('10.*', '*.internal') -BypassLocal $false
    Save-ProxyConfig -Config $roundTrip -Path $testConfigPath
    $loaded = Read-ProxyConfig -Path $testConfigPath

    Assert-Equal '2001:db8::1' $loaded.ProxyAddress '配置读写保留 IPv6 地址'
    Assert-Equal 3128 $loaded.ProxyPort '配置读写保留端口'
    Assert-Equal '10.*;*.internal' ($loaded.BypassAddresses -join ';') '配置读写保留例外列表'
    Assert-Equal 'False' $loaded.BypassLocal '配置读写保留本地地址开关'
}
finally {
    if (Test-Path -LiteralPath $testConfigPath) {
        Remove-Item -LiteralPath $testConfigPath -Force
    }
}

Write-Host "`n$($script:Passed) passed, $($script:Failed) failed."
if ($script:Failed -gt 0) {
    exit 1
}
