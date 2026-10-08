// Shared CI execution: each ABI gets its own source tree; logs survive cleanup.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import { spawn, spawnSync, execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const sourceRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
export const examples = ['skeleton', 'my_php_extension'];
let cancelled = false;

export function configuration(env = process.env, root = sourceRoot) {
  const php = env.CI_PHP;
  const ts = env.CI_TS;
  const debug = env.CI_DEBUG;
  if (!/^8\.[2-5]$/.test(php) || !['nts', 'ts'].includes(ts) || !['true', 'false'].includes(debug)) {
    throw new Error('Expected CI_PHP=8.2..8.5, CI_TS=nts|ts and CI_DEBUG=true|false');
  }
  const extension = env.CI_EXTENSION;
  if (extension && !examples.includes(extension)) throw new Error('Unknown built-in extension');
  const id = `php-${php}-${ts}-${debug === 'true' ? 'debug' : 'release'}${extension ? `-${extension}` : ''}`;
  const work = path.join(path.resolve(env.RUNNER_TEMP), 'phpz-ci', id);
  return { php, ts, debug, extension, id, root, work,
    repo: path.join(work, 'repo'), logs: path.join(root, 'build/ci-results', id) };
}

export function copyCheckout(root, destination) {
  fs.mkdirSync(destination, { recursive: true });
  // Copy tracked working-tree files, including edits when validating locally.
  // Never recursively copy build/php-src, SDKs, modules or generated caches.
  const files = execFileSync('git', ['ls-files', '-z'], { cwd: root }).toString().split('\0').filter(Boolean);
  for (const file of files) {
    const from = path.join(root, file);
    const to = path.join(destination, file);
    fs.mkdirSync(path.dirname(to), { recursive: true });
    fs.cpSync(from, to, { dereference: false });
  }
}

export function isolatedEnv(config, base = process.env) {
  const env = { ...base };
  for (const key of Object.keys(env)) {
    if (/^(PHPRC|PHP_INI_SCAN_DIR|TEST_PHP_.*|ZIG_LOCAL_CACHE_DIR|ZIG_LOCAL_PKG_DIR|ZIG_LIBC|PHP_BUILD_.*)$/i.test(key)) delete env[key];
  }
  const tmp = path.join(config.work, 'tmp');
  fs.mkdirSync(tmp, { recursive: true });
  return { ...env, TMPDIR: tmp, TMP: tmp, TEMP: tmp,
    ZIG_GLOBAL_CACHE_DIR: base.ZIG_GLOBAL_CACHE_DIR || path.join(path.dirname(config.work), 'zig-global'),
    NO_INTERACTION: '1', REPORT_EXIT_STATUS: '1' };
}

export function prepare(config) {
  fs.rmSync(config.work, { recursive: true, force: true });
  fs.rmSync(config.logs, { recursive: true, force: true });
  fs.mkdirSync(config.logs, { recursive: true });
  fs.mkdirSync(config.work, { recursive: true });
  copyCheckout(config.root, config.repo);
}

async function terminateTree(child, logFd) {
  if (!child.pid) return;
  if (process.platform === 'win32') {
    // Kill descendants before their parent disappears from the process tree.
    await new Promise((resolve, reject) => {
      const killer = spawn('taskkill.exe', ['/PID', String(child.pid), '/T', '/F'], {
        stdio: ['ignore', logFd, logFd], windowsHide: true,
      });
      killer.once('error', reject);
      killer.once('close', code => code === 0 ? resolve() : reject(new Error(`taskkill exited with ${code}`)));
    });
  } else {
    const signalGroup = signal => {
      try { process.kill(-child.pid, signal); }
      catch (error) { if (error.code !== 'ESRCH') throw error; }
    };
    signalGroup('SIGTERM');
    // The parent may exit first; still kill any descendants ignoring SIGTERM.
    await new Promise(resolve => setTimeout(resolve, 500));
    signalGroup('SIGKILL');
  }
}

