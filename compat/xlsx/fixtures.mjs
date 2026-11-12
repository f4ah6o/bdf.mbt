// Content-addressed storage for the XLSX compatibility fixtures.
//
// The fixture JSON files used to embed every input XLSX and expected BDF as a
// base64 string, repeated once per case that shares them. A fixture is now
// stored as a manifest that keeps every case, option, warning, label and
// order, but replaces large base64 strings with a marker pointing at the
// decoded bytes in a shared blob store addressed by SHA-256 of the bytes.
//
// A packed fixture file looks like:
//
//   BXF1 + brotli({"format":"bdf-xlsx-fixture","version":1,"blobs":12,
//                  "root": <original JSON value with markers instead of the
//                  extracted strings>})
//
// where every marker is {"$blob": "<64 lowercase hex chars>"}. The BXF1 magic
// makes the container self-identifying: plain generator output still loads
// unchanged, and a damaged stream fails with the file name instead of a JSON
// syntax error.
//
// The blob store is split by the first hash byte to keep the file count small
// while staying content-addressed:
//
//   store/aa.pk   one gzip stream of the concatenation of that group's blobs,
//                 in first-seen sweep order; gzipped because expected BDFs
//                 across cases share most of their bytes, which only a shared
//                 stream sees (per-blob compression costs twice as much).
//   store/aa.idx  {"format":"bdf-xlsx-store","version":1,"blobs":{"<hash>":
//                 [offset, length], ...}} with offsets into the decompressed
//                 .pk bytes.
//
// Addressing a blob therefore reads one pack, decompresses it once per
// process, slices [offset, length) and verifies that the slice hashes to the
// address. The hash covers the uncompressed content, and readers hash every
// slice they hand out, so corruption anywhere in the path is detected.
//
// `loadFixture` returns exactly the value `JSON.parse` returned for the old
// file: markers are replaced with the canonical base64 text of the blob, so
// existing verifiers keep comparing the same bytes, options, warnings and
// case order without knowing the storage changed. Files without the envelope
// are returned as parsed, which keeps the flow "generate, then pack" workable:
// a freshly regenerated fixture is verified in its plain form first.

import { createHash } from 'node:crypto';
import { brotliCompressSync, brotliDecompressSync, constants as zlibConstants, gunzipSync } from 'node:zlib';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

export const FIXTURE_FORMAT = 'bdf-xlsx-fixture';
export const FIXTURE_VERSION = 1;
export const STORE_FORMAT = 'bdf-xlsx-store';
export const STORE_VERSION = 1;
export const BLOB_MARKER = '$blob';
export const STORE_DIR = new URL('./store/', import.meta.url);

// Packed manifests are stored as `BXF2` followed by the uncompressed JSON
// length (4 bytes, big endian), the SHA-256 of the uncompressed JSON (32
// bytes) and a brotli stream of that JSON. The magic makes the container
// self-identifying: a plain fixture still starts with `[` or `{`, so the
// loader can accept both without a sidecar flag. The digest is checked before
// parsing, because brotli has no checksum of its own: a mutated compressed
// byte can still decompress to valid JSON, and without the digest that
// mutation would silently change a case. Brotli quality 9 keeps the one-off
// pack cost near gzip while landing close to quality 11 on this JSON (see
// docs/xlsx-fixture-storage.md).
export const FIXTURE_ENVELOPE = 'BXF2';
export const LEGACY_FIXTURE_ENVELOPE = 'BXF1';
const FIXTURE_ENVELOPE_BYTES = Buffer.from(FIXTURE_ENVELOPE, 'latin1');
const LEGACY_FIXTURE_ENVELOPE_BYTES = Buffer.from(LEGACY_FIXTURE_ENVELOPE, 'latin1');
const ENVELOPE_HEADER_BYTES = 4 + 4 + 32;

export function encodeFixtureText(text) {
  const body = Buffer.from(text, 'utf8');
  const header = Buffer.alloc(ENVELOPE_HEADER_BYTES);
  FIXTURE_ENVELOPE_BYTES.copy(header, 0);
  header.writeUInt32BE(body.length, 4);
  createHash('sha256').update(body).digest().copy(header, 8);
  return Buffer.concat([
    header,
    brotliCompressSync(body, {
      params: {
        [zlibConstants.BROTLI_PARAM_QUALITY]: 9,
        [zlibConstants.BROTLI_PARAM_LGWIN]: 24,
      },
    }),
  ]);
}

