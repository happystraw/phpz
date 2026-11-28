<#
.SYNOPSIS
Build a Linux or macOS PHP extension from its project directory.
.DESCRIPTION
Downloads the selected php-extension-sdk release, verifies its SHA256, then
passes the target and include directory to Zig. Verified SDKs are cached in
%LOCALAPPDATA%/phpz/sdk on Windows, or under XDG_CACHE_HOME when set.
Requires Zig, tar, and PowerShell.
.PARAMETER PhpVersion
Exact PHP release version (major.minor.patch) with published SDK assets.
.PARAMETER Target
Zig target: x86_64 or aarch64 with linux-gnu, linux-musl, or macos.
.PARAMETER Nts
Select non-thread-safe PHP explicitly (the default).
.PARAMETER Zts
Select the thread-safe SDK. The default is NTS.
.PARAMETER ZigArgs
Additional arguments for zig build, passed as an array of strings.
.EXAMPLE
PS> C:\tools\phpz\scripts\build-unix.ps1 -PhpVersion 8.2.36 -Target aarch64-linux-gnu -Nts
Build an ARM64 Linux extension with glibc for PHP 8.2.36 NTS.
.EXAMPLE
PS> C:\tools\phpz\scripts\build-unix.ps1 -PhpVersion 8.2.36 -Target x86_64-macos -Zts -ZigArgs @('-Doptimize=ReleaseFast')
Build an optimized Intel macOS extension for PHP 8.2.36 ZTS.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string] $PhpVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('x86_64-linux-gnu', 'aarch64-linux-gnu', 'x86_64-linux-musl',
                 'aarch64-linux-musl', 'x86_64-macos', 'aarch64-macos')]
    [string] $Target,

    [switch] $Zts,
    [string[]] $ZigArgs = @(),
    [switch] $Nts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($Nts -and $Zts) { throw 'Choose either -Nts or -Zts.' }
if (!(Test-Path -LiteralPath 'build.zig') -or !(Test-Path -LiteralPath 'build.zig.zon')) {
    throw 'Run from the extension project directory.'
}
foreach ($arg in $ZigArgs) {
    if ($arg -match '^-D(target|php-include-dir)=') {
        throw "SDK selection already sets $arg"
    }
}

$Target = $Target.ToLowerInvariant()
$arch, $system = $Target -split '-', 2
switch ($system) {
    'linux-gnu'  { $platform = "linux-$arch-glibc"; $legacyTarget = "$Target.2.36" }
    'linux-musl' { $platform = "linux-$arch-musl";  $legacyTarget = $Target }
    'macos'      { $platform = "macos-$arch";       $legacyTarget = "$Target.15.0" }
}
$ts = if ($Zts) { 'zts' } else { 'nts' }
$package = "php-$PhpVersion-$platform-$ts"
$archive = "$package.tar.gz"
$cacheRoot = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else {
    [Environment]::GetFolderPath('LocalApplicationData')
}
$cache = Join-Path $cacheRoot 'phpz/sdk'
$cache = (New-Item -ItemType Directory -Force -Path $cache).FullName
$sdk = Join-Path $cache $package
if (!(Test-Path -LiteralPath $sdk -PathType Container)) {
    $url = "https://github.com/happystraw/php-extension-sdk/releases/download/php-$PhpVersion"
    $tmp = (New-Item -ItemType Directory -Path (Join-Path $cache ([Guid]::NewGuid().ToString()))).FullName
    try {
        foreach ($asset in @('SHA256SUMS', $archive)) {
            Invoke-WebRequest -UseBasicParsing -Uri "$url/$asset" -OutFile (Join-Path $tmp $asset)
        }
        $pattern = '^([0-9a-fA-F]{64})  ' + [regex]::Escape($archive) + '$'
        $entries = @(Select-String -LiteralPath (Join-Path $tmp 'SHA256SUMS') -Pattern $pattern -CaseSensitive)
        if ($entries.Count -ne 1) { throw "Missing or duplicate checksum for $archive" }
        $file = Join-Path $tmp $archive
        if ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ne $entries[0].Matches[0].Groups[1].Value) {
            throw "SHA256 mismatch for $archive"
        }
        & tar -xzf $file -C $tmp
        if ($LASTEXITCODE -ne 0) { throw "Cannot extract $archive" }
        $extracted = Join-Path $tmp $package
        if (!(Test-Path (Join-Path $extracted 'include/main/php.h')) -or
            !(Test-Path (Join-Path $extracted 'build-info.txt'))) { throw "Incomplete SDK: $archive" }
        try {
            [IO.Directory]::Move($extracted, $sdk)
        } catch [IO.IOException] {
            if (!(Test-Path -LiteralPath $sdk -PathType Container)) { throw }
        }
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force
    }
}

$zigTarget = $legacyTarget
foreach ($line in Get-Content -LiteralPath (Join-Path $sdk 'build-info.txt')) {
    if ($line -cmatch '^zig_target=(.+)$') { $zigTarget = $Matches[1] }
}
if ($zigTarget -cne $Target -and !$zigTarget.StartsWith("$Target.")) {
    throw "SDK $package declares an incompatible Zig target: $zigTarget"
}
Write-Host "Building $zigTarget with SDK $package"
$include = Join-Path $sdk 'include'
& zig build "-Dtarget=$zigTarget" "-Dphp-include-dir=$include" @ZigArgs
exit $LASTEXITCODE
