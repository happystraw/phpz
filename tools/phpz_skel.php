#!/usr/bin/env php
<?php

declare(strict_types=1);

namespace Phpz\Tools;

// phpcs:disable PSR1.Files.SideEffects.FoundWithSymbols -- CLI script entry point calls Command::run().
// phpcs:disable PSR1.Classes.ClassDeclaration.MultipleClasses -- CLI script is distributed as one file.
// phpcs:disable Generic.Files.LineLength.TooLong -- Embedded Zig templates use Zig formatting.

const MIN_PHP_VERSION = '8.2.0';
const MIN_ZIG_VERSION = '0.17.0-dev.1282+c0f9b51d8';
const DEFAULT_PHPZ_SPEC = 'git+https://github.com/happystraw/phpz';
const DEFAULT_PHP_INCLUDE_DIR = '/usr/include/php';
const REQUIRED_PHP_EXTENSIONS = ['pcre', 'standard'];
const REQUIRED_PHP_FUNCTIONS = ['proc_open'];

readonly class Args
{
    public function __construct(
        public string $ext,
        public string $dir,
        public string $phpz,
        public string $zig,
        public PhpConfig $phpConfig,
        public ToolOption $genStub,
        public ToolOption $runTests,
        public bool $unix,
        public bool $windows,
        public bool $force,
        public bool $verbose,
    ) {
    }

    /**
     * @param list<string> $argv
     */
    public static function parse(array $argv): self
    {
        $envZig = getenv('ZIG');
        $ext = null;
        $dir = PathUtil::cwd();
        $phpz = DEFAULT_PHPZ_SPEC;
        $zig = is_string($envZig) && $envZig !== '' ? $envZig : 'zig';
        $phpConfig = PhpConfig::auto();
        $genStub = ToolOption::auto();
        $runTests = ToolOption::auto();
        $unix = true;
        $windows = true;
        $force = false;
        $verbose = false;

        for ($i = 1; $i < count($argv); $i++) {
            $arg = $argv[$i];
            if ($arg === '--force') {
                $force = true;
                continue;
            }
            if ($arg === '--verbose' || $arg === '-v') {
                $verbose = true;
                continue;
            }
            if ($arg === '--without-gen-stub') {
                $genStub = ToolOption::disabled();
                continue;
            }
            if ($arg === '--without-run-tests') {
                $runTests = ToolOption::disabled();
                continue;
            }
            if ($arg === '--onlyunix') {
                $windows = false;
                continue;
            }
            if ($arg === '--onlywindows') {
                $unix = false;
                continue;
            }

            $name = null;
            $value = null;
            if (str_contains($arg, '=')) {
                [$name, $value] = explode('=', $arg, 2);
            } else {
                $name = $arg;
            }

            switch ($name) {
                case '--with-gen-stub':
                case '--with-run-tests':
                    if ($value === null && isset($argv[$i + 1]) && !str_starts_with($argv[$i + 1], '--')) {
                        $value = $argv[++$i];
                    }
                    $toolArg = $value === null || $value === ''
                        ? ToolOption::auto()
                        : ToolOption::explicit(PathUtil::absolute($value));
                    if ($name === '--with-gen-stub') {
                        $genStub = $toolArg;
                    } else {
                        $runTests = $toolArg;
                    }
                    break;

                case '--ext':
                case '--dir':
                case '--phpz':
                case '--zig':
                case '--with-php-config':
                    if ($value === null) {
                        if (!isset($argv[$i + 1]) || str_starts_with($argv[$i + 1], '--')) {
                            Console::fail("$name expects a value");
                        }
                        $value = $argv[++$i];
                    }
                    if ($value === '') {
                        Console::fail("$name expects a non-empty value");
                    }
                    if ($name === '--ext') {
                        $ext = $value;
                    } elseif ($name === '--dir') {
                        $dir = $value;
                    } elseif ($name === '--phpz') {
                        $phpz = $value;
                    } elseif ($name === '--zig') {
                        $zig = $value;
                    } else {
                        $phpConfig = PhpConfig::explicit(PathUtil::resolveBin($value));
                    }
                    break;

                default:
                    Console::fail("Unsupported argument $arg");
            }
        }

        if ($ext === null) {
            Console::fail('Missing --ext <name>');
        }
        if (!$unix && !$windows) {
            Console::fail('Cannot pass both --onlyunix and --onlywindows');
        }
        if (!preg_match('/^[A-Za-z][A-Za-z0-9_]*$/', $ext)) {
            Console::fail('Invalid extension name. Use letters, numbers and underscores, starting with a letter.');
        }
        $ext = TemplateVars::snack($ext, NameCase::Lower);

        return new self(
            $ext,
            $dir,
            PackageSpec::resolve($phpz),
            PathUtil::resolveBin($zig),
            $phpConfig,
            $genStub,
            $runTests,
            $unix,
            $windows,
            $force,
            $verbose,
        );
    }
}

readonly class PhpConfig
{
    private function __construct(
        public string $bin,
        private bool $explicit,
    ) {
    }

    public static function auto(): self
    {
        return new self('php-config', false);
    }

    public static function explicit(string $bin): self
    {
        return new self($bin, true);
    }

    public function isExplicit(): bool
    {
        return $this->explicit;
    }
}

enum ToolOptionMode
{
    case Auto;
    case Disabled;
    case Explicit;
}

readonly class ToolOption
{
    private function __construct(
        public ToolOptionMode $mode,
        public ?string $path,
    ) {
    }

    public static function auto(): self
    {
        return new self(ToolOptionMode::Auto, null);
    }

    public static function disabled(): self
    {
        return new self(ToolOptionMode::Disabled, null);
    }

    public static function explicit(string $path): self
    {
        return new self(ToolOptionMode::Explicit, $path);
    }

    public function isDisabled(): bool
    {
        return $this->mode === ToolOptionMode::Disabled;
    }

    public function isExplicit(): bool
    {
        return $this->mode === ToolOptionMode::Explicit;
    }
}

