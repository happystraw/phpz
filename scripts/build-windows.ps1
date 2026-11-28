<#
.SYNOPSIS
Build a Windows x64 MSVC PHP extension from its project directory.
.DESCRIPTION
Downloads the official PHP development pack and prepares the Windows SDK and
MSVC CRT using xwin. Running xwin accepts the Microsoft SDK license. Projects
share prepared SDKs under %LOCALAPPDATA%/phpz/windows/win32, or under
XDG_CACHE_HOME/phpz/windows/win32 when set.
Requires Zig, tar, and PowerShell on Windows x64.
.PARAMETER PhpVersion
Exact PHP version from 8.2 through 8.6. Defaults to 8.6.0. Alpha, beta and RC
versions use the PHP Windows QA downloads when available.
.PARAMETER Nts
Select non-thread-safe PHP explicitly (the default).
.PARAMETER Zts
Build against thread-safe PHP (php8ts.lib). The default is NTS (php8.lib).
.PARAMETER XwinVersion
Version of the official xwin Windows x64 release. Defaults to 0.10.0.
.PARAMETER XwinCacheDir
Cache root for xwin downloads. Defaults to XDG_CACHE_HOME/xwin when set,
otherwise %LOCALAPPDATA%/xwin.
.PARAMETER ZigArgs
Additional arguments for zig build, passed as an array of strings.
.EXAMPLE
PS> C:\tools\phpz\scripts\build-windows.ps1 -PhpVersion 8.6.0 -Nts
Build for PHP 8.6.0 NTS.
.EXAMPLE
PS> C:\tools\phpz\scripts\build-windows.ps1 -PhpVersion 8.5.13 -Zts -ZigArgs @('-Doptimize=ReleaseFast')
Build an optimized DLL for PHP 8.5.13 ZTS.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^8\.[2-6]\.[0-9]+((alpha|beta|RC)[0-9]+)?$')]
    [string] $PhpVersion = '8.6.0',

    [switch] $Zts,

    [ValidatePattern('^[0-9]+\.[0-9]+\.[0-9]+$')]
    [string] $XwinVersion = '0.10.0',

    [string[]] $ZigArgs = @(),
    [switch] $Nts,
    [ValidateNotNullOrEmpty()]
    [string] $XwinCacheDir
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

if ($Nts -and $Zts) { throw 'Choose either -Nts or -Zts.' }
if (!(Test-Path -LiteralPath 'build.zig') -or !(Test-Path -LiteralPath 'build.zig.zon')) {
    throw 'Run from the extension project directory.'
}
foreach ($arg in $ZigArgs) {
    if ($arg -match '^-D(target|php-include-dir|php-lib-dir|libc-file|windows-zts|windows-debug)=') {
        throw "SDK selection already sets $arg"
    }
}
$null = Get-Command zig -ErrorAction Stop

function Install-Directory([string] $Source, [string] $Destination) {
    [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Destination)) | Out-Null
    try {
        [IO.Directory]::Move($Source, $Destination)
    } catch [IO.IOException] {
        if (!(Test-Path -LiteralPath $Destination -PathType Container)) { throw }
    }
}

$vs = switch -Regex ($PhpVersion) {
    '^8\.[23]\.' { '16' }
    '^8\.[45]\.' { '17' }
    '^8\.6\.'    { '18' }
}
$mode = if ($Zts) { 'zts' } else { 'nts' }
$suffix = if ($Zts) { '' } else { '-nts' }
$importLib = if ($Zts) { 'php8ts.lib' } else { 'php8.lib' }
$cacheRoot = if ($env:XDG_CACHE_HOME) { $env:XDG_CACHE_HOME } else { [Environment]::GetFolderPath('LocalApplicationData') }
$cache = (New-Item -ItemType Directory -Force -Path (Join-Path $cacheRoot 'phpz/windows/win32')).FullName
$phpSdk = Join-Path $cache "php/$PhpVersion/$mode/x86_64/php-$PhpVersion-devel-vs$vs-x64"
$winSdk = Join-Path $cache "sdk/$XwinVersion/vs$vs/x86_64"
$tmp = (New-Item -ItemType Directory -Path (Join-Path $cache ([Guid]::NewGuid().ToString()))).FullName

