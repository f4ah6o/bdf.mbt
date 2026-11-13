// Derive typed hashes from the independent original corpus, not the new loader.
import assert from 'node:assert/strict';
import { readFile, readdir, writeFile } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { gunzipSync } from 'node:zlib';
import { loadFixture } from '../fixtures.mjs';
import { strictSha } from '../oracle/strict-hash.mjs';

const { values } = parseArgs({ options: { generated: { type: 'string' }, output: { type: 'string' } } });
if (!values.generated || !values.output) throw Error('--generated <completed-run> --output <new-file> required');
if (process.env.BDF_XLSX_FIXTURE_ROOT || process.env.BDF_XLSX_RUN_ID || process.env.BDF_XLSX_RECEIPT_SHA) throw Error('Original corpus required');
const lock = JSON.parse(await readFile(new URL('../oracle/lock.manifest', import.meta.url)));
const root = fileURLToPath(new URL('../', import.meta.url));
const names = (await readdir(root, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
assert.deepEqual(names, Object.keys(lock.fixtures).sort());
const notes = new Set(['sheet-multiple-notes-filter.json', 'sheet-multiple-notes-legacy.json', 'sheet-multiple-notes.json']);
const fixtures = {}, noteCases = {};
for (const name of names) {
  const old = await loadFixture('./' + name), fresh = JSON.parse(await readFile(path.join(values.generated, 'compat/xlsx', name)));
  fixtures[name] = strictSha(old);
  if (notes.has(name)) {
    assert.equal(old.length, fresh.length);
    for (const [i, entry] of old.entries()) {
      const { bdf: a, ...before } = entry, { bdf: b, ...after } = fresh[i];
      assert.equal(typeof a, 'string'); assert.equal(typeof b, 'string'); assert.deepEqual(before, after);
      noteCases[`${name}#${i}`] = strictSha(entry);
    }
  } else {
    assert.ok(isDeepStrictEqual(old, fresh), `baseline mismatch ${name}`);
    assert.equal(strictSha(old), strictSha(fresh), `strict digest mismatch ${name}`);
  }
}
assert.equal(Object.keys(noteCases).length, 264);
const extras = {};
for (const name of Object.keys(lock.extras)) extras[name] = strictSha(JSON.parse(await readFile(path.join(values.generated, 'compat/xlsx', name))));
const input = JSON.parse(gunzipSync(await readFile(new URL('../oracle/inputs.data', import.meta.url))));
const inputs = Object.fromEntries(Object.keys(input).sort().map(name => [name, strictSha(input[name])]));
await writeFile(values.output, JSON.stringify({ version: 1, baseline: lock.baseline, fixtures, extras, noteCases, inputs }, null, 2) + '\n', { flag: 'wx' });
console.log(JSON.stringify({ fixtures: names.length, notes: Object.keys(noteCases).length, inputs: Object.keys(inputs).length, extras: Object.keys(extras).length }));