final class Console
{
    public static function fail(string $message): never
    {
        fwrite(STDERR, "Error: $message\n");
        exit(1);
    }

    public static function info(string $message): void
    {
        fwrite(STDERR, "$message\n");
        fflush(STDERR);
    }

    public static function check(string $subject, string $result): void
    {
        self::info("checking $subject... $result");
    }
}

final class PathUtil
{
    public static function cwd(): string
    {
        $cwd = getcwd();
        if ($cwd === false) {
            Console::fail('Unable to determine current directory');
        }
        return $cwd;
    }

    public static function normalize(string $path): string
    {
        $path = str_replace('\\', '/', $path);
        $parts = [];
        $absolute = str_starts_with($path, '/');
        foreach (explode('/', $path) as $part) {
            if ($part === '' || $part === '.') {
                continue;
            }
            if ($part === '..') {
                if ($parts !== [] && end($parts) !== '..') {
                    array_pop($parts);
                } elseif (!$absolute) {
                    $parts[] = '..';
                }
                continue;
            }
            $parts[] = $part;
        }
        return ($absolute ? '/' : '') . implode('/', $parts);
    }

    public static function absolute(string $path): string
    {
        if (str_starts_with($path, '/')) {
            return self::normalize($path);
        }
        return self::normalize(self::cwd() . '/' . $path);
    }

    public static function resolveBin(string $bin): string
    {
        if (str_contains($bin, '/') && !str_starts_with($bin, '/')) {
            return self::absolute($bin);
        }
        return $bin;
    }

    public static function mkdir(string $dir): void
    {
        if (is_dir($dir)) {
            return;
        }
        if (!mkdir($dir, 0777, true) && !is_dir($dir)) {
            Console::fail("Unable to create directory $dir");
        }
    }
}

final class PackageSpec
{
    public static function resolve(string $spec): string
    {
        if (preg_match('/^(?:https?:\/\/|git(?:\+|:\/\/))/', $spec) === 1) {
            return $spec;
        }

        return DEFAULT_PHPZ_SPEC . '#' . $spec;
    }
}

enum NameCase
{
    case Original;
    case Lower;
    case Upper;
}

final class TemplateVars
{
    public static function replace(string $text, string $ext): string
    {
        return str_replace(
            [
                '{{EXT_NAME}}',
                '{{EXT_NAME_UPPER}}',
                '{{EXT_NAME_STUDLY}}',
            ],
            [
                $ext,
                strtoupper($ext),
                self::studly($ext),
            ],
            $text,
        );
    }

    public static function escapeZigString(string $text): string
    {
        return str_replace(
            ["\\", "\"", "\n", "\r", "\t"],
            ["\\\\", "\\\"", "\\n", "\\r", "\\t"],
            $text,
        );
    }

    private static function studly(string $name): string
    {
        return str_replace(' ', '', ucwords(str_replace('_', ' ', strtolower($name))));
    }

    public static function snack(string $name, NameCase $case): string
    {
        $nameWithWordBoundaries = preg_replace('/([A-Z]+)([A-Z][a-z])/', '$1_$2', $name);
        if ($nameWithWordBoundaries === null) {
            return self::applyCase($name, $case);
        }

        $nameWithCaseBoundaries = preg_replace('/([a-z0-9])([A-Z])/', '$1_$2', $nameWithWordBoundaries);
        if ($nameWithCaseBoundaries === null) {
            return self::applyCase($nameWithWordBoundaries, $case);
        }

        return self::applyCase($nameWithCaseBoundaries, $case);
    }

    private static function applyCase(string $name, NameCase $case): string
    {
        return match ($case) {
            NameCase::Original => $name,
            NameCase::Lower => strtolower($name),
            NameCase::Upper => strtoupper($name),
        };
    }
}

final class ProcessRunner
{
    /**
     * @param list<string> $command
     */
    public static function commandLine(array $command): string
    {
        $parts = [];
        foreach ($command as $arg) {
            $parts[] = self::shellArg($arg);
        }
        return implode(' ', $parts);
    }

    public static function shellArg(string $arg): string
    {
        if (preg_match('/^[A-Za-z0-9_@%+=:,\.\#\/-]+$/', $arg) === 1) {
            return $arg;
        }
        return escapeshellarg($arg);
    }

    /**
     * @param list<string> $command
     * @return array{int, string}
     */
    public static function run(array $command, string $cwd, bool $echoOutput = false): array
    {
        if ($echoOutput) {
            Console::info('$ ' . self::commandLine($command));
        }

        $pipes = [];
        $startError = null;
        set_error_handler(static function (int $severity, string $message) use (&$startError): bool {
            $startError = $message;
            return true;
        });
        try {
            $proc = proc_open(
                $command,
                [
                1 => ['pipe', 'w'],
                2 => ['pipe', 'w'],
                ],
                $pipes,
                $cwd,
            );
        } finally {
            restore_error_handler();
        }
        if (!is_resource($proc)) {
            return [1, $startError ?? 'Unable to start process'];
        }

        stream_set_blocking($pipes[1], false);
        stream_set_blocking($pipes[2], false);

        $output = '';
        $error = '';
        $outputLineStart = true;
        while (!feof($pipes[1]) || !feof($pipes[2])) {
            $read = false;

            $chunk = stream_get_contents($pipes[1]);
            if ($chunk !== false && $chunk !== '') {
                $output .= $chunk;
                if ($echoOutput) {
                    self::writeOutput(STDERR, $chunk, $outputLineStart);
                }
                $read = true;
            }

            $chunk = stream_get_contents($pipes[2]);
            if ($chunk !== false && $chunk !== '') {
                $error .= $chunk;
                if ($echoOutput) {
                    self::writeOutput(STDERR, $chunk, $outputLineStart);
                }
                $read = true;
            }

            if (!$read) {
                usleep(10000);
            }
        }

        fclose($pipes[1]);
        fclose($pipes[2]);

        if ($echoOutput && !$outputLineStart) {
            fwrite(STDERR, "\n");
        }

        $code = proc_close($proc);
        return [$code, $output . $error];
    }

