import assert from 'node:assert/strict';
import test from 'node:test';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { execFileSync, spawn } from 'node:child_process';
import { configuration, copyCheckout, isolatedEnv, prepare, command, runTasks, finish, modes, installBuiltinExtension } from './ci.mjs';

function fixture(t) {
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'phpz ci test '));
  t.after(() => fs.rmSync(temp, { recursive: true, force: true }));
  const root = path.join(temp, 'checkout');
  fs.mkdirSync(root);
  execFileSync('git', ['init', '-q', root]);
  fs.writeFileSync(path.join(root, '.gitignore'), 'build/generated/\n.zig-cache/\n');
  fs.mkdirSync(path.join(root, 'examples/skeleton'), { recursive: true });
  fs.writeFileSync(path.join(root, 'examples/skeleton/build.zig.zon'), '.{ .dependencies = .{ .phpz = .{ .path = "../.." } } }');
  fs.writeFileSync(path.join(root, 'source.txt'), 'tracked');
  execFileSync('git', ['add', '.'], { cwd: root });
  const env = { RUNNER_TEMP: temp, CI_PHP: '8.5', CI_TS: 'nts', CI_DEBUG: 'false' };
  const config = configuration(env, root);
  return { temp, root, env, config };
}

test('configuration validates labels before constructing removable paths', t => {
  const { env, root } = fixture(t);
  for (const bad of [{ CI_PHP: '../..' }, { CI_TS: '../..' }, { CI_DEBUG: '1' }, { CI_EXTENSION: '../..' }]) {
    assert.throws(() => configuration({ ...env, ...bad }, root));
  }
  const first = configuration(env, root);
  const second = configuration({ ...env, CI_TS: 'ts' }, root);
  assert.notEqual(first.work, second.work);
});

test('source snapshots preserve working-tree edits and exclude generated trees', t => {
  const { root, config } = fixture(t);
  fs.writeFileSync(path.join(root, 'source.txt'), 'current edit');
  fs.mkdirSync(path.join(root, 'build/generated'), { recursive: true });
  fs.writeFileSync(path.join(root, 'build/generated/big.obj'), 'not source');
  copyCheckout(root, config.repo);
  assert.equal(fs.readFileSync(path.join(config.repo, 'source.txt'), 'utf8'), 'current edit');
  assert.equal(fs.existsSync(path.join(config.repo, 'build/generated')), false);
  assert.equal(fs.existsSync(path.join(config.repo, '.git')), false);
});

