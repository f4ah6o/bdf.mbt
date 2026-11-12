// Packs the XLSX compatibility fixtures into the content-addressed blob store.
//
// Old form: a fixture JSON embeds every input XLSX and expected BDF as base64,
// duplicated once per case that shares them.
// New form: base64 strings with at least BLOB_MIN_CHARS characters and
// BLOB_MIN_DECODED decoded bytes become {"$blob": "<sha256>"} markers, and the
// decoded bytes go into the hash-prefix pack files under compat/xlsx/store/
// (see ../fixtures.mjs). Metadata (mode, no_index, warnings, labels, case
// order) stays inline in the manifest.
//
// Usage:
//   node compat/xlsx/tools/pack-fixtures.mjs                        canonical full pack
//   node compat/xlsx/tools/pack-fixtures.mjs --dry-run              report what would change, write nothing
//   node compat/xlsx/tools/pack-fixtures.mjs --check                verify integrity and packing invariants, write nothing
//   node compat/xlsx/tools/pack-fixtures.mjs --files a.json,b.json  pack only these fixtures (adds blobs, carries the rest over)
//   node compat/xlsx/tools/pack-fixtures.mjs --unpack [--files ...] write the fixture files back in plain form (the stored
//                                                                   bytes stay in the store until the next pack prunes them)
//
// A full pack is canonical: packs are rebuilt from the blobs the current
// fixtures reference, so blobs that are no longer referenced by any fixture
// drop out of the store, and store groups nothing references are removed. A
// partial --files pack merges: every existing store entry is carried over
// (re-hashed while carried) and only the named fixtures' new blobs are added,
// so other fixtures' blobs can never be lost to a partial update.
//
// Regeneration workflow: run the upstream Go generator with BDF_FIXTURE_ROOT
// pointing at the repository root (it writes plain fixtures), re-run the
// affected verifier, then run this script to pack everything again and
// `--check` to assert the stored state is complete. Do not commit fixtures
// with inline large base64: the check fails on them.

import { readdir, readFile, rm, stat, writeFile, mkdir } from 'node:fs/promises';
import { parseArgs } from 'node:util';
import { gzipSync } from 'node:zlib';
import {
  BLOB_MARKER,
  BLOB_MIN_DECODED,
  FIXTURE_FORMAT,
  FIXTURE_VERSION,
  buildPack,
  decodeFixtureBytes,
  encodeFixtureText,
  isCanonicalBase64,
  loadFixture,
  mergePackGroup,
  packFixture,
} from '../fixtures.mjs';

const root = new URL('../', import.meta.url);
const storeDir = new URL('./store/', root);

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
    unpack: { type: 'boolean', default: false },
    print: { type: 'boolean', default: false },
    files: { type: 'string' },
  },
}).values;