    /**
     * @param list<string> $command
     * @return array{int, string}
     */
    public static function runStep(
        string $label,
        array $command,
        string $cwd,
        bool $keepOutput,
        bool $required = true,
    ): array {
        if ($keepOutput) {
            Console::info("$label...");
        } else {
            fwrite(STDERR, "$label...");
            fflush(STDERR);
        }

        [$code, $output] = self::run($command, $cwd, $keepOutput);
        if ($code === 0) {
            if ($keepOutput) {
                Console::info("$label... done");
            } else {
                fwrite(STDERR, " done\n");
                fflush(STDERR);
            }
            return [$code, $output];
        }

        if (!$keepOutput) {
            fwrite(STDERR, "\n");
            Console::info('$ ' . self::commandLine($command));
            self::writeBufferedOutput($output);
        }

        if ($required) {
            Console::fail("$label failed");
        }

        return [$code, $output];
    }

    /**
     * @param list<string> $command
     */
    public static function runRequired(array $command, string $cwd, bool $echoOutput = false): string
    {
        [$code, $output] = self::run($command, $cwd, $echoOutput);
        if ($code !== 0) {
            Console::fail("Command failed in $cwd:\n  " . self::commandLine($command) . "\n" . trim($output));
        }
        return $output;
    }

    /**
     * @param resource $stream
     */
    private static function writeOutput($stream, string $chunk, bool &$atLineStart): void
    {
        foreach (explode("\n", $chunk) as $i => $part) {
            if ($i > 0) {
                fwrite($stream, "\n");
                $atLineStart = true;
            }
            if ($part === '') {
                continue;
            }
            if ($atLineStart) {
                fwrite($stream, '    ');
            }
            fwrite($stream, $part);
            $atLineStart = false;
        }
    }

    private static function writeBufferedOutput(string $output): void
    {
        if ($output === '') {
            return;
        }

        $atLineStart = true;
        self::writeOutput(STDERR, $output, $atLineStart);
        if (!$atLineStart) {
            fwrite(STDERR, "\n");
        }
    }
}

final class Environment
{
    public static function checkZigVersion(string $zig): string
    {
        $version = trim(ProcessRunner::runRequired([$zig, 'version'], PathUtil::cwd()));
        if (version_compare($version, MIN_ZIG_VERSION, '<')) {
            Console::fail("Unsupported Zig version $version. Expected >= " . MIN_ZIG_VERSION . '.');
        }
        return $version;
    }

    public static function checkPhpVersion(): string
    {
        $version = PHP_VERSION;
        if (version_compare($version, MIN_PHP_VERSION, '<')) {
            Console::fail("Unsupported PHP version $version. Expected >= " . MIN_PHP_VERSION . '.');
        }

        self::checkPhpRuntimeSupport();
        return $version;
    }

    public static function checkPhpConfig(PhpConfig $phpConfig): void
    {
        PhpToolResolver::phpConfigValue($phpConfig, true, '--prefix');
    }

    private static function checkPhpRuntimeSupport(): void
    {
        $missingExtensions = [];
        foreach (REQUIRED_PHP_EXTENSIONS as $extension) {
            if (!extension_loaded($extension)) {
                $missingExtensions[] = $extension;
            }
        }
        if ($missingExtensions !== []) {
            Console::fail('Missing required PHP extension(s): ' . implode(', ', $missingExtensions));
        }

        $missingFunctions = [];
        foreach (REQUIRED_PHP_FUNCTIONS as $function) {
            if (!function_exists($function)) {
                $missingFunctions[] = $function;
            }
        }
        if ($missingFunctions !== []) {
            Console::fail(
                'Missing required PHP function(s): '
                . implode(', ', $missingFunctions)
                . ' (check disable_functions)',
            );
        }
    }
}

final class PhpToolResolver
{
    public static function phpConfigValue(PhpConfig $phpConfig, bool $required, string $option): ?string
    {
        $command = [$phpConfig->bin, $option];
        [$code, $output] = ProcessRunner::run($command, PathUtil::cwd());
        if ($code !== 0) {
            if ($required) {
                Console::fail("Unable to run " . ProcessRunner::commandLine($command) . ":\n" . trim($output));
            }
            return null;
        }
        $value = trim($output);
        if ($value === '' && $required) {
            Console::fail(ProcessRunner::commandLine($command) . ' returned empty output');
        }
        return $value === '' ? null : $value;
    }

    public static function phpIncludeDir(PhpConfig $phpConfig): string
    {
        return self::phpConfigValue($phpConfig, $phpConfig->isExplicit(), '--include-dir')
            ?? DEFAULT_PHP_INCLUDE_DIR;
    }

