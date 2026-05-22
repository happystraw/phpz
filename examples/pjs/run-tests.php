#!/usr/bin/env php
<?php
/**
 * PHPT Test Runner - PHP extension testing framework
 *
 * Usage: php run-tests.php [options] [testfile...]
 *
 * Options:
 *   -e <php>       PHP executable (default: "php")
 *   -x <ext.so>    Extension .so file to load for all tests
 *   -d <dir>       Tests directory (default: ./tests/)
 *   -h             Show help
 *
 * PHPT file format supports these sections:
 *   --TEST--       Test name (required)
 *   --INI--        INI directives, one per line (optional)
 *   --SKIPIF--     Skip condition PHP code (optional)
 *   --FILE--       PHP code to execute (required)
 *   --EXPECT--     Exact expected output (required if no EXPECTF)
 *   --EXPECTF--    Expected output with % patterns (required if no EXPECT)
 */

declare(strict_types=1);

// ===== Configuration =====
$php_executable = 'php';
$extension_file = null;
$tests_dir = __DIR__ . '/tests';
$test_files = [];

// ===== Parse command line =====
$args = array_slice($argv, 1);
for ($i = 0; $i < count($args); $i++) {
    switch ($args[$i]) {
        case '-e':
            $php_executable = $args[++$i] ?? 'php';
            break;
        case '-x':
            $extension_file = $args[++$i] ?? null;
            break;
        case '-d':
            $tests_dir = $args[++$i] ?? __DIR__ . '/tests';
            break;
        case '-h':
        case '--help':
            echo "Usage: php run-tests.php [options] [testfile...]\n";
            echo "  -e <php>    PHP executable (default: php)\n";
            echo "  -x <ext.so> Extension .so file path\n";
            echo "  -d <dir>    Tests directory (default: ./tests/)\n";
            echo "  -h          Show help\n";
            exit(0);
        default:
            $test_files[] = $args[$i];
            break;
    }
}

// ===== Auto-detect extension =====
if ($extension_file === null) {
    $modules_glob = glob(__DIR__ . '/modules/*.so');
    if (!empty($modules_glob)) {
        $extension_file = $modules_glob[0];
    }
}

if ($extension_file === null) {
    fwrite(STDERR, "Error: No extension file specified. Use -x <ext.so> or place .so in modules/\n");
    exit(1);
}

if (!file_exists($extension_file)) {
    fwrite(STDERR, "Error: Extension file not found: $extension_file\n");
    exit(1);
}

// ===== Find test files =====
if (empty($test_files)) {
    $test_files = glob($tests_dir . '/*.phpt');
}

if (empty($test_files)) {
    fwrite(STDERR, "Error: No .phpt test files found in $tests_dir\n");
    exit(1);
}

echo "PHPT Test Runner\n";
echo "PHP: $php_executable | Extension: $extension_file\n";
echo "Tests directory: $tests_dir\n\n";

// ===== Run tests =====
$total = 0;
$passed = 0;
$failed = 0;
$skipped = 0;

foreach ($test_files as $phpt_file) {
    if (!file_exists($phpt_file)) {
        echo "WARN: File not found: $phpt_file\n";
        continue;
    }

    $total++;
    $basename = basename($phpt_file);
    $sections = parse_phpt($phpt_file);

    if (!isset($sections['TEST'])) {
        echo "FAIL $basename [missing --TEST--]\n";
        $failed++;
        continue;
    }

    $test_name = trim($sections['TEST']);
    $file_code = $sections['FILE'] ?? '';
    $ini_directives = $sections['INI'] ?? '';
    $skipif_code = $sections['SKIPIF'] ?? null;
    $expect = $sections['EXPECT'] ?? null;
    $expectf = $sections['EXPECTF'] ?? null;

    if ($file_code === '') {
        echo "FAIL $basename [missing --FILE--]";
        if ($test_name) echo " $test_name";
        echo "\n";
        $failed++;
        continue;
    }

    // Check skip condition
    if ($skipif_code !== null) {
        $skip_cmd = build_php_cmd($php_executable, $extension_file, $ini_directives, $skipif_code);
        $skip_output = run_php($skip_cmd);
        if (trim($skip_output) === 'skip') {
            echo "SKIP $basename $test_name\n";
            $skipped++;
            continue;
        }
    }

    // Execute test
    $cmd = build_php_cmd($php_executable, $extension_file, $ini_directives, $file_code);
    $actual = run_php($cmd);

    // Normalize: strip PHP log/error header lines
    $actual = preg_replace('/^(?:PHP )?Warning:.*$/m', '', $actual);
    $actual = preg_replace('/^\[\w+ \w+ \d+ \d+:\d+:\d+ \d+\]\s+.*$/m', '', $actual);
    $actual = preg_replace("/\n{3,}/", "\n\n", $actual);
    $actual = trim($actual);

    // Compare
    if ($expectf !== null) {
        $expected = trim($expectf);
        $section_type = 'EXPECTF';
        $result = match_expectf($actual, $expected);
    } elseif ($expect !== null) {
        $expected = trim($expect);
        $section_type = 'EXPECT';
        $result = ($actual === $expected);
    } else {
        echo "FAIL $basename [missing --EXPECT--/--EXPECTF--]";
        if ($test_name) echo " $test_name";
        echo "\n";
        $failed++;
        continue;
    }

    if ($result) {
        echo "PASS $basename [$section_type] $test_name\n";
        $passed++;
    } else {
        echo "FAIL $basename [$section_type] $test_name\n";
        echo "  -- Expected --\n";
        foreach (explode("\n", $expected) as $line) {
            echo "  | $line\n";
        }
        echo "  -- Actual --\n";
        foreach (explode("\n", $actual) as $line) {
            echo "  | $line\n";
        }
        $failed++;
    }
}

