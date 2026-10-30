Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'launcher\ProxySwitchLauncher.cs'
$output = Join-Path $root 'Start-ProxySwitch.exe'
$icon = Join-Path $root 'assets\app-icon.ico'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'

if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'The .NET Framework C# compiler was not found.'
}

& $compiler `
    /nologo `
    /target:winexe `
    /platform:anycpu `
    /optimize+ `
    /out:"$output" `
    /win32icon:"$icon" `
    /reference:System.dll `
    /reference:System.Windows.Forms.dll `
    "$source"

if ($LASTEXITCODE -ne 0) {
    throw "The launcher build failed with exit code $LASTEXITCODE."
}

Write-Host 'Launcher built: Start-ProxySwitch.exe'