    public static function resolveOptional(
        ToolOption $config,
        string $filename,
        PhpConfig $phpConfig,
        ?string $targetDir = null,
    ): ?string {
        if ($config->isDisabled()) {
            Console::check("for $filename", 'disabled');
            return null;
        }

        if ($config->isExplicit()) {
            $path = (string) $config->path;
            if (!is_file($path)) {
                Console::fail("$filename not found: $path");
            }
            Console::check("for $filename", $path);
            return $path;
        }

        $path = self::detectPhpBuildTool($phpConfig, $filename);
        if ($path === null) {
            $path = $targetDir !== null && $filename === 'run-tests.php'
                ? self::detectPhpzPackageRunTests($targetDir)
                : null;
            if ($path !== null) {
                Console::check("for $filename", $path);
                return $path;
            }

            Console::check("for $filename", 'no');
            return null;
        }

        Console::check("for $filename", $path);
        return $path;
    }

    private static function detectPhpBuildTool(PhpConfig $phpConfig, string $filename): ?string
    {
        $candidates = [];

        $libDir = self::phpConfigValue($phpConfig, false, '--lib-dir');
        if ($libDir !== null) {
            $candidates[] = PathUtil::normalize($libDir . '/php/build/' . $filename);
        }

        $prefix = self::phpConfigValue($phpConfig, $phpConfig->isExplicit(), '--prefix');
        if ($prefix !== null) {
            $candidates[] = PathUtil::normalize($prefix . '/lib/php/build/' . $filename);
            $candidates[] = PathUtil::normalize($prefix . '/lib64/php/build/' . $filename);
        }

        $extensionDir = self::phpConfigValue($phpConfig, $phpConfig->isExplicit(), '--extension-dir');
        if ($extensionDir !== null) {
            $candidates[] = PathUtil::normalize(dirname($extensionDir) . '/build/' . $filename);
        }

        foreach (array_values(array_unique($candidates)) as $candidate) {
            if (is_file($candidate)) {
                return $candidate;
            }
        }

        return null;
    }

    private static function detectPhpzPackageRunTests(string $targetDir): ?string
    {
        $roots = glob($targetDir . '/zig-pkg/phpz-*', GLOB_ONLYDIR);
        if ($roots === false || $roots === []) {
            return null;
        }
        sort($roots);

        foreach ($roots as $root) {
            $candidate = PathUtil::normalize($root . '/examples/skeleton/run-tests.php');
            if (is_file($candidate)) {
                return $candidate;
            }
        }

        return null;
    }
}

final class ProjectInstaller
{
    public static function prepareTargetDir(string $targetDir, bool $force): void
    {
        Console::check('target directory', $targetDir);
        if (file_exists($targetDir) && !$force) {
            Console::fail("Target already exists: $targetDir (pass --force to overwrite template files)");
        }
        PathUtil::mkdir($targetDir);
        Console::info('creating target directory... done');
    }

    public static function initZigProject(
        string $targetDir,
        string $zig,
        bool $force,
        bool $keepCommandOutput,
    ): void {
        $buildFile = $targetDir . '/build.zig';
        $zonFile = $targetDir . '/build.zig.zon';

        if ((file_exists($buildFile) || file_exists($zonFile)) && !$force) {
            Console::fail("Target already contains build.zig or build.zig.zon: $targetDir (pass --force)");
        }
        if ($force) {
            if (file_exists($buildFile) && !unlink($buildFile)) {
                Console::fail("Unable to remove $buildFile");
            }
            if (file_exists($zonFile) && !unlink($zonFile)) {
                Console::fail("Unable to remove $zonFile");
            }
        }

        ProcessRunner::runStep(
            'initializing Zig project',
            [$zig, 'init', '--minimal'],
            $targetDir,
            $keepCommandOutput,
        );
    }

    public static function fetchPhpz(
        string $targetDir,
        string $zig,
        string $phpzSpec,
        bool $keepCommandOutput,
    ): void {
        ProcessRunner::runStep(
            'fetching phpz dependency',
            [$zig, 'fetch', '--save=phpz', $phpzSpec],
            $targetDir,
            $keepCommandOutput,
        );
    }

    public static function installRunTests(string $source, string $targetDir, bool $force): void
    {
        $dest = $targetDir . '/run-tests.php';
        if (file_exists($dest) && !$force) {
            Console::fail("Refusing to overwrite $dest");
        }
        if (!copy($source, $dest)) {
            Console::fail("Unable to copy $source to $dest");
        }
        if (!chmod($dest, 0755)) {
            Console::fail("Unable to chmod $dest");
        }
    }

    public static function installGenStub(string $source, string $targetDir, bool $force): string
    {
        $buildDir = $targetDir . '/build';
        PathUtil::mkdir($buildDir);

        $localGenStub = $buildDir . '/gen_stub.php';
        if (file_exists($localGenStub) && !$force) {
            Console::fail("Refusing to overwrite $localGenStub");
        }
        if (!copy($source, $localGenStub)) {
            Console::fail("Unable to copy $source to $localGenStub");
        }

        return $localGenStub;
    }

    public static function runGenStub(
        string $localGenStub,
        string $targetDir,
        string $ext,
        bool $keepCommandOutput,
    ): void {
        ProcessRunner::runStep(
            'generating arginfo',
            [PHP_BINARY, $localGenStub, $ext . '.stub.php'],
            $targetDir,
            $keepCommandOutput,
            true,
        );
    }
}

// Template definitions.
const PHPZ_TEST_STEP_TEMPLATE = <<<'ZIG'

    const test_step = b.step("test", "Run PHPT tests");
    const test_phpt_cmd = b.addSystemCommand(&[_][]const u8{
        "php",
        "run-tests.php",
        "-q",
        "--show-diff",
        "-d",
        b.fmt("extension=modules/{s}", .{ext_filename}),
    });
    test_phpt_cmd.step.dependOn(b.getInstallStep());
    test_step.dependOn(&test_phpt_cmd.step);
ZIG;