const files = options.files
  ? options.files.split(',').map(name => name.replace(/^\.?\//, '')).sort()
  : await fixtureFiles();

// Manifest values for every target; the union of their blobs drives the store.
const manifests = new Map();
const originalValues = new Map();
const blobs = new Map();
let failures = 0;

for (const name of files) {
  const target = new URL(name, root);
  const before = await readFile(target);
  const parsed = JSON.parse(decodeFixtureBytes(before, name));
  try {
    // A packed fixture is loaded back to its original value so re-packing is
    // idempotent and threshold rule changes can move blobs in or out. In
    // --check mode this line is the integrity gate: a missing or corrupt store
    // blob must fail the run for this file instead of aborting the sweep.
    const value = await loadFixture(target);
    const { packed, blobs: fileBlobs } = packFixture(value);
    manifests.set(name, { source: before, parsed, packed, blobs: fileBlobs });
    originalValues.set(name, value);
    for (const [hash, bytes] of fileBlobs) blobs.set(hash, bytes);
  } catch (error) {
    if (!options.check) throw error;
    console.error(`${name}: ${error.message}`);
    failures++;
  }
}

if (options.check) {
  for (const [name, { parsed, packed, blobs: fileBlobs }] of manifests) {
    if (parsed.format !== undefined && fileBlobs.size === 0) {
      console.error(`${name}: packed manifest with no blobs`);
      failures++;
    }
    if (parsed.format === undefined && countInlineCandidates(parsed) > 0) {
      console.error(`${name}: not packed but embeds ${countInlineCandidates(parsed)} large base64 value(s)`);
      failures++;
    }
    if (parsed.format === FIXTURE_FORMAT && parsed.blobs !== fileBlobs.size) {
      console.error(`${name}: manifest claims ${parsed.blobs} blobs, fixture references ${fileBlobs.size}`);
      failures++;
    }
    if (parsed.format === FIXTURE_FORMAT) {
      const claimed = new Set();
      referencedHashes(parsed.root, claimed);
      let stale = false;
      for (const hash of claimed) {
        if (!fileBlobs.has(hash)) {
          console.error(`${name}: manifest references blob ${hash} that the fixture no longer contains`);
          failures++;
          stale = true;
          break;
        }
      }
    }
  }
  // Orphan detection only speaks for a full run: with --files the blobs of
  // other fixtures legitimately stay outside the referenced set.
  if (!options.files) {
    const referenced = new Set();
    for (const { packed } of manifests.values()) referencedHashes(packed, referenced);
    for (const entry of await readdir(storeDir, { withFileTypes: true })) {
      if (entry.name.endsWith('.idx')) {
        const idx = JSON.parse(await readFile(new URL(`./${entry.name}`, storeDir), 'utf8'));
        const orphans = Object.keys(idx.blobs).filter(hash => !referenced.has(hash));
        if (orphans.length) {
          console.error(`store/${entry.name}: ${orphans.length} unreferenced blob(s), e.g. ${orphans[0]}`);
          failures++;
        }
      }
    }
    const prefixIdx = new Map();
    for (const entry of await readdir(storeDir, { withFileTypes: true })) {
      if (entry.name.endsWith('.idx')) {
        const idx = JSON.parse(await readFile(new URL(`./${entry.name}`, storeDir), 'utf8'));
        prefixIdx.set(entry.name.slice(0, 2), new Set(Object.keys(idx.blobs)));
      }
    }
    for (const hash of referenced) {
      const prefix = hash.slice(0, 2);
      if (!prefixIdx.has(prefix) || !prefixIdx.get(prefix).has(hash)) {
        console.error(`referenced blob ${hash} absent from store/${prefix}.idx`);
        failures++;
      }
    }
  }
  console.log(`checked ${manifests.size} fixture file(s) against the store`);
  if (failures) {
    console.error(`${failures} check failure(s)`);
    process.exitCode = 1;
  }
  process.exit();
}

// --unpack writes the plain JSON for the target fixtures back to disk, the
// inverse of packing: upstream Go generators emit plain files, so this is the
// export path for diffing a stored tree, feeding a plain file to other tools,
// or checking what regeneration would replace. The store is left alone: blobs
// survive until the next full pack prunes whatever nothing references.
if (options.unpack) {
  let unpacked = 0;
  for (const [name, value] of originalValues) {
    const plain = JSON.stringify(value);
    if (!options['dry-run'] && !Buffer.from(plain).equals(manifests.get(name).source)) {
      await writeFile(new URL(name, root), plain);
      unpacked++;
    }
  }
  console.log(`unpacked ${unpacked} fixture file(s) to plain form (${originalValues.size} in scope)`);
  process.exit();
}

// --print writes one fixture's decoded JSON to stdout, so a packed manifest
// stays inspectable without unpacking the tree or remembering the envelope.
if (options.print) {
  for (const name of files) {
    const value = originalValues.get(name);
    if (value === undefined) {
      console.error(`${name}: not a fixture file`);
      process.exitCode = 1;
      continue;
    }
    process.stdout.write(`${JSON.stringify(value)}\n`);
  }
  process.exit();
}

// Write the store first so a half-finished run fails loudly (missing blob)
// instead of silently serving a manifest whose packs are not there yet.
const uniquePrefixes = [...new Set([...blobs.keys()].map(hash => hash.slice(0, 2)))].sort();
let packsRewritten = 0;
let packsUnchanged = 0;

// A partial sweep only knows its own fixtures' blobs; merge the touched
// groups with the existing store so nothing else can be dropped.
const groupBlobs = async prefix => {
  const fresh = new Map([...blobs].filter(([hash]) => hash.startsWith(prefix)));
  return options.files ? await mergePackGroup(prefix, fresh, { storeDir }) : fresh;
};

for (const prefix of uniquePrefixes) {
  const { pk, idx } = buildPack(prefix, await groupBlobs(prefix));
  // The pack stream gains from one shared gzip context across adjacent BDFs;
  // keep the raw form if gzip ever fails to help for this group.
  const compressed = gzipSync(pk);
  const outPk = compressed.length < pk.length ? compressed : pk;
  const outIdx = JSON.stringify(idx);
  const existingPk = await stat(new URL(`./${prefix}.pk`, storeDir)).then(s => s.isFile(), () => false);
  const existingIdx = await stat(new URL(`./${prefix}.idx`, storeDir)).then(s => s.isFile(), () => false);
  if (existingPk && existingIdx) {
    const beforePk = await readFile(new URL(`./${prefix}.pk`, storeDir));
    const beforeIdx = await readFile(new URL(`./${prefix}.idx`, storeDir), 'utf8');
    if (beforePk.equals(outPk) && beforeIdx === outIdx) {
      packsUnchanged++;
      continue;
    }
  }
  if (!options['dry-run']) {
    await mkdir(storeDir, { recursive: true });
    await writeFile(new URL(`./${prefix}.pk`, storeDir), outPk);
    await writeFile(new URL(`./${prefix}.idx`, storeDir), outIdx);
  }
  packsRewritten++;
}

let packedFiles = 0;
let plainFiles = 0;

for (const [name, { source, parsed, packed, blobs: fileBlobs }] of manifests) {
  if (fileBlobs.size === 0) {
    if (parsed.format === FIXTURE_FORMAT) {
      // No large strings left; a manifest with no markers would only hide
      // plain data behind the loader.
      const plain = JSON.stringify(originalValues.get(name));
      if (!options['dry-run'] && !Buffer.from(plain).equals(source)) await writeFile(new URL(name, root), plain);
      console.log(`${name}: no blobs left; restored plain JSON`);
    }
    plainFiles++;
    continue;
  }
  const manifest = JSON.stringify({
    format: FIXTURE_FORMAT,
    version: FIXTURE_VERSION,
    blobs: fileBlobs.size,
    root: packed,
  });
  const encoded = encodeFixtureText(manifest);
  if (!encoded.equals(source) && !options['dry-run']) {
    await writeFile(new URL(name, root), encoded);
  }
  if (!encoded.equals(source) || parsed.format !== FIXTURE_FORMAT) packedFiles++;
  console.log(`${name}: ${fileBlobs.size} blob(s) referenced, manifest ${source.length} -> ${encoded.length} bytes`);
}

// A canonical full run owns the whole store: prefixes nothing references
// anymore are groups whose fixtures disappeared, so remove their files rather
// than leaving orphans that --check would (rightly) reject.
if (!options.files && !options['dry-run'] && !options.check && !options.unpack) {
  let removed = 0;
  for (const entry of await readdir(storeDir, { withFileTypes: true })) {
    if (!entry.isFile()) continue;
    const prefix = entry.name.slice(0, 2);
    if (!uniquePrefixes.includes(prefix)) {
      await rm(new URL(`./${entry.name}`, storeDir));
      removed++;
    }
  }
  if (removed) console.log(`removed ${removed / 2 | 0} unreferenced store group(s)`);
}

console.log(`packed ${packedFiles} fixture file(s), left ${plainFiles} plain, ` +
  `store: ${packsRewritten} pack group(s) rewritten, ${packsUnchanged} unchanged`);
