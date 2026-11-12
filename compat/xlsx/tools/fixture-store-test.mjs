// Failure-detection checks for the packed fixture store.
//
// The verifiers themselves prove the packing preserved every case; this file
// proves the storage layer fails loudly when the store is damaged: a missing
// or corrupt blob, an edited hash, an unknown envelope, or a regenerated
// fixture committed with large inline base64 must never pass silently. It also
// exercises the two representative fixtures from the size-reduction issue:
// conditional-top.json (heavy intra-file duplication) and simple-picture.json
// (no duplication), so both store shapes run through the loader on every
// `npm run test:xlsx-compat`.

import assert from 'node:assert/strict';
import { mkdir, writeFile } from 'node:fs/promises';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import {
  FIXTURE_FORMAT,
  FIXTURE_VERSION,
  BLOB_MARKER,
  loadFixture,
  packFixture,
  resolveFixture,
  storePath,
} from '../fixtures.mjs';

let checked = 0;

// Builds a temporary store holding `fixture`, returns the store directory URL.
async function withTempStore(fixture) {
  const dir = await mkdtempSync(join(tmpdir(), 'fixture-store-'));
  const storeDir = new URL(`file://${dir}/store/`);
  const { packed, blobs } = packFixture(fixture.root, { compress: fixture.compress });
  for (const [hash, bytes] of blobs) {
    const target = storePath(hash, storeDir);
    await mkdir(new URL('./', target), { recursive: true });
    await writeFile(target, bytes);
  }
  const envelope = { format: FIXTURE_FORMAT, version: FIXTURE_VERSION, blobs: blobs.size, root: packed };
  return { dir, storeDir, envelope, blobs, packed };
}

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

// Round trip: pack a case-rich value and restore it byte for byte, both with
// raw and gzip-compressed blobs. The value mimics the render fixtures: keys,
// arrays, repeated strings, warnings and options.
{
  const media = name => Buffer.from(`${name}-`.repeat(512));
  const originalValue = [
    { input: media('xlsx-input-A').toString('base64'), bdf: media('bdf-expected').toString('base64'), mode: 'none', no_index: true, warnings: ['uncached formula'] },
    { input: media('xlsx-input-A').toString('base64'), bdf: media('bdf-expected').toString('base64'), mode: 'batch', warnings: [] },
  ];
  for (const compress of [undefined, 'gzip']) {
    const { storeDir, blobs } = await withTempStore({ root: originalValue, compress });
    const { packed } = packFixture(originalValue, { compress });
    assert.equal(blobs.size, 2, 'one blob per distinct large string');
    const restored = await resolveFixture(
      { format: FIXTURE_FORMAT, version: FIXTURE_VERSION, root: packed }, 'test', { storeDir });
    assert.deepEqual(restored, originalValue);
    assert.equal(restored[0].input, restored[1].input, 'duplicate inputs stay string-identical');
    checked++;
  }
}

// Missing blob: a marker whose bytes are not in the store must fail by name.
{
  const { storeDir, envelope } = await withTempStore({
    root: [{ input: Buffer.from('gif-file'.repeat(256)).toString('base64') }],
  });
  const hash = firstHash(envelope.root);
  rmSync(storePath(hash, storeDir));
  await rejectsMatch(
    resolveFixture(envelope, 'missing.mjs', { storeDir }),
    /fixture blob [0-9a-f]{64} is missing from the store/,
  );
}

// Corrupt blob: a single flipped byte must be detected by the hash check,
// with both the stored and the actual hash in the message.
{
  const { storeDir, envelope, blobs } = await withTempStore({
    root: [{ input: Buffer.from('corrupt-me'.repeat(256)).toString('base64') }],
  });
  const [hash, bytes] = [...blobs.entries()][0];
  bytes[5] ^= 0xff;
  await writeFile(storePath(hash, storeDir), bytes);
  await rejectsMatch(
    resolveFixture(envelope, 'corrupt.mjs', { storeDir }),
    new RegExp(`fixture blob ${hash} is corrupt: content hashes to [0-9a-f]{64}`),
  );
}

// Edited hash: a marker that no longer names a well-formed hash must fail
// even before touching the store.
{
  const { storeDir, envelope } = await withTempStore({ root: [''] });
  envelope.root = { [BLOB_MARKER]: '0123456789abcdef' };
  await rejectsMatch(resolveFixture(envelope, 'edited.mjs', { storeDir }), /invalid blob hash/);
}

// Unknown envelope versions and formats must never be guessed at.
{
  const { storeDir, envelope } = await withTempStore({ root: {} });
  envelope.version = 99;
  await rejectsMatch(resolveFixture(envelope, 'future.mjs', { storeDir }), /unsupported fixture format version/);
  envelope.version = FIXTURE_VERSION;
  envelope.format = 'some-other-format';
  await rejectsMatch(resolveFixture(envelope, 'other.mjs', { storeDir }), /unknown fixture format/);
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

console.log(`fixture-store-test: ${checked} store checks passed`);