// Child commands use argument arrays, never shell interpolation of paths.
export async function command(exe, args, { cwd, env, log }) {
  if (cancelled) throw new Error('CI execution cancelled');
  fs.mkdirSync(path.dirname(log), { recursive: true });
  const invocation = `\n$ ${JSON.stringify([exe, ...args])}\n`;
  fs.appendFileSync(log, invocation);
  process.stdout.write(invocation);
  const fd = fs.openSync(log, 'a');
  try {
    await new Promise((resolve, reject) => {
      // A separate Unix process group keeps compiler descendants addressable
      // even after make/the shell exits. Windows uses taskkill /T instead.
      // Pipe output through Node so it is visible live and retained in full.
      // Native Windows tools no longer inherit an append-only log file handle.
      const child = spawn(exe, args, { cwd, env, stdio: ['ignore', 'pipe', 'pipe'], detached: process.platform !== 'win32' });
      let stopping;
      let stopError;
      let outputError;
      const stop = () => { stopping ??= terminateTree(child, fd).catch(error => { stopError = error; }); };
      const cancel = () => {
        cancelled = true;
        stop();
      };
      const forward = (stream, destination) => {
        stream.on('data', chunk => {
          if (!outputError) {
            try { fs.appendFileSync(fd, chunk); }
            catch (error) { outputError = error; stop(); }
          }
          if (!destination.write(chunk)) {
            stream.pause();
            destination.once('drain', () => stream.resume());
          }
        });
        stream.on('error', error => { outputError ??= error; stop(); });
      };
      forward(child.stdout, process.stdout);
      forward(child.stderr, process.stderr);
      process.on('SIGTERM', cancel);
      process.on('SIGINT', cancel);
      const clear = () => { process.removeListener('SIGTERM', cancel); process.removeListener('SIGINT', cancel); };
      child.once('error', error => { clear(); reject(error); });
      child.once('close', async (code, signal) => {
        // Do not let collection/cleanup race with tree termination.
        if (stopping) await stopping;
        clear();
        if (outputError) reject(outputError);
        else if (stopError) reject(stopError);
        else if (stopping) reject(new Error(`${exe} interrupted: CI execution cancelled`));
        else if (signal) reject(new Error(`${exe} interrupted: ${signal}`));
        else if (code !== 0) reject(new Error(`${exe} exited with ${code}`));
        else resolve();
      });
    });
  } finally { fs.closeSync(fd); }
}

export function collectDiagnostics(from, destination) {
  if (!fs.existsSync(from)) return;
  for (const entry of fs.readdirSync(from, { withFileTypes: true })) {
    if (entry.isSymbolicLink()) continue;
    const src = path.join(from, entry.name);
    const dst = path.join(destination, entry.name);
    if (entry.isDirectory()) {
      if (!['.git', '.zig-cache', 'zig-out', 'zig-pkg', 'sdk', 'tmp', 'node_modules'].includes(entry.name)) collectDiagnostics(src, dst);
    } else if (/\.(log|diff|out|exp)$/.test(entry.name)) {
      fs.mkdirSync(path.dirname(dst), { recursive: true });
      fs.copyFileSync(src, dst);
    }
  }
}

export async function runTasks(config, tasks) {
  const resultFile = path.join(config.logs, 'results.json');
  const results = fs.existsSync(resultFile) ? JSON.parse(fs.readFileSync(resultFile)) : [];
  for (const task of tasks) {
    if (cancelled) break;
    const started = Date.now();
    const log = path.join(config.logs, `${task.name}.log`);
    console.log(`::group::${config.id}: ${task.name}`);
    let result = 'PASS';
    try { await task.run(log); }
    catch (error) {
      result = 'FAIL';
      fs.appendFileSync(log, `${error.stack}\n`);
      // Command output was already streamed; report the error without replaying it.
      console.error(error.stack);
    }
    try { collectDiagnostics(config.repo, path.join(config.logs, task.name)); }
    catch (error) { result = 'FAIL'; fs.appendFileSync(log, `${error.stack}\n`); }
    console.log(`::endgroup::\n${result} ${task.name}`);
    results.push({ task: task.name, result, seconds: ((Date.now() - started) / 1000).toFixed(1) });
    fs.writeFileSync(path.join(config.logs, 'results.json'), JSON.stringify(results, null, 2));
  }
  return !cancelled && results.every(row => row.result === 'PASS');
}

