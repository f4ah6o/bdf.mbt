// Baseline measurement for the XLSX compatibility fixtures: size, base64 blob
// duplication, and the storage sizes that alternative storage schemes would
// need. Reads every fixture at run time; nothing is hardcoded.

import { readFileSync, readdirSync, statSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { gzipSync, brotliCompressSync } from 'node:zlib';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
import path from 'node:path';
import process from 'node:process';

const MiB = 1024 * 1024;

// A string is a "blob candidate" only when it clears all three thresholds:
// long enough to be worth storing out-of-line, a canonical base64 round-trip
// (the same rule a future packer would use, so plain text never qualifies),
// and at least 1024 decoded bytes.
const BLOB_MIN_CHARS = 128;
const BLOB_MIN_BYTES = 1024;

// The fixture keys whose values represent the input XLSX and the expected BDF
// bytes; reported separately as duplicate-pressure examples per the issue.
const CASED_KEYS = ['input', 'bdf'];

const parseArgs = (argv) => {
  const options = { jsonPath: null, quick: false, errors: [] };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i] === '--quick') options.quick = true;
    else if (argv[i] === '--json') {
      if (i + 1 >= argv.length) options.errors.push('--json requires an output path');
      else options.jsonPath = argv[++i];
    } else if (argv[i].startsWith('--json=')) options.jsonPath = argv[i].slice(7);
    else options.errors.push(`unknown argument: ${argv[i]}`);
  }
  return options;
};

const sha256Hex = (buf) => createHash('sha256').update(buf).digest('hex');

// Canonical base64 test: decoding must succeed and re-encode to the exact
// input string, so padding quirks or appended garbage reject the string.
// Buffer.from never throws on invalid base64, hence the round-trip check.
const decodeCanonicalBase64 = (text) => {
  const decoded = Buffer.from(text, 'base64');
  return decoded.toString('base64') === text ? decoded : null;
};

const mib = (bytes) => (bytes / MiB).toFixed(3);

