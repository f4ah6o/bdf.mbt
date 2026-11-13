// Read-only hypothetical repacking. No fixture is removed or selected by tests.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readdir, readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import { gzipSync } from 'node:zlib';
import path from 'node:path';
import { buildPack, decodeFixtureBytes, encodeFixtureText, FIXTURE_FORMAT, FIXTURE_VERSION, loadFixture, packFixture, resolveFixture } from '../fixtures.mjs';

const { values } = parseArgs({ options: { receipt: { type: 'string' } } });
if (!values.receipt) throw Error('--receipt <completed-generation-identity.json> required');
const receipt = JSON.parse(await readFile(values.receipt));
if (receipt.version !== 1 || receipt.upstream !== 'a5e4d7a6b202cfe73de44b0be51f6fb86cd8ee22' || receipt.go !== 'go1.27.0' || receipt.goos !== 'linux' || receipt.goarch !== 'arm64' || receipt.goarm64 !== 'v8.0' || receipt.binarySha256 !== '6425c89b0af6753bfc03735695f655e7d4d11c7fcaab33b325049fe2b6fc7035' || !receipt.inputSeeds || Array.isArray(receipt.inputSeeds) || Object.keys(receipt.inputSeeds).length !== 76 || !receipt.retainedInputs || Array.isArray(receipt.retainedInputs)) throw Error('Expected completed pinned ARM64 receipt');
const retained = JSON.parse(await readFile(new URL('./retained-inputs.manifest', import.meta.url)));
const proposal = JSON.parse(await readFile(new URL('./notes-static-proposal.manifest', import.meta.url)));
if (proposal.status !== 'proposal-not-active' || proposal.files.length !== 3) throw Error('Expected inactive notes proposal');
const noteNames = proposal.files.map(x => x.file);
const retainedNames = retained.map(x => x.file);
assert.equal(retainedNames.length, 26);
assert.equal(new Set(retainedNames).size, retainedNames.length);
assert.deepEqual(Object.keys(receipt.retainedInputs).sort(), [...retainedNames].sort());
for (const entry of retained) assert.equal(receipt.retainedInputs[entry.file], entry.sha256, `retained identity ${entry.file}`);
for (const [name, hash] of Object.entries(receipt.inputSeeds)) {
  if (!/^[A-Za-z0-9_-]+\.json$/.test(name) || !/^[a-f0-9]{64}$/.test(hash)) throw Error('Invalid seed identity');
}
const sha = x => createHash('sha256').update(x).digest('hex');
const fixtures = fileURLToPath(new URL('../', import.meta.url));
const files = (await readdir(fixtures, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
const storeFiles = (await readdir(path.join(fixtures, 'store'))).filter(f => /\.(idx|pk)$/.test(f)).sort();
async function totalSize(dir, names) { let total = 0; for (const name of names) total += (await stat(path.join(dir, name))).size; return total; }
const current = { fixtureFiles: files.length, fixtureBytes: await totalSize(fixtures, files), storeFiles: storeFiles.length, storeBytes: await totalSize(path.join(fixtures, 'store'), storeFiles) };
current.totalBytes = current.fixtureBytes + current.storeBytes;
const required = [...new Set([...noteNames, ...retainedNames, 'base-border-tint-too-large.json'])].sort();
const conservative = [...new Set([...required, ...Object.keys(receipt.inputSeeds)])].sort();
const currentNotesManifestBytes = await totalSize(fixtures, noteNames);
let seedFilesWithBdf = 0, seedBdfCases = 0, seedBdfCasesOutsideNotes = 0;
const inputOnlySeedNames = [];
for (const name of Object.keys(receipt.inputSeeds)) {
  const value = await loadFixture('./' + name);
  const entries = Array.isArray(value) ? value : [value];
  const count = entries.filter(entry => entry && typeof entry === 'object' && !Array.isArray(entry) && typeof entry.bdf === 'string').length;
  if (count) seedFilesWithBdf++;
  else {
    assert.ok(entries.every(entry => typeof entry === 'string' || entry && typeof entry === 'object' && !Array.isArray(entry) && typeof entry.input === 'string' && Object.keys(entry).every(k => ['input', 'label', 'mode', 'no_index', 'variant'].includes(k))), `unclassified seed ${name}`);
    inputOnlySeedNames.push(name);
  }
  seedBdfCases += count;
  if (!noteNames.includes(name)) seedBdfCasesOutsideNotes += count;
}
assert.equal(inputOnlySeedNames.length, 44);

async function repack(names) {
  const manifests = new Map(), originals = new Map(), blobs = new Map();
  for (const name of names) {
    const value = await loadFixture('./' + name);
    if (receipt.inputSeeds[name]) assert.equal(sha(JSON.stringify(value)), receipt.inputSeeds[name], `seed identity ${name}`);
    const retainedEntry = retained.find(entry => entry.file === name);
    if (retainedEntry) assert.equal(sha(JSON.stringify(value)), retainedEntry.sha256, `retained value ${name}`);
    const note = proposal.files.find(x => x.file === name);
    if (note) assert.equal(sha(JSON.stringify(value)), note.sha256, `note identity ${name}`);
    const { packed, blobs: parts } = packFixture(value);
    for (const [hash, bytes] of parts) blobs.set(hash, bytes);
    originals.set(name, value);
    const encoded = parts.size === 0 ? Buffer.from(JSON.stringify(value)) : encodeFixtureText(JSON.stringify({ format: FIXTURE_FORMAT, version: FIXTURE_VERSION, blobs: parts.size, root: packed }));
    manifests.set(name, encoded);
  }
  const packs = new Map();
  const prefixes = [...new Set([...blobs.keys()].map(h => h.slice(0, 2)))].sort();
  for (const prefix of prefixes) {
    const group = new Map([...blobs].filter(([hash]) => hash.startsWith(prefix)));
    const { pk, idx } = buildPack(prefix, group), gz = gzipSync(pk);
    packs.set(`./${prefix}.pk`, gz.length < pk.length ? gz : pk);
    packs.set(`./${prefix}.idx`, Buffer.from(JSON.stringify(idx)));
  }
  const readStore = async name => packs.get(name) ?? null;
  const cache = new Map();
  for (const [name, encoded] of manifests) {
    const parsed = JSON.parse(decodeFixtureBytes(encoded, name));
    assert.ok(isDeepStrictEqual(await resolveFixture(parsed, name, { readStore, cache }), originals.get(name)), `repacked fixture mismatch ${name}`);
  }
  const manifestBytes = [...manifests.values()].reduce((n, b) => n + b.length, 0);
  const storeBytes = [...packs.values()].reduce((n, b) => n + b.length, 0);
  return { files: names.length, manifestBytes, storeBytes, totalBytes: manifestBytes + storeBytes, blobs: blobs.size, allValuesRoundTripExactly: true };
}
const notesOnly = await repack(noteNames);
const notesAndRetained = await repack(required);
const inputOnlyCandidate = await repack([...new Set([...required, ...inputOnlySeedNames])].sort());
const conservativeCurrentSeeds = await repack(conservative);
console.log(JSON.stringify({ diagnosticOnly: true, proposalActive: false, scope: 'fixture JSON manifests plus .idx/.pk bytes; excludes scripts, binary, runtime seeds, emulator and generated outputs', limitation: 'No loader or seed exporter is changed; the reduced-seed scenario requires separate generation and verifier coverage evidence.', current, currentNotesManifestBytes, notesOnly, notesAndRetained, inputOnlyCandidate, conservativeCurrentSeeds, inputOnlySeedFiles: inputOnlySeedNames.length, inputOnlySeedNames: [...inputOnlySeedNames].sort(), inputOnlySeedManifestSha256: sha(JSON.stringify(Object.fromEntries(inputOnlySeedNames.sort().map(name => [name, receipt.inputSeeds[name]])))), receiptSeedFiles: Object.keys(receipt.inputSeeds).length, retainedFiles: retainedNames.length, seedFilesWithBdf, seedBdfCases, seedBdfCasesOutsideNotes }, null, 2));
