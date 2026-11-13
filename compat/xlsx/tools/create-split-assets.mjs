// One-time migration audit: compare against the still-present original corpus.
// Writes new assets only to a fresh output directory; never changes fixtures.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import { gzipSync, gunzipSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { loadFixture } from '../fixtures.mjs';
import { validateRetained } from './retained-inputs.mjs';

const { values } = parseArgs({ options: { generated: { type: 'string' }, build: { type: 'string' }, output: { type: 'string' } } });
if (!values.generated || !values.build || !values.output) throw Error('--generated <completed-run> --build <pinned-build> --output <new-dir> required');
if (process.env.BDF_XLSX_FIXTURE_ROOT || process.env.BDF_XLSX_RUN_ID || process.env.BDF_XLSX_RECEIPT_SHA) throw Error('Asset creation requires the independent original corpus');
const generated = path.resolve(values.generated), build = path.resolve(values.build), out = path.resolve(values.output);
const sha = x => createHash('sha256').update(x).digest('hex');
const digest = value => sha(JSON.stringify(value));
const buildId = JSON.parse(await readFile(path.join(build, 'identity.json')));
const runId = JSON.parse(await readFile(path.join(generated, 'identity.json')));
if (buildId.version !== 1 || buildId.upstream !== 'a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22' || buildId.go !== 'go1.27.0' || buildId.goos !== 'linux' || buildId.goarch !== 'arm64' || buildId.goarm64 !== 'v8.0' || buildId.binarySha256 !== '6425c89b0af6753bfc03735695f655e7d4d11c7fcaab33b325049fe2b6fc7035') throw Error('Unexpected pinned build');
for (const [key, val] of Object.entries(buildId)) assert.deepEqual(runId[key], val, `receipt ${key}`);
assert.equal(sha(await readFile(path.join(build, 'xlsx-oracle.test'))), buildId.binarySha256);
assert.equal(runId.tests.length, 724);
const noteManifest = JSON.parse(await readFile(new URL('./notes-static-proposal.manifest', import.meta.url)));
const noteMap = new Map(noteManifest.files.map(x => [x.file, x]));
assert.deepEqual([...noteMap.keys()].sort(), ['sheet-multiple-notes-filter.json', 'sheet-multiple-notes-legacy.json', 'sheet-multiple-notes.json']);
const fixtureDir = fileURLToPath(new URL('../', import.meta.url));
const files = (await readdir(fixtureDir, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
assert.equal(files.length, 804);
const actualFiles = (await readdir(path.join(generated, 'compat/xlsx'), { recursive: true })).filter(f => f.endsWith('.json')).sort();
const expectedExtras = ['percent-links-unsupported.json', 'rich-run-data-unsupported.json', 'rich-run-wrap-unsupported.json', 'sheet-multiple-notes-filter-unsupported.json', 'sheet-multiple-notes-unsupported.json', 'sheet-notes-filter-unsupported.json'];
assert.deepEqual(actualFiles.filter(f => !files.includes(f)), expectedExtras);
const fixtures = {}, notes = {}, noteCases = {};
for (const file of files) {
  const old = await loadFixture('./' + file);
  const fresh = JSON.parse(await readFile(path.join(generated, 'compat/xlsx', file)));
  fixtures[file] = { sha256: digest(old), count: Array.isArray(old) ? old.length : null };
  if (noteMap.has(file)) {
    const entry = noteMap.get(file);
    assert.equal(digest(old), entry.sha256, file); assert.equal(old.length, entry.cases); assert.equal(old.length, fresh.length);
    for (let i = 0; i < old.length; i++) {
      const { bdf: a, ...aa } = old[i], { bdf: b, ...bb } = fresh[i];
      assert.equal(typeof a, 'string'); assert.equal(typeof b, 'string'); assert.deepEqual(aa, bb, `${file} input ${i}`);
      noteCases[`${file}#${i}`] = digest(old[i]);
    }
    notes[file] = old;
  } else {
    assert.ok(isDeepStrictEqual(old, fresh), `historical mismatch: ${file}`);
    // Runtime integrity uses canonical serialization as well as value equality.
    assert.equal(digest(old), digest(fresh), `canonical order differs: ${file}`);
  }
}
assert.equal(Object.keys(noteCases).length, 264);
const extras = {};
for (const file of expectedExtras) {
  const value = JSON.parse(await readFile(path.join(generated, 'compat/xlsx', file)));
  if (file === 'percent-links-unsupported.json') assert.deepEqual(value, await loadFixture('./links-unsupported.json'));
  else assert.deepEqual(value, []);
  extras[file] = digest(value);
}
const retained = JSON.parse(await readFile(new URL('./retained-inputs.manifest', import.meta.url)));
const seedNames = [];
for (const [name, hash] of Object.entries(runId.inputSeeds)) {
  assert.match(name, /^[A-Za-z0-9_-]+\.json$/);
  const value = await loadFixture('./' + name); assert.equal(digest(value), hash, name);
  const entries = Array.isArray(value) ? value : [value];
  if (entries.some(x => x && typeof x === 'object' && !Array.isArray(x) && typeof x.bdf === 'string')) continue;
  assert.ok(entries.every(x => typeof x === 'string' || x && typeof x === 'object' && !Array.isArray(x) && typeof x.input === 'string' && Object.keys(x).every(k => ['input','label','mode','no_index','variant'].includes(k))), name);
  seedNames.push(name);
}
assert.equal(seedNames.length, 44);
const inputs = {};
for (const name of [...new Set([...seedNames, ...retained.map(x => x.file)])].sort()) inputs[name] = await loadFixture('./' + name);
for (const entry of retained) validateRetained(entry, inputs[entry.file]);
const seedHashes = Object.fromEntries(seedNames.sort().map(name => [name, digest(inputs[name])]));
const inputBytes = gzipSync(Buffer.from(JSON.stringify(inputs))), noteBytes = gzipSync(Buffer.from(JSON.stringify(notes)));
assert.deepEqual(JSON.parse(gunzipSync(inputBytes)), inputs, 'input bundle round trip');
assert.deepEqual(JSON.parse(gunzipSync(noteBytes)), notes, 'notes bundle round trip');
const lock = { version: 1, baseline: 'ab0b102ced2ef6e43bdb00590daff83d0f316986', build: buildId,
  emulatorSha256: '0338d0ed6013abe5e0f41c5a22976ac6fe2f1b5869edf05d4a9098c121248f02', tests: runId.tests,
  fixtures, extras, noteCases, seedHashes, retained, inputBundleSha256: sha(inputBytes), noteBundleSha256: sha(noteBytes) };
await mkdir(out); await writeFile(path.join(out, 'inputs.data'), inputBytes); await writeFile(path.join(out, 'notes.data'), noteBytes); await writeFile(path.join(out, 'lock.manifest'), JSON.stringify(lock, null, 2) + '\n');
console.log(JSON.stringify({ historicalFiles: files.length, nonNotesExact: files.length - noteMap.size, notes: Object.keys(noteCases).length, extras: expectedExtras.length, seeds: seedNames.length, retained: retained.length, inputBytes: inputBytes.length, noteBytes: noteBytes.length }));