echo "\n" . str_repeat('=', 50) . "\n";
echo "Results: $total tests, $passed passed, $failed failed";
if ($skipped > 0) echo ", $skipped skipped";
echo "\n";

exit($failed > 0 ? 1 : 0);

// ===== Functions =====

/**
 * Parse a .phpt file into its sections.
 */
function parse_phpt(string $filepath): array {
    $content = file_get_contents($filepath);
    $lines = explode("\n", $content);
    $sections = [];
    $current_section = null;
    $current_content = '';

    foreach ($lines as $line) {
        if (preg_match('/^--([A-Z_]+)--\s*$/', $line, $m)) {
            if ($current_section !== null) {
                $sections[$current_section] = rtrim($current_content);
            }
            $current_section = $m[1];
            $current_content = '';
        } else {
            if ($current_section !== null) {
                $current_content .= $line . "\n";
            }
        }
    }
    if ($current_section !== null) {
        $sections[$current_section] = rtrim($current_content);
    }

    return $sections;
}

/**
 * Build the PHP command string for running test code.
 */
function build_php_cmd(string $php_exe, string $ext_file, string $ini_directives, string $code): string {
    $tmpfile = tempnam(sys_get_temp_dir(), 'phpt_');
    file_put_contents($tmpfile, $code);

    $args = [$php_exe, '-dextension=' . escapeshellarg($ext_file), '-dlog_errors=0'];

    // Parse --INI-- directives (one per line: key=value)
    if ($ini_directives !== '') {
        foreach (explode("\n", $ini_directives) as $line) {
            $line = trim($line);
            if ($line !== '' && str_contains($line, '=')) {
                $args[] = '-d' . escapeshellarg($line);
            }
        }
    }

    $args[] = escapeshellarg($tmpfile);

    // Register cleanup
    register_shutdown_function(function () use ($tmpfile) { @unlink($tmpfile); });

    return implode(' ', $args);
}

/**
 * Execute PHP and return stdout + stderr combined.
 */
function run_php(string $cmd): string {
    $descriptors = [
        0 => ['pipe', 'r'],
        1 => ['pipe', 'w'],
        2 => ['pipe', 'w'],
    ];
    $process = proc_open($cmd, $descriptors, $pipes);
    if (!is_resource($process)) {
        return '';
    }
    fclose($pipes[0]);
    $stdout = stream_get_contents($pipes[1]);
    $stderr = stream_get_contents($pipes[2]);
    fclose($pipes[1]);
    fclose($pipes[2]);
    proc_close($process);

    return ($stdout ?: '') . ($stderr ?: '');
}

/**
 * Match actual output against EXPECTF pattern.
 *
 * Supported format specifiers:
 *   %A   zero or more characters including newlines (non-greedy)
 *   %a   one or more characters including newlines (non-greedy)
 *   %S   zero or more characters including newlines (non-greedy)
 *   %s   one or more non-newline characters
 *   %w   zero or more whitespace
 *   %d   digits only
 *   %i   signed integer
 *   %f   floating point number
 *   %x   hex digits
 *   %c   single character
 *   %e   directory separator (\/ or \\)
 *   %%   literal percent sign
 */
function match_expectf(string $actual, string $expected): bool {
    // Escape all regex-special characters
    $regex = preg_quote($expected, '#');

    // Replace % patterns with regex equivalents
    // Order matters: longer patterns first, %% before single %
    $replacements = [
        '%A' => '[\s\S]*?',
        '%a' => '[\s\S]+?',
        '%S' => '[\s\S]*?',
        '%s' => '[^\r\n]+',
        '%w' => '\s*',
        '%d' => '\d+',
        '%i' => '[-+]?\d+',
        '%f' => '[-+]?\d*\.?\d+(?:[eE][-+]?\d+)?',
        '%x' => '[0-9a-fA-F]+',
        '%c' => '.',
        '%e' => '[\\\\\/]',
        '%%' => '%',
    ];

    foreach ($replacements as $pattern => $replacement) {
        $regex = str_replace($pattern, $replacement, $regex);
    }

    $regex = '#^' . $regex . '$#s';

    // Suppress warnings for invalid regex (malformed expected content)
    $result = @preg_match($regex, $actual);
    return $result === 1;
}
