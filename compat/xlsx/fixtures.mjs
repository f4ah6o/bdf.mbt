// Content-addressed storage for the XLSX compatibility fixtures.
//
// The fixture JSON files used to embed every input XLSX and expected BDF as a
// base64 string, repeated for each case that shares them. A fixture is now
// stored as a manifest that keeps every case, option, warning, label and
// order, but replaces large base64 strings with a marker pointing at the
// decoded bytes in a shared blob store addressed by SHA-256 of the bytes.
//
// A packed fixture file looks like:
//
//   {"format":"bdf-xlsx-fixture","version":1,"blobs":12,"root": <original JSON
//   value with markers instead of the extracted strings>}
//
// where every marker is {"$blob": "<64 lowercase hex chars>"} and the bytes
// live at store/<first two hex chars>/<hash>.bin (optionally gzip-compressed,
// detectable by the 1f 8b magic). The hash covers the uncompressed bytes, so
// loading always verifies the content the case will actually see.
//
// `loadFixture` returns exactly the value `JSON.parse` returned for the old
// file: markers are replaced with the canonical base64 text of the blob, so
// existing verifiers keep comparing the same bytes, options, warnings and case
// order without knowing the storage changed. Files without the envelope are
// returned as parsed, which keeps the flow "generate, then pack" workable:
// a freshly regenerated fixture is verified in its plain form first.

import { createHash } from 'node:crypto';
import { gunzipSync, gzipSync } from 'node:zlib';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

export const FIXTURE_FORMAT = 'bdf-xlsx-fixture';
export const FIXTURE_VERSION = 1;
export const BLOB_MARKER = '$blob';
export const STORE_DIR = new URL('./store/', import.meta.url);

// Only strings that meet both bounds are moved to the store; everything
// smaller stays inline so tiny fixtures keep a readable, self-contained form.
export const BLOB_MIN_CHARS = 128;
export const BLOB_MIN_DECODED = 1024;

// True when the string round-trips through base64 unchanged, i.e. it is
// canonical base64 text. Prose and XML never survive this test, so it selects
// exactly the embedded binary the generators write.
export function isCanonicalBase64(value) {
  return typeof value === 'string' &&
    value.length >= BLOB_MIN_CHARS &&
    Buffer.from(value, 'base64').toString('base64') === value;
}

export function sha256(buffer) {
  return createHash('sha256').update(buffer).digest('hex');
}

export function isBlobHash(value) {
  return typeof value === 'string' && /^[0-9a-f]{64}$/.test(value);
}

export function storePath(hash, storeDir = STORE_DIR) {
  if (!isBlobHash(hash)) throw new Error(`invalid blob hash ${JSON.stringify(hash)}`);
  return new URL(`./${hash.slice(0, 2)}/${hash}.bin`, storeDir);
}

function gunzipIfCompressed(buffer, source, hash) {
  if (buffer[0] === 0x1f && buffer[1] === 0x8b) {
    try {
      return gunzipSync(buffer);
    } catch (error) {
      throw new Error(`${source}: fixture blob ${hash} is not a valid gzip stream: ${error.message}`);
    }
  }
  return buffer;
}

// Reads one blob from the store and verifies its hash. The cache lets a
// process reuse bytes that several cases or several fixtures reference.
export async function readBlob(hash, { storeDir = STORE_DIR, cache } = {}) {
  if (!isBlobHash(hash)) throw new Error(`invalid blob hash ${JSON.stringify(hash)}`);
  if (cache?.has(hash)) return cache.get(hash);
  let raw;
  try {
    raw = await readFile(storePath(hash, storeDir));
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new Error(`fixture blob ${hash} is missing from the store`);
    }
    throw error;
  }
  const bytes = gunzipIfCompressed(raw, 'store', hash);
  const actual = sha256(bytes);
  if (actual !== hash) {
    throw new Error(`fixture blob ${hash} is corrupt: content hashes to ${actual}`);
  }
  cache?.set(hash, bytes);
  return bytes;
}

function isMarker(value) {
  return typeof value === 'object' && value !== null && !Array.isArray(value) &&
    Object.keys(value).length === 1 && BLOB_MARKER in value;
}

// Replaces every marker under a packed root with the base64 text of its blob.
async function resolveValue(value, options) {
  if (Array.isArray(value)) {
    const out = new Array(value.length);
    for (let i = 0; i < value.length; i++) out[i] = await resolveValue(value[i], options);
    return out;
  }
  if (typeof value === 'object' && value !== null) {
    if (isMarker(value)) {
      const hash = value[BLOB_MARKER];
      const bytes = await readBlob(hash, options);
      return bytes.toString('base64');
    }
    const out = {};
    for (const [key, child] of Object.entries(value)) out[key] = await resolveValue(child, options);
    return out;
  }
  return value;
}

// Returns the fixture value with all markers resolved, or the parsed value
// unchanged when the file is not packed.
export async function resolveFixture(parsed, source, { storeDir = STORE_DIR, cache } = {}) {
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return parsed;
  if (parsed.format === undefined) return parsed;
  if (parsed.format !== FIXTURE_FORMAT) {
    throw new Error(`${source}: unknown fixture format ${JSON.stringify(parsed.format)}`);
  }
  if (parsed.version !== FIXTURE_VERSION) {
    throw new Error(`${source}: unsupported fixture format version ${JSON.stringify(parsed.version)}`);
  }
  return resolveValue(parsed.root, { storeDir, cache });
}

// Loads a fixture file, packed or plain. `target` is a URL or a path relative
// to this directory, matching the old `JSON.parse(await readFile(new
// URL('./name.json', import.meta.url)))` call sites.
export async function loadFixture(target, { storeDir = STORE_DIR, cache } = {}) {
  const url = target instanceof URL ? target : new URL(target, import.meta.url);
  const source = fileURLToPath(url);
  if (typeof target === 'string' && !target.startsWith('.')) {
    throw new Error(`loadFixture wants a fixture path relative to this directory, got ${JSON.stringify(target)}`);
  }
  const parsed = JSON.parse(await readFile(url, 'utf8'));
  return resolveFixture(parsed, source, { storeDir, cache });
}

// Packs a parsed fixture value in memory: returns the packed root with
// markers and the blobs keyed by hash. Shared with the packer and the tests
// so the extraction rule has a single implementation.
export function packFixture(root, { minDecoded = BLOB_MIN_DECODED, compress } = {}) {
  const blobs = new Map();
  const packValue = value => {
    if (Array.isArray(value)) return value.map(packValue);
    if (typeof value === 'object' && value !== null) {
      if (isMarker(value)) throw new Error(`fixture already contains a ${BLOB_MARKER} marker`);
      const out = {};
      for (const [key, child] of Object.entries(value)) out[key] = packValue(child);
      return out;
    }
    if (!isCanonicalBase64(value)) return value;
    const bytes = Buffer.from(value, 'base64');
    if (bytes.length < minDecoded) return value;
    const hash = sha256(bytes);
    if (!blobs.has(hash)) {
      let stored = bytes;
      if (compress === 'gzip') {
        const compressed = gzipSync(bytes);
        if (compressed.length < bytes.length) stored = compressed;
      }
      blobs.set(hash, stored);
    }
    return { [BLOB_MARKER]: hash };
  };
  const packed = packValue(root);
  return { packed, blobs };
}
