<?php

if (PHP_SAPI !== 'custom_sapi') {
    throw new RuntimeException('Wrong SAPI');
}
if (!extension_loaded('custom_sapi_app') || custom_sapi_greeting() !== 'Hello from the built-in module') {
    throw new RuntimeException('Additional module was not registered');
}
if (ini_get('display_errors') !== '0' || ini_get('log_errors') !== '1') {
    throw new RuntimeException('SAPI initialization did not apply INI entries');
}
echo (int) PHP_ZTS, '|', (int) PHP_DEBUG, '|body';
register_shutdown_function(static function () {
    echo '|shutdown';
});
