--TEST--
INI displayers adapt Zig callbacks and distinguish active and original values without changing reads
--EXTENSIONS--
my_php_extension
--FILE--
<?php
function check($condition) { if (!$condition) throw new RuntimeException('check failed'); }
function info(): string {
    ob_start();
    phpinfo(INFO_MODULES);
    return ob_get_clean();
}
function row(string $info, string $name, string $local, string $master): void {
    check(preg_match('/^' . preg_quote($name, '/') . '\s*=>\s*' . preg_quote($local, '/') . '\s*=>\s*' . preg_quote($master, '/') . '\s*$/m', $info) === 1);
}
$initial = info();
row($initial, 'my_php_extension.mode', 'MODE[safe]', 'MODE[safe]');
row($initial, 'my_php_extension.debug', 'DEBUG[off]', 'DEBUG[off]');
ini_set('my_php_extension.mode', 'fast');
ini_set('my_php_extension.debug', '1');
$changed = info();
row($changed, 'my_php_extension.mode', 'MODE[fast]', 'MODE[safe]');
row($changed, 'my_php_extension.debug', 'DEBUG[on]', 'DEBUG[off]');
check(ini_get('my_php_extension.mode') === 'fast');
check(ini_get('my_php_extension.debug') === '1');
ini_restore('my_php_extension.mode');
ini_restore('my_php_extension.debug');
$restored = info();
row($restored, 'my_php_extension.mode', 'MODE[safe]', 'MODE[safe]');
row($restored, 'my_php_extension.debug', 'DEBUG[off]', 'DEBUG[off]');
echo "INI displayers passed\n";
?>
--EXPECT--
INI displayers passed
