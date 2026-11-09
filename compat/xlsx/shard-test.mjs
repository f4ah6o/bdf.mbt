// Failure-detection checks for the shard aggregator.
//
// Each case runs runSharded against a fake child, so the aggregate verdict can
// be tested without the 144k-case fixture run. The point is that a shard that
// fails, dies, times out, or silently drops cases must never be reported as a
// successful run.

import assert from 'node:assert/strict';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { runSharded, shardIndex } from './shard.mjs';

const FAKE = String.raw`
import { writeFileSync } from 'node:fs';
const spec = JSON.parse(process.env.FAKE_SPEC);
const argv = process.argv.slice(2);
const idsPath = argv[argv.indexOf('--ids') + 1];
const shardArg = argv.includes('--shard') ? argv[argv.indexOf('--shard') + 1] : null;
const summary = (shard, seen, ran) =>
  'verify-render-shard: shard=' + shard + ' seen=' + seen + ' ran=' + ran + ' skipped=0 repeats=0\n';
if (argv.includes('--list')) {
  if (spec.failList) process.exit(1);
  writeFileSync(idsPath, spec.ids.map((id) => id + '\n').join(''));
  process.stderr.write(summary('all', spec.ids.length, 0));
  process.exit(0);
}
const [index, count] = shardArg.split('/').map(Number);
let mine = spec.ids.filter((_, k) => k % count === index);
if (spec.dropShard === index) mine = mine.slice(1);
if (spec.dupShard === index) mine = [...mine, spec.ids[0]];
if (spec.failShard === index) process.exit(1);
if (spec.hangShard === index) await new Promise((resolve) => setTimeout(resolve, 60000));
if (!spec.noIds) writeFileSync(idsPath, mine.map((id) => id + '\n').join(''));
if (!spec.noSummary) process.stderr.write(summary(shardArg, spec.ids.length, mine.length));
process.exit(0);
`;

const dir = mkdtempSync(join(tmpdir(), 'shard-test-'));
const fake = join(dir, 'fake.mjs');
writeFileSync(fake, FAKE);
const ids = Array.from({ length: 40 }, (_, k) => `case ${k}`);

async function run(spec, env = {}) {
  const saved = new Map();
  for (const [key, value] of Object.entries({ FAKE_SPEC: JSON.stringify({ ids, ...spec }), ...env })) {
    saved.set(key, process.env[key]);
    process.env[key] = value;
  }
  try {
    return await runSharded(fake);
  } finally {
    for (const [key, value] of saved) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  }
}

async function rejects(spec, pattern, env = {}) {
  await assert.rejects(run(spec, { VERIFY_RENDER_SHARDS: '4', ...env }), pattern);
}

// The ID hash must be stable across calls and stay inside the shard range.
assert.equal(shardIndex('picture simple-picture.json 0', 8), shardIndex('picture simple-picture.json 0', 8));
for (const count of [1, 3, 8, 64]) {
  const index = shardIndex('picture simple-picture.json 0', count);
  assert.ok(index >= 0 && index < count, `shardIndex out of range for ${count}`);
}

// A clean run reports the full case count.
const clean = await run({}, { VERIFY_RENDER_SHARDS: '4' });
assert.equal(clean.total, ids.length, 'clean run must cover every case');
assert.equal(clean.count, 4, 'clean run must use the requested shard count');

// Every way a shard can go wrong must fail the aggregate.
await rejects({ failList: true }, /--list failed/);
await rejects({ failShard: 2 }, /shard 2\/4 exit 1/);
await rejects({ noSummary: true }, /printed no summary line/);
await rejects({ noIds: true }, /wrote no ID file/);
await rejects({ dropShard: 1 }, /ran in no shard/);
await rejects({ dupShard: 1 }, /ran in shards/);
await rejects({ hangShard: 3 }, /timed out/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: '500' });
// More shards than cases leaves some shards empty. That is still a complete
// run as long as the union of the shard ID sets covers every case.
const sparse = await run({}, { VERIFY_RENDER_SHARDS: '50' });
assert.equal(sparse.total, ids.length, 'sparse sharding must still cover every case');

rmSync(dir, { recursive: true, force: true });
console.log('shard aggregator failure detection verified.');
