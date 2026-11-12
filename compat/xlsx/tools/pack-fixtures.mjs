// Packs the XLSX compatibility fixtures into the content-addressed blob store.
//
// Old form: a fixture JSON embeds every input XLSX and expected BDF as base64,
// duplicated once per case that shares them.
// New form: base64 strings with at least BLOB_MIN_CHARS characters and
// BLOB_MIN_DECODED decoded bytes become {"$blob": "<sha256>"} markers, and the
// decoded bytes go to compat/xlsx/store/<aa>/<hash>.bin, shared across all
// fixtures. Metadata (mode, no_index, warnings, labels, case order) stays
// inline in the manifest. See ../fixtures.mjs for the loader contract.
//
// Usage:
//   node compat/xlsx/tools/pack-fixtures.mjs                        pack everything under compat/xlsx
//   node compat/xlsx/tools/pack-fixtures.mjs --dry-run              report what would change, write nothing
//   node compat/xlsx/tools/pack-fixtures.mjs --check                verify integrity and packing invariants, write nothing
//   node compat/xlsx/tools/pack-fixtures.mjs --files a.json,b.json  pack or check only these fixtures
//   node compat/xlsx/tools/pack-fixtures.mjs --prune                after a full pack, delete unreferenced store blobs
//   node compat/xlsx/tools/pack-fixtures.mjs --compression gzip      store compressed blobs when smaller
//
// Regeneration workflow: run the upstream Go generator with BDF_FIXTURE_ROOT
// pointing at the repository root (it writes plain fixtures), re-run the
// affected verifier, then run this script to pack everything again and
// `--check` to assert the stored state is complete. Do not commit fixtures
// with inline large base64: the check fails on them.

import { readdir, readFile, rm, stat, writeFile, mkdir } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import {
  BLOB_MARKER,
  BLOB_MIN_DECODED,
  FIXTURE_FORMAT,
  FIXTURE_VERSION,
  isCanonicalBase64,
  loadFixture,
  packFixture,
  storePath,
} from '../fixtures.mjs';

const root = new URL('../', import.meta.url);

