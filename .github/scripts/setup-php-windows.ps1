[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+$')]
    [string] $PhpVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet('x64', 'x86')]
    [string] $Arch,

    [Parameter(Mandatory = $true)]
    [ValidateSet('nts', 'ts')]
    [string] $ThreadSafety,

    [Parameter(Mandatory = $true)]
    [string] $Destination
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$PSNativeCommandUseErrorActionPreference = $true

trap {
    Write-Host "setup-php-windows.ps1 failed at line $($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)"
    Write-Host $_.ScriptStackTrace
    throw
}

$vsVersion = switch ($PhpVersion) {
    '8.2' { 'vs16' }
    '8.3' { 'vs16' }
    '8.4' { 'vs17' }
    '8.5' { 'vs17' }
    default { throw "Unsupported PHP version $PhpVersion" }
}

# Keep toolset ranges and component IDs aligned with php-windows-builder.
$vsConfiguration = switch ($vsVersion) {
    'vs16' {
        [PSCustomObject]@{
            ToolsetMajor = 14
            ToolsetMinorMinimum = 20
            ToolsetMinorMaximum = 29
            Components = @(
                'Microsoft.VisualStudio.Component.CoreBuildTools'
                'Microsoft.VisualStudio.ComponentGroup.VC.Tools.142.x86.x64'
                'Microsoft.VisualStudio.Component.VC.ATL'
                'Microsoft.VisualStudio.Component.Windows10SDK.19041'
            )
        }
    }
    'vs17' {
        [PSCustomObject]@{
            ToolsetMajor = 14
            ToolsetMinorMinimum = 30
            ToolsetMinorMaximum = 49
            Components = @(
                'Microsoft.VisualStudio.Component.CoreBuildTools'
                'Microsoft.VisualStudio.Component.VC.Tools.x86.x64'
                'Microsoft.VisualStudio.Component.VC.ATL'
                'Microsoft.VisualStudio.Component.Windows10SDK.19041'
            )
        }
    }
}

$baseUrl = 'https://downloads.php.net/~windows/releases'
$releases = Invoke-RestMethod -Uri "$baseUrl/releases.json"
$releaseProperty = $releases.PSObject.Properties[$PhpVersion]
if ($null -eq $releaseProperty) {
    throw "PHP $PhpVersion is missing from releases.json"
}

$release = $releaseProperty.Value
$buildKey = "$ThreadSafety-$vsVersion-$Arch"
$buildProperty = $release.PSObject.Properties[$buildKey]
if ($null -eq $buildProperty) {
    throw "PHP $PhpVersion has no $buildKey build in releases.json"
}

$build = $buildProperty.Value
$destinationPath = [System.IO.Path]::GetFullPath($Destination)
$downloadDirectory = Join-Path $destinationPath 'downloads'
$phpBinDirectory = Join-Path $destinationPath 'php-bin'
$phpDevDirectory = Join-Path $destinationPath 'php-dev'

if (Test-Path -LiteralPath $destinationPath) {
    Remove-Item -LiteralPath $destinationPath -Recurse -Force
}
New-Item -Path $downloadDirectory -ItemType Directory -Force | Out-Null

function Get-VsWherePath {
    $installedPath = Join-Path "${env:ProgramFiles(x86)}\Microsoft Visual Studio" 'Installer\vswhere.exe'
    if (Test-Path -LiteralPath $installedPath) {
        return $installedPath
    }

    $downloadPath = Join-Path $downloadDirectory 'vswhere.exe'
    Write-Host 'Downloading vswhere.exe'
    Invoke-WebRequest `
        -Uri 'https://github.com/microsoft/vswhere/releases/latest/download/vswhere.exe' `
        -OutFile $downloadPath `
        -MaximumRetryCount 3 `
        -RetryIntervalSec 2
    return $downloadPath
}

function Get-VisualStudioInstance {
    param(
        [Parameter(Mandatory = $true)]
        [string] $VsWherePath
    )

    $json = ((& $VsWherePath -latest -products '*' -format json 2>$null) -join [Environment]::NewLine)
    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    return @($json | ConvertFrom-Json) | Select-Object -First 1
}

