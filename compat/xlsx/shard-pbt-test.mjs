// Generated and regression tests for the XLSX render shard aggregator.
//
// Fixed seed: 0x5eed2026. The independent oracle is a BigInt FNV-1a over
// TextEncoder bytes; the implementation uses 32-bit Math.imul over Buffer
// bytes. They must agree for every generated ID and shard count.
//
// The fake child imports the real shardIndex, so the partition tests exercise
// the same hash the production child uses. Failure modes are injected through
// FAKE_SPEC instead of mocking runSharded's internals.

import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { availableParallelism, tmpdir } from 'node:os';
import { join } from 'node:path';
import { CaseTracker, parseArgs, runSharded, shardCount, shardIndex } from './shard.mjs';

const SEED = 0x5eed2026;
const SEED_TEXT = '0x5eed2026';
const SHARD_URL = new URL('./shard.mjs', import.meta.url).href;

function mulberry32(seed) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

const rand = mulberry32(SEED);
const pick = (items) => items[Math.floor(rand() * items.length)];
const shuffle = (items) => {
  const copy = [...items];
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [copy[i], copy[j]] = [copy[j], copy[i]];
  }
  return copy;
};

const encoder = new TextEncoder();
function oracleShardIndex(id, count) {
  let hash = 0x811c9dc5n;
  for (const byte of encoder.encode(String(id))) {
    hash ^= BigInt(byte);
    hash = (hash * 0x01000193n) & 0xffffffffn;
  }
  return Number(hash % BigInt(count));
}

const fixedIds = [
  '',
  'a',
  'case 0',
  'picture simple-picture.json 0',
  '日本語',
  '🙂',
  'a #2',
  'a #3',
  'x'.repeat(200),
  'tab\there',
  'slash/back\\slash',
  'percent%20',
  'nul\0byte',
];
const alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 #%/_-.\\\t日本語🙂';
function randomId() {
  const length = Math.floor(rand() * 48);
  let text = '';
  for (let i = 0; i < length; i++) text += pick([...alphabet]);
  return text;
}
const generatedIds = [...fixedIds];
while (generatedIds.length < 160) generatedIds.push(randomId());
const uniqueIds = [...new Set(generatedIds)];
assert.ok(uniqueIds.length >= 120, `seed ${SEED_TEXT}: generator produced too few unique IDs`);

let checks = 0;
const ok = (message) => {
  checks++;
  if (process.env.SHARD_PBT_VERBOSE) console.log(`ok ${checks} - ${message}`);
};

// 1. The independent oracle and the implementation agree, and every index is
//    inside the requested range.
for (const [caseIndex, id] of generatedIds.entries()) {
  const count = 1 + Math.floor(rand() * 16);
  const actual = shardIndex(id, count);
  const expected = oracleShardIndex(id, count);
  assert.equal(
    actual,
    expected,
    `seed ${SEED_TEXT} case ${caseIndex}: shardIndex(${JSON.stringify(id)}, ${count})`,
  );
  assert.ok(
    Number.isInteger(actual) && actual >= 0 && actual < count,
    `seed ${SEED_TEXT} case ${caseIndex}: index ${actual} out of range for ${count}`,
  );
}
ok('generated IDs match the independent BigInt FNV-1a oracle');

// 2. Exhaustive and disjoint partitions for several shard counts. The oracle
//    builds the expected buckets independently of shardIndex.
for (const count of [1, 2, 3, 4, 5, 7, 8, 16, 64]) {
  const ids = uniqueIds.slice(0, 80);
  const actual = Array.from({ length: count }, () => []);
  const expected = Array.from({ length: count }, () => []);
  for (const id of ids) {
    actual[shardIndex(id, count)].push(id);
    expected[oracleShardIndex(id, count)].push(id);
  }
  assert.deepEqual(actual, expected, `seed ${SEED_TEXT}: partition differs for count ${count}`);
  assert.equal(
    actual.flat().length,
    ids.length,
    `seed ${SEED_TEXT}: partition is not exhaustive for count ${count}`,
  );
  assert.deepEqual(
    [...actual.flat()].sort(),
    [...ids].sort(),
    `seed ${SEED_TEXT}: partition lost or duplicated an ID for count ${count}`,
  );
  assert.equal(
    new Set(actual.flat()).size,
    ids.length,
    `seed ${SEED_TEXT}: partition is not disjoint for count ${count}`,
  );
}
ok('generated partitions are exhaustive and disjoint for 1, 2, 3, 4, 5, 7, 8, 16 and 64 shards');

