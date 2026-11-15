--TEST--
Observers are not registered when the extension is loaded with dl()
--EXTENSIONS--
my_php_extension
--SKIPIF--
<?php
if (!function_exists('proc_open')) die('skip proc_open is required');
$probe = proc_open([PHP_BINARY, '-n', '-r', 'exit(extension_loaded("my_php_extension") ? 0 : 1);'], [], $pipes);
if (!is_resource($probe)) die('skip cannot start PHP');
if (proc_close($probe) === 0) die('skip extension is built in');
?>
--FILE--
<?php
$module = realpath(__DIR__ . '/../modules/' . (PHP_OS_FAMILY === 'Windows' ? 'php_my_php_extension.dll' : 'my_php_extension.so'));
if ($module === false) throw new RuntimeException('Cannot find extension module');

// The request that called dl() still runs with the module loaded.
$code = <<<'PHP'
dl($argv[1]);
MyPHPExt\Metrics::reset();
@trigger_error('not observed', E_USER_WARNING);
try { throw new LogicException('not observed'); } catch (LogicException) {}
$metrics = MyPHPExt\Metrics::snapshot();
echo "errors {$metrics['errors']['total']}, exceptions {$metrics['exceptions']['total']}, calls {$metrics['function_calls']['total']}\n";
PHP;
$process = proc_open(
    [PHP_BINARY, '-n', '-d', 'enable_dl=1', '-d', 'extension_dir=' . dirname($module), '-r', $code, basename($module)],
    [1 => ['pipe', 'w'], 2 => ['redirect', 1]],
    $pipes,
);
if (!is_resource($process)) throw new RuntimeException('Cannot start PHP');
echo stream_get_contents($pipes[1]);
fclose($pipes[1]);
echo "exit ", proc_close($process), "\n";
?>
--EXPECT--
errors 0, exceptions 0, calls 0
exit 0
