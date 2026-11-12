#!/usr/bin/env node
// Drives the MoonBit native converter worker (js build) over worker_threads
// without any npm dependency. Env: WORKER_TARGET INPUT OUTPUT NAME.
// Writes the converted BDF to OUTPUT and prints its size.
import { Worker } from 'node:worker_threads';
import { readFileSync, writeFileSync } from 'node:fs';

const target = process.env.WORKER_TARGET;
const input = process.env.INPUT;
const output = process.env.OUTPUT;
const name = process.env.NAME ?? 'aws.drawio';
if (!target || !input || !output) {
  console.error('usage: WORKER_TARGET=... INPUT=... OUTPUT=... [NAME=aws.drawio] node oracle-worker.mjs');
  process.exit(2);
}
const shim = new URL('./oracle-worker-shim.mjs', import.meta.url);
const worker = new Worker(shim, { type: 'module', env: { ...process.env, WORKER_TARGET: target } });
let finished = false;
const timer = setTimeout(() => finish(1, 'worker timed out after 60 seconds'), 60000);
function finish(code, error) {
  if (finished) return;
  finished = true;
  clearTimeout(timer);
  if (error) console.error(error);
  worker.terminate();
  process.exitCode = code;
}
worker.on('exit', (code) => { if (!finished) finish(1, `worker exited before conversion: ${code}`); });
worker.postMessage({ type: 'init', wasm: '' });
worker.on('message', (message) => {
  if (message.id === 0 && !message.ok) {
    finish(1, 'worker initialization failed');
  } else if (message.id === 0 && message.ok) {
    const data = readFileSync(input);
    const copy = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
    worker.postMessage({ type: 'convert', id: 1, data: copy, options: { name } }, [copy]);
  } else if (message.id === 1) {
    if (!message.ok) { finish(1, 'conversion failed'); return; }
    writeFileSync(output, Buffer.from(message.result.bdf));
    console.log(`converted ${input} -> ${output} (${message.result.bdf.byteLength} bytes)`);
    finish(0);
  }
});
worker.on('error', (error) => { finish(1, error); });