async function fixtureFiles() {
  const names = [];
  for (const entry of await readdir(root, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.json')) names.push(entry.name);
  }
  const render = new URL('./render/', root);
  for (const entry of await readdir(render, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.json')) names.push(`render/${entry.name}`);
  }
  names.sort();
  return names;
}

function countInlineCandidates(value) {
  if (Array.isArray(value)) return value.reduce((sum, item) => sum + countInlineCandidates(item), 0);
  if (typeof value === 'object' && value !== null) {
    return Object.values(value).reduce((sum, child) => sum + countInlineCandidates(child), 0);
  }
  return isCanonicalBase64(value) && Buffer.from(value, 'base64').length >= BLOB_MIN_DECODED ? 1 : 0;
}

// Collects every hash referenced from a manifest, recursively.
function referencedHashes(value, into) {
  if (Array.isArray(value)) {
    for (const item of value) referencedHashes(item, into);
  } else if (typeof value === 'object' && value !== null) {
    if (Object.keys(value).length === 1 && BLOB_MARKER in value) into.add(value[BLOB_MARKER]);
    else for (const child of Object.values(value)) referencedHashes(child, into);
  }
}

const options = parseArgs({
  args: process.argv.slice(2),
  options: {
    'dry-run': { type: 'boolean', default: false },
    check: { type: 'boolean', default: false },
    files: { type: 'string' },
    prune: { type: 'boolean', default: false },
    compression: { type: 'string', default: 'none' },
  },
}).values;

if (options.compression !== 'none' && options.compression !== 'gzip') {
  throw new Error(`--compression wants gzip or none, got ${options.compression}`);
}

const files = options.files
  ? options.files.split(',').map(name => name.replace(/^\.?\//, '')).sort()
  : await fixtureFiles();

const referenced = new Set();
let packedFiles = 0;
let plainFiles = 0;
let blobsWritten = 0;
let blobsExisting = 0;
let failures = 0;

for (const name of files) {
  const target = new URL(name, root);
  const before = await readFile(target, 'utf8');
  const parsed = JSON.parse(before);
  let original;
  try {
    // A packed fixture is loaded back to its original value so re-packing is
    // idempotent and threshold rule changes can move blobs in or out. In
    // --check mode this line is the integrity gate: a missing or corrupt store
    // blob must fail the run for this file instead of aborting the sweep.
    original = await loadFixture(target);
  } catch (error) {
    if (!options.check) throw error;
    console.error(`${name}: ${error.message}`);
    failures++;
    continue;
  }
  const { packed, blobs } = packFixture(original, { compress: options.compression });
  referencedHashes(packed, referenced);
  const blobTotal = [...blobs.values()].reduce((sum, bytes) => sum + bytes.length, 0);

  if (options.check) {
    if (parsed.format !== undefined && blobs.size === 0) {
      console.error(`${name}: packed manifest with no blobs`);
      failures++;
    }
    if (parsed.format === undefined && countInlineCandidates(parsed) > 0) {
      console.error(`${name}: not packed but embeds ${countInlineCandidates(parsed)} large base64 value(s)`);
      failures++;
    }
    if (parsed.format === FIXTURE_FORMAT && parsed.blobs !== blobs.size) {
      console.error(`${name}: manifest claims ${parsed.blobs} blobs, fixture references ${blobs.size}`);
      failures++;
    }
    continue;
  }

  if (blobs.size === 0) {
    if (parsed.format === FIXTURE_FORMAT) {
      // No large strings left; a manifest with no markers would only hide
      // plain data behind the loader.
      if (!options['dry-run']) await writeFile(target, JSON.stringify(original));
      console.log(`${name}: no blobs left; restored plain JSON`);
      plainFiles++;
    } else {
      plainFiles++;
    }
    continue;
  }

  for (const [hash, bytes] of blobs) {
    const blobTarget = storePath(hash);
    let exists = false;
    try {
      const current = await stat(blobTarget);
      exists = current.isFile() && current.size === bytes.length;
    } catch {
      exists = false;
    }
    if (exists) {
      blobsExisting++;
    } else {
      blobsWritten++;
      if (!options['dry-run']) {
        await mkdir(new URL('./', blobTarget), { recursive: true });
        await writeFile(blobTarget, bytes);
      }
    }
  }
  const manifest = JSON.stringify({
    format: FIXTURE_FORMAT,
    version: FIXTURE_VERSION,
    blobs: blobs.size,
    root: packed,
  });
  const changed = manifest !== before;
  if (changed) packedFiles++;
  if (!options['dry-run'] && changed) await writeFile(target, manifest);
  console.log(`${name}: ${blobs.size} blob(s) (${blobTotal} bytes), manifest ${before.length} -> ${manifest.length}`);
}

// Orphan detection needs the referenced set, so it only speaks for a full run.
if (!options.files && (options.check || options.prune)) {
  const store = new URL('./store/', root);
  let orphans = 0;
  for (const shard of await readdir(store, { withFileTypes: true })) {
    const shardDir = new URL(`./${shard.name}/`, store);
    for (const entry of await readdir(shardDir, { withFileTypes: true })) {
      const hash = `${shard.name}${entry.name.replace(/\.bin$/, '')}`;
      if (!referenced.has(hash)) {
        if (options.prune && !options.check && !options['dry-run']) {
          await rm(new URL(`./${entry.name}`, shardDir));
          if (orphans === 0) console.log('prune: removing unreferenced store blobs');
        } else {
          console.error(`store/${shard.name}/${entry.name}: unreferenced blob`);
        }
        orphans++;
      }
    }
  }
  if (options.check && orphans) failures += orphans;
  console.log(`orphan blobs: ${orphans}`);
}

console.log(`packed ${packedFiles} fixture file(s), left ${plainFiles} plain, ` +
  `wrote ${blobsWritten} blob(s), reused ${blobsExisting} existing blob(s)`);
if (failures) {
  console.error(`${failures} check failure(s)`);
  process.exitCode = 1;
}
