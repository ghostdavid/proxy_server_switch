Set-StrictMode -Version 2.0

$script:ProxyRegistryPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'

function Get-DefaultProxyConfig {
    return [pscustomobject]@{
        ProxyAddress    = '127.0.0.1'
        ProxyPort       = 7890
        BypassAddresses = @()
        BypassLocal     = $true
    }
}

function New-ProxyConfig {
    param(
        [Parameter(Mandatory = $true)][string]$ProxyAddress,
        [Parameter(Mandatory = $true)][int]$ProxyPort,
        [string[]]$BypassAddresses = @(),
        [Parameter(Mandatory = $true)][bool]$BypassLocal
    )

    $normalizedAddress = $ProxyAddress.Trim()
    if ($normalizedAddress.Length -ge 2 -and $normalizedAddress.StartsWith('[') -and $normalizedAddress.EndsWith(']')) {
        $normalizedAddress = $normalizedAddress.Substring(1, $normalizedAddress.Length - 2)
    }

    $parsedAddress = $null
    if (-not [System.Net.IPAddress]::TryParse($normalizedAddress, [ref]$parsedAddress)) {
        throw '代理地址必须是有效的 IPv4 或 IPv6 地址。'
    }

    if ($parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork -and
        $parsedAddress.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
        throw '代理地址必须是有效的 IPv4 或 IPv6 地址。'
    }

    if ($ProxyPort -lt 1 -or $ProxyPort -gt 65535) {
        throw '端口号必须在 1 到 65535 之间。'
    }

    $normalizedBypass = @()
    foreach ($entry in @($BypassAddresses)) {
        if ($null -eq $entry) {
            continue
        }

        $value = ([string]$entry).Trim()
        if ([string]::IsNullOrWhiteSpace($value) -or $value -ieq '<local>') {
            continue
        }

        if ($normalizedBypass -notcontains $value) {
            $normalizedBypass += $value
        }
    }

    return [pscustomobject]@{
        ProxyAddress    = $parsedAddress.IPAddressToString
        ProxyPort       = $ProxyPort
        BypassAddresses = $normalizedBypass
        BypassLocal     = $BypassLocal
    }
}

function Read-ProxyConfig {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return Get-DefaultProxyConfig
    }

    try {
        $raw = Get-Content -LiteralPath $Path -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "无法读取配置文件：$Path`n$($_.Exception.Message)"
    }

    foreach ($name in @('ProxyAddress', 'ProxyPort', 'BypassAddresses', 'BypassLocal')) {
        if ($raw.PSObject.Properties.Name -notcontains $name) {
            throw "配置文件缺少字段：$name"
        }
    }

    if ($raw.BypassLocal -isnot [bool]) {
        throw '配置文件字段 BypassLocal 必须是 true 或 false。'
    }

    return New-ProxyConfig `
        -ProxyAddress ([string]$raw.ProxyAddress) `
        -ProxyPort ([int]$raw.ProxyPort) `
        -BypassAddresses ([string[]]@($raw.BypassAddresses)) `
        -BypassLocal ([bool]$raw.BypassLocal)
}