const PHPZ_WINDOWS_BUILD_OPTIONS_TEMPLATE = <<<'ZIG'
    const php_lib_dir = b.option([]const u8, "php-lib-dir", "PHP SDK library directory (Windows only, contains php8*.lib)");
    const windows_zts = b.option(bool, "windows-zts", "Windows only: link against the thread-safe PHP library") orelse false;
    const windows_debug = b.option(bool, "windows-debug", "Windows only: build against a debug PHP SDK") orelse false;
ZIG;

const PHPZ_WINDOWS_INIT_OPTIONS_TEMPLATE = <<<'ZIG'
        .php_lib_dir = if (php_lib_dir) |dir| .{ .cwd_relative = dir } else null,
        .windows_zts = windows_zts,
        .windows_debug = windows_debug,
ZIG;

const PHPZ_ALL_PLATFORM_FILENAME_TEMPLATE = <<<'ZIG'
    const ext_filename = if (target.result.os.tag == .windows)
        "php_" ++ ext_name ++ ".dll"
    else
        ext_name ++ ".so";
ZIG;

const PHPZ_UNIX_FILENAME_TEMPLATE = <<<'ZIG'
    const ext_filename = ext_name ++ ".so";
ZIG;

const PHPZ_WINDOWS_FILENAME_TEMPLATE = <<<'ZIG'
    const ext_filename = "php_" ++ ext_name ++ ".dll";
ZIG;

const PHPZ_UNIX_TARGET_CHECK_TEMPLATE = <<<'ZIG'
    if (target.result.os.tag == .windows) {
        @panic("This extension only supports Unix targets");
    }
ZIG;

const PHPZ_WINDOWS_TARGET_CHECK_TEMPLATE = <<<'ZIG'
    if (target.result.os.tag != .windows) {
        @panic("This extension only supports Windows targets");
    }
ZIG;

const PHPZ_UNIX_MANUAL_COMMANDS_TEMPLATE = <<<'MD'
php -dextension=./modules/{{EXT_NAME}}.so -r 'hello();'
php -dextension=./modules/{{EXT_NAME}}.so -r 'echo greet("World");'
MD;

const PHPZ_WINDOWS_MANUAL_COMMANDS_TEMPLATE = <<<'MD'
php -dextension=./modules/php_{{EXT_NAME}}.dll -r 'hello();'
php -dextension=./modules/php_{{EXT_NAME}}.dll -r 'echo greet("World");'
MD;

const PHPZ_GEN_STUB_REGEN_TEMPLATE = <<<'MD'
After changing `{{EXT_NAME}}.stub.php`, regenerate C arginfo:

```bash
php build/gen_stub.php {{EXT_NAME}}.stub.php
```
MD;

const PHPZ_GEN_STUB_MISSING_TEMPLATE = <<<'MD'
Arginfo generation is not configured. To regenerate after changing `{{EXT_NAME}}.stub.php`,
copy gen_stub.php to `build/gen_stub.php`, then run:

```bash
php build/gen_stub.php {{EXT_NAME}}.stub.php
```
MD;

const PHPZ_TEMPLATE_FILES = [
    '.gitignore' => <<<'TXT'
/build/
/modules/
/zig-out/
/.zig-cache/
/zig-pkg/
TXT,
    'build.zig' => <<<'ZIG'
const std = @import("std");

const Phpz = @import("phpz").Phpz;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
{{PHPZ_PLATFORM_TARGET_CHECK}}

    const php_include_dir = b.option([]const u8, "php-include-dir", "PHP include dir") orelse "{{PHP_INCLUDE_DIR}}";
{{PHPZ_WINDOWS_BUILD_OPTIONS}}

    const phpz_dep = b.dependency("phpz", .{});
    const phpz = Phpz.init(phpz_dep, .{
        .translator = .{
            .c_source_file = b.path("{{EXT_NAME}}.h"),
            .target = target,
            .optimize = optimize,
        },
        .php_include_dir = .{ .cwd_relative = php_include_dir },
{{PHPZ_WINDOWS_INIT_OPTIONS}}
    });

    const ext_name = "{{EXT_NAME}}";
    const ext_lib = phpz.addExtension(b, .{
        .name = ext_name,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root.zig"),
            .target = target,
            .optimize = optimize,
        }),
        .linkage = .dynamic,
    });

{{PHPZ_EXT_FILENAME}}

    const ext_file = std.Build.Step.UpdateSourceFiles.create(b);
    ext_file.addCopyFileToSource(ext_lib.getEmittedBin(), b.fmt("modules/{s}", .{ext_filename}));
    b.getInstallStep().dependOn(&ext_file.step);
{{PHPZ_TEST_STEP}}
}

ZIG,
    'README.md' => <<<'MD'
# {{EXT_NAME_STUDLY}}

A minimal PHP extension built with phpz.

## Run

```bash
{{PHPZ_GEN_STUB_RUN_COMMAND}}{{PHPZ_TEST_COMMAND}}
```

Custom PHP include path:

```bash
{{PHPZ_TEST_COMMAND}} -Dphp-include-dir=/usr/local/include/php
```

{{PHPZ_GEN_STUB_REGEN_SECTION}}

## Try it manually

```bash
zig build
{{PHPZ_MANUAL_COMMANDS}}
```
MD,
    '{{EXT_NAME}}.h' => <<<'C'
#ifndef {{EXT_NAME_UPPER}}_H
#define {{EXT_NAME_UPPER}}_H

#include "phpz.h"
#include "{{EXT_NAME}}_arginfo.h"

extern zend_module_entry {{EXT_NAME}}_module_entry;
#define phpext_{{EXT_NAME}}_ptr &{{EXT_NAME}}_module_entry

