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
    '8.6' { 'vs18' }
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
    'vs18' {
        [PSCustomObject]@{
            ToolsetMajor = 14
            ToolsetMinorMinimum = 50
            ToolsetMinorMaximum = $null
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
    $baseUrl = 'https://downloads.php.net/~windows/qa'
    $releases = Invoke-RestMethod -Uri "$baseUrl/releases.json"
    $releaseProperty = $releases.PSObject.Properties[$PhpVersion]
}
if ($null -eq $releaseProperty) {
    throw "PHP $PhpVersion is missing from both release and QA indexes"
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
        [string] $VsWherePath,

        [Parameter(Mandatory = $true)]
        [string] $VsVersion,

        [Parameter(Mandatory = $true)]
        [object] $Configuration
    )

    $minimumVersion = $VsVersion.Substring(2)
    $json = ((& $VsWherePath -products '*' -version "[$minimumVersion.0,)" -format json 2>$null) -join [Environment]::NewLine)
    if ([string]::IsNullOrWhiteSpace($json)) {
        return $null
    }

    $instances = @($json | ConvertFrom-Json)
    $selectedInstance = $null
    $selectedToolset = $null
    foreach ($instance in $instances) {
        $candidate = Get-MsvcToolset -VsInstance $instance -Configuration $Configuration
        if ($null -ne $candidate -and ($null -eq $selectedToolset -or $candidate.Version -gt $selectedToolset.Version)) {
            $selectedInstance = $instance
            $selectedToolset = $candidate
        }
    }
    if ($null -ne $selectedInstance) {
        return $selectedInstance
    }
    return $instances | Select-Object -First 1
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
                ($null -eq $Configuration.ToolsetMinorMaximum -or $version.Minor -le $Configuration.ToolsetMinorMaximum)
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
    $releaseChannel = if ([int] $channel -ge 18) { 'stable' } else { 'release' }
    $installerUrl = "https://aka.ms/vs/$channel/$releaseChannel/$installerName"
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

function Get-WindowsSdk {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('x64', 'x86')]
        [string] $Arch
    )

    $sdkRoot = Get-ItemPropertyValue `
        -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows Kits\Installed Roots' `
        -Name 'KitsRoot10' `
        -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($sdkRoot)) {
        return $null
    }
    $includeRoot = Join-Path $sdkRoot 'Include'
    if (!(Test-Path -LiteralPath $includeRoot)) {
        return $null
    }

    $sdks = @(
        Get-ChildItem -LiteralPath $includeRoot -Directory | ForEach-Object {
            $version = $null
            if ([System.Version]::TryParse($_.Name, [ref] $version)) {
                $includeDirectory = Join-Path $_.FullName 'ucrt'
                $libDirectory = Join-Path (Join-Path $sdkRoot 'Lib') $_.Name
                $crtDirectory = Join-Path $libDirectory "ucrt\$Arch"
                $kernel32Directory = Join-Path $libDirectory "um\$Arch"
                if (
                    (Test-Path -LiteralPath (Join-Path $includeDirectory 'stdlib.h')) -and
                    (Test-Path -LiteralPath (Join-Path $crtDirectory 'ucrt.lib')) -and
                    (Test-Path -LiteralPath (Join-Path $kernel32Directory 'kernel32.lib'))
                ) {
                    [PSCustomObject]@{
                        Version = $version
                        IncludeDirectory = $includeDirectory
                        CrtDirectory = $crtDirectory
                        Kernel32Directory = $kernel32Directory
                    }
                }
            }
        } | Sort-Object -Property Version -Descending
    )

    return $sdks | Select-Object -First 1
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

# Prepare the toolchain before invoking PHP, as php-windows-builder does.
$vsWherePath = Get-VsWherePath
$vsInstance = Get-VisualStudioInstance -VsWherePath $vsWherePath -VsVersion $vsVersion -Configuration $vsConfiguration
$toolset = if ($null -ne $vsInstance) {
    Get-MsvcToolset -VsInstance $vsInstance -Configuration $vsConfiguration
} else {
    $null
}
$windowsSdk = Get-WindowsSdk -Arch $Arch
if ($null -eq $toolset -or $null -eq $windowsSdk) {
    Install-VisualStudioComponents `
        -VsVersion $vsVersion `
        -VsInstance $vsInstance `
        -Components $vsConfiguration.Components
    $vsInstance = Get-VisualStudioInstance -VsWherePath $vsWherePath -VsVersion $vsVersion -Configuration $vsConfiguration
    if ($null -eq $vsInstance) {
        throw 'Visual Studio installation is not available after installing components'
    }
    $toolset = Get-MsvcToolset -VsInstance $vsInstance -Configuration $vsConfiguration
    $windowsSdk = Get-WindowsSdk -Arch $Arch
}
if ($null -eq $toolset) {
    throw "Unable to locate an MSVC $vsVersion toolset after installing components"
}
if ($null -eq $windowsSdk) {
    throw "Unable to locate a Windows SDK with UCRT headers, ucrt.lib and kernel32.lib for $Arch after installing components"
}

$zigExe = (Get-Command zig -CommandType Application -ErrorAction Stop).Source
$libcTarget = if ($Arch -eq 'x64') { 'x86_64-windows-msvc' } else { 'x86-windows-msvc' }
$toolsetIncludeDirectory = Join-Path $toolset.Path 'include'
$toolsetLibDirectory = Join-Path (Join-Path $toolset.Path 'lib') $Arch
if (!(Test-Path -LiteralPath (Join-Path $toolsetIncludeDirectory 'vcruntime.h'))) {
    throw "Missing vcruntime.h in $toolsetIncludeDirectory"
}
if (!(Test-Path -LiteralPath (Join-Path $toolsetLibDirectory 'vcruntime.lib'))) {
    throw "Missing vcruntime.lib in $toolsetLibDirectory"
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

$libcFile = Join-Path $destinationPath 'libc.txt'
# Keep the field roles aligned with scripts/build-windows.sh. Windows/MSVC
# does not use the crtbegin.o/crtend.o directory represented by cc_dir.
@(
    '# The directory that contains stdlib.h.'
    "include_dir=$($windowsSdk.IncludeDirectory)"
    "sys_include_dir=$toolsetIncludeDirectory"
    "crt_dir=$($windowsSdk.CrtDirectory)"
    "msvc_lib_dir=$toolsetLibDirectory"
    "kernel32_lib_dir=$($windowsSdk.Kernel32Directory)"
    'cc_dir='
    'darwin_sdk_dir='
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
Write-Host "Windows SDK: $($windowsSdk.Version)"
Write-Host "Libc file: $libcFile"
