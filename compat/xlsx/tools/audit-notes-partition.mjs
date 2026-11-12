// Hypothetical, read-only inventory proof. This does not activate a loader or
// establish that generated expectations pass the migration gate.
import assert from 'node:assert/strict';
import { readdir, readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { isDeepStrictEqual, parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { loadFixture } from '../fixtures.mjs';
import { CaseTracker, shardIndex } from '../shard.mjs';

const { values } = parseArgs({ options: { generated: { type: 'string' }, ids: { type: 'string' }, shards: { type: 'string', default: '8' } } });
if (!values.generated || !values.ids) throw Error('--generated <fixture-root> --ids <verify-render --list output> [--shards n] required');
const count = Number(values.shards);
if (!Number.isSafeInteger(count) || count < 1 || count > 128) throw Error('Invalid shard count');
const root = fileURLToPath(new URL('../', import.meta.url));
const files = (await readdir(root, { recursive: true })).filter(f => f.endsWith('.json') && !f.startsWith('store/')).sort();
const proposal = JSON.parse(await readFile(new URL('./notes-static-proposal.manifest', import.meta.url)));
const notes = new Map(proposal.files.map(entry => [entry.file, entry]));
assert.equal(proposal.status, 'proposal-not-active');
assert.equal(notes.size, 3);
const retained = JSON.parse(await readFile(new URL('./retained-inputs.manifest', import.meta.url)));
const retainedNames = new Set(retained.map(entry => entry.file));
const full = new Set(), staticNotes = new Set(), retainedInputs = new Set(), other = new Set();
let notesCount = 0;
for (const file of files) {
  const before = await loadFixture('./' + file);
  const after = JSON.parse(await readFile(path.join(values.generated, 'compat/xlsx', file)));
  if (notes.has(file)) {
    const entry = notes.get(file), text = JSON.stringify(before);
    assert.ok(Array.isArray(before));
    assert.equal(before.length, entry.cases);
    assert.equal(Buffer.byteLength(text), entry.serializedBytes);
    assert.equal(createHash('sha256').update(text).digest('hex'), entry.sha256);
    assert.equal(before.length, after.length);
    for (let i = 0; i < before.length; i++) {
      const { bdf: oldBdf, ...oldInput } = before[i], { bdf: newBdf, ...newInput } = after[i];
      assert.equal(typeof oldBdf, 'string'); assert.equal(typeof newBdf, 'string');
      assert.deepEqual(oldInput, newInput, `${file} input/options ${i}`);
    }
    notesCount += before.length;
  } else {
    assert.ok(isDeepStrictEqual(before, after), `Non-notes file differs: ${file}`);
  }
  // Arrays represent ordered fixture entries; scalar/object roots are one
  // inventory unit. These IDs describe fixture data, not verifier execution.
  const size = Array.isArray(before) ? before.length : 1;
  const target = notes.has(file) ? staticNotes : retainedNames.has(file) ? retainedInputs : other;
  for (let i = 0; i < size; i++) {
    const id = JSON.stringify([file, i]);
    assert.ok(!full.has(id)); full.add(id); target.add(id);
  }
}
assert.equal(notesCount, 264);
const union = new Set([...staticNotes, ...retainedInputs, ...other]);
assert.equal(union.size, staticNotes.size + retainedInputs.size + other.size, 'partitions overlap');
assert.deepEqual(union, full, 'fixture inventory union differs');

// These are actual --list labels from the sharded verifier, not fixture IDs.
// The 264 notes cases belong to a separate unsharded verifier.
const ids = (await readFile(values.ids, 'utf8')).split('\n').filter(Boolean);
assert.ok(ids.length > 0); assert.equal(new Set(ids).size, ids.length);
const owners = new Map(); const shardSizes = [];
for (let i = 0; i < count; i++) {
  const tracker = new CaseTracker({ list: false, shard: { index: i, count }, ids: null });
  for (const id of ids) tracker.enter(id);
  for (const id of tracker.ran) { assert.ok(!owners.has(id)); owners.set(id, i); assert.equal(shardIndex(id, count), i); }
  shardSizes.push(tracker.ran.length);
}
assert.equal(owners.size, ids.length);
for (const id of ids) assert.ok(owners.has(id));
console.log(JSON.stringify({ diagnosticOnly: true, activated: false, fixtureInventory: { files: files.length, units: full.size, notesCases: staticNotes.size, retainedInputUnits: retainedInputs.size, otherFixtureUnits: other.size, unionExact: true, disjoint: true }, renderVerifier: { listedIds: ids.length, shardCount: count, shardSizes, unionExact: true, disjoint: true, notesShardedHere: false }, separateNotesVerifier: { cases: notesCount, sharded: false } }, null, 2));