#endif
C,
    '{{EXT_NAME}}.stub.php' => <<<'PHP'
<?php

/**
 * @generate-class-entries
 * @undocumentable
 */

function hello(): void {}

function greet(string $name): string {}

class Counter
{
    public function __construct(int $n = 0) {}

    public function add(int $n): void {}

    public function dec(int $n): void {}

    public function value(): int {}
}
PHP,
    '{{EXT_NAME}}_arginfo.h' => <<<'C'
/* This is a generated file, edit the .stub.php file instead.
 * Stub hash: d84374eb3cc93ebb1e1cf6f0dfa2ee49381bec07 */

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_hello, 0, 0, IS_VOID, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_greet, 0, 1, IS_STRING, 0)
	ZEND_ARG_TYPE_INFO(0, name, IS_STRING, 0)
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_INFO_EX(arginfo_class_Counter___construct, 0, 0, 0)
	ZEND_ARG_TYPE_INFO_WITH_DEFAULT_VALUE(0, n, IS_LONG, 0, "0")
ZEND_END_ARG_INFO()

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Counter_add, 0, 1, IS_VOID, 0)
	ZEND_ARG_TYPE_INFO(0, n, IS_LONG, 0)
ZEND_END_ARG_INFO()

#define arginfo_class_Counter_dec arginfo_class_Counter_add

ZEND_BEGIN_ARG_WITH_RETURN_TYPE_INFO_EX(arginfo_class_Counter_value, 0, 0, IS_LONG, 0)
ZEND_END_ARG_INFO()


ZEND_FUNCTION(hello);
ZEND_FUNCTION(greet);
ZEND_METHOD(Counter, __construct);
ZEND_METHOD(Counter, add);
ZEND_METHOD(Counter, dec);
ZEND_METHOD(Counter, value);


static const zend_function_entry ext_functions[] = {
	ZEND_FE(hello, arginfo_hello)
	ZEND_FE(greet, arginfo_greet)
	ZEND_FE_END
};


static const zend_function_entry class_Counter_methods[] = {
	ZEND_ME(Counter, __construct, arginfo_class_Counter___construct, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, add, arginfo_class_Counter_add, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, dec, arginfo_class_Counter_dec, ZEND_ACC_PUBLIC)
	ZEND_ME(Counter, value, arginfo_class_Counter_value, ZEND_ACC_PUBLIC)
	ZEND_FE_END
};

static zend_class_entry *register_class_Counter(void)
{
	zend_class_entry ce, *class_entry;

	INIT_CLASS_ENTRY(ce, "Counter", class_Counter_methods);
	class_entry = zend_register_internal_class_ex(&ce, NULL);

	return class_entry;
}
C,
    'src/root.zig' => <<<'ZIG'
const std = @import("std");

const phpz = @import("phpz");

const counter = @import("classes/counter.zig");

comptime {
    phpz.function("hello", hello);
    phpz.function("greet", greet);

    phpz.module(.{
        .name = "{{EXT_NAME}}",
        .version = "0.1.0",
        .classes = &.{counter.Class},
    });
}

// --- Functions ---

/// function hello(): void
fn hello() void {
    _ = phpz.printf("Hello from Zig!\n", .{});
}

/// function greet(string $name): string
fn greet(ctx: phpz.Ctx) !void {
    const args = try ctx.call.expectArgs(&.{
        .{ .string = .{} },
    }, {});
    const name = args[0];

    var buffer: [256]u8 = undefined;
    const result = try std.fmt.bufPrint(&buffer, "Hello, {s}!", .{name});
    ctx.ret.set(.string, result);
}

ZIG,
    'src/classes/counter.zig' => <<<'ZIG'
const phpz = @import("phpz");

/// class Counter
pub const Counter = extern struct {
    n: i64,

    /// public function __construct(int $n = 0): void
    pub fn construct(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{ .optional = true } },
        }, {});
        self.n = args[0] orelse 0;
    }

    /// public function add(int $n): void
    pub fn add(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n +|= args[0];
    }

    /// public function dec(int $n): void
    pub fn dec(self: *Counter, ctx: phpz.Ctx) !void {
        const args = try ctx.call.expectArgs(&.{
            .{ .int = .{} },
        }, {});
        self.n -|= args[0];
    }

    /// public function value(): int
    pub fn value(self: Counter, ctx: phpz.Ctx) void {
        ctx.ret.set(.int, self.n);
    }
};

pub const Class = phpz.Class("Counter", Counter);

comptime {
    Class.method("__construct", .construct);
    Class.method("add", .add);
    Class.method("dec", .dec);
    Class.method("value", .value);
}

ZIG,
    'tests/hello.phpt' => <<<'PHPT'
--TEST--
hello() prints a greeting
--FILE--
<?php

hello();
--EXPECT--
Hello from Zig!
PHPT,
    'tests/greet.phpt' => <<<'PHPT'
--TEST--
greet($name) returns a personalized greeting
--FILE--
<?php

echo greet("Zig");
echo "\n";
echo greet("PHP");
--EXPECT--
Hello, Zig!
Hello, PHP!
PHPT,
    'tests/counter.phpt' => <<<'PHPT'
--TEST--
Counter class methods
--FILE--
<?php

$c = new Counter(10);
echo $c->value() . "\n";

$c->add(5);
echo $c->value() . "\n";

$c->add(2);
echo $c->value() . "\n";

$c->dec(3);
echo $c->value() . "\n";

$c2 = new Counter(100);
echo $c2->value() . "\n";

$c3 = new Counter();
echo $c3->value() . "\n";
--EXPECT--
10
15
17
14
100
0
PHPT,
];

