// Fresh-run generator. Build artifacts may be cached; generated expectations may not.
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { mkdir, readFile, readdir, writeFile, copyFile, lstat } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import path from 'node:path';
import { strictSha } from './strict-hash.mjs';
import { readNoteDifferences } from './note-differences.mjs';
import { fixtureRoot, lock, lockSha, strictLock, strictLockSha, noteNames, readInputs, readNotes, sha, valueSha, validateRawNotes } from './contract.mjs';

export async function validateBuild(build, emulator) {
  const identity = JSON.parse(await readFile(path.join(build, 'identity.json')));
  assert.deepEqual(identity, lock.build, 'oracle build identity');
  const binary = path.join(build, 'xlsx-oracle.test');
  assert.equal(sha(await readFile(binary)), lock.build.binarySha256, 'oracle binary integrity');
  const found = [];
  for (const name of await readdir(fixtureRoot)) {
    if (/^generate.*\.go$/.test(name) && /^package xlsx\s*$/m.test(await readFile(path.join(fixtureRoot, name), 'utf8'))) found.push(name);
  }
  assert.deepEqual(found.sort(), Object.keys(lock.build.adapters).sort(), 'adapter inventory');
  for (const [name, digest] of Object.entries(lock.build.adapters)) {
    if (path.basename(name) !== name) throw Error('Invalid adapter name');
    assert.equal(sha(await readFile(path.join(fixtureRoot, name))), digest, `adapter ${name}`);
  }
  for (const [name, digest] of Object.entries(lock.build.seeds)) {
    if (!name.startsWith('runtime/') || name.split('/').includes('..')) throw Error('Invalid build seed name');
    assert.equal(sha(await readFile(path.join(build, name))), digest, `build seed ${name}`);
  }
  if (emulator) assert.equal(sha(await readFile(emulator)), lock.emulatorSha256, 'emulator integrity');
  else if (process.platform !== 'linux' || process.arch !== 'arm64') throw Error('Pinned Linux ARM64 oracle requires native ARM64 or the approved QEMU executable');
  return binary;
}

export async function validateGenerated(output) {
  const dir = path.join(output, 'compat/xlsx'), notes = await readNotes();
  const expected = [...Object.keys(lock.fixtures), ...Object.keys(lock.extras)].sort();
  const allowedDirs = new Set(expected.map(name => path.dirname(name)).filter(name => name !== '.'));
  const names = [];
  for (const name of await readdir(dir, { recursive: true })) {
    const entry = await lstat(path.join(dir, name));
    if (entry.isDirectory()) { if (!allowedDirs.has(name)) throw Error(`Unexpected generated directory: ${name}`); }
    else if (entry.isFile()) names.push(name);
    else throw Error(`Invalid generated entry: ${name}`);
  }
  assert.deepEqual(names.sort(), expected, 'generated inventory');
  const files = {};
  for (const name of names) {
    const bytes = await readFile(path.join(dir, name)), value = JSON.parse(bytes);
    files[name] = sha(bytes);
    if (noteNames.has(name)) {
      await validateRawNotes(name, value, notes);
    } else if (Object.hasOwn(lock.fixtures, name)) {
      assert.equal(valueSha(value), lock.fixtures[name].sha256, `generated fixture ${name}`);
      assert.equal(strictSha(value), strictLock.fixtures[name], `strict generated fixture ${name}`);
    } else {
      assert.equal(valueSha(value), lock.extras[name], `sideproduct ${name}`);
      assert.equal(strictSha(value), strictLock.extras[name], `strict sideproduct ${name}`);
      if (name !== 'percent-links-unsupported.json') assert.deepEqual(value, []);
    }
  }
  const links = JSON.parse(await readFile(path.join(dir, 'links-unsupported.json')));
  const extraLinks = JSON.parse(await readFile(path.join(dir, 'percent-links-unsupported.json')));
  assert.deepEqual(extraLinks, links, 'percent-link sideproduct correspondence');
  return files;
}

export async function generate(build, output, emulator) {
  const binary = await validateBuild(build, emulator);
  const inputs = await readInputs(); await readNotes();
  await mkdir(output); // Must be fresh; failure leaves evidence and never falls back.
  await mkdir(path.join(output, 'compat/xlsx'), { recursive: true });
  await mkdir(path.join(output, 'seed/compat/xlsx'), { recursive: true });
  for (const [name, digest] of Object.entries(lock.seedHashes)) {
    assert.equal(valueSha(inputs[name]), digest, `seed ${name}`);
    await writeFile(path.join(output, 'seed/compat/xlsx', name), JSON.stringify(inputs[name]), { flag: 'wx' });
  }
  await copyFile(path.join(output, 'seed/compat/xlsx/formula-previously-unsupported-inputs.json'), path.join(output, 'compat/xlsx/formula-previously-unsupported-inputs.json'));
  async function run(selected) {
    if (!selected.length || selected.some(name => !/^Test\w+$/.test(name))) throw Error('Invalid test inventory');
    const args = ['-test.run', `^(${selected.join('|')})$`, '-test.count=1', '-test.timeout=20m'];
    const command = emulator || binary; if (emulator) args.unshift(binary);
    const status = await new Promise((resolve, reject) => {
      const child = spawn(command, args, { cwd: path.join(build, 'runtime/xlsx'), stdio: 'inherit', env: { ...process.env, GOMAXPROCS: '2', GODEBUG: '', TZ: 'UTC', LC_ALL: 'C', BDF_FIXTURE_ROOT: output, BDF_SOURCE_ROOT: path.join(output, 'seed') } });
      child.once('error', reject); child.once('close', resolve);
    });
    if (status !== 0) throw Error(`Oracle failed (${status}); output retained: ${output}`);
  }
  await run(lock.tests.filter(name => name !== 'TestCodexXLSXStoreSheet'));
  await run(['TestCodexXLSXStoreSheet']);
  for (const entry of lock.retained) {
    if (path.basename(entry.file) !== entry.file) throw Error('Invalid retained input name');
    assert.equal(valueSha(inputs[entry.file]), entry.sha256);
    await writeFile(path.join(output, 'compat/xlsx', entry.file), JSON.stringify(inputs[entry.file]), { flag: 'wx' });
  }
  const files = await validateGenerated(output);
  const noteReport = await readNoteDifferences(output);
  const receipt = { version: 1, lockSha, strictLockSha, runId: randomUUID(), binarySha256: lock.build.binarySha256,
    emulatorSha256: emulator ? lock.emulatorSha256 : null, generatedAt: new Date().toISOString(), files, noteReport };
  await writeFile(path.join(output, 'receipt.json'), JSON.stringify(receipt, null, 2) + '\n', { flag: 'wx' });
  console.log(`Raw notes BDF differences: ${noteReport.differences.length}/${noteReport.compared} (unclassified; fixed static expectations selected)`);
  return receipt;
}

if (process.argv[1] && path.resolve(process.argv[1]) === new URL(import.meta.url).pathname) {
  const { values } = parseArgs({ options: { build: { type: 'string' }, output: { type: 'string' }, emulator: { type: 'string' } } });
  if (!values.build || !values.output) throw Error('--build <build> --output <new-output> [--emulator <approved-qemu>] required');
  const result = await generate(path.resolve(values.build), path.resolve(values.output), values.emulator ? path.resolve(values.emulator) : null);
  console.log(`Generated fresh XLSX oracle run ${result.runId} in ${values.output}`);
}
