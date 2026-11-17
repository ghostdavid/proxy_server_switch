# 项目记忆

## 项目概况与现状

- 本项目是 Windows 当前用户的手动系统代理开关，不提供代理服务器或节点。面向 Windows 11，使用 Windows PowerShell、WinForms、Windows 注册表和 WinINet；其他系统的兼容性未验证。
- 当前显示版本由 `VERSION` 定义为 `v2026.11.13`，启动器程序集及文件版本在 `launcher/ProxySwitchLauncher.cs` 中定义为 `2026.11.13.0`。版本变更需同步核对这两处与用户文档，构建脚本不会自动同步版本。
- 已实现 IPv4/IPv6 与端口校验、例外地址去重、本地地址例外、保存配置、代理开关、托盘操作、状态定时刷新和单实例唤醒。代理地址仅接受 IP，不接受域名或 URL。
- 交付形式包括源码入口与独立 EXE。EXE 内嵌脚本、版本和状态图标，启动时解包到随机临时目录并调用系统 Windows PowerShell，等待子进程退出后尝试清理；独立 EXE 仍依赖 PowerShell。
- 关闭或最小化窗口会隐藏到托盘。托盘退出先处理未保存配置，再关闭代理、通知系统并确认状态；Windows 关机不调用同一退出逻辑，强制结束进程也不能保证关闭代理。

## 资料与文件地图

- `ProxySwitch.Core.ps1`：配置默认值、规范化、JSON 读写、代理字符串生成、当前用户注册表读写、开启失败回滚尝试及 WinINet 通知。
- `ProxySwitch.ps1`：WinForms 界面、托盘、未保存状态、开关与退出、互斥量和唤醒事件。代理状态轮询间隔 2 秒，唤醒事件轮询间隔 300 毫秒。
- `Start-ProxySwitch.cmd`：源码入口，以 STA 模式启动系统 Windows PowerShell。
- `launcher/ProxySwitchLauncher.cs`：内嵌资源解包和 PowerShell 子进程管理，支持自定义实例标识与冒烟参数。源码和 EXE 默认使用相同实例名称，同一会话中不会作为两个默认实例同时运行。
- `tools/build_launcher.ps1`：调用系统 .NET Framework C# 编译器，优先 Framework64、其次 Framework，输出 `release/Start-ProxySwitch.exe`，不运行测试。
- `tools/generate_icons.py`：正式图标维护工具，依赖 Python 与 Pillow；普通运行不需要 Python。`assets/` 保存应用和状态图标。
- `tools/capture_screenshot.ps1`：使用临时脚本副本、示例配置及模拟读取状态生成 `docs/images/main-window.png`；临时工作目录为 `.release-updater/screenshot/`。使用客户区尺寸与捕获标志排除标题栏和外边框，但仍有前台激活问题，见规则与限制。
- `tests/`：本地自定义 PowerShell 检查脚本，不是 Pester 套件。`ProxySwitch.Core.Tests.ps1` 检查配置校验、格式化与读写；`ProxySwitch.Exit.Tests.ps1` 模拟代理函数检查退出；`ProxySwitch.Window.Tests.ps1` 检查关闭及最小化隐藏；`ProxySwitch.Launcher.Tests.ps1` 检查已有 EXE 的隐藏控制台、最小化及重复启动。窗口与退出检查使用独立事件名和互斥量，窗口使用示例配置。
- `README.md`：面向用户的介绍、源码使用说明及必要限制；`PROJECT.md`：项目专属事实、文件位置与约束；`VERSION`：显示版本。
- `config.example.json`：本地合成示例配置，也供截图工具和部分检查使用；真实配置为源码目录的 `config.json` 或 EXE 目录的 `release/config.json`，不作为记忆材料复制。
- `.gitignore`：忽略真实配置、示例配置、`release/`、`tests/`、`.release-updater/`、根目录 `tmp/`、`temp/`、`scratch/`、日志、部分临时文件及 `AGENTS.md`。`.gitattributes` 保持 CMD 与 PowerShell 文件使用 CRLF。

## 规则与限制

- 配置位于程序目录而非用户数据目录：源码使用主脚本目录，EXE 使用 EXE 目录，两者不会自动同步。保存要求目录可写；修改当前用户代理不需要管理员权限，不代表任意安装位置都可保存。
- 仅操作当前用户 Internet Settings 下的 `ProxyEnable`、`ProxyServer` 和 `ProxyOverride`，不管理 WinHTTP、PAC 或自动检测设置。界面状态只依据 `ProxyEnable`，不表示代理服务可用，也不能证明所有应用直连或使用代理。
- 关闭代理仅修改启用标志，保留服务器、例外与 JSON 配置；退出不是恢复启动前设置。其他软件或组织策略可能同时改变状态，读回结果只代表当时状态。
- 配置保存先写同目录随机临时文件，再以 File.Replace 替换已有文件或 File.Move 创建新文件，防止写入失败截断旧配置；不回退到直接覆盖。Windows PowerShell 调用 Replace 时通过 NullString.Value 传递空备份路径，避免普通 null 被转换为空字符串。不支持替换的文件系统可能保存失败；损坏配置读取失败后回退默认值并警告。
- 开启代理失败时尝试回滚三个注册表值，但忽略回滚失败，且快照不记录原值是否存在，因此不是严格事务恢复。
- WinINet 通知检查每次调用返回值，失败时报告原生错误并区分设置写入与通知失败。托盘退出在关闭及通知后回读状态，仍启用或读取失败时不退出；不能阻止其他软件随后改变状态。
- 真实系统代理开关、网络连通性、真实写入中断、注册表部分失败及回滚失败未得到完整运行验证。模拟检查或历史构建不能证明当前交付通过这些场景；文档同步不代表重新验证功能。
- 旧项目记忆记录测试、示例配置及发布 EXE 曾被 Git 跟踪，当前跟踪状态未复核。新增忽略规则不会取消已有跟踪；不得据此删除、移动或取消跟踪这些文件，处理既有跟踪差异需另行授权。
- README 首张软件截图紧接标题和一句话介绍，先于版本及详细介绍；截图仅展示客户区，不含系统标题栏，依据用户展示要求。
- 当前截图工具会调用 ShowWindow 和 SetForegroundWindow，尚不符合后台截图要求；未经修正不应运行该流程。工具只模拟读取状态，不隔离写操作，不应在截图实例中手动切换代理或选择托盘退出。现有图片内容未重新核验，不能仅依据工具使用示例数据认定图片已完成隐私核验。
