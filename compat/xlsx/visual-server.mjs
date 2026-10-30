import { createReadStream } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';

// Keep each capture's network request open until its own asynchronous render
// finishes. VLMKit waits for network idle before taking the screenshot.
export function createVisualServer(root) {
  const pending = new Map();
  const allowed = ['/compat/xlsx/', '/node_modules/@bdfkit/', '/_build/js/debug/build/compat/xlsx/', '/_build/js/debug/build/browser/'];
  const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };
  return createServer((request, response) => {
    const url = new URL(request.url, 'http://localhost');
    const token = url.searchParams.get('token');
    if (url.pathname === '/compat/xlsx/visual-wait' && request.method === 'GET' && token && !pending.has(token)) {
      pending.set(token, response);
      response.once('close', () => { if (pending.get(token) === response) pending.delete(token); });
      response.writeHead(200, { 'Content-Type': 'text/plain', 'Cache-Control': 'no-store' });
      response.flushHeaders();
      return;
    }
    if (url.pathname === '/compat/xlsx/visual-release' && request.method === 'POST') {
      const waiting = pending.get(token);
      if (!waiting) { response.writeHead(404).end(); return; }
      pending.delete(token);
      waiting.end('ready');
      response.writeHead(204).end();
      return;
    }
    let pathname;
    try { pathname = decodeURIComponent(url.pathname); } catch { response.writeHead(400).end(); return; }
    const file = path.resolve(root, '.' + pathname);
    if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
      response.writeHead(403).end(); return;
    }
    const stream = createReadStream(file);
    stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
    response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
    stream.pipe(response);
  });
}
