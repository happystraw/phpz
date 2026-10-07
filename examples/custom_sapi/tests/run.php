<?php

$executable = realpath($argv[1] ?? '') ?: throw new RuntimeException('Expected SAPI executable');
$scripts = [
    'basic.php' => [true, '/^[01]\|[01]\|body\|shutdown$/D', null],
    'shutdown-exception.php' => [false, '/^body$/D', 'PhpScriptFailed'],
    'shutdown-exit.php' => [false, '/^body$/D', 'PhpScriptFailed'],
    'fatal.php' => [false, '/^body\|shutdown$/D', 'PhpScriptFailed'],
    'exception-report-fatal.php' => [false, '/^body\|shutdown$/D', 'PhpScriptFailed'],
    'exit-zero.php' => [true, '/^body\|shutdown$/D', null],
    'exit-nonzero.php' => [false, '/^body\|shutdown$/D', 'PhpScriptFailed'],
    'exit-shutdown-fatal.php' => [false, '/^body$/D', 'PhpScriptFailed'],
    'fatal-shutdown-exit-zero.php' => [false, '/^body$/D', 'PhpScriptFailed'],
];
$cases = [];
foreach ($scripts as $file => [$success, $expected, $error]) {
    $path = __DIR__ . '/' . $file;
    $code = preg_replace('/^<\?php\s*/', '', file_get_contents($path));
    $cases[$file] = [[$path], $success, $expected, $error];
    $cases["-r $file"] = [['-r', $code], $success, $expected, $error];
}
$cases['-r return'] = [['-r', "echo 'body'; return 123;"], true, '/^body$/D', null];
$cases['-r empty'] = [['-r', ''], true, '/^$/D', null];
$cases['-r exception'] = [['-r', "echo 'body'; throw new RuntimeException('eval failure');"], false, '/^body$/D', 'eval failure'];
$cases['-r syntax'] = [['-r', 'function ('], false, '/^$/D', 'Command line code'];
$cases['-r missing code'] = [['-r'], false, '/^$/D', 'ExpectedPhpCode'];
$cases['missing input'] = [[], false, '/^$/D', 'ExpectedPhpScriptOrCode'];
foreach ($cases as $name => [$args, $success, $expected, $error]) {
    $process = proc_open([$executable, ...$args], [
        0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w'],
    ], $pipes);
    if (!is_resource($process)) {
        throw new RuntimeException('Cannot start custom SAPI');
    }
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    $status = proc_close($process);
    if (($status === 0) !== $success || !preg_match($expected, $stdout)) {
        throw new RuntimeException("$name: unexpected result (exit $status)\n$stdout\n$stderr");
    }
    if ($error === null ? $stderr !== '' : !str_contains($stderr, $error)) {
        throw new RuntimeException("$name: unexpected stderr\n$stderr");
    }
    if (str_contains($stderr, 'memory leaks detected')) {
        throw new RuntimeException("$name: PHP reported a memory leak\n$stderr");
    }
    if (str_contains($stderr, 'Bailed out without a bailout address')) {
        throw new RuntimeException("$name: unhandled PHP bailout\n$stderr");
    }
    if ($name === 'basic.php' || $name === '-r basic.php') {
        if (($ts = getenv('PHP_BUILD_TS')) !== false && (int)$stdout[0] !== (int)($ts === 'ts')) {
            throw new RuntimeException('PHP ZTS configuration mismatch');
        }
        if (($debug = getenv('PHP_BUILD_DEBUG')) !== false && (int)$stdout[2] !== (int)$debug) {
            throw new RuntimeException('PHP debug configuration mismatch');
        }
    }
    echo "PASS $name\n";
}
