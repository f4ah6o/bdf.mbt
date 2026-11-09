// Stable case IDs and shard selection for the XLSX render verification.
//
// A case ID is the label the verification already puts in its assertion
// messages, so a shard can be re-run on its own and the ID still names the
// same fixture. Shard assignment hashes the ID instead of slicing the case
// order, so adding or reordering fixtures does not move unrelated cases
// between shards.

import { spawn } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { availableParallelism, tmpdir } from 'node:os';
import { join } from 'node:path';

/// FNV-1a over the UTF-8 bytes: stable across processes and platforms.
export function shardIndex(id, count) {
  let hash = 0x811c9dc5;
  for (const byte of Buffer.from(String(id), 'utf8')) {
    hash ^= byte;
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash % count;
}

export function parseArgs(argv) {
  const options = { shard: null, list: false, ids: null };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--list') {
      options.list = true;
    } else if (arg === '--shard') {
      const value = argv[++i] ?? '';
      const match = /^(\d+)\/(\d+)$/.exec(value);
      if (!match) throw new Error(`--shard wants i/n, got ${JSON.stringify(value)}`);
      const index = Number(match[1]);
      const count = Number(match[2]);
      if (count < 1 || index < 0 || index >= count) {
        throw new Error(`--shard ${value} is out of range`);
      }
      options.shard = { index, count };
    } else if (arg === '--ids') {
      const value = argv[++i];
      if (value === undefined) throw new Error('--ids wants a path');
      options.ids = value;
    } else {
      throw new Error(`unknown argument ${JSON.stringify(arg)}`);
    }
  }
  return options;
}

export class CaseTracker {
  constructor(options) {
    this.options = options;
    this.seen = new Set();
    this.ran = [];
    this.repeats = 0;
    this.skipped = 0;
    this.occurrences = new Map();
  }

  /// Records the case and reports whether this process should run it.
  /// A fixture that repeats verbatim under the same message gets an
  /// occurrence suffix instead of being dropped, so every execution keeps
  /// its own ID and the case count stays what it was before sharding.
  enter(id) {
    const occurrence = this.occurrences.get(id) ?? 0;
    this.occurrences.set(id, occurrence + 1);
    if (occurrence > 0) this.repeats++;
    const unique = occurrence === 0 ? id : `${id} #${occurrence + 1}`;
    this.seen.add(unique);
    if (this.options.list) return false;
    if (
      this.options.shard &&
      shardIndex(unique, this.options.shard.count) !== this.options.shard.index
    ) {
      this.skipped++;
      return false;
    }
    this.ran.push(unique);
    return true;
  }

  /// `--list` writes every ID it saw; a shard writes only the IDs it ran.
  writeIds() {
    if (!this.options.ids) return;
    const ids = this.options.list ? [...this.seen] : this.ran;
    writeFileSync(this.options.ids, ids.length ? `${ids.join('\n')}\n` : '');
  }

  /// The one line the aggregator reads back. It is written even when the
  /// shard ran nothing, so a missing line means the shard died.
  summary() {
    const shard = this.options.shard
      ? `${this.options.shard.index}/${this.options.shard.count}`
      : 'all';
    return `verify-render-shard: shard=${shard} seen=${this.seen.size} ran=${this.ran.length} skipped=${this.skipped} repeats=${this.repeats}`;
  }
}

const SUMMARY = /^verify-render-shard: shard=(\S+) seen=(\d+) ran=(\d+) skipped=(\d+) repeats=(\d+)$/m;

export function shardCount() {
  const raw = process.env.VERIFY_RENDER_SHARDS;
  if (raw === undefined || raw === '') return Math.min(8, availableParallelism());
  const count = Number(raw);
  if (!Number.isInteger(count) || count < 1) {
    throw new Error(`VERIFY_RENDER_SHARDS wants a positive integer, got ${JSON.stringify(raw)}`);
  }
  return count;
}

function shardTimeout() {
  const raw = process.env.VERIFY_RENDER_SHARD_TIMEOUT_MS;
  if (raw === undefined || raw === '') return 45 * 60 * 1000;
  const ms = Number(raw);
  if (!Number.isFinite(ms) || ms <= 0) {
    throw new Error(`VERIFY_RENDER_SHARD_TIMEOUT_MS wants a positive number, got ${JSON.stringify(raw)}`);
  }
  return ms;
}

function describeExit(result) {
  if (result.timedOut) return 'timed out';
  if (result.signal) return `killed by ${result.signal}`;
  return `exit ${result.code}`;
}

function readIds(path) {
  return readFileSync(path, 'utf8').split('\n').filter((line) => line.length > 0);
}