test('built-in dependency points at isolated phpz even with spaces and extra nesting', t => {
  const { config } = fixture(t);
  prepare(config);
  config.extension = 'skeleton';
  const source = path.join(config.repo, 'build/nested/php source');
  installBuiltinExtension(config, source);
  const target = path.join(source, 'ext/skeleton');
  const zon = fs.readFileSync(path.join(target, 'build.zig.zon'), 'utf8');
  const dependency = JSON.parse(zon.match(/\.path = ("[^"]+")/)[1]);
  assert.equal(path.resolve(target, dependency), config.repo);
});

test('a failed command keeps its full log, runs later tasks and reports failure', async t => {
  const { config } = fixture(t);
  prepare(config);
  const marker = path.join(config.repo, 'second ran.txt');
  const tasks = [
    { name: 'fails', run: log => command(process.execPath, ['-e', 'console.log("first diagnostic"); process.exit(7)'], { cwd: config.repo, env: process.env, log }) },
    { name: 'continues', run: log => command(process.execPath, ['-e', 'require("fs").writeFileSync(process.argv[1], "ran")', marker], { cwd: config.repo, env: process.env, log }) },
  ];
  assert.equal(await runTasks(config, tasks), false);
  assert.equal(fs.readFileSync(marker, 'utf8'), 'ran');
  assert.match(fs.readFileSync(path.join(config.logs, 'fails.log'), 'utf8'), /first diagnostic/);
  assert.deepEqual(JSON.parse(fs.readFileSync(path.join(config.logs, 'results.json'))).map(row => row.result), ['FAIL', 'PASS']);
  finish(config, 'success', 'failure', null);
  assert.equal(fs.existsSync(config.work), false);
  assert.equal(fs.existsSync(path.join(config.logs, 'fails.log')), true);
});

test('missing executable cannot turn a task green', async t => {
  const { config } = fixture(t);
  prepare(config);
  assert.equal(await runTasks(config, [{ name: 'missing', run: log => command(path.join(config.work, 'no-such-command'), [], { cwd: config.repo, env: process.env, log }) }]), false);
});

test('command and both output streams are visible before exit and retained once', async t => {
  const { config } = fixture(t);
  prepare(config);
  const gate = path.join(config.work, 'release-child');
  const log = path.join(config.logs, 'stream.log');
  const ciUrl = pathToFileURL(path.resolve(import.meta.dirname, 'ci.mjs')).href;
  const childSource = `
    console.log('LIVE_STDOUT_MARKER');
    console.error('LIVE_STDERR_MARKER');
    const fs = require('fs');
    const timer = setInterval(() => { if (fs.existsSync(process.argv[1])) { clearInterval(timer); process.exit(7); } }, 10);
    setTimeout(() => process.exit(9), 5000).unref();
  `;
  const controller = `
    import { command, runTasks } from ${JSON.stringify(ciUrl)};
    const config = ${JSON.stringify(config)};
    const passed = await runTasks(config, [{name: 'stream', run: log => command(process.execPath,
      ['-e', ${JSON.stringify(childSource)}, ${JSON.stringify(gate)}],
      {cwd: config.repo, env: process.env, log})}]);
    process.exitCode = passed ? 0 : 1;
  `;
  const child = spawn(process.execPath, ['--input-type=module', '-e', controller], { stdio: ['ignore', 'pipe', 'pipe'] });
  let stdout = '';
  let stderr = '';
  let released = false;
  const release = () => {
    // Match actual output lines, not the source text in the printed command.
    if (/(?:^|\n)LIVE_STDOUT_MARKER\r?\n/.test(stdout) && /(?:^|\n)LIVE_STDERR_MARKER\r?\n/.test(stderr)) {
      fs.writeFileSync(gate, 'release');
      released = true;
    }
  };
  child.stdout.on('data', chunk => { stdout += chunk; release(); });
  child.stderr.on('data', chunk => { stderr += chunk; release(); });
  const code = await new Promise((resolve, reject) => { child.once('error', reject); child.once('close', resolve); });
  assert.equal(released, true, 'output must arrive while the command is still running');
  assert.equal(code, 1, 'task failure must reach the controller exit code');
  assert.match(stdout, /\$ \[/);
  assert.equal((stdout.match(/^LIVE_STDOUT_MARKER\r?$/gm) || []).length, 1);
  assert.equal((stderr.match(/^LIVE_STDERR_MARKER\r?$/gm) || []).length, 1);
  const saved = fs.readFileSync(log, 'utf8');
  assert.equal((saved.match(/^LIVE_STDOUT_MARKER\r?$/gm) || []).length, 1);
  assert.equal((saved.match(/^LIVE_STDERR_MARKER\r?$/gm) || []).length, 1);
  assert.match(saved, /exited with 7/);
});

test('Windows native cmd output works through the command logger', { skip: process.platform !== 'win32' }, async t => {
  const { config } = fixture(t);
  prepare(config);
  const log = path.join(config.logs, 'cmd.log');
  await command(process.env.ComSpec || 'cmd.exe', ['/d', '/c', 'echo PHPZ_CMD_STDOUT & echo PHPZ_CMD_STDERR 1>&2'], {cwd: config.repo, env: process.env, log});
  const saved = fs.readFileSync(log, 'utf8');
  assert.match(saved, /^PHPZ_CMD_STDOUT\s*$/m);
  assert.match(saved, /^PHPZ_CMD_STDERR\s*$/m);
});

test('failed setup is recorded, logs retained and only its own work is removed', t => {
  const { config, root, env } = fixture(t);
  prepare(config);
  const sibling = configuration({ ...env, CI_TS: 'ts' }, root);
  prepare(sibling);
  fs.writeFileSync(path.join(config.logs, 'setup.log'), 'installation failed');
  finish(config, 'failure', 'skipped', null);
  assert.match(fs.readFileSync(path.join(root, 'build/ci-results/results.md'), 'utf8'), /setup \| FAILURE/);
  assert.equal(fs.existsSync(config.work), false);
  assert.equal(fs.existsSync(sibling.repo), true);
  assert.equal(fs.readFileSync(path.join(config.logs, 'setup.log'), 'utf8'), 'installation failed');
});

test('summary write failure still cleans work and preserves collected logs', t => {
  const { config, temp } = fixture(t);
  prepare(config);
  fs.writeFileSync(path.join(config.repo, 'config.log'), 'build evidence');
  // A directory cannot be used as a summary file on any supported platform.
  assert.throws(() => finish(config, 'success', 'success', temp));
  assert.equal(fs.existsSync(config.work), false);
  assert.equal(fs.readFileSync(path.join(config.logs, 'diagnostics/config.log'), 'utf8'), 'build evidence');
});

test('diagnostic copy failure still cleans only the current variant', t => {
  const { config, env, root } = fixture(t);
  prepare(config);
  const sibling = configuration({ ...env, CI_TS: 'ts' }, root);
  prepare(sibling);
  fs.writeFileSync(path.join(config.repo, 'config.log'), 'build evidence');
  fs.writeFileSync(path.join(config.logs, 'diagnostics'), 'blocks directory creation');
  assert.throws(() => finish(config, 'success', 'success', null));
  assert.equal(fs.existsSync(config.work), false);
  assert.equal(fs.existsSync(sibling.repo), true);
  assert.equal(fs.existsSync(config.logs), true);
});

test('cleanup errors do not hide the original collection error', t => {
  const { config } = fixture(t);
  prepare(config);
  fs.writeFileSync(path.join(config.logs, 'results.json'), 'invalid json');
  const cleanupError = new Error('cleanup failed');
  const originalRm = fs.rmSync;
  const mockedRm = t.mock.method(fs, 'rmSync', (target, options) => {
    if (target === config.work) throw cleanupError;
    return originalRm(target, options);
  });
  try {
    assert.throws(() => finish(config, 'success', 'success', null), error => {
      assert.ok(error instanceof AggregateError);
      assert.ok(error.errors[0] instanceof SyntaxError);
      assert.equal(error.errors[1], cleanupError);
      return true;
    });
  } finally { mockedRm.mock.restore(); }
});

test('cancellation stops descendants before returning and skips subsequent tasks', t => {
  const { config, temp } = fixture(t);
  prepare(config);
  const ciUrl = pathToFileURL(path.resolve(import.meta.dirname, 'ci.mjs')).href;
  // Isolate process signals and the module's cancelled flag from this test runner.
  const controller = `
    import assert from 'node:assert/strict';
    import fs from 'node:fs';
    import path from 'node:path';
    import { spawnSync } from 'node:child_process';
    import { command, runTasks } from ${JSON.stringify(ciUrl)};
    const config = ${JSON.stringify(config)};
    const ready = path.join(config.work, 'ready');
    const heartbeat = path.join(config.work, 'heartbeat');
    const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
    const grandchild = \`
      const fs = require('fs');
      process.on('SIGTERM', () => {});
      let count = 0;
      fs.writeFileSync(process.argv[1], String(count));
      fs.writeFileSync(process.argv[2], String(process.pid));
      setInterval(() => fs.writeFileSync(process.argv[1], String(++count)), 20);
    \`;
    const parent = \`
      require('child_process').spawn(process.execPath, ['-e', process.argv[1], process.argv[2], process.argv[3]], {stdio: 'inherit'});
      setInterval(() => {}, 1000);
    \`;
    let laterRan = false;
    const result = runTasks(config, [
      {name: 'cancel', run: log => command(process.execPath, ['-e', parent, grandchild, heartbeat, ready], {cwd: config.repo, env: process.env, log})},
      {name: 'later', run: async () => { laterRan = true; }},
    ]);
    try {
      const deadline = Date.now() + 5000;
      while (!fs.existsSync(ready) && Date.now() < deadline) await sleep(10);
      assert.ok(fs.existsSync(ready), 'descendant must be running before cancellation');
      // emit also works on Windows, where process.kill(SIGTERM) is uncatchable.
      process.emit('SIGTERM');
      process.emit('SIGINT');
      assert.equal(await result, false);
      const count = fs.readFileSync(heartbeat, 'utf8');
      await sleep(200);
      assert.equal(fs.readFileSync(heartbeat, 'utf8'), count, 'descendant still writes after command returned');
      assert.equal(laterRan, false);
      await assert.rejects(command(process.execPath, ['-e', 'process.exit(0)'], {cwd: config.repo, env: process.env, log: path.join(config.logs, 'new.log')}), /cancelled/);
    } finally {
      // Avoid leaving a writer behind even when this regression test fails.
      if (fs.existsSync(ready)) {
        const pid = Number(fs.readFileSync(ready, 'utf8'));
        if (process.platform === 'win32') spawnSync('taskkill.exe', ['/PID', String(pid), '/T', '/F'], {stdio: 'ignore'});
        else { try { process.kill(pid, 'SIGKILL'); } catch (error) { if (error.code !== 'ESRCH') throw error; } }
      }
    }
  `;
  execFileSync(process.execPath, ['--input-type=module', '-e', controller], { cwd: temp, timeout: 15000, stdio: 'pipe' });
});

test('old test interpreter and local caches never leak into a new ABI', t => {
  const { config } = fixture(t);
  const env = isolatedEnv(config, { PHPRC: 'old.ini', PHP_INI_SCAN_DIR: 'old', TEST_PHP_EXECUTABLE: 'old/php', TEST_PHP_CGI_EXECUTABLE: 'old/cgi', PHP_BUILD_TS: 'ts', ZIG_LOCAL_CACHE_DIR: 'old/cache', ZIG_LOCAL_PKG_DIR: 'old/pkg', ZIG_LIBC: 'old/libc.txt', ZIG_GLOBAL_CACHE_DIR: 'shared/hash-cache', PATH: 'tools' });
  for (const name of ['PHPRC', 'PHP_INI_SCAN_DIR', 'TEST_PHP_EXECUTABLE', 'TEST_PHP_CGI_EXECUTABLE', 'PHP_BUILD_TS', 'ZIG_LOCAL_CACHE_DIR', 'ZIG_LOCAL_PKG_DIR', 'ZIG_LIBC']) assert.equal(env[name], undefined);
  assert.equal(env.ZIG_GLOBAL_CACHE_DIR, 'shared/hash-cache');
  assert.equal(env.TMPDIR, path.join(config.work, 'tmp'));
});

test('optimization coverage preserves PHP debug restrictions and Windows modes', () => {
  assert.deepEqual(modes('linux', 'false'), ['Debug', 'ReleaseSafe', 'ReleaseFast', 'ReleaseSmall']);
  assert.deepEqual(modes('darwin', 'false'), ['Debug', 'ReleaseSafe', 'ReleaseFast', 'ReleaseSmall']);
  assert.deepEqual(modes('darwin', 'true'), ['Debug', 'ReleaseSafe']);
  assert.deepEqual(modes('win32', 'false'), ['Debug', 'ReleaseSafe', 'ReleaseFast']);
});