final class TemplateWriter
{
    public static function render(
        string $contents,
        string $ext,
        string $phpIncludeDir,
        bool $hasRunTests,
        bool $hasGenStub,
        bool $unix,
        bool $windows,
    ): string {
        $targetCheck = '';
        $extFilename = PHPZ_ALL_PLATFORM_FILENAME_TEMPLATE;
        if (!$windows) {
            $targetCheck = PHPZ_UNIX_TARGET_CHECK_TEMPLATE;
            $extFilename = PHPZ_UNIX_FILENAME_TEMPLATE;
        } elseif (!$unix) {
            $targetCheck = PHPZ_WINDOWS_TARGET_CHECK_TEMPLATE;
            $extFilename = PHPZ_WINDOWS_FILENAME_TEMPLATE;
        }

        $contents = str_replace(
            "{{PHPZ_PLATFORM_TARGET_CHECK}}\n",
            $targetCheck === '' ? '' : $targetCheck . "\n",
            $contents,
        );
        $contents = str_replace(
            "{{PHPZ_WINDOWS_BUILD_OPTIONS}}\n",
            $windows ? PHPZ_WINDOWS_BUILD_OPTIONS_TEMPLATE . "\n" : '',
            $contents,
        );
        $contents = str_replace(
            "{{PHPZ_WINDOWS_INIT_OPTIONS}}\n",
            $windows ? PHPZ_WINDOWS_INIT_OPTIONS_TEMPLATE . "\n" : '',
            $contents,
        );
        $contents = str_replace("{{PHPZ_EXT_FILENAME}}\n", $extFilename . "\n", $contents);
        $manualCommands = PHPZ_UNIX_MANUAL_COMMANDS_TEMPLATE;
        if ($unix && $windows) {
            $manualCommands = "# Unix\n" . PHPZ_UNIX_MANUAL_COMMANDS_TEMPLATE
                . "\n\n# Windows\n" . PHPZ_WINDOWS_MANUAL_COMMANDS_TEMPLATE;
        } elseif ($windows) {
            $manualCommands = PHPZ_WINDOWS_MANUAL_COMMANDS_TEMPLATE;
        }
        $contents = str_replace('{{PHPZ_MANUAL_COMMANDS}}', $manualCommands, $contents);
        $contents = str_replace(
            "{{PHPZ_TEST_STEP}}\n",
            $hasRunTests ? PHPZ_TEST_STEP_TEMPLATE . "\n" : '',
            $contents,
        );
        $contents = str_replace('{{PHPZ_TEST_COMMAND}}', $hasRunTests ? 'zig build test' : 'zig build', $contents);
        $contents = str_replace('{{PHP_INCLUDE_DIR}}', TemplateVars::escapeZigString($phpIncludeDir), $contents);
        $contents = str_replace(
            '{{PHPZ_GEN_STUB_RUN_COMMAND}}',
            $hasGenStub ? "php build/gen_stub.php {{EXT_NAME}}.stub.php\n" : '',
            $contents,
        );
        $contents = str_replace(
            '{{PHPZ_GEN_STUB_REGEN_SECTION}}',
            $hasGenStub ? PHPZ_GEN_STUB_REGEN_TEMPLATE : PHPZ_GEN_STUB_MISSING_TEMPLATE,
            $contents,
        );
        return TemplateVars::replace($contents, $ext);
    }

    /**
     * @return array{int, int}
     */
    public static function write(
        string $targetDir,
        string $ext,
        string $phpIncludeDir,
        bool $force,
        bool $hasRunTests,
        bool $hasGenStub,
        bool $unix,
        bool $windows,
    ): array {
        $written = 0;
        $skippedTests = 0;

        foreach (PHPZ_TEMPLATE_FILES as $relative => $contents) {
            if (!$hasRunTests && str_starts_with($relative, 'tests/')) {
                $skippedTests++;
                continue;
            }

            $destRelative = TemplateVars::replace($relative, $ext);
            $destPath = $targetDir . '/' . $destRelative;
            PathUtil::mkdir(dirname($destPath));

            if (file_exists($destPath) && !$force && $destRelative !== 'build.zig') {
                Console::fail("Refusing to overwrite $destPath");
            }

            if (
                file_put_contents(
                    $destPath,
                    self::render($contents, $ext, $phpIncludeDir, $hasRunTests, $hasGenStub, $unix, $windows),
                ) === false
            ) {
                Console::fail("Unable to write $destPath");
            }
            $written++;
        }

        return [$written, $skippedTests];
    }
}

final class Command
{
    public static function run(mixed $argv): void
    {
        $argv = self::normalizeArgv($argv);
        if (self::hasHelpOption($argv)) {
            self::usage();
        }

        $args = Args::parse($argv);

        $phpVersion = Environment::checkPhpVersion();
        Console::check('PHP version', $phpVersion);
        Console::check('PHP runtime support', 'yes');
        $zigVersion = Environment::checkZigVersion($args->zig);
        Console::check('Zig version', $zigVersion);
        Console::check('phpz package', $args->phpz);
        if ($args->phpConfig->isExplicit()) {
            Console::check('php-config', $args->phpConfig->bin);
            Environment::checkPhpConfig($args->phpConfig);
        }
        $phpIncludeDir = PhpToolResolver::phpIncludeDir($args->phpConfig);

        $parentDir = PathUtil::absolute($args->dir);
        $targetDir = PathUtil::normalize($parentDir . '/' . $args->ext);
        ProjectInstaller::prepareTargetDir($targetDir, $args->force);
        ProjectInstaller::initZigProject($targetDir, $args->zig, $args->force, $args->verbose);
        ProjectInstaller::fetchPhpz($targetDir, $args->zig, $args->phpz, $args->verbose);

        $genStubPath = PhpToolResolver::resolveOptional(
            $args->genStub,
            'gen_stub.php',
            $args->phpConfig,
        );
        $runTestsPath = PhpToolResolver::resolveOptional(
            $args->runTests,
            'run-tests.php',
            $args->phpConfig,
            $targetDir,
        );

        [$templateCount, $skippedTestTemplateCount] = TemplateWriter::write(
            $targetDir,
            $args->ext,
            $phpIncludeDir,
            $args->force,
            $runTestsPath !== null,
            $genStubPath !== null,
            $args->unix,
            $args->windows,
        );
        $templateResult = $templateCount . ' files';
        if ($skippedTestTemplateCount > 0) {
            $templateResult .= ", $skippedTestTemplateCount PHPT skipped";
        }
        Console::info("writing template files... $templateResult");

        $testsStatus = self::installRunTests($runTestsPath, $targetDir, $args->force);
        $arginfoStatus = self::installGenStubAndGenerate($genStubPath, $targetDir, $args->ext, $args);

        self::printSummary(
            $args,
            $targetDir,
            $testsStatus,
            $arginfoStatus,
            $runTestsPath !== null,
            $genStubPath !== null,
        );
    }

