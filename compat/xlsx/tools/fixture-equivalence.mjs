// All-case equivalence gate between the packed fixtures and a git commit.
//
// For every fixture file under compat/xlsx this loads the fixture from the
// working tree through the storage loader, loads the same file from `--base`,
// and compares the two values. The comparison covers every case's input bytes,
// expected BDF bytes, options, warnings, labels and the case order, because
// the loader restores exactly the value JSON.parse produced at the base
// commit: markers become base64 strings again and everything else is compared
// verbatim. It is the migration gate for the fixture storage change, so it
// needs the git history and is not part of the per-run test suite.
//
// Usage:
//   node compat/xlsx/tools/fixture-equivalence.mjs --base e02e4e02 [--report out.json]
//
// Exit code 1 with a per-file list when any fixture differs, is missing on
// either side, or fails to load from the store.

import { spawnSync } from 'node:child_process';
import { readFile, writeFile } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { decodeFixtureBytes, loadFixture, resolveFixture } from '../fixtures.mjs';

const xlsxDir = new URL('../', import.meta.url);

const options = parseArgs({
  args: process.argv.slice(2),
  options: {
    base: { type: 'string' },
    report: { type: 'string' },
  },
}).values;

if (!options.base) throw new Error('--base <revision> is required');

function git(args) {
  const result = spawnSync('git', args, { encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 });
  if (result.status !== 0) {
    throw new Error(`git ${args.join(' ')} failed: ${result.stderr}`);
  }
  return result.stdout;
}

// The base side may itself be packed (a later migration commit), so resolve
// its markers through the base commit's own store instead of comparing a
// resolved value against a manifest of markers. Reading the store from git
// keeps the check value-level for any base revision, not just the original
// uncompressed one.
const baseStoreCache = new Map();
function baseReadStore(name) {
  const file = name.replace(/^\.\//, '');
  if (!baseStoreCache.has(file)) {
    const result = spawnSync('git', ['show', `${options.base}:compat/xlsx/store/${file}`],
      { maxBuffer: 64 * 1024 * 1024 });
    baseStoreCache.set(file, result.status === 0 ? result.stdout : null);
  }
  return baseStoreCache.get(file);
}
const baseCache = new Map();

// The union of fixture paths: everything tracked at the base commit and
// everything the migration unpacked into the working tree.
const baseList = git(['ls-tree', '-r', '--name-only', options.base, '--', 'compat/xlsx'])
  .split('\n')
  .filter(path => /^compat\/xlsx\/[^/]*\.json$|^compat\/xlsx\/render\/[^/]*\.json$/.test(path));
const newList = git(['ls-files', '--', 'compat/xlsx'])
  .split('\n')
  .filter(path => /^compat\/xlsx\/[^/]*\.json$|^compat\/xlsx\/render\/[^/]*\.json$/.test(path));
const paths = [...new Set([...baseList, ...newList])].sort();

// A resolved value must contain no markers. Without this guard a future
// loader regression could compare a manifest of markers with a manifest of
// markers and report equality without ever checking the stored bytes.
function containsMarker(value) {
  if (Array.isArray(value)) return value.some(containsMarker);
  if (typeof value === 'object' && value !== null) {
    if (Object.keys(value).length === 1 && '$blob' in value) return true;
    return Object.values(value).some(containsMarker);
  }
  return false;
}

const results = [];
let failures = 0;
let totalCases = 0;
const blobHashes = new Set();

for (const path of paths) {
  const name = path.replace(/^compat\/xlsx\//, './');
  const record = { file: path, status: 'ok', oldBytes: 0, manifestBytes: 0, blobBytes: 0, newBlobs: 0 };
  results.push(record);
  const gitBase = spawnSync('git', ['show', `${options.base}:${path}`], { maxBuffer: 512 * 1024 * 1024 });
  if (gitBase.status !== 0) {
    record.status = 'missing at base';
    failures++;
    continue;
  }
  record.oldBytes = Buffer.byteLength(gitBase.stdout);
  let expected;
  try {
    expected = await resolveFixture(JSON.parse(decodeFixtureBytes(gitBase.stdout, `${options.base}:${path}`)),
      `${options.base}:${path}`, { readStore: baseReadStore, cache: baseCache });
  } catch (error) {
    record.status = `base load failed: ${error.message}`;
    failures++;
    continue;
  }
  let loaded;
  try {
    loaded = await loadFixture(name);
  } catch (error) {
    record.status = `load failed: ${error.message}`;
    failures++;
    continue;
  }
  let manifest;
  try {
    manifest = JSON.parse(decodeFixtureBytes(await readFile(new URL(name, xlsxDir)), name));
  } catch {
    record.status = 'unreadable manifest';
    failures++;
    continue;
  }
  // Walk the manifest for marker statistics without changing the comparison.
  const walk = value => {
    if (Array.isArray(value)) {
      for (const item of value) walk(item);
    } else if (typeof value === 'object' && value !== null) {
      if (Object.keys(value).length === 1 && '$blob' in value) {
        blobHashes.add(value.$blob);
        record.newBlobs++;
      } else {
        for (const child of Object.values(value)) walk(child);
      }
    }
  };
  walk(manifest);
  record.manifestBytes = Buffer.byteLength(JSON.stringify(manifest));
  if (containsMarker(expected) || containsMarker(loaded)) {
    record.status = 'unresolved blob marker after load';
    failures++;
    continue;
  }
  const oldText = JSON.stringify(expected);
  const newText = JSON.stringify(loaded);
  if (oldText.length !== newText.length || oldText !== newText) {
    record.status = 'value differs';
    failures++;
    continue;
  }
  record.cases = Array.isArray(loaded) ? loaded.length : null;
  if (record.status === 'ok' && Array.isArray(loaded)) totalCases += loaded.length;
}

const ok = results.filter(r => r.status === 'ok');

console.log(`compared ${results.length} fixture file(s): ${ok.length} identical, ${failures} differing or failed`);
console.log(`total cases compared: ${totalCases}`);
console.log(`distinct blobs referenced: ${blobHashes.size}`);
for (const record of results) {
  if (record.status !== 'ok') {
    console.log(`${record.file}: ${record.status}`);
  }
}

if (options.report) {
  const summary = {
    base: options.base,
    files: results.length,
    identical: ok.length,
    failures,
    distinctBlobs: blobHashes.size,
    perFile: results,
  };
  await writeFile(options.report, JSON.stringify(summary, null, 2));
  console.log(`report: ${options.report}`);
}
if (failures) process.exitCode = 1;
