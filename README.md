# Windows 代理开关

当前版本：1.0.0（2026-10-30）

一个适用于 Windows 11 的本地代理切换工具。它通过中文图形界面保存代理配置，让你从窗口或系统托盘一键开启、关闭当前用户的 Windows 系统代理。

本工具只负责切换和管理系统代理设置，不提供代理服务器或代理节点。使用前请准备可用的代理 IP 地址和端口。

## 软件界面

![Windows 代理开关 1.0.0 主界面](docs/images/main-window.png)

截图中的地址均为文档示例，不是可用的代理节点。

## 主要功能

- 图形化填写并保存代理 IP 地址、端口和例外地址。
- 支持 IPv4、IPv6，以及本地（Intranet）地址绕过设置。
- 点击窗口按钮即可保存配置并开启代理，或关闭当前代理。
- 最小化或关闭窗口后自动隐藏到系统托盘，继续驻留后台。
- 只运行一个软件实例；再次双击主程序会恢复之前已打开的窗口。
- 左键单击托盘图标直接切换代理状态。
- 绿色对勾表示代理已开启，灰色叉号表示代理已关闭。
- 每 2 秒同步 Windows 的实际代理状态，避免图标状态过时。
- 配置保存在本机，重新打开程序后仍可继续使用。
- 无需管理员权限，无需安装第三方运行环境。

## 环境要求

- Windows 11。
- Windows 自带的 Windows PowerShell 5.1。
- 一个已经可用的代理服务器及其 IP 地址、端口。

普通用户不需要安装 Python、Node.js 或其他开发工具。

## 快速开始

### 1. 启动程序

下载并解压项目后，双击：

```text
Start-ProxySwitch.exe
```

该启动器不会显示 PowerShell 终端窗口。程序会打开主窗口，并在 Windows 右下角系统托盘显示图标。如果看不到图标，请点击托盘区域的“显示隐藏的图标”箭头。

软件只运行一个实例。如果程序已经打开，再次双击 EXE 会把之前的窗口恢复到桌面；窗口在托盘中时也会自动显示，不会启动第二个副本。

`Start-ProxySwitch.cmd` 仅保留为兼容入口，日常使用请优先双击 `.exe` 文件。

### 2. 填写代理配置

| 配置项 | 填写方法 |
| --- | --- |
| 代理 IP 地址 | 填写代理服务器的 IPv4 或 IPv6 地址，不要添加 `http://`、`https://` 或端口。 |
| 端口 | 填写 1–65535 范围内的代理端口。 |
| 例外地址 | 每行填写一个不希望使用代理的地址条目。 |
| 本地地址例外 | 勾选后，不将代理用于本地（Intranet）地址。 |

例外地址示例：

```text
localhost
127.*
10.*
192.168.*
*.example.com
```

程序会在保存时自动把每行条目转换为 Windows 所需格式。具体匹配规则由 Windows 系统代理设置决定。

### 3. 保存并开启代理

- 点击“保存配置”：只保存修改，不改变当前代理状态。
- 点击“保存并开启代理”：保存修改并立即开启系统代理。
- 开启成功后，状态区域显示“代理已开启”，托盘图标变为绿色对勾。

首次使用时，请先把默认地址和端口改为自己的代理信息，再开启代理。

### 4. 关闭代理

点击窗口中的“关闭代理”，或左键单击绿色托盘图标。关闭代理不会删除已保存的配置。

## 托盘操作指南

| 操作 | 结果 |
| --- | --- |
| 最小化窗口 | 隐藏窗口，程序继续留在托盘运行。 |
| 点击窗口右上角“关闭” | 隐藏窗口，程序继续留在托盘运行，不会直接退出。 |
| 左键单击托盘图标 | 根据当前状态开启或关闭代理。开启时会使用窗口中保存的配置。 |
| 右键单击托盘图标 →“打开设置” | 重新显示主窗口。 |
| 右键单击托盘图标 →“退出” | 先关闭 Windows 系统代理，再真正退出程序。 |