// 3. Identity is stable across calls and across a fresh process. Both matrices
//    are checked against the independent oracle, not against themselves.
const stableIds = uniqueIds.slice(0, 12);
const stableCounts = [1, 2, 3, 8, 64];
const oracleMatrix = stableIds.map((id) => stableCounts.map((count) => oracleShardIndex(id, count)));
const parentMatrix = stableIds.map((id) => stableCounts.map((count) => shardIndex(id, count)));
assert.deepEqual(parentMatrix, oracleMatrix, `seed ${SEED_TEXT}: parent shard identity differs from the oracle`);
const childScript = `
import { shardIndex } from ${JSON.stringify(SHARD_URL)};
const ids = JSON.parse(process.env.SHARD_IDS);
const counts = JSON.parse(process.env.SHARD_COUNTS);
console.log(JSON.stringify(ids.map(id => counts.map(count => shardIndex(id, count)))));
`;
const childOutput = execFileSync(process.execPath, ['--input-type=module', '-e', childScript], {
  encoding: 'utf8',
  env: { ...process.env, SHARD_IDS: JSON.stringify(stableIds), SHARD_COUNTS: JSON.stringify(stableCounts) },
});
const childMatrix = JSON.parse(childOutput.trim());
assert.deepEqual(childMatrix, oracleMatrix, `seed ${SEED_TEXT}: shard identity changed across processes`);
ok('case identity is stable across calls and processes');

// 4. Order and unrelated additions do not move an existing case when the
//    labels are unique and do not collide with a generated occurrence suffix.
//    This drives the real CaseTracker selection for every shard, not just the
//    pure hash. The collision test below documents the suffix-order limit.
const baseIds = uniqueIds.slice(0, 40);
const addedIds = uniqueIds.slice(40, 80).filter((id) => !baseIds.includes(id));
const count = 8;
function assignments(ids) {
  const owner = new Map();
  for (let index = 0; index < count; index++) {
    const tracker = new CaseTracker({ list: false, shard: { index, count }, ids: null });
    for (const id of ids) tracker.enter(id);
    for (const id of tracker.ran) {
      assert.equal(owner.has(id), false, `seed ${SEED_TEXT}: ${JSON.stringify(id)} ran in two shards`);
      owner.set(id, index);
    }
  }
  assert.equal(owner.size, ids.length, `seed ${SEED_TEXT}: shard selection lost a case`);
  return owner;
}
const sortedEntries = (map) => [...map].sort(([a], [b]) => a.localeCompare(b));
const baseAssignments = assignments(baseIds);
assert.deepEqual(
  sortedEntries(assignments(shuffle(baseIds))),
  sortedEntries(baseAssignments),
  `seed ${SEED_TEXT}: input order changed shard assignment`,
);
const extendedAssignments = assignments([...baseIds, ...addedIds]);
for (const id of baseIds) {
  assert.equal(
    extendedAssignments.get(id),
    baseAssignments.get(id),
    `seed ${SEED_TEXT}: unrelated addition moved ${JSON.stringify(id)}`,
  );
}
const reducedAssignments = assignments(baseIds.slice(5));
for (const id of baseIds.slice(5)) {
  assert.equal(
    reducedAssignments.get(id),
    baseAssignments.get(id),
    `seed ${SEED_TEXT}: unrelated removal moved ${JSON.stringify(id)}`,
  );
}
ok('order, unrelated additions and removals preserve assignment for unique non-colliding IDs');