function runChild(scriptPath, args, { timeoutMs, forwardStderr = false }) {
  return new Promise((resolve) => {
    const child = spawn(process.execPath, [scriptPath, ...args], {
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    let stdout = '';
    let stderr = '';
    let timedOut = false;
    let settled = false;
    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };
    const timer = setTimeout(() => {
      timedOut = true;
      child.kill('SIGKILL');
    }, timeoutMs);
    child.stdout.setEncoding('utf8');
    child.stderr.setEncoding('utf8');
    child.stdout.on('data', (chunk) => {
      stdout += chunk;
    });
    child.stderr.on('data', (chunk) => {
      stderr += chunk;
      if (forwardStderr) process.stderr.write(chunk);
    });
    child.once('error', (error) => {
      finish({ code: null, signal: null, timedOut, stdout, stderr: `${stderr}${error}` });
    });
    child.once('close', (code, signal) => {
      finish({ code, signal, timedOut, stdout, stderr });
    });
  });
}

async function runShard(scriptPath, index, count, dir, timeoutMs, totalCases) {
  const idsPath = join(dir, `shard-${index}.ids`);
  const result = await runChild(
    scriptPath,
    ['--shard', `${index}/${count}`, '--ids', idsPath],
    { timeoutMs, forwardStderr: true },
  );
  const problems = [];
  const label = `shard ${index}/${count}`;
  if (result.code !== 0) problems.push(`${label} ${describeExit(result)}`);
  const summary = SUMMARY.exec(result.stderr);
  if (!summary) {
    problems.push(`${label} printed no summary line`);
  } else if (summary[1] !== `${index}/${count}`) {
    problems.push(`${label} reported shard=${summary[1]}`);
  }
  let ids = [];
  try {
    ids = readIds(idsPath);
  } catch {
    problems.push(`${label} wrote no ID file`);
  }
  if (summary && Number(summary[3]) !== ids.length) {
    problems.push(`${label} reported ran=${summary[3]} but wrote ${ids.length} IDs`);
  }
  if (ids.length === 0 && count <= totalCases) problems.push(`${label} ran no cases`);
  return { index, ids, problems };
}

/// Parent mode: enumerate every case ID, run the shards, and only report
/// success when every shard finished, wrote its IDs, and the union of the
/// shard ID sets is exactly the enumerated set with no repeats.
export async function runSharded(scriptPath) {
  const count = shardCount();
  const timeoutMs = shardTimeout();
  const dir = mkdtempSync(join(tmpdir(), 'verify-render-shards-'));
  const started = Date.now();
  try {
    const allPath = join(dir, 'all.ids');
    const listed = await runChild(scriptPath, ['--list', '--ids', allPath], { timeoutMs });
    if (listed.code !== 0) {
      throw new Error(
        `verify-render --list failed (${describeExit(listed)})\n${listed.stderr.trim()}`,
      );
    }
    const allIds = readIds(allPath);
    if (allIds.length === 0) throw new Error('verify-render --list produced no case IDs');
    const allSet = new Set(allIds);
    if (allSet.size !== allIds.length) {
      const seen = new Set();
      const dupes = allIds.filter((id) => (seen.has(id) ? true : (seen.add(id), false)));
      throw new Error(
        `verify-render case IDs are not unique (${dupes.length}): ${dupes.slice(0, 5).join(' | ')}`,
      );
    }
    process.stderr.write(`verify-render: ${allIds.length} cases across ${count} shards\n`);

    const shards = await Promise.all(
      Array.from({ length: count }, (_, index) =>
        runShard(scriptPath, index, count, dir, timeoutMs, allIds.length),
      ),
    );

    const problems = shards.flatMap((shard) => shard.problems);
    if (problems.length === 0) {
      const owner = new Map();
      for (const shard of shards) {
        for (const id of shard.ids) {
          if (owner.has(id)) {
            problems.push(`case ${JSON.stringify(id)} ran in shards ${owner.get(id)} and ${shard.index}`);
          } else {
            owner.set(id, shard.index);
          }
        }
      }
      for (const id of allIds) {
        if (!owner.has(id)) problems.push(`case ${JSON.stringify(id)} ran in no shard`);
      }
      for (const id of owner.keys()) {
        if (!allSet.has(id)) problems.push(`case ${JSON.stringify(id)} is not in the --list set`);
      }
    }
    if (problems.length > 0) {
      const shown = problems.slice(0, 20).join('\n  ');
      const more = problems.length > 20 ? `\n  (+${problems.length - 20} more)` : '';
      throw new Error(`verify-render sharding failed:\n  ${shown}${more}`);
    }

    const total = shards.reduce((sum, shard) => sum + shard.ids.length, 0);
    const seconds = ((Date.now() - started) / 1000).toFixed(1);
    process.stderr.write(
      `verify-render: ${total} cases verified across ${count} shards in ${seconds}s\n`,
    );
    return { total, count };
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}
