// Failure-detection checks for the packed fixture store.
//
// The verifiers themselves prove the packing preserved every case; this file
// proves the storage layer fails loudly when the store is damaged: a missing
// or corrupt pack, a truncated slice, an edited hash, an unknown envelope, or
// a regenerated fixture committed with large inline base64 must never pass
// silently. It also exercises the two representative fixtures from the
// size-reduction issue: conditional-top.json (heavy intra-file duplication)
// and simple-picture.json (no duplication), so both store shapes run through
// the loader on every `npm run test:xlsx-compat`.

import assert from 'node:assert/strict';
import { mkdir, readFile, readdir, writeFile } from 'node:fs/promises';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { gunzipSync, gzipSync } from 'node:zlib';
import {
  FIXTURE_FORMAT,
  FIXTURE_VERSION,
  BLOB_MARKER,
  buildPack,
  loadFixture,
  mergePackGroup,
  packFixture,
  resolveFixture,
} from '../fixtures.mjs';

let checked = 0;

async function rejectsMatch(promise, pattern) {
  await assert.rejects(promise, pattern);
  checked++;
}

// First marker hash under a packed root, for tests that damage one blob.
function firstHash(packed) {
  const walk = value => {
    if (Array.isArray(value)) {
      for (const item of value) {
        const found = walk(item);
        if (found) return found;
      }
    } else if (typeof value === 'object' && value !== null) {
      if (Object.keys(value).length === 1 && BLOB_MARKER in value) return value[BLOB_MARKER];
      for (const child of Object.values(value)) {
        const found = walk(child);
        if (found) return found;
      }
    }
    return null;
  };
  const hash = walk(packed);
  assert.ok(hash, 'fixture under test contains a marker');
  return hash;
}

// Builds a temporary store packed for `root`, returns the envelope and paths.
async function withTempStore(root, { pack = 'gzip' } = {}) {
  const dir = mkdtempSync(join(tmpdir(), 'fixture-store-'));
  const storeDir = new URL(`file://${dir}/store/`);
  const { packed, blobs } = packFixture(root);
  await mkdir(storeDir, { recursive: true });
  const prefixes = [...new Set([...blobs.keys()].map(hash => hash.slice(0, 2)))].sort();
  for (const prefix of prefixes) {
    const { pk, idx } = buildPack(prefix, blobs);
    const body = pack === 'raw' ? pk : gzipSync(pk);
    await writeFile(new URL(`./${prefix}.pk`, storeDir), body);
    await writeFile(new URL(`./${prefix}.idx`, storeDir), JSON.stringify(idx));
  }
  return {
    storeDir, packed, blobs, prefixes,
    envelope: { format: FIXTURE_FORMAT, version: FIXTURE_VERSION, blobs: blobs.size, root: packed },
  };
}

// Round trip: pack a case-rich value and restore it byte for byte, both with
// gzipped and raw pack bodies. The value mimics the render fixtures: keys,
// arrays, repeated strings, warnings and options.
{
  const media = name => Buffer.from(`${name}-`.repeat(512));
  const originalValue = [
    { input: media('xlsx-input-A').toString('base64'), bdf: media('bdf-expected').toString('base64'), mode: 'none', no_index: true, warnings: ['uncached formula'] },
    { input: media('xlsx-input-A').toString('base64'), bdf: media('bdf-expected').toString('base64'), mode: 'batch', warnings: [] },
  ];
  for (const pack of ['gzip', 'raw']) {
    const { storeDir, envelope } = await withTempStore(originalValue, { pack });
    const restored = await resolveFixture(envelope, 'test', { storeDir });
    assert.deepEqual(restored, originalValue);
    assert.equal(restored[0].input, restored[1].input, 'duplicate inputs stay string-identical');
    checked++;
  }
}

// Missing pack group: a marker whose hash prefix has no pack on disk must fail
// by naming the group it expected.
{
  const { storeDir, envelope, prefixes } = await withTempStore(
    [{ input: Buffer.from('orphan-pack'.repeat(256)).toString('base64') }],
  );
  rmSync(new URL(`./${prefixes[0]}.pk`, storeDir));
  rmSync(new URL(`./${prefixes[0]}.idx`, storeDir));
  const prefix = prefixes[0];
  await rejectsMatch(
    resolveFixture(envelope, 'missing-pack.mjs', { storeDir }),
    new RegExp(`fixture blob [0-9a-f]{64} is missing from store/${prefix}\\.pk`),
  );
}