// 5. Bad --shard input is rejected before any child is spawned.
const validArgs = [
  [[], { shard: null, list: false, ids: null }],
  [['--list'], { shard: null, list: true, ids: null }],
  [['--shard', '0/4'], { shard: { index: 0, count: 4 }, list: false, ids: null }],
  [['--shard', '3/4'], { shard: { index: 3, count: 4 }, list: false, ids: null }],
  [['--shard', '00/01'], { shard: { index: 0, count: 1 }, list: false, ids: null }],
  [['--ids', 'out.ids'], { shard: null, list: false, ids: 'out.ids' }],
  [
    ['--list', '--shard', '1/2', '--ids', 'x'],
    { shard: { index: 1, count: 2 }, list: true, ids: 'x' },
  ],
  [['--shard', '0/9007199254740991'], { shard: { index: 0, count: 9007199254740991 }, list: false, ids: null }],
  [['--shard', '9007199254740990/9007199254740991'], { shard: { index: 9007199254740990, count: 9007199254740991 }, list: false, ids: null }],
];
for (const [argv, expected] of validArgs) {
  assert.deepEqual(parseArgs(argv), expected, `valid args ${JSON.stringify(argv)}`);
}
const invalidArgs = [
  [['--shard'], /--shard wants i\/n/],
  [['--shard', ''], /--shard wants i\/n/],
  [['--shard', '1'], /--shard wants i\/n/],
  [['--shard', '1/'], /--shard wants i\/n/],
  [['--shard', '/2'], /--shard wants i\/n/],
  [['--shard', '1/2/3'], /--shard wants i\/n/],
  [['--shard', 'a/b'], /--shard wants i\/n/],
  [['--shard', '-1/2'], /--shard wants i\/n/],
  [['--shard', '1/-2'], /--shard wants i\/n/],
  [['--shard', '1.5/2'], /--shard wants i\/n/],
  [['--shard', '1/2.5'], /--shard wants i\/n/],
  [['--shard', ' 1/2'], /--shard wants i\/n/],
  [['--shard', '1/2 '], /--shard wants i\/n/],
  [['--shard', '1/2x'], /--shard wants i\/n/],
  [['--shard', '+1/2'], /--shard wants i\/n/],
  [['--shard', '1/2\n'], /--shard wants i\/n/],
  [['--shard', '2/2'], /out of range/],
  [['--shard', '0/0'], /out of range/],
  [['--shard', '1/0'], /out of range/],
  [['--shard', '9007199254740991/9007199254740991'], /out of range/],
  [['--shard', '9007199254740992/2'], /safe integer/],
  [['--shard', '1/9007199254740992'], /safe integer/],
  [['--shard', '999999999999999999999/2'], /safe integer/],
  [['--shard', '1/999999999999999999999'], /safe integer/],
  [['--shard', 'Infinity/2'], /--shard wants i\/n/],
  [['--shard', '1/Infinity'], /--shard wants i\/n/],
  [['--ids'], /--ids wants a path/],
  [['--unknown'], /unknown argument/],
  [['--shard', '1/2', 'extra'], /unknown argument/],
];
for (const [argv, pattern] of invalidArgs) {
  assert.throws(() => parseArgs(argv), pattern, `invalid args ${JSON.stringify(argv)}`);
}
assert.deepEqual(parseArgs(['--shard', '1/2', '--shard', '0/2']).shard, { index: 0, count: 2 });
assert.deepEqual(parseArgs(['--ids', 'a', '--ids', 'b']).ids, 'b');
ok('bad --shard input is rejected, including unsafe integers');

// 6. Environment shard counts are validated and the default stays bounded.
const savedShards = process.env.VERIFY_RENDER_SHARDS;
try {
  delete process.env.VERIFY_RENDER_SHARDS;
  const fallback = shardCount();
  assert.ok(
    Number.isInteger(fallback) && fallback >= 1 && fallback <= Math.min(8, availableParallelism()),
    `default shard count ${fallback} is not bounded`,
  );
  process.env.VERIFY_RENDER_SHARDS = '';
  assert.equal(shardCount(), fallback, 'empty VERIFY_RENDER_SHARDS must use the default');
  for (const [raw, expected] of [
    ['1', 1],
    ['8', 8],
    [' 4 ', 4],
    ['4.0', 4],
    ['+4', 4],
    ['04', 4],
  ]) {
    process.env.VERIFY_RENDER_SHARDS = raw;
    assert.equal(shardCount(), expected, `VERIFY_RENDER_SHARDS=${JSON.stringify(raw)}`);
  }
  for (const raw of ['0', '-1', '1.5', 'abc', 'NaN', 'Infinity', '1e309', '9007199254740992']) {
    process.env.VERIFY_RENDER_SHARDS = raw;
    assert.throws(
      () => shardCount(),
      /positive integer/,
      `VERIFY_RENDER_SHARDS=${JSON.stringify(raw)} must be rejected`,
    );
  }
} finally {
  if (savedShards === undefined) delete process.env.VERIFY_RENDER_SHARDS;
  else process.env.VERIFY_RENDER_SHARDS = savedShards;
}
ok('VERIFY_RENDER_SHARDS rejects unsafe and non-integer values');

