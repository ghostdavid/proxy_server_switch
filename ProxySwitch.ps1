param(
    [switch]$SmokeTest,
    [string]$ShowWindowEventName = 'Local\ProxyServerSwitch-Default.ShowWindow',
    [string]$SingleInstanceMutexName = 'Local\ProxyServerSwitch-Default.SingleInstance',
    [string]$ConfigurationPath
)

Set-StrictMode -Version 2.0

$script:ShowWindowEvent = $null
$script:InstanceMutex = $null
$script:OwnsInstanceMutex = $false

try {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    . (Join-Path $PSScriptRoot 'ProxySwitch.Core.ps1')

    $script:ShowWindowEvent = [System.Threading.EventWaitHandle]::new(
        $false,
        [System.Threading.EventResetMode]::AutoReset,
        $ShowWindowEventName
    )
    $createdNew = $false
    $script:InstanceMutex = [System.Threading.Mutex]::new(
        $true,
        $SingleInstanceMutexName,
        [ref]$createdNew
    )
    if (-not $createdNew) {
        $script:ShowWindowEvent.Set()
        return
    }
    $script:OwnsInstanceMutex = $true

    if ([string]::IsNullOrWhiteSpace($ConfigurationPath)) {
        $script:ConfigPath = Join-Path $PSScriptRoot 'config.json'
    }
    else {
        $script:ConfigPath = [System.IO.Path]::GetFullPath($ConfigurationPath)
    }
    $script:ApplicationVersion = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'VERSION') -Raw -Encoding UTF8).Trim()
    $script:IsDirty = $false
    $script:IsExiting = $false

    $proxyOnIcon = [System.Drawing.Icon]::new((Join-Path $PSScriptRoot 'assets\proxy-on.ico'))
    $proxyOffIcon = [System.Drawing.Icon]::new((Join-Path $PSScriptRoot 'assets\proxy-off.ico'))

    try {
        $script:CurrentConfig = Read-ProxyConfig -Path $script:ConfigPath
    }
    catch {
        $script:CurrentConfig = Get-DefaultProxyConfig
        [void][System.Windows.Forms.MessageBox]::Show(
            "$($_.Exception.Message)`n`n已载入默认配置，请检查后重新保存。",
            '配置读取失败',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }

    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Windows 代理开关 $script:ApplicationVersion"
    $form.ClientSize = New-Object System.Drawing.Size(640, 632)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::Dpi

    $titleLabel = New-Object System.Windows.Forms.Label
    $titleLabel.Text = 'Windows 代理开关'
    $titleLabel.Location = New-Object System.Drawing.Point(24, 18)
    $titleLabel.Size = New-Object System.Drawing.Size(590, 34)
    $titleLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 17, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($titleLabel)

    $statusPanel = New-Object System.Windows.Forms.Panel
    $statusPanel.Location = New-Object System.Drawing.Point(24, 64)
    $statusPanel.Size = New-Object System.Drawing.Size(592, 68)
    $statusPanel.BackColor = [System.Drawing.Color]::FromArgb(242, 242, 242)
    $form.Controls.Add($statusPanel)

    $statusLabel = New-Object System.Windows.Forms.Label
    $statusLabel.Location = New-Object System.Drawing.Point(14, 10)
    $statusLabel.Size = New-Object System.Drawing.Size(560, 25)
    $statusLabel.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 11, [System.Drawing.FontStyle]::Bold)
    $statusPanel.Controls.Add($statusLabel)

    $currentProxyLabel = New-Object System.Windows.Forms.Label
    $currentProxyLabel.Location = New-Object System.Drawing.Point(14, 39)
    $currentProxyLabel.Size = New-Object System.Drawing.Size(560, 20)
    $statusPanel.Controls.Add($currentProxyLabel)

    $configGroup = New-Object System.Windows.Forms.GroupBox
    $configGroup.Text = '代理配置'
    $configGroup.Location = New-Object System.Drawing.Point(24, 148)
    $configGroup.Size = New-Object System.Drawing.Size(592, 360)
    $form.Controls.Add($configGroup)

    $addressLabel = New-Object System.Windows.Forms.Label
    $addressLabel.Text = '代理 IP 地址'
    $addressLabel.Location = New-Object System.Drawing.Point(18, 31)
    $addressLabel.Size = New-Object System.Drawing.Size(120, 24)
    $configGroup.Controls.Add($addressLabel)

    $addressText = New-Object System.Windows.Forms.TextBox
    $addressText.Location = New-Object System.Drawing.Point(145, 27)
    $addressText.Size = New-Object System.Drawing.Size(255, 29)
    $addressText.Text = $script:CurrentConfig.ProxyAddress
    $configGroup.Controls.Add($addressText)

    $portLabel = New-Object System.Windows.Forms.Label
    $portLabel.Text = '端口'
    $portLabel.Location = New-Object System.Drawing.Point(420, 31)
    $portLabel.Size = New-Object System.Drawing.Size(50, 24)
    $configGroup.Controls.Add($portLabel)

    $portNumeric = New-Object System.Windows.Forms.NumericUpDown
    $portNumeric.Location = New-Object System.Drawing.Point(475, 27)
    $portNumeric.Size = New-Object System.Drawing.Size(90, 29)
    $portNumeric.Minimum = 1
    $portNumeric.Maximum = 65535
    $portNumeric.Value = [decimal]$script:CurrentConfig.ProxyPort
    $portNumeric.TextAlign = 'Right'
    $configGroup.Controls.Add($portNumeric)

    $bypassLocalCheck = New-Object System.Windows.Forms.CheckBox
    $bypassLocalCheck.Text = '请勿将代理服务器用于本地（Intranet）地址'
    $bypassLocalCheck.Location = New-Object System.Drawing.Point(18, 76)
    $bypassLocalCheck.Size = New-Object System.Drawing.Size(550, 28)
    $bypassLocalCheck.Checked = $script:CurrentConfig.BypassLocal
    $configGroup.Controls.Add($bypassLocalCheck)

    $bypassLabel = New-Object System.Windows.Forms.Label
    $bypassLabel.Text = '请勿对以下列条目开头的地址使用代理服务器'
    $bypassLabel.Location = New-Object System.Drawing.Point(18, 122)
    $bypassLabel.Size = New-Object System.Drawing.Size(550, 24)
    $configGroup.Controls.Add($bypassLabel)

    $bypassText = New-Object System.Windows.Forms.TextBox
    $bypassText.Location = New-Object System.Drawing.Point(18, 151)
    $bypassText.Size = New-Object System.Drawing.Size(550, 145)
    $bypassText.Multiline = $true
    $bypassText.AcceptsReturn = $true
    $bypassText.ScrollBars = 'Vertical'
    $bypassText.Lines = [string[]]$script:CurrentConfig.BypassAddresses
    $configGroup.Controls.Add($bypassText)

    $bypassHintLabel = New-Object System.Windows.Forms.Label
    $bypassHintLabel.Text = '每行一个条目，例如 192.168.* 或 *.example.com'
    $bypassHintLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $bypassHintLabel.Location = New-Object System.Drawing.Point(18, 307)
    $bypassHintLabel.Size = New-Object System.Drawing.Size(550, 24)
    $configGroup.Controls.Add($bypassHintLabel)

    $saveButton = New-Object System.Windows.Forms.Button
    $saveButton.Text = '保存配置'
    $saveButton.Location = New-Object System.Drawing.Point(24, 526)
    $saveButton.Size = New-Object System.Drawing.Size(125, 40)
    $form.Controls.Add($saveButton)

    $toggleButton = New-Object System.Windows.Forms.Button
    $toggleButton.Location = New-Object System.Drawing.Point(388, 526)
    $toggleButton.Size = New-Object System.Drawing.Size(228, 40)
    $toggleButton.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($toggleButton)
    $form.AcceptButton = $toggleButton

    $dirtyLabel = New-Object System.Windows.Forms.Label
    $dirtyLabel.Location = New-Object System.Drawing.Point(166, 535)
    $dirtyLabel.Size = New-Object System.Drawing.Size(205, 24)
    $dirtyLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $form.Controls.Add($dirtyLabel)

    $noteLabel = New-Object System.Windows.Forms.Label
    $noteLabel.Text = '仅修改当前 Windows 用户的系统代理，无需管理员权限。'
    $noteLabel.Location = New-Object System.Drawing.Point(24, 589)
    $noteLabel.Size = New-Object System.Drawing.Size(590, 24)
    $noteLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 90, 90)
    $form.Controls.Add($noteLabel)

    function Update-DirtyState {
        param([bool]$Dirty)

        $script:IsDirty = $Dirty
        if ($Dirty) {
            $dirtyLabel.Text = '配置尚未保存'
            $dirtyLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 95, 0)
        }
        else {
            $dirtyLabel.Text = '配置已保存'
            $dirtyLabel.ForeColor = [System.Drawing.Color]::FromArgb(70, 120, 70)
        }
    }

    function Update-ProxyStatus {
        try {
            $state = Get-SystemProxyState
            if ($state.Enabled) {
                $statusLabel.Text = '● 代理已开启'
                $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 120, 80)
                $toggleButton.Text = '关闭代理'
                $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(205, 65, 65)
                $notifyIcon.Icon = $proxyOnIcon
                $notifyIcon.Text = '代理已开启｜单击切换'
                $form.Icon = $proxyOnIcon
            }
            else {
                $statusLabel.Text = '● 代理已关闭'
                $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
                $toggleButton.Text = '保存并开启代理'
                $toggleButton.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 90)
                $notifyIcon.Icon = $proxyOffIcon
                $notifyIcon.Text = '代理已关闭｜单击切换'
                $form.Icon = $proxyOffIcon
            }

            if ([string]::IsNullOrWhiteSpace($state.Server)) {
                $currentProxyLabel.Text = '当前 Windows 代理地址：未设置'
            }
            else {
                $currentProxyLabel.Text = "当前 Windows 代理地址：$($state.Server)"
            }
            $toggleButton.ForeColor = [System.Drawing.Color]::White
            $toggleButton.UseVisualStyleBackColor = $false
        }
        catch {
            $statusLabel.Text = '无法读取代理状态'
            $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
            $currentProxyLabel.Text = $_.Exception.Message
            $notifyIcon.Text = '无法读取代理状态'
        }
    }

    function Save-ConfigFromForm {
        try {
            $config = New-ProxyConfig `
                -ProxyAddress $addressText.Text `
                -ProxyPort ([int]$portNumeric.Value) `
                -BypassAddresses ($bypassText.Text -split '\r?\n') `
                -BypassLocal $bypassLocalCheck.Checked

            Save-ProxyConfig -Config $config -Path $script:ConfigPath
            $script:CurrentConfig = $config
            Update-DirtyState -Dirty $false
            return $config
        }
        catch {
            [void][System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                '配置无效或无法保存',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            return $null
        }
    }

    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = $proxyOffIcon
    $notifyIcon.Text = 'Windows 代理开关'
    $notifyIcon.Visible = $true

    $trayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $openMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem('打开设置')
    $exitMenuItem = New-Object System.Windows.Forms.ToolStripMenuItem('退出')
    [void]$trayMenu.Items.Add($openMenuItem)
    [void]$trayMenu.Items.Add($exitMenuItem)
    $notifyIcon.ContextMenuStrip = $trayMenu

    $statusTimer = New-Object System.Windows.Forms.Timer
    $statusTimer.Interval = 2000
    $instanceTimer = New-Object System.Windows.Forms.Timer
    $instanceTimer.Interval = 300

    function Invoke-ProxyToggle {
        try {
            $state = Get-SystemProxyState
            if ($state.Enabled) {
                Disable-SystemProxy
                Send-ProxySettingsChangedNotification
            }
            else {
                $config = Save-ConfigFromForm
                if ($null -eq $config) {
                    return
                }

                Enable-SystemProxy -Config $config
                Send-ProxySettingsChangedNotification

                $appliedState = Get-SystemProxyState
                $expectedServer = Format-ProxyServer $config
                $expectedOverride = ConvertTo-ProxyOverride $config
                if (-not $appliedState.Enabled -or $appliedState.Server -ne $expectedServer -or $appliedState.Override -ne $expectedOverride) {
                    [void][System.Windows.Forms.MessageBox]::Show(
                        '设置已写入，但 Windows 当前状态与配置不一致。代理可能由组织策略或其他软件管理。',
                        '请检查代理设置',
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Warning
                    )
                }
            }

            Update-ProxyStatus
        }
        catch {
            Update-ProxyStatus
            [void][System.Windows.Forms.MessageBox]::Show(
                $_.Exception.Message,
                '代理操作失败',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
        }
    }

    function Hide-ToTray {
        $form.Hide()
        $form.ShowInTaskbar = $false
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        }
    }

    function Show-MainWindow {
        $form.ShowInTaskbar = $true
        if (-not $form.Visible) {
            $form.Show()
        }
        $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
        $form.Activate()
        Update-ProxyStatus
    }

    function Exit-Application {
        if ($script:IsDirty) {
            $result = [System.Windows.Forms.MessageBox]::Show(
                '配置尚未保存，是否保存后退出？',
                '退出代理开关',
                [System.Windows.Forms.MessageBoxButtons]::YesNoCancel,
                [System.Windows.Forms.MessageBoxIcon]::Question
            )

            if ($result -eq [System.Windows.Forms.DialogResult]::Cancel) {
                return
            }
            if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
                $config = Save-ConfigFromForm
                if ($null -eq $config) {
                    return
                }
            }
        }

        try {
            Disable-SystemProxy
            Send-ProxySettingsChangedNotification
            Update-ProxyStatus
        }
        catch {
            Update-ProxyStatus
            [void][System.Windows.Forms.MessageBox]::Show(
                "关闭代理失败，软件尚未退出。`n`n$($_.Exception.Message)",
                '退出代理开关',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error
            )
            return
        }

        $script:IsExiting = $true
        $notifyIcon.Visible = $false
        $form.Close()
    }

    $markDirty = {
        Update-DirtyState -Dirty $true
    }

    $addressText.add_TextChanged($markDirty)
    $portNumeric.add_ValueChanged($markDirty)
    $bypassLocalCheck.add_CheckedChanged($markDirty)
    $bypassText.add_TextChanged($markDirty)

    $saveButton.add_Click({
        $config = Save-ConfigFromForm
        if ($null -ne $config) {
            $dirtyLabel.Text = '配置已保存'
        }
    })

    $toggleButton.add_Click({ Invoke-ProxyToggle })
    $notifyIcon.add_MouseClick({
        param($sender, $eventArgs)

        if ($eventArgs.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
            Invoke-ProxyToggle
        }
    })
    $openMenuItem.add_Click({ Show-MainWindow })
    $exitMenuItem.add_Click({ Exit-Application })
    $statusTimer.add_Tick({ Update-ProxyStatus })
    $instanceTimer.add_Tick({
        if ($script:ShowWindowEvent.WaitOne(0)) {
            Show-MainWindow
        }
    })

    $form.add_Resize({
        if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
            Hide-ToTray
        }
    })

    $form.add_FormClosing({
        param($sender, $eventArgs)

        if (-not $script:IsExiting -and $eventArgs.CloseReason -ne [System.Windows.Forms.CloseReason]::WindowsShutDown) {
            $eventArgs.Cancel = $true
            Hide-ToTray
        }
    })

    Update-DirtyState -Dirty $false
    Update-ProxyStatus
    $statusTimer.Start()
    $instanceTimer.Start()

    if ($SmokeTest) {
        $script:IsExiting = $true
        $statusTimer.Stop()
        $statusTimer.Dispose()
        $instanceTimer.Stop()
        $instanceTimer.Dispose()
        $notifyIcon.Visible = $false
        $notifyIcon.Dispose()
        $trayMenu.Dispose()
        $form.Dispose()
        $proxyOnIcon.Dispose()
        $proxyOffIcon.Dispose()
        return
    }

    [void][System.Windows.Forms.Application]::Run($form)
    $statusTimer.Stop()
    $statusTimer.Dispose()
    $instanceTimer.Stop()
    $instanceTimer.Dispose()
    $notifyIcon.Visible = $false
    $notifyIcon.Dispose()
    $trayMenu.Dispose()
    $proxyOnIcon.Dispose()
    $proxyOffIcon.Dispose()
}
catch {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
        [void][System.Windows.Forms.MessageBox]::Show(
            $_.Exception.Message,
            '代理开关启动失败',
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error
        )
    }
    catch {
        Write-Error $_
    }
    exit 1
}
finally {
    if ($script:OwnsInstanceMutex -and $null -ne $script:InstanceMutex) {
        try {
            $script:InstanceMutex.ReleaseMutex()
        }
        catch {
            # 实例已经异常退出时，无需再次报告释放失败。
        }
    }
    if ($null -ne $script:InstanceMutex) {
        $script:InstanceMutex.Dispose()
    }
    if ($null -ne $script:ShowWindowEvent) {
        $script:ShowWindowEvent.Dispose()
    }
}
