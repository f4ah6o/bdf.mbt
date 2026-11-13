// All-case migration audit against the immutable pre-migration Git corpus.
// This is separate from runtime loading and never substitutes missing fixtures.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import path from 'node:path';
import { decodeFixtureBytes, resolveFixture } from '../fixtures.mjs';
import { strictSha } from './strict-hash.mjs';
import { lock, strictLock, noteNames, sha, valueSha } from './contract.mjs';
import { validateGenerated } from './generate.mjs';

const { values } = parseArgs({ options: { run: { type: 'string' }, repo: { type: 'string' }, report: { type: 'string' } } });
if (!values.run || !values.repo || !values.report) throw Error('--run <generated-run> --repo <git-repo> --report <file> required');
const repo = path.resolve(values.repo), run = path.resolve(values.run);
function git(...args) { return execFileSync('git', ['-C', repo, ...args], { maxBuffer: 256 * 1024 * 1024, stdio: ['ignore', 'pipe', 'pipe'] }); }
const commit = git('rev-parse', `${lock.baseline}^{commit}`).toString().trim();
assert.equal(commit, lock.baseline, 'historical baseline missing or wrong');
const files = git('ls-tree', '-r', '--name-only', commit, '--', 'compat/xlsx').toString().split('\n').filter(f => /^compat\/xlsx\/[^/]*\.json$|^compat\/xlsx\/render\/[^/]*\.json$/.test(f)).map(f => f.slice('compat/xlsx/'.length)).sort();
assert.deepEqual(files, Object.keys(lock.fixtures).sort(), 'historical fixture inventory');
await validateGenerated(run); // Includes explicit validation of all six extras.
const receiptBytes = await readFile(path.join(run, 'receipt.json')), receipt = JSON.parse(receiptBytes);
process.env.BDF_XLSX_FIXTURE_ROOT = run; process.env.BDF_XLSX_RUN_ID = receipt.runId; process.env.BDF_XLSX_RECEIPT_SHA = sha(receiptBytes);
const { loadRunFixture } = await import('./load.mjs');
const storeCache = new Map(), fixtureCache = new Map();
async function readStore(name) {
  if (!/^\.\/[a-f0-9]{2}\.(pk|idx)$/.test(name)) throw Error(`Invalid baseline store name: ${name}`);
  if (!storeCache.has(name)) storeCache.set(name, git('show', `${commit}:compat/xlsx/store/${name.slice(2)}`));
  return storeCache.get(name);
}
const report = { version: 1, baseline: commit, runId: receipt.runId, compared: 0, equal: 0, units: 0, failures: [], notes: 0, extras: Object.keys(lock.extras).length };
for (const file of files) {
  try {
    const bytes = git('show', `${commit}:compat/xlsx/${file}`);
    const old = await resolveFixture(JSON.parse(decodeFixtureBytes(bytes, file)), file, { readStore, cache: fixtureCache });
    const selected = await loadRunFixture('./' + file);
    assert.equal(valueSha(old), lock.fixtures[file].sha256, `baseline digest ${file}`);
    assert.equal(strictSha(old), strictLock.fixtures[file], `strict baseline digest ${file}`);
    assert.ok(isDeepStrictEqual(old, selected), `selected fixture differs: ${file}`);
    const units = Array.isArray(old) ? old.length : 1;
    assert.equal(Array.isArray(old) ? old.length : null, lock.fixtures[file].count, `case inventory ${file}`);
    report.units += units;
    if (noteNames.has(file)) report.notes += old.length;
    report.compared++; report.equal++;
  } catch (error) { report.failures.push({ file, error: error.message }); }
}
await writeFile(values.report, JSON.stringify(report, null, 2) + '\n');
console.log(JSON.stringify(report));
if (report.compared !== 804 || report.equal !== 804 || report.units !== 316370 || report.notes !== 264 || report.failures.length) process.exitCode = 1;
