Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$source = Join-Path $root 'launcher\ProxySwitchLauncher.cs'
$releaseDirectory = Join-Path $root 'release'
$output = Join-Path $releaseDirectory 'Start-ProxySwitch.exe'
$icon = Join-Path $root 'assets\app-icon.ico'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$resources = @(
    @{ Path = (Join-Path $root 'ProxySwitch.ps1'); Name = 'ProxySwitch.ps1' },
    @{ Path = (Join-Path $root 'ProxySwitch.Core.ps1'); Name = 'ProxySwitch.Core.ps1' },
    @{ Path = (Join-Path $root 'VERSION'); Name = 'VERSION' },
    @{ Path = (Join-Path $root 'assets\proxy-on.ico'); Name = 'assets/proxy-on.ico' },
    @{ Path = (Join-Path $root 'assets\proxy-off.ico'); Name = 'assets/proxy-off.ico' }
)

if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $compiler -PathType Leaf)) {
    throw 'The .NET Framework C# compiler was not found.'
}

foreach ($resource in $resources) {
    if (-not (Test-Path -LiteralPath $resource.Path -PathType Leaf)) {
        throw "Embedded resource not found: $($resource.Path)"
    }
}

[void](New-Item -Path $releaseDirectory -ItemType Directory -Force)

$compilerArguments = @(
    '/nologo',
    '/target:winexe',
    '/platform:anycpu',
    '/optimize+',
    "/out:`"$output`"",
    "/win32icon:`"$icon`"",
    '/reference:System.dll',
    '/reference:System.Windows.Forms.dll'
)
foreach ($resource in $resources) {
    $compilerArguments += "/resource:`"$($resource.Path)`",$($resource.Name)"
}
$compilerArguments += $source

& $compiler $compilerArguments

if ($LASTEXITCODE -ne 0) {
    throw "The launcher build failed with exit code $LASTEXITCODE."
}

Write-Host 'Standalone launcher built: release\Start-ProxySwitch.exe'