export function finish(config, setup, outcome, summaryPath = process.env.GITHUB_STEP_SUMMARY) {
  const errors = [];
  try {
    collectDiagnostics(config.repo, path.join(config.logs, 'diagnostics'));
    const resultFile = path.join(config.logs, 'results.json');
    const rows = fs.existsSync(resultFile) ? JSON.parse(fs.readFileSync(resultFile)) : [];
    if (setup !== 'success') rows.unshift({ task: 'setup', result: setup.toUpperCase(), seconds: '-' });
    if (outcome !== 'success') rows.push({ task: 'variant', result: outcome.toUpperCase(), seconds: '-' });
    const summary = ['\n### ' + config.id, '', `Runner: ${process.env.RUNNER_OS || os.platform()} / ${process.env.RUNNER_ARCH || os.arch()}`, '',
      '| Task / optimization | Result | Seconds |', '| --- | --- | ---: |',
      ...rows.map(row => `| ${row.task} | ${row.result} | ${row.seconds} |`), ''].join('\n');
    fs.appendFileSync(path.join(config.root, 'build/ci-results/results.md'), summary);
    if (summaryPath) fs.appendFileSync(summaryPath, summary);
  } catch (error) { errors.push(error); }
  finally {
    try { fs.rmSync(config.work, { recursive: true, force: true, maxRetries: 3, retryDelay: 100 }); }
    catch (error) { errors.push(error); }
  }
  if (errors.length === 1) throw errors[0];
  if (errors.length > 1) throw new AggregateError(errors, 'CI result collection and cleanup both failed');
}

export function modes(platform, debug) {
  if (debug === 'true') return ['Debug', 'ReleaseSafe'];
  return platform === 'win32' ? ['Debug', 'ReleaseSafe', 'ReleaseFast'] : ['Debug', 'ReleaseSafe', 'ReleaseFast', 'ReleaseSmall'];
}

