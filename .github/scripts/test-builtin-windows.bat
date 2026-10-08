@echo off
setlocal
if not defined PHP_BUILD_SOURCE exit /b 1
cd /d "%PHP_BUILD_SOURCE%"
if errorlevel 1 exit /b 1

rem Verify native command resolution and output forwarding before a PHP build.
echo === Windows build tools ===
where nmake
if errorlevel 1 exit /b 1
where cl
if errorlevel 1 exit /b 1
where link
if errorlevel 1 exit /b 1
echo COMSPEC=%COMSPEC%
where echo 2>nul
"%COMSPEC%" /d /c echo PHPZ_CMD_OK
if errorlevel 1 exit /b 1
> "%TEMP%\phpz-nmake-smoke.mak" echo all:
>> "%TEMP%\phpz-nmake-smoke.mak" echo 	@echo PHPZ_NMAKE_OK
nmake /nologo /f "%TEMP%\phpz-nmake-smoke.mak"
if errorlevel 1 exit /b 1
del "%TEMP%\phpz-nmake-smoke.mak"

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
call configure.bat --disable-all --enable-cli --enable-cgi --enable-%PHP_BUILD_EXTENSION% %ZTS_FLAG% %DEBUG_FLAG%
if errorlevel 1 exit /b 1
nmake
if errorlevel 1 exit /b 1

set "TEST_PHP_EXECUTABLE=%CD%\%PHP_BUILD_DIR%\php.exe"
set "TEST_PHP_CGI_EXECUTABLE=%CD%\%PHP_BUILD_DIR%\php-cgi.exe"
if not exist "%TEST_PHP_CGI_EXECUTABLE%" exit /b 1
"%TEST_PHP_EXECUTABLE%" -n -r "if (!extension_loaded(getenv('PHP_BUILD_EXTENSION')) || (bool) PHP_ZTS !== (getenv('PHP_BUILD_TS') === 'ts') || (int) PHP_DEBUG !== (int) getenv('PHP_BUILD_DEBUG')) { exit(1); }"
if errorlevel 1 exit /b 1
"%TEST_PHP_EXECUTABLE%" -n -i
if errorlevel 1 exit /b 1
"%TEST_PHP_EXECUTABLE%" -n --ri "%PHP_BUILD_EXTENSION%"
if errorlevel 1 exit /b 1
"%TEST_PHP_EXECUTABLE%" -n run-tests.php -n -q "ext/%PHP_BUILD_EXTENSION%/tests"
exit /b %ERRORLEVEL%
