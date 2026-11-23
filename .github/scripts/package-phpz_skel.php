<?php

declare(strict_types=1);

if ($argc !== 3 || $argv[1] === '') {
    fwrite(STDERR, "Usage: php package-phpz_skel.php <release-tag> <output>\n");
    exit(1);
}

$source = file_get_contents(__DIR__ . '/../../tools/phpz_skel.php');
$artifact = str_replace(
    'const DEFAULT_PHPZ_SPEC = PHPZ_REPOSITORY;',
    'const DEFAULT_PHPZ_SPEC = PHPZ_REPOSITORY . ' . var_export('#' . $argv[1], true) . ';',
    $source,
    $replacements,
);
if ($replacements !== 1 || file_put_contents($argv[2], $artifact) !== strlen($artifact)) {
    fwrite(STDERR, "Could not package phpz_skel.php for $argv[1]\n");
    exit(1);
}
