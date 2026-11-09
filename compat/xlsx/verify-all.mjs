import { readdirSync } from 'node:fs';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import os from 'node:os';

const jobs = [];
for (const directory of ['../ooxml/', './']) {
  const dir = new URL(directory, import.meta.url);
  const scripts = readdirSync(dir).filter(name => /^verify-.+\.mjs$/.test(name) && name !== 'verify-all.mjs').sort();
  for (const script of scripts) jobs.push({ directory, dir, script });
}

// Each script is an independent read-only fixture check; run them concurrently
// so the suite is bounded by the slowest script instead of their sum.
const concurrency = Math.max(1, Math.min(8, os.availableParallelism?.() ?? 4));
let next = 0, failed = 0;

// Forward a child stream line by line, tagged with the script it came from.
// Buffering until the child exits hid all progress for the length of the
// slowest script, which is what made a stalled run indistinguishable from a
// slow one.
function forward(stream, target, prefix) {
  let pending = '';
  stream.setEncoding('utf8');
  stream.on('data', chunk => {
    pending += chunk;
    const lines = pending.split('\n');
    pending = lines.pop();
    for (const line of lines) target.write(`${prefix}${line}\n`);
  });
  stream.on('end', () => {
    if (pending) target.write(`${prefix}${pending}\n`);
    pending = '';
  });
}

async function worker() {
  while (next < jobs.length) {
    const job = jobs[next++];
    const file = fileURLToPath(new URL(job.script, job.dir));
    const label = `${job.directory}${job.script}`;
    process.stdout.write(`Checking ${label}\n`);
    const code = await new Promise(resolve => {
      const child = spawn(process.execPath, [file], { stdio: ['ignore', 'pipe', 'pipe'] });
      forward(child.stdout, process.stdout, `${label} | `);
      forward(child.stderr, process.stderr, `${label} | `);
      child.once('error', error => { process.stderr.write(`${label} | ${error}\n`); });
      child.once('close', status => {
        if (status !== 0) process.stderr.write(`${label} exited with status ${status}\n`);
        resolve(status ?? 1);
      });
    });
    if (code !== 0) failed = code;
  }
}
await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, worker));
if (failed) process.exitCode = failed;