function Get-MsvcToolset {
    param(
        [Parameter(Mandatory = $true)]
        [object] $VsInstance,

        [Parameter(Mandatory = $true)]
        [object] $Configuration
    )

    $msvcDirectory = Join-Path ([string] $VsInstance.installationPath) 'VC\Tools\MSVC'
    if (!(Test-Path -LiteralPath $msvcDirectory)) {
        return $null
    }

    $toolsets = @(
        Get-ChildItem -LiteralPath $msvcDirectory -Directory | ForEach-Object {
            $version = $null
            if (
                [System.Version]::TryParse($_.Name, [ref] $version) -and
                $version.Major -eq $Configuration.ToolsetMajor -and
                $version.Minor -ge $Configuration.ToolsetMinorMinimum -and
                $version.Minor -le $Configuration.ToolsetMinorMaximum
            ) {
                [PSCustomObject]@{
                    Name = $_.Name
                    Path = $_.FullName
                    Version = $version
                }
            }
        } | Sort-Object -Property Version -Descending
    )

    return $toolsets | Select-Object -First 1
}

function Install-VisualStudioComponents {
    param(
        [Parameter(Mandatory = $true)]
        [string] $VsVersion,

        [AllowNull()]
        [object] $VsInstance,

        [Parameter(Mandatory = $true)]
        [string[]] $Components
    )

    $channel = $VsVersion.Substring(2)
    $installerName = 'vs_buildtools.exe'
    $installerArguments = @()

    if ($null -ne $VsInstance) {
        $channel = ([string] $VsInstance.installationVersion).Split('.')[0]
        $productId = $null
        if ($VsInstance.PSObject.Properties['catalog']) {
            $catalog = $VsInstance.catalog
            if ($null -ne $catalog -and $catalog.PSObject.Properties['productId']) {
                $productId = [string] $catalog.productId
            }
        }
        if ($null -eq $productId -and $VsInstance.PSObject.Properties['productId']) {
            $productId = [string] $VsInstance.productId
        }
        if ($productId -match '(Enterprise|Professional|Community)$') {
            $installerName = "vs_$($Matches[1].ToLowerInvariant()).exe"
        }
        $installerArguments += @('modify', '--installPath', [string] $VsInstance.installationPath)
    }

    $installerPath = Join-Path $downloadDirectory $installerName
    $installerUrl = "https://aka.ms/vs/$channel/release/$installerName"
    Write-Host "Downloading $installerUrl"
    Invoke-WebRequest `
        -Uri $installerUrl `
        -OutFile $installerPath `
        -MaximumRetryCount 3 `
        -RetryIntervalSec 2

    $installerArguments += @('--quiet', '--wait', '--norestart', '--nocache')
    foreach ($component in $Components) {
        $installerArguments += @('--add', $component)
    }

    Write-Host "Installing Visual Studio components for $VsVersion"
    $previousNativeErrorPreference = $PSNativeCommandUseErrorActionPreference
    $installerExitCode = $null
    try {
        $PSNativeCommandUseErrorActionPreference = $false
        & $installerPath @installerArguments 2>&1 | ForEach-Object { Write-Host $_ }
        $installerExitCode = $LASTEXITCODE
    } finally {
        $PSNativeCommandUseErrorActionPreference = $previousNativeErrorPreference
    }

    if ($installerExitCode -notin @(0, 3010)) {
        throw "Visual Studio installer failed with exit code $installerExitCode"
    }
}

function Get-ZigLibCFields {
    param(
        [Parameter(Mandatory = $true)]
        [string] $ZigExe
    )

    $fields = [ordered]@{}
    foreach ($line in @(& $ZigExe libc)) {
        if ($line -match '^([a-z0-9_]+)=(.*)$') {
            $fields[$Matches[1]] = $Matches[2]
        }
    }

    foreach ($name in @('include_dir', 'sys_include_dir', 'crt_dir', 'msvc_lib_dir', 'kernel32_lib_dir', 'gcc_dir')) {
        if (!$fields.Contains($name)) {
            throw "zig libc did not provide $name"
        }
    }

    return $fields
}