// 7. Duplicate case handling keeps every execution distinct, including a
//    literal ID that already looks like an occurrence suffix.
{
  const tracker = new CaseTracker({ list: false, shard: null, ids: null });
  for (const id of ['a', 'a', 'a #2']) assert.equal(tracker.enter(id), true);
  assert.deepEqual(tracker.ran, ['a', 'a #2', 'a #2 #2']);
  assert.equal(tracker.seen.size, 3, 'every duplicate execution must have a distinct ID');
  assert.equal(tracker.repeats, 1);
  assert.equal(
    tracker.summary(),
    'verify-render-shard: shard=all seen=3 ran=3 skipped=0 repeats=1',
  );
}
{
  const tracker = new CaseTracker({ list: false, shard: null, ids: null });
  for (const id of ['a #2', 'a', 'a']) assert.equal(tracker.enter(id), true);
  assert.deepEqual(tracker.ran, ['a #2', 'a', 'a #3']);
  assert.equal(tracker.seen.size, 3);
}
{
  const tracker = new CaseTracker({ list: false, shard: null, ids: null });
  for (const id of ['x', 'x', 'x', 'x #2', 'x #3']) tracker.enter(id);
  assert.equal(tracker.seen.size, 5);
  assert.equal(new Set(tracker.ran).size, 5);
  assert.equal(tracker.repeats, 2);
}
{
  const tracker = new CaseTracker({ list: true, shard: null, ids: null });
  for (const id of ['a', 'a', 'a #2']) assert.equal(tracker.enter(id), false);
  assert.deepEqual([...tracker.seen], ['a', 'a #2', 'a #2 #2']);
  assert.deepEqual(tracker.ran, []);
  assert.equal(tracker.summary(), 'verify-render-shard: shard=all seen=3 ran=0 skipped=0 repeats=1');
}
{
  const tracker = new CaseTracker({ list: false, shard: { index: 0, count: 2 }, ids: null });
  for (const id of ['a', 'a', 'a #2']) tracker.enter(id);
  assert.equal(tracker.ran.length + tracker.skipped, 3);
  assert.equal(new Set(tracker.ran).size, tracker.ran.length);
}
{
  const tracker = new CaseTracker({ list: false, shard: null, ids: null });
  tracker.enter(1);
  tracker.enter('1');
  assert.deepEqual([...tracker.seen], ['1', '1 #2']);
  assert.equal(tracker.seen.size, 2);
}
ok('duplicate case IDs keep distinct, deterministic identities');

// 7b. Generated collision labels: every execution must stay unique, and the
//     shard union must be exhaustive and disjoint even when literal labels
//     already look like occurrence suffixes.
{
  const collisionLabels = ['a', 'a #2', 'a #3', 'b', 'b #2', 'x', 'x #2', 'x #3'];
  const collisionIds = ['a', 'a', 'a #2', 'a', 'a #3', 'a #2', 'b', 'b', 'b #2', 'x', 'x', 'x #2', 'x #3'];
  for (let i = 0; i < 35; i++) {
    const label = pick(collisionLabels);
    collisionIds.push(label);
    if (rand() < 0.5) collisionIds.push(label);
  }
  const uniqueLabels = new Set(collisionIds).size;
  const expectedRepeats = collisionIds.length - uniqueLabels;
  const listTracker = new CaseTracker({ list: true, shard: null, ids: null });
  for (const id of collisionIds) listTracker.enter(id);
  assert.equal(
    listTracker.seen.size,
    collisionIds.length,
    `seed ${SEED_TEXT}: every collision execution must keep a distinct ID`,
  );
  assert.equal(listTracker.repeats, expectedRepeats, `seed ${SEED_TEXT}: repeat count must match duplicate labels`);

  for (const count of [1, 2, 3, 8]) {
    const union = new Set();
    for (let index = 0; index < count; index++) {
      const tracker = new CaseTracker({ list: false, shard: { index, count }, ids: null });
      for (const id of collisionIds) tracker.enter(id);
      assert.equal(
        tracker.seen.size,
        collisionIds.length,
        `seed ${SEED_TEXT}: shard ${index}/${count} lost a collision execution`,
      );
      assert.equal(
        tracker.ran.length + tracker.skipped,
        collisionIds.length,
        `seed ${SEED_TEXT}: shard ${index}/${count} did not account for every execution`,
      );
      assert.equal(
        tracker.repeats,
        expectedRepeats,
        `seed ${SEED_TEXT}: shard ${index}/${count} repeat count changed`,
      );
      for (const id of tracker.ran) {
        assert.equal(union.has(id), false, `seed ${SEED_TEXT}: ${JSON.stringify(id)} ran in two shards`);
        union.add(id);
      }
    }
    assert.equal(union.size, collisionIds.length, `seed ${SEED_TEXT}: collision shard union is not exhaustive`);
    assert.deepEqual(
      [...union].sort(),
      [...listTracker.seen].sort(),
      `seed ${SEED_TEXT}: collision shard union differs from the list IDs`,
    );
  }

  // Honest limit: a literal suffix can displace a generated suffix. ['a','a']
  // emits 'a #2'; prepending the literal 'a #2' moves the later duplicate to
  // 'a #3'. No execution is lost, but the duplicate's ID is order-sensitive.
  const base = new CaseTracker({ list: true, shard: null, ids: null });
  base.enter('a');
  base.enter('a');
  assert.deepEqual([...base.seen], ['a', 'a #2']);
  const withLiteral = new CaseTracker({ list: true, shard: null, ids: null });
  withLiteral.enter('a #2');
  withLiteral.enter('a');
  withLiteral.enter('a');
  assert.deepEqual([...withLiteral.seen], ['a #2', 'a', 'a #3']);
  assert.notEqual(
    [...base.seen][1],
    [...withLiteral.seen][2],
    `seed ${SEED_TEXT}: the collision test must document the order-sensitive suffix`,
  );
}
ok('generated collision labels stay unique and partition exhaustively; suffix order sensitivity is explicit');