    /**
     * @return list<string>
     */
    private static function normalizeArgv(mixed $argv): array
    {
        if (!is_array($argv)) {
            return [];
        }

        $normalized = [];
        foreach ($argv as $arg) {
            if (is_string($arg)) {
                $normalized[] = $arg;
            }
        }

        return $normalized;
    }

    /**
     * @param list<string> $argv
     */
    private static function hasHelpOption(array $argv): bool
    {
        foreach ($argv as $arg) {
            if ($arg === '--help' || $arg === '-h') {
                return true;
            }
        }

        return false;
    }

    private static function usage(): never
    {
        echo <<<USAGE
Usage:
  php tools/phpz_skel.php --ext <name> [options]
  curl -fsSL https://raw.githubusercontent.com/happystraw/phpz/dev/tools/phpz_skel.php | php -- --ext <name> [options]

Options:
  --ext <name>             Extension name (required), e.g. demo_ext.
  --dir <path>             Parent directory for the extension (default: cwd).
  --phpz <spec>            phpz package spec for `zig fetch --save=phpz`.
                           Bare values are treated as phpz tags, e.g. dev.
                           Default: git+https://github.com/happystraw/phpz.
  --zig <path>             Zig executable (default: \$ZIG, or zig).
  --with-php-config <path> php-config executable for auto-detecting PHP tools.
  --with-gen-stub [path]   Use gen_stub.php; without path, auto-detect via php-config.
  --without-gen-stub       Disable gen_stub.php and arginfo generation.
  --with-run-tests [path]  Use run-tests.php; without path, auto-detect via php-config
                           or zig-pkg/phpz-*/examples/skeleton/run-tests.php.
  --without-run-tests      Disable run-tests.php; omit tests/ and the build test step.
  --onlyunix               Only include Unix support in build.zig.
  --onlywindows            Only include Windows support in build.zig.
  --force                  Overwrite generated template files in an existing target.
  -v, --verbose            Print successful command output.
  -h, --help               Show this help.

Examples:
  php tools/phpz_skel.php --ext demo_ext
  php tools/phpz_skel.php --ext demo_ext --phpz dev --without-gen-stub

Output:
  Commands are quiet by default. Failed commands print the command and output.

USAGE;
        exit(0);
    }

    private static function installRunTests(?string $runTestsPath, string $targetDir, bool $force): string
    {
        if ($runTestsPath === null) {
            Console::info('configuring PHPT tests... disabled');
            return 'disabled';
        }

        ProjectInstaller::installRunTests($runTestsPath, $targetDir, $force);
        Console::info('installing run-tests.php... done');
        return 'enabled';
    }

    private static function installGenStubAndGenerate(
        ?string $genStubPath,
        string $targetDir,
        string $extName,
        Args $args,
    ): string {
        if ($genStubPath === null) {
            Console::info('generating arginfo... skipped');
            return 'skipped';
        }

        $localGenStub = ProjectInstaller::installGenStub($genStubPath, $targetDir, $args->force);
        Console::info('installing gen_stub.php... done');
        ProjectInstaller::runGenStub($localGenStub, $targetDir, $extName, $args->verbose);
        return 'generated';
    }

    private static function printSummary(
        Args $args,
        string $targetDir,
        string $testsStatus,
        string $arginfoStatus,
        bool $hasRunTests,
        bool $hasGenStub,
    ): void {
        $stubFile = TemplateVars::replace('{{EXT_NAME}}.stub.php', $args->ext);

        echo "\nphpz skeleton configured\n\n";
        echo "Project:\n";
        echo '  extension:    ' . $args->ext . "\n";
        echo "  directory:    $targetDir\n";
        echo '  platforms:    ' . ($args->unix && $args->windows
            ? 'Unix, Windows'
            : ($args->unix ? 'Unix' : 'Windows')) . "\n";
        echo "  arginfo:      $arginfoStatus\n";
        echo "  PHPT tests:   $testsStatus\n";
        echo "\nQuick start:\n";
        echo '  $ cd ' . ProcessRunner::shellArg($targetDir) . "\n";
        echo $hasRunTests ? "  $ zig build test\n" : "  $ zig build\n";
        echo "\nRegenerate arginfo after changing $stubFile:\n";
        if ($hasGenStub) {
            echo "  $ php build/gen_stub.php $stubFile\n";
        } else {
            echo "  copy gen_stub.php to build/gen_stub.php, then run:\n";
            echo "  $ php build/gen_stub.php $stubFile\n";
        }
    }
}

Command::run($GLOBALS['argv'] ?? []);