function Save-PhpAsset {
    param(
        [Parameter(Mandatory = $true)]
        [object] $Asset
    )

    $assetName = [string] $Asset.path
    $archivePath = Join-Path $downloadDirectory ([System.IO.Path]::GetFileName($assetName))
    $downloaded = $false
    $lastError = $null

    foreach ($url in @("$baseUrl/$assetName", "$baseUrl/archives/$assetName")) {
        try {
            Write-Host "Downloading $url"
            Invoke-WebRequest -Uri $url -OutFile $archivePath -MaximumRetryCount 3 -RetryIntervalSec 2
            $downloaded = $true
            break
        } catch {
            $lastError = $_
            Remove-Item -LiteralPath $archivePath -Force -ErrorAction SilentlyContinue
        }
    }

    if (!$downloaded) {
        throw "Failed to download $assetName`: $lastError"
    }

    $expectedHash = ([string] $Asset.sha256).ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw "SHA256 mismatch for $assetName`: expected $expectedHash, got $actualHash"
    }

    return $archivePath
}

$runtimeArchive = Save-PhpAsset -Asset $build.zip
$develArchive = Save-PhpAsset -Asset $build.devel_pack

Expand-Archive -LiteralPath $runtimeArchive -DestinationPath $phpBinDirectory -Force
Expand-Archive -LiteralPath $develArchive -DestinationPath $phpDevDirectory -Force

$phpDevRoot = if (
    (Test-Path -LiteralPath (Join-Path $phpDevDirectory 'include')) -and
    (Test-Path -LiteralPath (Join-Path $phpDevDirectory 'lib'))
) {
    Get-Item -LiteralPath $phpDevDirectory
} else {
    Get-ChildItem -LiteralPath $phpDevDirectory -Directory |
        Where-Object {
            (Test-Path -LiteralPath (Join-Path $_.FullName 'include')) -and
            (Test-Path -LiteralPath (Join-Path $_.FullName 'lib'))
        } |
        Select-Object -First 1
}

if ($null -eq $phpDevRoot) {
    throw "Unable to locate include and lib directories in $phpDevDirectory"
}

$phpExe = Join-Path $phpBinDirectory 'php.exe'
$phpIncludeDirectory = Join-Path $phpDevRoot.FullName 'include'
$phpLibDirectory = Join-Path $phpDevRoot.FullName 'lib'
$phpImportLibrary = if ($ThreadSafety -eq 'ts') { 'php8ts.lib' } else { 'php8.lib' }

if (!(Test-Path -LiteralPath $phpExe)) {
    throw "Missing PHP executable $phpExe"
}
if (!(Test-Path -LiteralPath (Join-Path $phpIncludeDirectory 'main\php.h'))) {
    throw "Missing PHP headers in $phpIncludeDirectory"
}
if (!(Test-Path -LiteralPath (Join-Path $phpLibDirectory $phpImportLibrary))) {
    throw "Missing $phpImportLibrary in $phpLibDirectory"
}

$actualVersion = ([string] (& $phpExe -n -r 'echo PHP_VERSION;')).Trim()
$actualThreadSafety = ([string] (& $phpExe -n -r 'echo PHP_ZTS ? "ts" : "nts";')).Trim()
$actualDebug = ([string] (& $phpExe -n -r 'echo PHP_DEBUG ? "1" : "0";')).Trim()
if ($actualVersion -ne [string] $release.version) {
    throw "Expected PHP $($release.version), got $actualVersion"
}
if ($actualThreadSafety -ne $ThreadSafety) {
    throw "Expected PHP $ThreadSafety, got $actualThreadSafety"
}
if ($actualDebug -ne '0') {
    throw "Expected a release PHP build, got PHP_DEBUG=$actualDebug"
}