// Enumerate every fixture JSON: compat/xlsx/*.json plus compat/xlsx/render/*.json
// (including render/index.json); remove the rendered-pictures dir; README.md and
// other extensions (and the tool scripts themselves) never carry the .json name.
const enumerateFixtures = (root) => {
  const files = [];
  for (const entry of readdirSync(root, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.json')) files.push({ name: entry.name, group: 'top' });
  }
  const renderDir = path.join(root, 'render');
  for (const entry of readdirSync(renderDir, { withFileTypes: true })) {
    if (entry.isFile() && entry.name.endsWith('.json')) files.push({ name: path.join('render', entry.name), group: 'render' });
  }
  files.sort((a, b) => (a.group === b.group ? a.name.localeCompare(b.name) : a.group === 'top' ? -1 : 1));
  return files;
};

// Walk one parsed fixture value: classify every string occurrence, collect the
// intra-file dedup stats, register the decoded bytes in the global store, and
// return the same value with each blob candidate replaced by its marker so the
// caller can measure the size of the remaining inline JSON.
const walkValue = (value, key, fileStats, globalBlobs) => {
  if (typeof value === 'string') {
    const cased = CASED_KEYS.includes(key);
    // Only decode strings that could matter: blob candidates by length, and
    // input/bdf values of any size for the keyed duplicate statistics.
    // Strings shorter than BLOB_MIN_CHARS cannot reach the 1024-byte anomaly
    // threshold either, so they never need decoding.
    if (value.length < BLOB_MIN_CHARS && !cased) return value;
    const decoded = decodeCanonicalBase64(value);
    if (decoded === null) {
      // Long but not base64: plain JSON content that a blob store would keep
      // inline; counted so the report can call out unusual files.
      if (value.length >= 1024) fileStats.longNonBlobStrings += 1;
      return value;
    }
    if (cased) {
      fileStats.keyed[key].occurrences += 1;
      fileStats.keyed[key].occurrenceBytes += decoded.length;
      const hash = sha256Hex(decoded);
      if (!fileStats.keyed[key].distinct.has(hash)) {
        fileStats.keyed[key].distinct.set(hash, decoded.length);
      }
    }
    if (value.length >= BLOB_MIN_CHARS && decoded.length >= BLOB_MIN_BYTES) {
      const hash = sha256Hex(decoded);
      fileStats.blobOccurrences += 1;
      fileStats.blobOccurrenceBytes += decoded.length;
      if (!fileStats.intraDistinct.has(hash)) fileStats.intraDistinct.set(hash, decoded.length);
      if (!globalBlobs.has(hash)) globalBlobs.set(hash, Buffer.from(decoded));
      return { $blob: hash };
    }
    return value;
  }
  if (Array.isArray(value)) return value.map((item) => walkValue(item, key, fileStats, globalBlobs));
  if (value !== null && typeof value === 'object') {
    const marked = {};
    for (const [k, v] of Object.entries(value)) marked[k] = walkValue(v, k, fileStats, globalBlobs);
    return marked;
  }
  return value;
};

const emptyKeyStat = () => ({ occurrences: 0, occurrenceBytes: 0, distinct: new Map(), distinctCount: 0, distinctBytes: 0 });

const processFile = (absPath, relativeName, group, globalBlobs) => {
  const fileStats = {
    file: `compat/xlsx/${relativeName}`,
    group,
    onDiskBytes: 0,
    gzippedBytes: 0,
    cases: null,
    blobOccurrences: 0,
    blobOccurrenceBytes: 0,
    intraDistinct: new Map(), // sha256 hex -> decoded size, intra-file only
    intraDistinctCount: 0,
    intraDistinctBytes: 0,
    inlineJsonBytes: 0,
    longNonBlobStrings: 0,
    keyed: Object.fromEntries(CASED_KEYS.map((k) => [k, emptyKeyStat()])),
    error: null,
  };
  const raw = readFileSync(absPath);
  fileStats.onDiskBytes = statSync(absPath).size;
  // Alternative (b): every file gzipped whole, as-is.
  fileStats.gzippedBytes = gzipSync(raw).length;
  try {
    const parsed = JSON.parse(raw.toString('utf8'));
    fileStats.cases = Array.isArray(parsed) ? parsed.length : null;
    const marked = walkValue(parsed, null, fileStats, globalBlobs);
    // Inline JSON for the blob-store alternatives: the file re-serialized with
    // each blob candidate replaced by a {"$blob":"<sha256 hex>"} marker.
    fileStats.inlineJsonBytes = Buffer.byteLength(JSON.stringify(marked));
  } catch (error) {
    fileStats.error = String(error);
  }
  fileStats.intraDistinctCount = fileStats.intraDistinct.size;
  fileStats.intraDistinctBytes = [...fileStats.intraDistinct.values()].reduce((sum, n) => sum + n, 0);
  for (const k of CASED_KEYS) {
    const keyed = fileStats.keyed[k];
    keyed.distinctCount = keyed.distinct.size;
    keyed.distinctBytes = [...keyed.distinct.values()].reduce((sum, n) => sum + n, 0);
  }
  // The mutable Maps stay out of the entry that is serialized to the report.
  const { intraDistinct, keyed, ...rest } = fileStats;
  void intraDistinct;
  return { ...rest, keyed: Object.fromEntries(CASED_KEYS.map((k) => {
    const { distinct, ...stats } = fileStats.keyed[k];
    void distinct;
    return [k, stats];
  })) };
};

const renderMarkdown = (results) => {
  const lines = [];
  const { meta, totals, alternatives, files } = results;
  lines.push('# `compat/xlsx` fixture storage measurements', '');
  lines.push(`Generated: ${meta.timestamp}`, `Node: ${meta.nodeVersion}, platform: ${meta.platform}, arch: ${meta.arch}`, `CPU: ${meta.cpuModel}`, '');
  lines.push('## Totals', '');
  lines.push('| metric | bytes | MiB |', '| --- | ---: | ---: |');
  for (const [label, value] of [
    ['JSON files (on disk)', totals.jsonBytes],
    ['blob candidate occurrences (decoded)', totals.blobOccurrenceBytes],
    ['intra-file dedup blobs (decoded)', totals.intraDistinctBytes],
    ['global distinct blobs (decoded)', totals.globalDistinctBytes],
    ['inline JSON with blob markers (all files)', totals.inlineJsonBytes],
  ]) lines.push(`| ${label} | ${value} | ${mib(value)} |`);
  lines.push(`| blob occurrences | ${totals.blobOccurrences} | |`, `| global distinct count | ${totals.globalDistinctCount} | |`, `| total cases | ${totals.cases} | |`, '');
  lines.push('## Storage alternatives (whole-fixture sizes)', '');
  lines.push('| id | scheme | bytes | MiB | % of current |', '| --- | --- | ---: | ---: | ---: |');
  for (const alt of Object.values(alternatives)) {
    if (!alt) continue;
    lines.push(`| ${alt.id} | ${alt.description} | ${alt.bytes} | ${mib(alt.bytes)} | ${((alt.bytes / totals.jsonBytes) * 100).toFixed(1)}% |`);
  }
  lines.push('', '(g) concatenates the distinct blobs in first-seen order; a real pack format would add offset bookkeeping on top of the gzip bytes.', '');
  lines.push('## Representative fixtures', '');
  for (const [name, rep] of Object.entries(results.representatives)) {
    lines.push(`### ${name}`, '');
    lines.push(`- cases: ${rep.cases}`);
    for (const key of CASED_KEYS) {
      lines.push(`- ${key}: ${rep.keyed[key].occurrences} occurrences (${mib(rep.keyed[key].occurrenceBytes)} MiB decoded), ${rep.keyed[key].distinctCount} distinct (${mib(rep.keyed[key].distinctBytes)} MiB decoded)`);
    }
    lines.push('');
  }
  lines.push('## Files (top 40 by on-disk size)', '');
  lines.push('| file | group | cases | on-disk MiB | blob-occurrence MiB | intra-dedup MiB |', '| --- | --- | ---: | ---: | ---: | ---: |');
  for (const f of results.topFiles) {
    lines.push(`| ${f.file} | ${f.group} | ${f.cases ?? '-'} | ${mib(f.onDiskBytes)} | ${mib(f.blobOccurrenceBytes)} | ${mib(f.intraDistinctBytes)} |`);
  }
  lines.push('', '## Timing and memory', '');
  lines.push(`- aggregation wall time: ${(meta.aggregationMs / 1000).toFixed(1)} s (enumerate, parse, classify, dedup, per-file gzip)`);
  if (meta.compressionMs !== null) lines.push(`- blob compression passes (e/f/g) wall time: ${(meta.compressionMs / 1000).toFixed(1)} s`);
  lines.push(`- total wall time: ${(meta.totalMs / 1000).toFixed(1)} s`);
  lines.push(`- final RSS: ${meta.memory.rss} bytes (${(meta.memory.rss / MiB).toFixed(1)} MiB), heapUsed: ${meta.memory.heapUsed} bytes (${(meta.memory.heapUsed / MiB).toFixed(1)} MiB)`, '');
  const anomalies = files.filter((f) => f.error || f.longNonBlobStrings > 0);
  lines.push('## Anomalies', '');
  if (anomalies.length === 0) lines.push('None: every fixture parsed and no long non-base64 strings were found.', '');
  else {
    for (const f of anomalies) {
      if (f.error) lines.push(`- ${f.file}: parse failed: ${f.error}`);
      else lines.push(`- ${f.file}: ${f.longNonBlobStrings} strings of >=1024 chars that are not base64`);
    }
    lines.push('');
  }
  return lines.join('\n');
};

const main = () => {
  const argv = process.argv.slice(2);
  const options = parseArgs(argv);
  if (options.errors.length > 0) {
    process.stderr.write(`usage: node compat/xlsx/tools/measure-fixtures.mjs [--json out.json] [--quick]\n`);
    for (const error of options.errors) process.stderr.write(`${error}\n`);
    process.exitCode = 1;
    return;
  }
  const fixturesRoot = path.join(path.dirname(fileURLToPath(import.meta.url)), '..');
  const totalStart = process.hrtime.bigint();
  const globalBlobs = new Map(); // sha256 hex -> decoded bytes, insertion order = first seen
  const files = [];
  let aggregationNanos = 0n;
  for (const f of enumerateFixtures(fixturesRoot)) {
    const fileStart = process.hrtime.bigint();
    files.push(processFile(path.join(fixturesRoot, f.name), f.name, f.group, globalBlobs));
    aggregationNanos += process.hrtime.bigint() - fileStart;
  }
  const totals = {
    fileCount: files.length,
    jsonBytes: files.reduce((sum, f) => sum + f.onDiskBytes, 0),
    gzippedBytes: files.reduce((sum, f) => sum + f.gzippedBytes, 0),
    cases: files.reduce((sum, f) => sum + (f.cases ?? 0), 0),
    blobOccurrences: files.reduce((sum, f) => sum + f.blobOccurrences, 0),
    blobOccurrenceBytes: files.reduce((sum, f) => sum + f.blobOccurrenceBytes, 0),
    intraDistinctBytes: files.reduce((sum, f) => sum + f.intraDistinctBytes, 0),
    inlineJsonBytes: files.reduce((sum, f) => sum + f.inlineJsonBytes, 0),
  };
  totals.globalDistinctCount = globalBlobs.size;
  totals.globalDistinctBytes = [...globalBlobs.values()].reduce((sum, buf) => sum + buf.length, 0);

  // Storage alternatives on dedup sets; (e)-(g) compress each stored blob so
  // --quick skips them, and the pack for (g) follows first-seen insertion order.
  const alt = (id, description, bytes) => ({ id, description, bytes });
  const alternatives = {
    a: alt('a', 'current JSON files as-is', totals.jsonBytes),
    b: alt('b', 'gzip each JSON file', totals.gzippedBytes),
    c: alt('c', 'binary blobs deduped within file + inline JSON', totals.intraDistinctBytes + totals.inlineJsonBytes),
    d: alt('d', 'binary blobs deduped globally + inline JSON', totals.globalDistinctBytes + totals.inlineJsonBytes),
  };
  let compressionNanos = null;
  if (!options.quick && totals.globalDistinctCount > 0) {
    const compressionStart = process.hrtime.bigint();
    let gzipBytes = 0;
    let brotliBytes = 0;
    for (const buf of globalBlobs.values()) {
      gzipBytes += gzipSync(buf).length;
      brotliBytes += brotliCompressSync(buf).length;
    }
    const pack = Buffer.concat([...globalBlobs.values()]);
    const packGzipBytes = gzipSync(pack).length;
    alternatives.e = alt('e', 'd + gzip each distinct blob', gzipBytes + totals.inlineJsonBytes);
    alternatives.f = alt('f', 'd + brotli each distinct blob', brotliBytes + totals.inlineJsonBytes);
    alternatives.g = alt('g', 'all distinct blobs concatenated, single gzip + inline JSON', packGzipBytes + totals.inlineJsonBytes);
    compressionNanos = process.hrtime.bigint() - compressionStart;
  }

  const representatives = {};
  for (const name of ['conditional-top.json', 'simple-picture.json']) {
    const f = files.find((entry) => entry.file === `compat/xlsx/${name}`);
    if (f) representatives[name] = { cases: f.cases, keyed: f.keyed };
  }

  const totalNanos = process.hrtime.bigint() - totalStart;
  const memory = process.memoryUsage();
  const cpus = os.cpus();
  const results = {
    meta: {
      timestamp: new Date().toISOString(),
      nodeVersion: process.version,
      platform: os.platform(),
      arch: os.arch(),
      release: os.release(),
      cpuModel: cpus.length > 0 ? cpus[0].model : 'unknown',
      cpuCount: cpus.length,
      argv,
      quick: options.quick,
      aggregationMs: Number(aggregationNanos / 1000000n),
      compressionMs: compressionNanos === null ? null : Number(compressionNanos / 1000000n),
      totalMs: Number(totalNanos / 1000000n),
      memory: { rss: memory.rss, heapUsed: memory.heapUsed, heapTotal: memory.heapTotal, external: memory.external },
    },
    totals,
    alternatives,
    representatives,
    topFiles: [...files].sort((a, b) => b.onDiskBytes - a.onDiskBytes).slice(0, 40),
    files,
  };
  if (options.jsonPath) writeFileSync(options.jsonPath, `${JSON.stringify(results, null, 2)}\n`);
  process.stdout.write(renderMarkdown(results));
};

main();