// 8. writeIds writes exactly the IDs the summary claims.
{
  const dir = mkdtempSync(join(tmpdir(), 'shard-pbt-ids-'));
  try {
    const idsPath = join(dir, 'all.ids');
    const tracker = new CaseTracker({ list: true, shard: null, ids: idsPath });
    for (const id of ['a', 'a', 'a #2']) tracker.enter(id);
    tracker.writeIds();
    assert.deepEqual(readFileSync(idsPath, 'utf8').split('\n').filter(Boolean), ['a', 'a #2', 'a #2 #2']);
    const emptyPath = join(dir, 'empty.ids');
    const empty = new CaseTracker({ list: false, shard: null, ids: emptyPath });
    empty.writeIds();
    assert.equal(readFileSync(emptyPath, 'utf8'), '');
    const noPath = new CaseTracker({ list: false, shard: null, ids: null });
    noPath.writeIds();
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
ok('writeIds preserves duplicate evidence and writes an empty file for an empty shard');

// 9. The fake child imports the real hash and can inject every failure mode.
const dir = mkdtempSync(join(tmpdir(), 'shard-pbt-'));
const fake = join(dir, 'fake.mjs');
const FAKE = String.raw`
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { shardIndex } from ${JSON.stringify(SHARD_URL)};
const spec = JSON.parse(process.env.FAKE_SPEC);
const argv = process.argv.slice(2);
const idsPath = argv[argv.indexOf('--ids') + 1];
const shardArg = argv.includes('--shard') ? argv[argv.indexOf('--shard') + 1] : null;
const summary = (shard, seen, ran, skipped = 0, repeats = 0) =>
  'verify-render-shard: shard=' + shard + ' seen=' + seen + ' ran=' + ran + ' skipped=' + skipped + ' repeats=' + repeats + '\n';
const evidence = (kind, text) => {
  if (spec.evidencePath) writeFileSync(spec.evidencePath + '.' + kind, JSON.stringify(text));
};
const formatIds = (ids, mode) => {
  if (mode === 'none') return null;
  if (mode === 'dir') { mkdirSync(idsPath, { recursive: true }); return null; }
  let text = ids.map((id) => id + '\n').join('');
  if (mode === 'blank-lines') text = '\n' + text + '\n';
  if (mode === 'crlf') text = ids.map((id) => id + '\r\n').join('');
  if (mode === 'no-trailing') text = ids.join('\n');
  return text;
};
const writeIds = (ids, mode, kind) => {
  const text = formatIds(ids, mode);
  if (text === null) return;
  writeFileSync(idsPath, text);
  evidence(kind, text);
};
if (argv.includes('--list')) {
  if (spec.listMode === 'fail') process.exit(1);
  if (spec.listMode === 'hang') await new Promise((resolve) => setTimeout(resolve, 60000));
  if (spec.listMode === 'signal') process.kill(process.pid, 'SIGTERM');
  if (spec.listMode === 'no-ids') process.exit(0);
  let listIds = spec.listIds ?? spec.ids;
  if (spec.listMode === 'duplicate') listIds = [...listIds, listIds[0]];
  if (spec.listMode === 'empty') listIds = [];
  writeIds(listIds, spec.listIdsMode ?? spec.idsMode, 'list');
  process.exit(0);
}
const [index, count] = shardArg.split('/').map(Number);
if (spec.markerDir) writeFileSync(join(spec.markerDir, 'shard-' + index + '-' + count + '.started'), '');
let mine = spec.ids.filter((id) => shardIndex(id, count) === index);
if (spec.dropShard === index) mine = mine.slice(1);
if (spec.dupShard === index) mine = [...mine, spec.ids[0]];
if (spec.unknownShard === index) mine = [...mine, 'unknown-id'];
if (spec.shardMode === 'drop') mine = mine.slice(1);
if (spec.shardMode === 'duplicate') mine = [...mine, spec.ids[0]];
if (spec.shardMode === 'unknown') mine = [...mine, 'unknown-id'];
if (spec.shardMode === 'empty') mine = [];
if (spec.failShard === index || spec.shardMode === 'fail') process.exit(1);
if (spec.hangShard === index || spec.shardMode === 'hang') await new Promise((resolve) => setTimeout(resolve, 60000));
if (spec.signalShard === index || spec.shardMode === 'signal') process.kill(process.pid, 'SIGTERM');
if (spec.shardMode !== 'no-ids') writeIds(mine, spec.shardIdsMode ?? spec.idsMode, 'shard-' + index + '-' + count);
if (spec.shardMode === 'no-summary') process.exit(0);
const summaryShard = spec.summaryShard ?? shardArg;
const summarySeen = spec.summarySeen ?? spec.ids.length;
const summaryRan = spec.summaryRan ?? mine.length;
const summarySkipped = spec.summarySkipped ?? 0;
const summaryRepeats = spec.summaryRepeats ?? 0;
let line = summary(summaryShard, summarySeen, summaryRan, summarySkipped, summaryRepeats);
if (spec.summaryMode === 'malformed') line = 'verify-render-shard: shard=' + summaryShard + ' seen=' + summarySeen + '\n';
if (spec.summaryMode === 'extra') line = line.trimEnd() + ' extra\n';
if (spec.summaryMode === 'prefix') line = 'prefix ' + line;
if (spec.summaryMode === 'crlf') line = line.replace(/\n$/, '\r\n');
if (spec.summaryMode === 'ansi') line = '\u001b[31m' + line + '\u001b[0m';
if (spec.summaryMode === 'multiple') {
  process.stderr.write(summary('9/4', spec.ids.length, mine.length) + line);
} else if (spec.summaryMode === 'stdout') {
  process.stdout.write(line);
} else {
  process.stderr.write(line);
}
process.exit(0);
`;
writeFileSync(fake, FAKE);

const ids = Array.from({ length: 40 }, (_, index) => `case ${index}`);
async function run(spec, env = {}) {
  const saved = new Map();
  const values = { FAKE_SPEC: JSON.stringify({ ids, ...spec }), ...env };
  for (const [key, value] of Object.entries(values)) {
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

try {
  // 10. A clean run covers every case, including sparse and single-shard runs.
  const clean = await run({}, { VERIFY_RENDER_SHARDS: '4' });
  assert.deepEqual(clean, { total: ids.length, count: 4 });
  const single = await run({}, { VERIFY_RENDER_SHARDS: '1' });
  assert.deepEqual(single, { total: ids.length, count: 1 });
  const sparse = await run({}, { VERIFY_RENDER_SHARDS: '50' });
  assert.deepEqual(sparse, { total: ids.length, count: 50 });
  ok('clean, single-shard and sparse runs cover every case');

  // 11. Regression: hashing can leave a shard empty even when count <= cases.
  //     The exhaustive union check is the authority, not an empty-bucket
  //     heuristic. These IDs share one bucket for count 2.
  const sameBucket = ['id-0', 'id-2'];
  assert.equal(shardIndex(sameBucket[0], 2), shardIndex(sameBucket[1], 2));
  const emptyBucket = await run({ ids: sameBucket }, { VERIFY_RENDER_SHARDS: '2' });
  assert.deepEqual(emptyBucket, { total: 2, count: 2 });
  const sameBucketThree = ['id-0', 'id-2', 'id-4'];
  assert.equal(new Set(sameBucketThree.map((id) => shardIndex(id, 2))).size, 1);
  const emptyBucketThree = await run({ ids: sameBucketThree }, { VERIFY_RENDER_SHARDS: '2' });
  assert.deepEqual(emptyBucketThree, { total: 3, count: 2 });
  ok('an empty hash bucket is accepted when the union is exhaustive');

  // 12. --list failures and malformed enumeration evidence.
  await rejects({ listMode: 'fail' }, /--list failed/);
  await rejects({ listMode: 'hang' }, /--list failed \(timed out\)/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: '2000' });
  await rejects({ listMode: 'signal' }, /--list failed \(killed by SIGTERM\)/);
  await rejects({ listMode: 'no-ids' }, /--list wrote no ID file/);
  await rejects({ listMode: 'empty' }, /--list produced no case IDs/);
  await rejects({ listMode: 'duplicate' }, /case IDs are not unique/);
  // A line-based ID file cannot represent an empty ID. The list drops the
  // blank line, so the child's seen count no longer matches the enumeration
  // and the aggregate fails closed instead of silently losing the case.
  await rejects({ ids: ['', 'case 1'] }, /reported seen=2 but enumerated 1/);
  const blankEvidence = join(dir, 'evidence-blank-list');
  const blankList = await run(
    { listIdsMode: 'blank-lines', evidencePath: blankEvidence },
    { VERIFY_RENDER_SHARDS: '4' },
  );
  assert.equal(blankList.total, ids.length);
  const blankText = JSON.parse(readFileSync(`${blankEvidence}.list`, 'utf8'));
  assert.ok(blankText.startsWith('\n'), 'blank-lines list evidence must start with a blank line');
  assert.ok(blankText.endsWith('\n\n'), 'blank-lines list evidence must end with a blank line');
  assert.equal(blankText.split('\n').filter(Boolean).length, ids.length);
  const noTrailingEvidence = join(dir, 'evidence-no-trailing-list');
  const noTrailing = await run(
    { listIdsMode: 'no-trailing', evidencePath: noTrailingEvidence },
    { VERIFY_RENDER_SHARDS: '4' },
  );
  assert.equal(noTrailing.total, ids.length);
  const noTrailingText = JSON.parse(readFileSync(`${noTrailingEvidence}.list`, 'utf8'));
  assert.equal(noTrailingText.endsWith('\n'), false, 'no-trailing list evidence must not end with a newline');
  assert.equal(noTrailingText.split('\n').length, ids.length);
  ok('--list failures, empty/duplicate IDs and blank/no-trailing formats are handled');

  // 13. Shard process failures, timeouts and signals.
  await rejects({ shardMode: 'fail', failShard: 2 }, /shard 2\/4 exit 1/);
  const markerDir = join(dir, 'markers');
  mkdirSync(markerDir, { recursive: true });
  await assert.rejects(
    run(
      { shardMode: 'hang', hangShard: 3, markerDir },
      { VERIFY_RENDER_SHARDS: '4', VERIFY_RENDER_SHARD_TIMEOUT_MS: '2000' },
    ),
    /shard 3\/4 timed out/,
  );
  assert.equal(
    existsSync(join(markerDir, 'shard-3-4.started')),
    true,
    'the hanging shard must have started before the timeout',
  );
  await rejects({ shardMode: 'signal', signalShard: 1 }, /killed by SIGTERM/);
  await rejects({ shardMode: 'no-summary' }, /printed no summary line/);
  const noIdsEvidence = join(dir, 'evidence-no-ids');
  await assert.rejects(
    run({ shardMode: 'no-ids', evidencePath: noIdsEvidence }, { VERIFY_RENDER_SHARDS: '4' }),
    /shard 0\/4 wrote no ID file/,
  );
  assert.equal(
    existsSync(`${noIdsEvidence}.list`),
    true,
    'the list evidence must be written before the shard failure',
  );
  assert.equal(
    existsSync(`${noIdsEvidence}.shard-0-4`),
    false,
    'the missing shard evidence must be the failure, not the enumeration',
  );
  await rejects({ shardMode: 'empty' }, /ran in no shard/);
  await rejects({ shardMode: 'drop', dropShard: 1 }, /ran in no shard/);
  await rejects({ shardMode: 'duplicate', dupShard: 1 }, /ran in shards/);
  await rejects({ shardMode: 'unknown', unknownShard: 1 }, /is not in the --list set/);
  const shardBlankEvidence = join(dir, 'evidence-blank-shard');
  const shardBlank = await run(
    { shardIdsMode: 'blank-lines', evidencePath: shardBlankEvidence },
    { VERIFY_RENDER_SHARDS: '4' },
  );
  assert.equal(shardBlank.total, ids.length);
  for (let index = 0; index < 4; index++) {
    const text = JSON.parse(readFileSync(`${shardBlankEvidence}.shard-${index}-4`, 'utf8'));
    assert.ok(text.startsWith('\n'), `shard ${index}/4 blank-lines evidence must start with a blank line`);
    assert.ok(text.endsWith('\n\n'), `shard ${index}/4 blank-lines evidence must end with a blank line`);
  }
  const shardNoTrailingEvidence = join(dir, 'evidence-no-trailing-shard');
  const shardNoTrailing = await run(
    { shardIdsMode: 'no-trailing', evidencePath: shardNoTrailingEvidence },
    { VERIFY_RENDER_SHARDS: '4' },
  );
  assert.equal(shardNoTrailing.total, ids.length);
  for (let index = 0; index < 4; index++) {
    const text = JSON.parse(readFileSync(`${shardNoTrailingEvidence}.shard-${index}-4`, 'utf8'));
    assert.equal(text.endsWith('\n'), false, `shard ${index}/4 no-trailing evidence must not end with a newline`);
  }
  await rejects({ ids: ['case 0'], shardIdsMode: 'crlf' }, /is not in the --list set/);
  await rejects({ shardIdsMode: 'dir' }, /shard 0\/4 wrote no ID file/);
  await rejects({ shardIdsMode: 'none' }, /shard 0\/4 wrote no ID file/);
  ok('shard failures, timeouts, signals and missing ID evidence fail closed');

  // 14. Malformed summaries and inconsistent counts.
  await rejects({ summaryShard: '9/4' }, /reported shard=9\/4/);
  await rejects({ summaryMode: 'malformed' }, /printed no summary line/);
  await rejects({ summaryMode: 'extra' }, /printed no summary line/);
  await rejects({ summaryMode: 'prefix' }, /printed no summary line/);
  await rejects({ summaryMode: 'ansi' }, /printed no summary line/);
  await rejects({ summaryMode: 'stdout' }, /printed no summary line/);
  await rejects({ summaryMode: 'multiple' }, /reported shard=9\/4/);
  const crlfSummary = await run({ summaryMode: 'crlf' }, { VERIFY_RENDER_SHARDS: '4' });
  assert.equal(crlfSummary.total, ids.length, 'a CRLF summary line is still valid evidence');
  await rejects({ summaryRan: 999 }, /reported ran=999 but wrote/);
  await rejects({ summarySeen: 0 }, /reported seen=0 but enumerated/);
  await rejects({ summaryRan: 'x' }, /printed no summary line/);
  await rejects({ summarySeen: 'x' }, /printed no summary line/);
  await rejects({ summarySkipped: 'x' }, /printed no summary line/);
  await rejects({ summaryRepeats: 'x' }, /printed no summary line/);
  await rejects({ summaryRan: -1 }, /printed no summary line/);
  await rejects({ summaryRan: 1.5 }, /printed no summary line/);
  ok('malformed summaries and inconsistent seen/ran counts fail closed');

  // 15. Invalid environment values fail before spawning a child.
  await rejects({}, /positive integer/, { VERIFY_RENDER_SHARDS: '0' });
  await rejects({}, /positive integer/, { VERIFY_RENDER_SHARDS: '1.5' });
  await rejects({}, /positive integer/, { VERIFY_RENDER_SHARDS: '9007199254740992' });
  await rejects({}, /positive number/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: '0' });
  await rejects({}, /positive number/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: '-1' });
  await rejects({}, /positive number/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: 'abc' });
  await rejects({}, /positive number/, { VERIFY_RENDER_SHARD_TIMEOUT_MS: 'Infinity' });
  ok('invalid shard count and timeout environment values fail closed');

  // 16. The temporary shard directory is removed on success and failure.
  const tmpRoot = mkdtempSync(join(tmpdir(), 'shard-pbt-tmp-'));
  const savedTmp = process.env.TMPDIR;
  try {
    process.env.TMPDIR = tmpRoot;
    await run({}, { VERIFY_RENDER_SHARDS: '4' });
    assert.deepEqual(readdirSync(tmpRoot), [], 'successful run left a temporary shard directory');
    await assert.rejects(run({ shardMode: 'fail', failShard: 2 }, { VERIFY_RENDER_SHARDS: '4' }), /exit 1/);
    assert.deepEqual(readdirSync(tmpRoot), [], 'failed run left a temporary shard directory');
    await assert.rejects(
      run(
        { shardMode: 'hang', hangShard: 3 },
        { VERIFY_RENDER_SHARDS: '4', VERIFY_RENDER_SHARD_TIMEOUT_MS: '2000' },
      ),
      /shard 3\/4 timed out/,
    );
    assert.deepEqual(readdirSync(tmpRoot), [], 'timed-out run left a temporary shard directory');
    await assert.rejects(run({ listMode: 'fail' }, { VERIFY_RENDER_SHARDS: '4' }), /--list failed/);
    assert.deepEqual(readdirSync(tmpRoot), [], 'failed --list left a temporary shard directory');
  } finally {
    if (savedTmp === undefined) delete process.env.TMPDIR;
    else process.env.TMPDIR = savedTmp;
    rmSync(tmpRoot, { recursive: true, force: true });
  }
  ok('temporary shard directories are removed on success and failure');
} finally {
  rmSync(dir, { recursive: true, force: true });
}

console.log(`shard PBT: ${checks} checks pass, 0 fail (seed ${SEED_TEXT})`);
export const shardPbtChecks = checks;