// Missing blob: the pack exists but the index has no entry for the hash.
{
  const { storeDir, envelope } = await withTempStore(
    [{ input: Buffer.from('missing-index'.repeat(256)).toString('base64') }],
  );
  const hash = firstHash(envelope.root);
  const prefix = hash.slice(0, 2);
  const idx = JSON.parse(await readFile(new URL(`./${prefix}.idx`, storeDir), 'utf8'));
  delete idx.blobs[hash];
  await writeFile(new URL(`./${prefix}.idx`, storeDir), JSON.stringify(idx));
  await rejectsMatch(
    resolveFixture(envelope, 'missing.mjs', { storeDir }),
    new RegExp(`fixture blob ${hash} is missing from store/${prefix}\\.pk`),
  );
}

// Corrupt blob: a single flipped byte inside the pack stream must be caught
// by the content hash, with both the stored and the actual hash in the
// message. The pack body is rewritten so the gzip container stays valid and
// only the sliced bytes changed.
{
  const { storeDir, envelope } = await withTempStore(
    [{ input: Buffer.from('corrupt-me'.repeat(256)).toString('base64') }],
  );
  const hash = firstHash(envelope.root);
  const prefix = hash.slice(0, 2);
  const idx = JSON.parse(await readFile(new URL(`./${prefix}.idx`, storeDir), 'utf8'));
  const [offset] = idx.blobs[hash];
  const packFile = gunzipSync(await readFile(new URL(`./${prefix}.pk`, storeDir)));
  packFile[offset + 5] ^= 0xff;
  await writeFile(new URL(`./${prefix}.pk`, storeDir), gzipSync(packFile));
  await rejectsMatch(
    resolveFixture(envelope, 'corrupt.mjs', { storeDir }),
    new RegExp(`fixture blob ${hash} is corrupt: content in store/${prefix}\\.pk hashes to [0-9a-f]{64}`),
  );
}

// Damaged pack container: a truncated gzip stream must report the pack, not a
// misleading hash mismatch downstream.
{
  const { storeDir, envelope, prefixes } = await withTempStore(
    [{ input: Buffer.from('damaged-container'.repeat(256)).toString('base64') }],
  );
  const prefix = prefixes[0];
  const bytes = await readFile(new URL(`./${prefix}.pk`, storeDir));
  await writeFile(new URL(`./${prefix}.pk`, storeDir), bytes.subarray(0, bytes.length - 40));
  await rejectsMatch(
    resolveFixture(envelope, 'container.mjs', { storeDir }),
    /corrupt store pack \(invalid gzip stream\)/,
  );
}

// Edited hash: a marker that no longer names a well-formed hash must fail
// even before touching the store.
{
  const blob = { input: Buffer.from('hash-check'.repeat(256)).toString('base64') };
  const { storeDir, envelope } = await withTempStore([blob]);
  envelope.root = { [BLOB_MARKER]: '0123456789abcdef' };
  await rejectsMatch(resolveFixture(envelope, 'edited.mjs', { storeDir }), /invalid blob hash/);
}

// Unknown envelope and store-index versions and formats must never be guessed
// at.
{
  const blob = { input: Buffer.from('version-check'.repeat(256)).toString('base64') };
  const { storeDir, envelope, prefixes } = await withTempStore([blob]);
  envelope.version = 99;
  await rejectsMatch(resolveFixture(envelope, 'future.mjs', { storeDir }), /unsupported fixture format version/);
  envelope.version = FIXTURE_VERSION;
  envelope.format = 'some-other-format';
  await rejectsMatch(resolveFixture(envelope, 'other.mjs', { storeDir }), /unknown fixture format/);
  envelope.format = FIXTURE_FORMAT;
  const idx = JSON.parse(await readFile(new URL(`./${prefixes[0]}.idx`, storeDir), 'utf8'));
  idx.version = 99;
  await writeFile(new URL(`./${prefixes[0]}.idx`, storeDir), JSON.stringify(idx));
  await rejectsMatch(
    resolveFixture(envelope, 'store.mjs', { storeDir }),
    /unsupported store index format/,
  );
}

// Plain fixtures pass through the loader unchanged, so freshly regenerated
// (unpacked) fixtures keep working until the packer runs.
{
  const plain = [{ mode: 'none', warnings: [], input: 'tiny' }];
  assert.deepEqual(await resolveFixture(plain, 'plain.mjs'), plain);
  const loaded = await loadFixture('./render/index.json');
  assert.ok(loaded.files.length > 0, 'plain fixture files load through the loader');
  checked += 2;
}

// A marker nested in an already-packed value is a packing bug, not data.
{
  assert.throws(() => packFixture({ nested: { [BLOB_MARKER]: '00'.repeat(32) } }),
    /fixture already contains a \$blob marker/);
  checked++;
}