function Initialize-Sdk {
    if (!(Test-Path -LiteralPath $phpSdk -PathType Container)) {
        $base = 'https://downloads.php.net/~windows'
        $name = "php-devel-pack-$PhpVersion$suffix-Win32-vs$vs-x64.zip"
        $zip = Join-Path $tmp $name
        if ($PhpVersion -match 'alpha|beta|RC') {
            Invoke-WebRequest -UseBasicParsing "$base/qa/$name" -OutFile $zip
        } else {
            try {
                Invoke-WebRequest -UseBasicParsing "$base/releases/$name" -OutFile $zip
            } catch {
                if (!$_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 404) { throw }
                Invoke-WebRequest -UseBasicParsing "$base/releases/archives/$name" -OutFile $zip
            }
        }
        $unpacked = Join-Path $tmp 'php'
        Expand-Archive -LiteralPath $zip -DestinationPath $unpacked
        $root = Join-Path $unpacked "php-$PhpVersion-devel-vs$vs-x64"
        if (!(Test-Path -LiteralPath (Join-Path $root 'include/main/php.h')) -or
            !(Test-Path -LiteralPath (Join-Path $root "lib/$importLib"))) { throw "Incomplete PHP SDK: $name" }
        Install-Directory $root $phpSdk
    }
    if (!(Test-Path -LiteralPath $winSdk -PathType Container)) {
        $toolDir = Join-Path $cache "tools/xwin/$XwinVersion/windows-x86_64"
        $xwin = Join-Path $toolDir 'xwin.exe'
        if (!(Test-Path -LiteralPath $xwin -PathType Leaf)) {
            $name = "xwin-$XwinVersion-x86_64-pc-windows-msvc"
            $url = "https://github.com/Jake-Shadle/xwin/releases/download/$XwinVersion/$name.tar.gz"
            $archive = Join-Path $tmp "$name.tar.gz"
            $hashFile = "$archive.sha256"
            Invoke-WebRequest -UseBasicParsing "$url.sha256" -OutFile $hashFile
            Invoke-WebRequest -UseBasicParsing $url -OutFile $archive
            $expected = (Get-Content -Raw -LiteralPath $hashFile).Trim()
            if ($expected -notmatch '^[0-9a-fA-F]{64}$' -or (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $expected) {
                throw "SHA256 mismatch for $url"
            }
            & tar -xzf $archive -C $tmp
            if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath (Join-Path $tmp "$name/xwin.exe"))) { throw "Cannot extract $name" }
            Install-Directory (Join-Path $tmp $name) $toolDir
        }
        if (!$XwinCacheDir) {
            $XwinCacheDir = Join-Path $cacheRoot 'xwin'
        }
        $downloadCache = Join-Path $XwinCacheDir "$XwinVersion/vs$vs/x86_64"
        $prepared = Join-Path $tmp 'sdk'
        & $xwin --accept-license --manifest-version $vs --arch x86_64 --variant desktop --cache-dir $downloadCache splat --copy --disable-symlinks --include-debug-libs --preserve-ms-arch-notation --output $prepared
        if ($LASTEXITCODE -ne 0) { throw "xwin failed to prepare the VS$vs desktop SDK (exit $LASTEXITCODE)" }
        foreach ($file in 'sdk/include/ucrt/stdlib.h','crt/include/vcruntime.h','sdk/lib/ucrt/x64/ucrt.lib','crt/lib/x64/vcruntime.lib','sdk/lib/um/x64/kernel32.lib') {
            if (!(Test-Path -LiteralPath (Join-Path $prepared $file))) { throw "Missing xwin SDK file: $file" }
        }
        Install-Directory $prepared $winSdk
    }
}

try {
    if (!(Test-Path -LiteralPath $phpSdk -PathType Container) -or !(Test-Path -LiteralPath $winSdk -PathType Container)) {
        $mutex = [Threading.Mutex]::new($false, 'phpz-windows-sdk-prepare')
        try {
            # A terminated owner releases the mutex and leaves only its temporary files.
            try { $null = $mutex.WaitOne() } catch [Threading.AbandonedMutexException] { }
            try { Initialize-Sdk } finally { $mutex.ReleaseMutex() }
        } finally {
            $mutex.Dispose()
        }
    }
    $libcFile = Join-Path $tmp 'libc.txt'
    $fields = @(
        "include_dir=$winSdk/sdk/include/ucrt"
        "sys_include_dir=$winSdk/crt/include"
        "crt_dir=$winSdk/sdk/lib/ucrt/x64"
        "msvc_lib_dir=$winSdk/crt/lib/x64"
        "kernel32_lib_dir=$winSdk/sdk/lib/um/x64"
        'cc_dir='
        'darwin_sdk_dir='
    )
    [IO.File]::WriteAllText($libcFile, ($fields -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
    $windowsZts = if ($Zts) { 'true' } else { 'false' }
    Write-Host "Building x86_64-windows-msvc for PHP $PhpVersion $mode (VS$vs)"
    & zig build -Dtarget=x86_64-windows-msvc "-Dlibc-file=$libcFile" "-Dphp-include-dir=$phpSdk/include" `
        "-Dphp-lib-dir=$phpSdk/lib" "-Dwindows-zts=$windowsZts" -Dwindows-debug=false @ZigArgs
    $buildExit = $LASTEXITCODE
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force
}
exit $buildExit
