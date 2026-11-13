// Fail-closed coverage for the split oracle; no upstream binary is executed.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile, copyFile, symlink } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { fixtureName, lock, lockBytes, lockSha, strictLockSha, readInputs, readNotes, sha, validateRawNotes } from './contract.mjs';
import { generate, validateGenerated } from './generate.mjs';
import { strictSha } from './strict-hash.mjs';
import { validateRenderIds } from './render-inventory.mjs';
import { compareVerifierNames, validateVerifiers } from './verifier-inventory.mjs';
import { noteDifferences } from './note-differences.mjs';

const temp = await mkdtemp(path.join(tmpdir(), 'xlsx-split-test-'));
try {
  assert.notEqual(strictSha(-0), strictSha(0), 'signed zero must differ');
  assert.notEqual(strictSha([1, 2]), strictSha([2, 1]), 'array order must differ');
  assert.equal(strictSha({ a: 1, b: 2 }), strictSha({ b: 2, a: 1 }), 'object key order is immaterial');
  let signedZeroMutation;
  if (process.env.BDF_XLSX_FIXTURE_ROOT) {
    const original = JSON.parse(await readFile(path.join(process.env.BDF_XLSX_FIXTURE_ROOT, 'compat/xlsx/color.json')));
    assert.ok(Object.is(original[2445].want[0], -0), 'real signed-zero regression case');
    const changed = structuredClone(original); changed[2445].want[0] = 0;
    assert.equal(JSON.stringify(changed), JSON.stringify(original), 'ordinary JSON hashing cannot detect this change');
    assert.notEqual(strictSha(changed), strictSha(original), 'typed hash detects real signed-zero change');
    function stringify(value) {
      if (typeof value === 'number' && Object.is(value, -0)) return '-0';
      if (Array.isArray(value)) return '[' + value.map(stringify).join(',') + ']';
      if (value && typeof value === 'object') return '{' + Object.entries(value).map(([k, v]) => JSON.stringify(k) + ':' + stringify(v)).join(',') + '}';
      return JSON.stringify(value);
    }
    signedZeroMutation = stringify(changed);
    assert.deepEqual(JSON.parse(signedZeroMutation), changed);
  }
  assert.throws(() => validateRenderIds('tampered\n'), /render ID count/);
  compareVerifierNames(['a', 'b'], ['b', 'a']);
  assert.throws(() => compareVerifierNames(['a', 'b'], ['a']), /verifier inventory/);
  await validateVerifiers();
  const inputs = await readInputs(), notes = await readNotes();
  assert.equal(Object.values(notes).reduce((n, v) => n + v.length, 0), 264);
  assert.deepEqual(noteDifferences(notes, notes), { compared: 264, differences: [] });
  const changedNotes = structuredClone(notes), noteFile = 'sheet-multiple-notes.json';
  changedNotes[noteFile][0].bdf = changedNotes[noteFile][1].bdf;
  const report = noteDifferences(notes, changedNotes);
  assert.equal(report.differences.length, 1);
  assert.equal(report.differences[0].id, `${noteFile}#0`);
  assert.notEqual(report.differences[0].staticBdfSha256, report.differences[0].rawBdfSha256);
  assert.equal(fixtureName('./render/index.json'), 'render/index.json');
  assert.equal(fixtureName(new URL('../render/index.json', import.meta.url)), 'render/index.json');
  assert.throws(() => fixtureName('../../outside.json'), /Unknown XLSX fixture/);
  assert.throws(() => fixtureName('./not-in-the-inventory.json'), /Unknown XLSX fixture/);
  assert.throws(() => fixtureName(new URL('https://example.com/a.json')), /Invalid XLSX fixture/);

  // Corrupt bundled bytes must fail before any test can use them.
  const assets = path.join(temp, 'assets'); await mkdir(assets);
  for (const name of ['contract.mjs', 'strict-hash.mjs', 'lock.manifest', 'strict-lock.manifest', 'inputs.data', 'notes.data']) await copyFile(new URL('./' + name, import.meta.url), path.join(assets, name));
  await symlink(path.resolve('node_modules'), path.join(temp, 'node_modules'));
  const notesData = await readFile(path.join(assets, 'notes.data')); notesData[20] ^= 1; await writeFile(path.join(assets, 'notes.data'), notesData);
  const corrupt = await import(pathToFileURL(path.join(assets, 'contract.mjs')));
  await assert.rejects(corrupt.readNotes(), /notes bundle integrity failure/);

  // A forged build receipt paired with different binary must fail before output exists.
  const build = path.join(temp, 'build'), output = path.join(temp, 'never-created'); await mkdir(build);
  await writeFile(path.join(build, 'identity.json'), JSON.stringify(lock.build)); await writeFile(path.join(build, 'xlsx-oracle.test'), 'wrong binary');
  await assert.rejects(generate(build, output, null), /oracle binary integrity/);
  await assert.rejects(readFile(output), { code: 'ENOENT' });

  // Missing/extra outputs fail before fixture content is considered.
  const inventoryRoot = path.join(temp, 'inventory'); await mkdir(path.join(inventoryRoot, 'compat/xlsx'), { recursive: true });
  await assert.rejects(validateGenerated(inventoryRoot), /generated inventory/);
  await writeFile(path.join(inventoryRoot, 'compat/xlsx/unexpected.json'), '[]');
  await assert.rejects(validateGenerated(inventoryRoot), /generated inventory/);
  await rm(path.join(inventoryRoot, 'compat/xlsx/unexpected.json'));
  await mkdir(path.join(inventoryRoot, 'compat/xlsx/unexpected-dir'));
  await assert.rejects(validateGenerated(inventoryRoot), /Unexpected generated directory/);
  await rm(path.join(inventoryRoot, 'compat/xlsx/unexpected-dir'), { recursive: true });
  await symlink('/dev/null', path.join(inventoryRoot, 'compat/xlsx/unexpected.json'));
  await assert.rejects(validateGenerated(inventoryRoot), /Invalid generated entry/);

  // A selected run is isolated from checkout fallbacks; corrupt, missing,
  // baseline-different or wrong-run data must fail. Exercise the public loader.
  const root = path.join(temp, 'run'), dir = path.join(root, 'compat/xlsx'); await mkdir(dir, { recursive: true });
  const name = lock.retained[0].file, data = Buffer.from(JSON.stringify(inputs[name]));
  const files = Object.fromEntries([...Object.keys(lock.fixtures), ...Object.keys(lock.extras)].map(n => [n, '0'.repeat(64)]));
  files[name] = sha(data);
  const noteName = 'sheet-multiple-notes.json', noteRaw = Buffer.from(JSON.stringify(notes[noteName]));
  files[noteName] = sha(noteRaw);
  const receipt = { version: 1, lockSha, strictLockSha, runId: 'test-run', binarySha256: lock.build.binarySha256, files };
  const saveReceipt = () => writeFile(path.join(root, 'receipt.json'), JSON.stringify(receipt));
  await saveReceipt(); await writeFile(path.join(dir, name), data); await writeFile(path.join(dir, noteName), noteRaw);
  const fixtures = new URL('../fixtures.mjs', import.meta.url).href;
  const child = (target, runId = 'test-run', receiptHash = sha(JSON.stringify(receipt))) => spawnSync(process.execPath, ['--input-type=module', '-e', `import {loadFixture} from ${JSON.stringify(fixtures)}; await loadFixture(${JSON.stringify(target)});`], { env: { ...process.env, BDF_XLSX_FIXTURE_ROOT: root, BDF_XLSX_RUN_ID: runId, BDF_XLSX_RECEIPT_SHA: receiptHash }, encoding: 'utf8' });
  assert.equal(child('./' + name).status, 0);
  if (signedZeroMutation) {
    await writeFile(path.join(dir, 'color.json'), signedZeroMutation);
    receipt.files['color.json'] = sha(signedZeroMutation); await saveReceipt();
    const rejected = child('./color.json');
    assert.notEqual(rejected.status, 0, 'real -0 to +0 change must fail even with updated receipt');
    assert.match(rejected.stderr, /XLSX strict fixture color\.json/);
  }
  assert.notEqual(child('./' + name, 'test-run', '0'.repeat(64)).status, 0, 'wrong receipt hash must fail');
  assert.equal(child('./sheet-multiple-notes.json').status, 0);
  await rm(path.join(dir, noteName));
  assert.notEqual(child('./sheet-multiple-notes.json').status, 0, 'missing raw notes must fail');
  await writeFile(path.join(dir, noteName), '[]');
  assert.notEqual(child('./sheet-multiple-notes.json').status, 0, 'corrupt raw notes must fail');
  receipt.files[noteName] = sha('[]'); await saveReceipt();
  assert.notEqual(child('./sheet-multiple-notes.json').status, 0, 'wrong notes count with updated receipt must fail');
  const invalid = structuredClone(notes[noteName]); invalid[0].bdf = 'not base64';
  const invalidBytes = JSON.stringify(invalid); await writeFile(path.join(dir, noteName), invalidBytes);
  receipt.files[noteName] = sha(invalidBytes); await saveReceipt();
  assert.notEqual(child('./sheet-multiple-notes.json').status, 0, 'invalid BDF with updated receipt must fail');
  const damaged = structuredClone(notes[noteName]), bdfBytes = Buffer.from(damaged[0].bdf, 'base64');
  bdfBytes[bdfBytes.length - 1] ^= 1; damaged[0].bdf = bdfBytes.toString('base64');
  await assert.rejects(validateRawNotes(noteName, damaged, notes), /hash|decode|format|truncat|invalid|Unexpected/i);
  assert.notEqual(child('./' + name, 'wrong-run').status, 0);
  await rm(path.join(dir, name)); assert.notEqual(child('./' + name).status, 0, 'missing output must not fall back');
  await writeFile(path.join(dir, name), '[]'); assert.notEqual(child('./' + name).status, 0, 'corrupt output must fail');
  receipt.files[name] = sha('[]'); await saveReceipt(); assert.notEqual(child('./' + name).status, 0, 'different output with updated receipt must fail baseline');
  delete receipt.files[name]; await saveReceipt(); assert.notEqual(child('./' + name).status, 0, 'missing receipt entry must fail');
  console.log('XLSX split identity, bundles, inventory, path, missing and corruption checks PASS');
} finally { await rm(temp, { recursive: true, force: true }); }