// Returns the JSON text of a fixture file, decompressing the packed-manifest
// envelope when present. Plain fixtures pass through unchanged. The length and
// digest are verified before the text reaches JSON.parse, so a mutated stream
// that still decompresses to valid JSON is rejected rather than loaded.
export function decodeFixtureBytes(raw, source) {
  if (raw.length >= LEGACY_FIXTURE_ENVELOPE_BYTES.length &&
      raw.subarray(0, LEGACY_FIXTURE_ENVELOPE_BYTES.length).equals(LEGACY_FIXTURE_ENVELOPE_BYTES)) {
    throw new Error(`${source}: unsupported fixture envelope ${LEGACY_FIXTURE_ENVELOPE} (no integrity digest); repack with pack-fixtures.mjs`);
  }
  if (raw.length >= FIXTURE_ENVELOPE_BYTES.length &&
      raw.subarray(0, FIXTURE_ENVELOPE_BYTES.length).equals(FIXTURE_ENVELOPE_BYTES)) {
    if (raw.length < ENVELOPE_HEADER_BYTES) {
      throw new Error(`${source}: corrupt fixture envelope (truncated header)`);
    }
    const expectedLength = raw.readUInt32BE(4);
    const expectedDigest = raw.subarray(8, ENVELOPE_HEADER_BYTES);
    let body;
    try {
      body = brotliDecompressSync(raw.subarray(ENVELOPE_HEADER_BYTES));
    } catch (error) {
      throw new Error(`${source}: corrupt fixture envelope (invalid brotli stream): ${error.message}`);
    }
    if (body.length !== expectedLength) {
      throw new Error(`${source}: corrupt fixture envelope (length ${body.length}, expected ${expectedLength})`);
    }
    const actualDigest = createHash('sha256').update(body).digest();
    if (!actualDigest.equals(expectedDigest)) {
      throw new Error(`${source}: corrupt fixture envelope (sha256 ${actualDigest.toString('hex')}, expected ${expectedDigest.toString('hex')})`);
    }
    return body.toString('utf8');
  }
  return raw.toString('utf8');
}

// Decompressed packs are shared process-wide by default: one verifier or shard
// child loads hundreds of fixtures, and the blobs resolve from the same 256
// packs every time. Each pack is held decompressed (a few MiB per group), so a
// cold run pays the gunzip once per group per process instead of once per
// fixture.
const sharedCache = new Map();

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

function decompressedStoreBytes(raw, source) {
  if (raw[0] === 0x1f && raw[1] === 0x8b) {
    try {
      return gunzipSync(raw);
    } catch (error) {
      throw new Error(`${source}: corrupt store pack (invalid gzip stream): ${error.message}`);
    }
  }
  return raw;
}

// The per-process pack cache: decompressed pack bytes plus its offset index.
// Fixture sets reference most blobs several times, and a verify-render shard
// resolves every blob in its fixtures, so this is where the loader earns its
// keep. A custom readStore is namespaced by callback identity: two readers
// sharing one cache must not see each other's packs, or a reader that returns
// null for a missing group would mask a later reader that can supply it.
const readStoreKeys = new WeakMap();
let nextReadStoreKey = 0;
function storeCacheKey(storeDir, readStore) {
  if (!readStore) return storeDir.href;
  let key = readStoreKeys.get(readStore);
  if (key === undefined) {
    key = `custom-${nextReadStoreKey++}`;
    readStoreKeys.set(readStore, key);
  }
  return key;
}

async function packFor(prefix, { storeDir, cache, readStore }) {
  const key = `${storeCacheKey(storeDir, readStore)}|${prefix}`;
  if (cache?.has(key)) return cache.get(key);
  const read = readStore ?? (async name => {
    try {
      return await readFile(new URL(`./${name}`, storeDir));
    } catch (error) {
      if (error?.code === 'ENOENT') return null;
      throw error;
    }
  });
  const pk = await read(`./${prefix}.pk`);
  if (pk === null) {
    const empty = { bytes: Buffer.alloc(0), offsets: new Map() };
    cache?.set(key, empty);
    return empty;
  }
  const idxRaw = await read(`./${prefix}.idx`);
  if (idxRaw === null) throw new Error(`store/${prefix}.idx: missing store index`);
  const idx = JSON.parse(idxRaw.toString('utf8'));
  if (idx.format !== STORE_FORMAT || idx.version !== STORE_VERSION) {
    throw new Error(`store/${prefix}.idx: unsupported store index format ${JSON.stringify(idx.format)}/${idx.version}`);
  }
  const offsets = new Map(Object.entries(idx.blobs).map(([hash, [offset, length]]) => [hash, [offset, length]]));
  const pack = { bytes: decompressedStoreBytes(pk, `store/${prefix}.pk`), offsets };
  cache?.set(key, pack);
  return pack;
}

