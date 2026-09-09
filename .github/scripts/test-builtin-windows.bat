@echo off
setlocal
cd /d "%GITHUB_WORKSPACE%\build\php-src"
if errorlevel 1 exit /b 1

set "ZTS_FLAG=--disable-zts"
set "DEBUG_FLAG=--disable-debug"
set "PHP_BUILD_DIR=x64\Release"
if "%PHP_BUILD_DEBUG%"=="1" (
    set "DEBUG_FLAG=--enable-debug"
    set "PHP_BUILD_DIR=x64\Debug"
)
if "%PHP_BUILD_TS%"=="ts" (
    set "ZTS_FLAG=--enable-zts"
    set "PHP_BUILD_DIR=%PHP_BUILD_DIR%_TS"
)

call buildconf.bat
if errorlevel 1 exit /b 1
call configure.bat --disable-all --enable-cli --enable-skeleton %ZTS_FLAG% %DEBUG_FLAG%
if errorlevel 1 exit /b 1
nmake
if errorlevel 1 exit /b 1

set "TEST_PHP_EXECUTABLE=%CD%\%PHP_BUILD_DIR%\php.exe"
"%TEST_PHP_EXECUTABLE%" -n -r "if (!extension_loaded('skeleton') || (bool) PHP_ZTS !== (getenv('PHP_BUILD_TS') === 'ts') || (int) PHP_DEBUG !== (int) getenv('PHP_BUILD_DEBUG')) { exit(1); }"
if errorlevel 1 exit /b 1
"%TEST_PHP_EXECUTABLE%" -n --ri skeleton
if errorlevel 1 exit /b 1
"%TEST_PHP_EXECUTABLE%" -n run-tests.php -n -q ext/skeleton/tests
exit /b %ERRORLEVEL%
