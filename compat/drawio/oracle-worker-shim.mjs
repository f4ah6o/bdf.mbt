// Bridges the web-style worker API (self.onmessage/self.postMessage) used by
// the MoonBit js worker onto node:worker_threads.
import { parentPort } from 'node:worker_threads';
globalThis.self = globalThis;
globalThis.postMessage = (value, transfer) => parentPort.postMessage(value, transfer);
await import(process.env.WORKER_TARGET);
parentPort.on('message', (data) => { globalThis.onmessage({ data }); });
