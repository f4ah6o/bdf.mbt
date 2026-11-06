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
async function worker() {
  while (next < jobs.length) {
    const job = jobs[next++];
    const file = fileURLToPath(new URL(job.script, job.dir));
    const label = `${job.directory}${job.script}`;
    process.stdout.write(`Checking ${label}\n`);
    const code = await new Promise(resolve => {
      const child = spawn(process.execPath, [file], { stdio: ['ignore', 'pipe', 'pipe'] });
      let output = '';
      child.stdout.on('data', chunk => { output += chunk; });
      child.stderr.on('data', chunk => { output += chunk; });
      child.once('error', error => { output += String(error); });
      child.once('close', status => {
        process.stdout.write(output);
        if (status !== 0) console.error(`${label} exited with status ${status}`);
        resolve(status ?? 1);
      });
    });
    if (code !== 0) failed = code;
  }
}
await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, worker));
if (failed) process.exitCode = failed;