function Save-ProxyConfig {
    param(
        [Parameter(Mandatory = $true)][pscustomobject]$Config,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $normalized = New-ProxyConfig `
        -ProxyAddress $Config.ProxyAddress `
        -ProxyPort $Config.ProxyPort `
        -BypassAddresses $Config.BypassAddresses `
        -BypassLocal $Config.BypassLocal

    $json = $normalized | ConvertTo-Json -Depth 4
    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = [System.IO.Path]::GetDirectoryName($fullPath)

    if (-not [System.IO.Directory]::Exists($directory)) {
        [void][System.IO.Directory]::CreateDirectory($directory)
    }

    try {
        $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($fullPath, $json + [System.Environment]::NewLine, $utf8WithoutBom)
    }
    catch {
        throw "无法保存配置文件：$fullPath`n$($_.Exception.Message)"
    }
}

function Format-ProxyServer {
    param([Parameter(Mandatory = $true)][pscustomobject]$Config)

    $address = $Config.ProxyAddress
    $parsedAddress = $null
    if ([System.Net.IPAddress]::TryParse($address, [ref]$parsedAddress) -and
        $parsedAddress.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
        return "[$address]:$($Config.ProxyPort)"
    }

    return "${address}:$($Config.ProxyPort)"
}

function ConvertTo-ProxyOverride {
    param([Parameter(Mandatory = $true)][pscustomobject]$Config)

    $entries = @($Config.BypassAddresses)
    if ($Config.BypassLocal) {
        $entries += '<local>'
    }

    return ($entries -join ';')
}

function Get-SystemProxyState {
    try {
        $settings = Get-ItemProperty -Path $script:ProxyRegistryPath -ErrorAction Stop
    }
    catch {
        throw "无法读取 Windows 代理设置：$($_.Exception.Message)"
    }

    $enabled = $false
    $server = ''
    $override = ''

    if ($settings.PSObject.Properties.Name -contains 'ProxyEnable') {
        $enabled = ([int]$settings.ProxyEnable -ne 0)
    }
    if ($settings.PSObject.Properties.Name -contains 'ProxyServer') {
        $server = [string]$settings.ProxyServer
    }
    if ($settings.PSObject.Properties.Name -contains 'ProxyOverride') {
        $override = [string]$settings.ProxyOverride
    }

    return [pscustomobject]@{
        Enabled  = $enabled
        Server   = $server
        Override = $override
    }
}

function Restore-SystemProxyState {
    param([Parameter(Mandatory = $true)][pscustomobject]$State)

    Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyServer -Value $State.Server -ErrorAction Stop
    Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyOverride -Value $State.Override -ErrorAction Stop
    Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyEnable -Value ([int]$State.Enabled) -Type DWord -ErrorAction Stop
}

function Enable-SystemProxy {
    param([Parameter(Mandatory = $true)][pscustomobject]$Config)

    $normalized = New-ProxyConfig `
        -ProxyAddress $Config.ProxyAddress `
        -ProxyPort $Config.ProxyPort `
        -BypassAddresses $Config.BypassAddresses `
        -BypassLocal $Config.BypassLocal

    $previousState = Get-SystemProxyState

    try {
        if (-not (Test-Path -LiteralPath $script:ProxyRegistryPath)) {
            [void](New-Item -Path $script:ProxyRegistryPath -Force -ErrorAction Stop)
        }

        Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyServer -Value (Format-ProxyServer $normalized) -ErrorAction Stop
        Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyOverride -Value (ConvertTo-ProxyOverride $normalized) -ErrorAction Stop
        Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyEnable -Value 1 -Type DWord -ErrorAction Stop
    }
    catch {
        try {
            Restore-SystemProxyState -State $previousState
        }
        catch {
            # 保留原始错误，避免回滚错误覆盖真正原因。
        }
        throw "无法开启 Windows 代理：$($_.Exception.Message)"
    }
}

function Disable-SystemProxy {
    try {
        Set-ItemProperty -Path $script:ProxyRegistryPath -Name ProxyEnable -Value 0 -Type DWord -ErrorAction Stop
    }
    catch {
        throw "无法关闭 Windows 代理：$($_.Exception.Message)"
    }
}

function Send-ProxySettingsChangedNotification {
    if (-not ('ProxySwitch.NativeMethods' -as [type])) {
        Add-Type -Namespace ProxySwitch -Name NativeMethods -MemberDefinition @'
[DllImport("wininet.dll", SetLastError = true)]
public static extern bool InternetSetOption(System.IntPtr hInternet, int dwOption, System.IntPtr lpBuffer, int dwBufferLength);
'@
    }

    # 通知支持 WinINet 的应用重新读取当前用户的代理设置。
    [void][ProxySwitch.NativeMethods]::InternetSetOption([System.IntPtr]::Zero, 39, [System.IntPtr]::Zero, 0)
    [void][ProxySwitch.NativeMethods]::InternetSetOption([System.IntPtr]::Zero, 37, [System.IntPtr]::Zero, 0)
}