// Reads one blob from the store and verifies its hash. The cache lets a
// process reuse bytes that several cases or several fixtures reference.
export async function readBlob(hash, { storeDir = STORE_DIR, cache = sharedCache, readStore } = {}) {
  if (!isBlobHash(hash)) throw new Error(`invalid blob hash ${JSON.stringify(hash)}`);
  const prefix = hash.slice(0, 2);
  const pack = await packFor(prefix, { storeDir, cache, readStore });
  const entry = pack.offsets.get(hash);
  if (!entry) throw new Error(`fixture blob ${hash} is missing from store/${prefix}.pk`);
  const bytes = pack.bytes.subarray(entry[0], entry[0] + entry[1]);
  if (bytes.length !== entry[1]) throw new Error(`fixture blob ${hash} is truncated in store/${prefix}.pk`);
  const actual = sha256(bytes);
  if (actual !== hash) {
    throw new Error(`fixture blob ${hash} is corrupt: content in store/${prefix}.pk hashes to ${actual}`);
  }
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
      return (await readBlob(value[BLOB_MARKER], options)).toString('base64');
    }
    const out = {};
    for (const [key, child] of Object.entries(value)) out[key] = await resolveValue(child, options);
    return out;
  }
  return value;
}

// Returns the fixture value with all markers resolved, or the parsed value
// unchanged when the file is not packed.
export async function resolveFixture(parsed, source, { storeDir = STORE_DIR, cache = sharedCache, readStore } = {}) {
  if (parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)) return parsed;
  if (parsed.format === undefined) return parsed;
  if (parsed.format !== FIXTURE_FORMAT) {
    throw new Error(`${source}: unknown fixture format ${JSON.stringify(parsed.format)}`);
  }
  if (parsed.version !== FIXTURE_VERSION) {
    throw new Error(`${source}: unsupported fixture format version ${JSON.stringify(parsed.version)}`);
  }
  return resolveValue(parsed.root, { storeDir, cache, readStore });
}

// Loads a fixture file, packed or plain. `target` is a URL or a path relative
// to this directory, matching the old `JSON.parse(await readFile(new
// URL('./name.json', import.meta.url)))` call sites.
export async function loadFixture(target, { storeDir = STORE_DIR, cache = sharedCache, readStore } = {}) {
  const url = target instanceof URL ? target : new URL(target, import.meta.url);
  const source = fileURLToPath(url);
  if (typeof target === 'string' && !target.startsWith('.')) {
    throw new Error(`loadFixture wants a fixture path relative to this directory, got ${JSON.stringify(target)}`);
  }
  const parsed = JSON.parse(decodeFixtureBytes(await readFile(url), source));
  return resolveFixture(parsed, source, { storeDir, cache, readStore });
}

// Packs a parsed fixture value in memory: returns the packed root with
// markers and the raw blob bytes keyed by hash. Shared with the packer and
// the tests so the extraction rule has a single implementation.
export function packFixture(root, { minDecoded = BLOB_MIN_DECODED } = {}) {
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
    if (!blobs.has(hash)) blobs.set(hash, bytes);
    return { [BLOB_MARKER]: hash };
  };
  const packed = packValue(root);
  return { packed, blobs };
}

// Reads one store group's decompressed bytes and offset map. Exported for
// the packer: a partial pack must carry over entries it is not replacing,
// which means reading exactly what a loader would read.
export async function readPackGroup(prefix, { storeDir = STORE_DIR, cache = sharedCache, readStore } = {}) {
  return packFor(prefix, { storeDir, cache, readStore });
}

// Merges new blobs into an existing store group without dropping entries.
// The packer rebuilds a group from the fixed set of blobs the swept fixtures
// reference, so a partial sweep passed straight through would wipe every
// other fixture's blob in that group; merging carries the existing entries
// over instead. Carried bytes are re-hashed: a corrupt store must abort the
// merge, not propagate its damage into a rebuilt pack.
export async function mergePackGroup(prefix, newBlobs, { storeDir = STORE_DIR, cache = sharedCache, readStore } = {}) {
  const merged = new Map(newBlobs);
  const pack = await packFor(prefix, { storeDir, cache, readStore });
  for (const [hash, [offset, length]] of pack.offsets) {
    if (merged.has(hash)) continue;
    const bytes = pack.bytes.subarray(offset, offset + length);
    if (bytes.length !== length || sha256(bytes) !== hash) {
      throw new Error(`fixture blob ${hash} is corrupt in store/${prefix}.pk; run a full pack to rebuild the store`);
    }
    merged.set(hash, Buffer.from(bytes));
  }
  return merged;
}

// Builds one store group: the `pk` bytes and the JSON-ready index for all
// blobs whose hash starts with `prefix`. The bytes follow the given order:
// the caller sweeps fixtures in a deterministic order, so identical inputs
// rebuild identical packs, and related blobs (expected BDFs of one fixture)
// stay adjacent where the shared gzip context can reuse them. Hash-sorted
// packs cost a quarter more because that order scatters the similar blobs.
export function buildPack(prefix, blobs) {
  const hashes = [...blobs.keys()].filter(hash => hash.startsWith(prefix));
  const offsets = {};
  let offset = 0;
  for (const hash of hashes) {
    const length = blobs.get(hash).length;
    offsets[hash] = [offset, length];
    offset += length;
  }
  return {
    pk: Buffer.concat(hashes.map(hash => blobs.get(hash))),
    idx: {
      format: STORE_FORMAT,
      version: STORE_VERSION,
      blobs: offsets,
    },
  };
}