如果退出时还有未保存的修改，程序会询问是否保存。关闭代理成功后才会退出；如果关闭代理失败，程序会提示原因并继续运行，避免代理仍处于开启状态。

## 配置文件与隐私

实际配置保存在程序目录的 `config.json` 中。建议直接通过窗口修改，不必手动编辑 JSON。

- `config.json` 可能包含内网 IP、域名等个人信息，已在 `.gitignore` 中排除，不应上传到 GitHub。
- `config.example.json` 是脱敏示例，仅用于说明配置格式。
- `192.0.2.10` 和 `*.example.com` 均为文档示例，不代表真实服务器。
- 发布项目前，还应检查截图、日志和其他本地文件是否包含个人信息。

## 常见问题

### 为什么推荐使用 EXE，而不是 CMD？

CMD 是命令行脚本入口，依赖 Windows 控制台宿主，启动 PowerShell 时可能出现控制台窗口。EXE 是按 Windows 图形程序类型编译的启动器，本身没有控制台，并以无窗口方式启动 PowerShell；它还负责单实例检查和通知已有实例恢复窗口。核心代理功能仍由 PowerShell 脚本实现，EXE 只负责启动。

### 点击窗口关闭按钮后，程序为什么还在运行？

这是设计行为。窗口关闭按钮只会把程序隐藏到托盘。要完全退出，请右键单击托盘图标并选择“退出”。

### 开启后，某个应用仍然没有使用代理怎么办？

部分应用使用自己的代理设置，不会读取 Windows 系统代理。请检查该应用的代理选项；某些已经运行的应用还需要重启后才能读取新设置。

### 设置被还原或状态显示不一致怎么办？

电脑可能受到组织策略或其他网络管理软件控制。请检查相关策略或软件是否覆盖了系统代理设置。

### 是否需要管理员权限？

不需要。本工具只修改当前 Windows 用户的系统代理，不修改其他用户的设置。

### 启动文件会修改 PowerShell 的全局执行策略吗？

不会。启动参数只对本次程序进程生效，不会更改系统的全局执行策略。

## 项目结构

```text
proxy_server_switch/
├── Start-ProxySwitch.exe          # 无控制台启动器，推荐双击使用
├── Start-ProxySwitch.cmd          # 兼容启动入口
├── ProxySwitch.ps1               # 主窗口、托盘和交互逻辑
├── ProxySwitch.Core.ps1          # 配置校验及系统代理读写
├── launcher/                     # 启动器 C# 源码
├── config.example.json           # 脱敏配置示例
├── VERSION                       # 当前版本号
├── CHANGELOG.md                  # 用户版本更新日志
├── assets/                       # 开启、关闭状态图标
├── docs/images/                  # README 软件界面截图
├── tests/                        # 核心、窗口和启动器测试
└── tools/                        # 构建、图标生成与脱敏截图工具
```

本机运行后还会出现 `config.json`，该文件被 Git 忽略。

## 开发与验证

普通用户无需执行本节命令。

核心测试不会修改真实代理状态或正式配置：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tests\ProxySwitch.Core.Tests.ps1"
```

窗口事件测试会启动独立实例，模拟最小化和关闭，并在结束后清理测试实例：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File ".\tests\ProxySwitch.Window.Tests.ps1"
```

启动器测试会检查可见控制台窗口、单实例运行，以及再次启动后恢复已有窗口：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File ".\tests\ProxySwitch.Launcher.Tests.ps1"
```

退出行为测试使用模拟代理状态，验证关闭代理和发送刷新通知后才退出，不修改真实设置：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File ".\tests\ProxySwitch.Exit.Tests.ps1"
```

修改启动器源码后，使用 Windows 自带的 .NET Framework 编译器重新构建：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File ".\tools\build_launcher.ps1"
```

重新生成脱敏主界面截图：

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File ".\tools\capture_screenshot.ps1"
```