$vsWherePath = Get-VsWherePath
$vsInstance = Get-VisualStudioInstance -VsWherePath $vsWherePath
$toolset = if ($null -ne $vsInstance) {
    Get-MsvcToolset -VsInstance $vsInstance -Configuration $vsConfiguration
} else {
    $null
}
if ($null -eq $toolset) {
    Install-VisualStudioComponents `
        -VsVersion $vsVersion `
        -VsInstance $vsInstance `
        -Components $vsConfiguration.Components
    $vsInstance = Get-VisualStudioInstance -VsWherePath $vsWherePath
    if ($null -eq $vsInstance) {
        throw 'Visual Studio installation is not available after installing components'
    }
    $toolset = Get-MsvcToolset -VsInstance $vsInstance -Configuration $vsConfiguration
}
if ($null -eq $toolset) {
    throw "Unable to locate an MSVC $vsVersion toolset after installing components"
}

$zigExe = (Get-Command zig -CommandType Application -ErrorAction Stop).Source
$libcTarget = if ($Arch -eq 'x64') { 'x86_64-windows-msvc' } else { 'x86-windows-msvc' }
$msvcArch = if ($Arch -eq 'x64') { 'x64' } else { 'x86' }
$libcFields = Get-ZigLibCFields -ZigExe $zigExe
if ($Arch -eq 'x86') {
    $libcFields['crt_dir'] = Join-Path (Split-Path -Parent $libcFields['crt_dir']) 'x86'
    $libcFields['kernel32_lib_dir'] = Join-Path (Split-Path -Parent $libcFields['kernel32_lib_dir']) 'x86'
}
$toolsetIncludeDirectory = Join-Path $toolset.Path 'include'
$toolsetLibDirectory = Join-Path (Join-Path $toolset.Path 'lib') $msvcArch
if (!(Test-Path -LiteralPath (Join-Path $toolsetIncludeDirectory 'vcruntime.h'))) {
    throw "Missing vcruntime.h in $toolsetIncludeDirectory"
}
if (!(Test-Path -LiteralPath (Join-Path $toolsetLibDirectory 'vcruntime.lib'))) {
    throw "Missing vcruntime.lib in $toolsetLibDirectory"
}
if (!(Test-Path -LiteralPath (Join-Path $libcFields['include_dir'] 'stdlib.h'))) {
    throw "Missing stdlib.h in $($libcFields['include_dir'])"
}
if (!(Test-Path -LiteralPath (Join-Path $libcFields['crt_dir'] 'ucrt.lib'))) {
    throw "Missing ucrt.lib in $($libcFields['crt_dir'])"
}
if (!(Test-Path -LiteralPath (Join-Path $libcFields['kernel32_lib_dir'] 'kernel32.lib'))) {
    throw "Missing kernel32.lib in $($libcFields['kernel32_lib_dir'])"
}
$libcFields['sys_include_dir'] = $toolsetIncludeDirectory
$libcFields['msvc_lib_dir'] = $toolsetLibDirectory
$libcFile = Join-Path $destinationPath 'libc.txt'
@(
    '# The directory that contains stdlib.h.'
    "include_dir=$($libcFields['include_dir'])"
    "sys_include_dir=$($libcFields['sys_include_dir'])"
    "crt_dir=$($libcFields['crt_dir'])"
    "msvc_lib_dir=$($libcFields['msvc_lib_dir'])"
    "kernel32_lib_dir=$($libcFields['kernel32_lib_dir'])"
    "gcc_dir=$($libcFields['gcc_dir'])"
) | Set-Content -LiteralPath $libcFile -Encoding utf8
& $zigExe libc -target $libcTarget $libcFile | Out-Null

$windowsZts = if ($ThreadSafety -eq 'ts') { 'true' } else { 'false' }
@(
    "PHP_VERSION=$actualVersion"
    "PHP_BIN_DIR=$phpBinDirectory"
    "PHP_INCLUDE_DIR=$phpIncludeDirectory"
    "PHP_LIB_DIR=$phpLibDirectory"
    "PHP_THREAD_SAFETY=$actualThreadSafety"
    "WINDOWS_ZTS=$windowsZts"
    "PHP_VS_VERSION=$vsVersion"
    "MSVC_TOOLSET=$($toolset.Name)"
    "LIBC_TARGET=$libcTarget"
    "LIBC_FILE=$libcFile"
) | Out-File -FilePath $env:GITHUB_ENV -Encoding utf8 -Append
$phpBinDirectory | Out-File -FilePath $env:GITHUB_PATH -Encoding utf8 -Append

Write-Host "PHP version: $actualVersion"
Write-Host "PHP mode: $actualThreadSafety"
Write-Host "PHP include: $phpIncludeDirectory"
Write-Host "PHP lib: $phpLibDirectory"
Write-Host "PHP Visual Studio: $vsVersion"
Write-Host "MSVC toolset: $($toolset.Name)"
Write-Host "Libc file: $libcFile"