export async function verifyShared(config, log) {
  const env = isolatedEnv(config);
  const win = process.platform === 'win32';
  const php = win ? path.join(env.PHP_BIN_DIR, 'php.exe') : 'php';
  if (win) {
    const pathKey = Object.keys(env).find(key => key.toUpperCase() === 'PATH');
    const previousPath = env[pathKey] || '';
    delete env[pathKey];
    env.PATH = env.PHP_BIN_DIR + path.delimiter + previousPath;
  }
  const capture = (exe, args) => {
    const invocation = `\n$ ${JSON.stringify([exe, ...args])}\n`;
    fs.appendFileSync(log, invocation);
    process.stdout.write(invocation);
    const result = spawnSync(exe, args, { env, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
    fs.appendFileSync(log, (result.stdout || '') + (result.stderr || ''));
    if (result.stdout) process.stdout.write(result.stdout);
    if (result.stderr) process.stderr.write(result.stderr);
    if (result.error) throw result.error;
    if (result.signal) throw new Error(`${exe} interrupted: ${result.signal}`);
    if (result.status !== 0) throw new Error(`${exe} exited with ${result.status}`);
    return result.stdout.trim();
  };
  const actual = JSON.parse(capture(php, ['-n', '-r', 'echo json_encode([PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION, (bool) PHP_ZTS, (bool) PHP_DEBUG, PHP_VERSION, PHP_BINARY, PHP_VERSION_ID]);']));
  if (actual[0] !== config.php || actual[1] !== (config.ts === 'ts') || actual[2] !== (config.debug === 'true')) {
    throw new Error(`PHP ABI mismatch: ${JSON.stringify(actual)}`);
  }
  env.TEST_PHP_EXECUTABLE = actual[4];
  // Check CGI only when installed; existing shared workflows permit CGI skips.
  const cgi = win ? path.join(env.PHP_BIN_DIR, 'php-cgi.exe') : path.join(path.dirname(actual[4]), 'php-cgi');
  if (fs.existsSync(cgi)) env.TEST_PHP_CGI_EXECUTABLE = cgi;
  const include = win ? env.PHP_INCLUDE_DIR : capture('php-config', ['--include-dir']);
  if (!win && capture('php-config', ['--version']) !== actual[3]) throw new Error('php-config/runtime version mismatch');
  fs.appendFileSync(log, `Runtime: ${JSON.stringify(actual)}\nHeaders: ${include}\n`);
  const headerVersion = fs.readFileSync(path.join(include, 'main/php_version.h'), 'utf8').match(/^#define\s+PHP_VERSION_ID\s+(\d+)\b/m)?.[1];
  if (!headerVersion || Number(headerVersion) !== actual[5]) {
    throw new Error(`PHP headers/runtime version mismatch: headers=${headerVersion || 'missing PHP_VERSION_ID'}, runtime=${actual[5]}`);
  }
  const args = [`-Dphp-include-dir=${include}`];
  if (win) {
    const library = path.join(env.PHP_LIB_DIR, config.ts === 'ts' ? 'php8ts.lib' : 'php8.lib');
    if (!fs.existsSync(library) || !fs.existsSync(env.LIBC_FILE)) throw new Error('Missing Windows SDK library/libc file');
    args.push('-Dtarget=native-native-msvc', `-Dlibc-file=${env.LIBC_FILE}`, `-Dphp-lib-dir=${env.PHP_LIB_DIR}`, `-Dwindows-zts=${config.ts === 'ts'}`);
  } else {
    const phpize = capture('phpize', ['--version']);
    const api = fs.readFileSync(path.join(include, 'main/php.h'), 'utf8').match(/^#define\s+PHP_API_VERSION\s+(\d+)/m)?.[1];
    const phpizeApi = phpize.match(/PHP\s+Api\s+Version:\s*(\d+)/i)?.[1];
    if (!api || phpizeApi !== api) throw new Error('phpize/headers API mismatch');
  }
  return { env, args, actual };
}

async function shared(config) {
  let verified;
  if (!await runTasks(config, [{ name: 'verify', run: async log => { verified = await verifyShared(config, log); } }])) return false;
  const { env, args, actual } = verified;
  const win = process.platform === 'win32';
  const run = (exe, argv, cwd, taskLog) => command(exe, argv, { cwd, env, log: taskLog });
  const tasks = [{ name: 'unit', run: taskLog => run('zig', ['build', 'test', ...args], config.repo, taskLog) }];
  for (const mode of modes(process.platform, config.debug)) {
    for (const example of examples) {
      tasks.push({ name: `${example}-${mode}`, run: taskLog => run('zig', ['build', 'run-tests', ...args, `-Doptimize=${mode}`], path.join(config.repo, 'examples', example), taskLog) });
    }
  }
  if (!win) tasks.push({ name: 'phpize', run: async taskLog => {
    // Preserve the example's ../../ phpz dependency without reusing Zig outputs.
    const fresh = path.join(config.work, 'phpize-repo');
    copyCheckout(config.root, fresh);
    const cwd = path.join(fresh, 'examples/skeleton');
    try {
      await run('phpize', [], cwd, taskLog);
      const phpConfig = execFileSync('sh', ['-c', 'command -v php-config'], { env, encoding: 'utf8' }).trim();
      await run('./configure', ['--enable-skeleton', `--with-php-config=${phpConfig}`], cwd, taskLog);
      await run('make', [], cwd, taskLog);
      await run('make', ['test', 'TESTS=tests'], cwd, taskLog);
    } finally { collectDiagnostics(fresh, path.join(config.logs, 'phpize')); }
  } });
  if (process.platform === 'linux') tasks.push({ name: 'cross-windows', run: taskLog => run('sh', ['scripts/test-windows.sh', '--php-version', actual[3], config.ts === 'ts' ? '--zts' : '--nts', '--xwin-cache-dir', path.join(os.homedir(), '.cache/xwin')], config.repo, taskLog) });
  return runTasks(config, tasks);
}

export function installBuiltinExtension(config, source) {
  const target = path.join(source, 'ext', config.extension);
  fs.rmSync(target, { recursive: true, force: true });
  fs.cpSync(path.join(config.repo, 'examples', config.extension), target, { recursive: true });
  const zon = path.join(target, 'build.zig.zon');
  const dependency = path.relative(target, config.repo).split(path.sep).join('/');
  const original = fs.readFileSync(zon, 'utf8');
  if (!original.includes('.path = "../.."')) throw new Error(`Unexpected phpz dependency in ${zon}`);
  fs.writeFileSync(zon, original.replace('.path = "../.."', `.path = ${JSON.stringify(dependency)}`));
}

async function builtin(config) {
  const env = isolatedEnv(config);
  const source = path.join(config.repo, 'build/php-src');
  const template = path.join(config.root, 'build/php-src');
  if (!await runTasks(config, [{ name: 'prepare-builtin', run: async () => {
    fs.mkdirSync(source, { recursive: true });
    // The template is pristine; exclude its Git database.
    fs.cpSync(template, source, { recursive: true, filter: entry => path.basename(entry) !== '.git' });
    installBuiltinExtension(config, source);
  } }])) return false;
  Object.assign(env, { PHP_BUILD_VERSION: config.php, PHP_BUILD_TS: config.ts, PHP_BUILD_DEBUG: config.debug === 'true' ? '1' : '0', PHP_BUILD_EXTENSION: config.extension, PHP_BUILD_SOURCE: source });
  const run = (exe, args, log) => command(exe, args, { cwd: source, env, log });
  return runTasks(config, [{ name: 'builtin', run: async log => {
    if (process.platform === 'win32') {
      await run('pwsh', ['-NoProfile', '-File', path.join(config.root, '.github/scripts/run-builtin-windows.ps1')], log);
    } else {
      await run('./buildconf', ['--force'], log);
      await run('./configure', ['--disable-all', '--disable-phpdbg', '--enable-cli', '--enable-cgi', `--enable-${config.extension}`, config.ts === 'ts' ? '--enable-zts' : '--disable-zts', config.debug === 'true' ? '--enable-debug' : '--disable-debug'], log);
      await run('make', [`-j${os.availableParallelism()}`], log);
      const php = path.join(source, 'sapi/cli/php');
      env.TEST_PHP_EXECUTABLE = php;
      env.TEST_PHP_CGI_EXECUTABLE = path.join(source, 'sapi/cgi/php-cgi');
      fs.accessSync(env.TEST_PHP_CGI_EXECUTABLE, fs.constants.X_OK);
      await run(php, ['-n', '-r', 'if (!extension_loaded(getenv("PHP_BUILD_EXTENSION")) || (bool) PHP_ZTS !== (getenv("PHP_BUILD_TS") === "ts") || (int) PHP_DEBUG !== (int) getenv("PHP_BUILD_DEBUG")) { exit(1); }'], log);
      await run(php, ['-n', '-i'], log);
      await run(php, ['-n', '--ri', config.extension], log);
      await run(php, ['-n', 'run-tests.php', '-n', '-q', `ext/${config.extension}/tests`], log);
    }
  } }]);
}

async function main() {
  const config = configuration();
  switch (process.argv[2]) {
    case 'prepare':
      prepare(config);
      if (process.env.GITHUB_OUTPUT) fs.appendFileSync(process.env.GITHUB_OUTPUT, `work=${config.work}\nlogs=${config.logs}\n`);
      break;
    case 'verify':
      if (!await runTasks(config, [{ name: 'verify', run: log => verifyShared(config, log) }])) process.exitCode = 1;
      break;
    case 'run':
      if (!await shared(config)) process.exitCode = 1;
      break;
    case 'finish':
      finish(config, process.env.CI_SETUP_OUTCOME, process.env.CI_TEST_OUTCOME);
      break;
    case 'builtin': {
      let success = false;
      try { prepare(config); success = await builtin(config); }
      finally { finish(config, 'success', success ? 'success' : 'failure'); }
      if (!success) process.exitCode = 1;
      break;
    }
    default: throw new Error('Expected prepare, verify, run, finish or builtin');
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  main().catch(error => { console.error(error); process.exitCode = 1; });
}