// The representative fixtures of the size-reduction issue load through the
// real store with their case sets intact. conditional-top.json repeats its
// inputs and expected BDFs across cases; simple-picture.json has 48 distinct
// cases with no duplication. These two shapes are what every other packed
// fixture looks like.
{
  const conditionalTop = await loadFixture('./conditional-top.json');
  assert.equal(conditionalTop.length, 257, 'conditional-top case count');
  const simplePicture = await loadFixture('./simple-picture.json');
  assert.equal(simplePicture.length, 48, 'simple-picture case count');
  const distinctInputs = new Set(conditionalTop.map(c => c.input));
  assert.equal(distinctInputs.size, 153, 'conditional-top distinct inputs');
  const distinctBdf = new Set(conditionalTop.map(c => c.bdf));
  assert.equal(distinctBdf.size, 43, 'conditional-top distinct expected BDFs');
  assert.equal(new Set(simplePicture.map(c => c.input)).size, 48, 'simple-picture distinct inputs');
  assert.deepEqual(Object.keys(simplePicture[0]).sort(), ['bdf', 'input', 'mode', 'no_index', 'warnings']);
  checked++;
}

// Partial packs must not lose other fixtures' blobs: merging a fresh subset
// into an existing store carries every existing entry over, re-verified, and
// rejects a damaged store instead of propagating it.
{
  const blob = text => ({ input: Buffer.from(text.repeat(256)).toString('base64') });
  const rootA = [blob('fixture-a')];
  const rootB = [blob('fixture-b-unique'), blob('fixture-b-second')];
  const { storeDir, envelope } = await withTempStore(rootA);
  const { packed: packedB, blobs: blobsB } = packFixture(rootB);
  const hashA = firstHash(envelope.root);
  const prefixA = hashA.slice(0, 2);
  for (const prefix of new Set([prefixA, ...[...blobsB.keys()].map(hash => hash.slice(0, 2))])) {
    const fresh = new Map([...blobsB].filter(([hash]) => hash.startsWith(prefix)));
    fresh.delete(hashA); // fixture A's blob must come from the store, not the sweep
    const merged = await mergePackGroup(prefix, fresh, { storeDir, cache: new Map() });
    const { pk, idx } = buildPack(prefix, merged);
    await writeFile(new URL(`./${prefix}.pk`, storeDir), pk);
    await writeFile(new URL(`./${prefix}.idx`, storeDir), JSON.stringify(idx));
  }
  const restoredA = await resolveFixture(envelope, 'merge.mjs', { storeDir, cache: new Map() });
  assert.deepEqual(restoredA, rootA, 'merge keeps the fixture the store already held');
  const envelopeB = { format: FIXTURE_FORMAT, version: FIXTURE_VERSION, root: packedB };
  const restoredB = await resolveFixture(envelopeB, 'merge.mjs', { storeDir, cache: new Map() });
  assert.deepEqual(restoredB, rootB, 'merge resolves the newly added fixture');
  checked += 2;

  // A damaged carried entry aborts the merge instead of writing it forward.
  const idxA = JSON.parse(await readFile(new URL(`./${prefixA}.idx`, storeDir), 'utf8'));
  // The merge wrote this group as one raw stream (buildPack output); only
  // assume gzip when the magic says so, like the loader does.
  const rawA = await readFile(new URL(`./${prefixA}.pk`, storeDir));
  const packA = rawA[0] === 0x1f && rawA[1] === 0x8b ? gunzipSync(rawA) : Buffer.from(rawA);
  packA[idxA.blobs[hashA][0]] ^= 0xff;
  await writeFile(new URL(`./${prefixA}.pk`, storeDir), packA);
  await assert.rejects(
    mergePackGroup(prefixA, new Map(), { storeDir, cache: new Map() }),
    /is corrupt in store/,
  );
  checked++;
}

// The process-wide default cache deduplicates pack reads across fixtures and
// is keyed per store root, so temporary stores never mask the real one (the
// sections above already resolved temp stores through it).
{
  const first = await loadFixture('./simple-picture.json');
  const second = await loadFixture('./simple-picture.json');
  assert.deepEqual(first, second, 'repeat loads are identical through the default cache');
  checked++;
}

// A loadFixture result indexed without parentheses indexes the Promise and
// silently yields undefined; the migration hit exactly once (cells.json[0]).
// Scan the verifier sources so the pattern cannot come back.
{
  const names = (await readdir(new URL('../', import.meta.url))).filter(name => name.endsWith('.mjs'));
  for (const name of names) {
    const text = await readFile(new URL(`../${name}`, import.meta.url), 'utf8');
    const offending = text.split('\n').findIndex(line =>
      /await loadFixture\([^)]*\)\s*\[/.test(line) && !/\(await loadFixture/.test(line));
    assert.equal(offending, -1, `${name} line ${offending + 1}: index the loaded value, not the Promise`);
  }
  checked++;
}

console.log(`fixture-store-test: ${checked} store checks passed`);
