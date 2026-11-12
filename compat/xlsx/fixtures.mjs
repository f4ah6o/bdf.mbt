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
//   {"format":"bdf-xlsx-fixture","version":1,"blobs":12,"root": <original JSON
//   value with markers instead of the extracted strings>}
//
// where every marker is {"$blob": "<64 lowercase hex chars>"}.
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
import { gunzipSync } from 'node:zlib';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';

export const FIXTURE_FORMAT = 'bdf-xlsx-fixture';
export const FIXTURE_VERSION = 1;
export const STORE_FORMAT = 'bdf-xlsx-store';
export const STORE_VERSION = 1;
export const BLOB_MARKER = '$blob';
export const STORE_DIR = new URL('./store/', import.meta.url);

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
// keep.
async function packFor(prefix, { storeDir, cache }) {
  const key = `${storeDir.href}|${prefix}`;
  if (cache?.has(key)) return cache.get(key);
  let pk;
  try {
    pk = await readFile(new URL(`./${prefix}.pk`, storeDir));
  } catch (error) {
    if (error?.code === 'ENOENT') {
      const empty = { bytes: Buffer.alloc(0), offsets: new Map() };
      cache?.set(key, empty);
      return empty;
    }
    throw error;
  }
  const idx = JSON.parse(await readFile(new URL(`./${prefix}.idx`, storeDir), 'utf8'));
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
export async function readBlob(hash, { storeDir = STORE_DIR, cache = sharedCache } = {}) {
  if (!isBlobHash(hash)) throw new Error(`invalid blob hash ${JSON.stringify(hash)}`);
  const prefix = hash.slice(0, 2);
  const pack = await packFor(prefix, { storeDir, cache });
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
export async function resolveFixture(parsed, source, { storeDir = STORE_DIR, cache = sharedCache } = {}) {
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
export async function loadFixture(target, { storeDir = STORE_DIR, cache = sharedCache } = {}) {
  const url = target instanceof URL ? target : new URL(target, import.meta.url);
  const source = fileURLToPath(url);
  if (typeof target === 'string' && !target.startsWith('.')) {
    throw new Error(`loadFixture wants a fixture path relative to this directory, got ${JSON.stringify(target)}`);
  }
  const parsed = JSON.parse(await readFile(url, 'utf8'));
  return resolveFixture(parsed, source, { storeDir, cache });
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
