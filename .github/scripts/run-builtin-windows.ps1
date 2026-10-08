# SDK installation is performed once by the workflow, before any variant runs.
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $true
Import-Module "$env:GITHUB_WORKSPACE\build\php-windows-builder\php\BuildPhp" -Force
$vs = Get-VsVersion -PhpVersion $env:PHP_BUILD_VERSION
Set-Location -LiteralPath $env:PHP_BUILD_SOURCE
Invoke-PhpSdkStarter -BuildDirectory "$env:GITHUB_WORKSPACE\build" -VsConfig $vs -Arch x64 `
    -Task "$env:GITHUB_WORKSPACE\.github\scripts\test-builtin-windows.bat"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
