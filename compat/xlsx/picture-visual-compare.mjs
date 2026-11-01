import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createReadStream, mkdtempSync, readFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = process.cwd();
const allowed = ['/compat/xlsx/', '/node_modules/@bdfkit/', '/_build/js/debug/build/compat/xlsx/', '/_build/js/debug/build/browser/'];
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };
const pending = new Map();
const server = createServer((request, response) => {
  let url;
  try { url = new URL(request.url, 'http://localhost'); } catch { response.writeHead(400).end(); return; }
  const token = url.searchParams.get('token');
  // Keep each capture's network request open until its own asynchronous render
  // finishes. VLMKit waits for network idle before taking the screenshot.
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
  if (pathname.includes('\0')) { response.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
    response.writeHead(403).end(); return;
  }
  let stream;
  try { stream = createReadStream(file); } catch { response.writeHead(400).end(); return; }
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
  stream.pipe(response);
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
const base = 'http://127.0.0.1:' + server.address().port + '/compat/xlsx/';
const run = args => new Promise((resolve, reject) => {
  const child = spawn(path.join(root, 'node_modules/.bin/vlmkit'), args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = '';
  child.stdout.on('data', chunk => { output += chunk; });
  child.stderr.on('data', chunk => { output += chunk; });
  child.once('error', reject);
  child.once('close', code => code === 0 ? resolve(output) : reject(new Error(output)));
});

try {
  const browser = await chromium.launch({ headless: true });
  try {
    for (const name of ['picture-upstream', 'picture-converted', 'picture-moon']) {
      const page = await browser.newPage();
      await page.goto(base + name + '.html', { waitUntil: 'networkidle' });
      await page.waitForFunction(() => window.bdfStatus === 'ready' || window.bdfStatus === 'error');
      const result = await page.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, count: document.querySelectorAll('canvas').length }));
      assert.equal(result.status, 'ready', result.error);
      assert.equal(result.count, 5);
      const colors = await page.locator('canvas').evaluateAll(canvases => canvases.map(canvas => {
        const data = canvas.getContext('2d').getImageData(0, 0, canvas.width, canvas.height).data;
        let colored = 0;
        for (let i = 35 * canvas.width * 4; i < data.length; i += 4) {
          if (data[i + 3] && Math.max(data[i], data[i + 1], data[i + 2]) - Math.min(data[i], data[i + 1], data[i + 2]) > 30) colored++;
        }
        return colored;
      }));
      assert.ok(colors.every(count => count > 50), `${name}: missing colored picture: ${colors}`);
      await page.close();
    }
    const barrierPage = await browser.newPage();
    try {
      // Simulate rendering that outlasts networkidle's 500 ms quiet window.
      await barrierPage.addInitScript(() => {
        const original = Response.prototype.json;
        let paused = false;
        Response.prototype.json = async function () {
          const result = await original.call(this);
          if (!paused) { paused = true; await new Promise(resolve => setTimeout(resolve, 1500)); }
          return result;
        };
      });
      await barrierPage.goto(base + 'picture-upstream.html', { waitUntil: 'networkidle' });
      const status = await barrierPage.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError }));
      assert.equal(status.status, 'ready', status.error ?? 'network became idle before rendering completed');
    } finally { await barrierPage.close(); }
  } finally { await browser.close(); }
  const rootOutput = path.join(root, '_build/visual-diff');
  mkdirSync(rootOutput, { recursive: true });
  for (const variant of ['converted', 'moon']) {
  const output = mkdtempSync(path.join(rootOutput, 'xlsx-picture-' + variant + '-'));
  await run(['diff', 'html', '--url', base + 'picture-upstream.html', '--current-url', base + 'picture-' + variant + '.html', '--output-dir', output, '--no-paint-tree']);
  const reportPath = path.join(output, 'diff-report.json');
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.results.length, 3);
  for (const result of report.results) {
    const before = PNG.sync.read(readFileSync(path.join(output, 'compat_xlsx_picture-upstream-' + result.viewport + '.png')));
    const after = PNG.sync.read(readFileSync(path.join(output, 'compat_xlsx_picture-' + variant + '-' + result.viewport + '.png')));
    assert.equal(before.width, after.width);
    assert.equal(before.height, after.height);
    for (const [name, png] of [['reference', before], [variant, after]]) {
      for (let sample = 0; sample < 5; sample++) {
        let colored = 0;
        const top = 24 + sample * 139;
        assert.ok(png.height >= top + 115, `${result.viewport}: ${name} case ${sample} is clipped vertically`);
        for (let y = top + 35; y < top + 115; y++) {
          for (let x = 8; x < Math.min(png.width, 568); x++) {
            const i = (y * png.width + x) * 4;
            if (png.data[i + 3] && Math.max(png.data[i], png.data[i + 1], png.data[i + 2]) - Math.min(png.data[i], png.data[i + 1], png.data[i + 2]) > 30) colored++;
          }
        }
        assert.ok(colored > 50, `${result.viewport}: ${name} case ${sample} is blank or uncolored`);
      }
    }
    let changed = 0, dark = 0;
    for (let i = 0; i < before.data.length; i += 4) {
      if (before.data[i] !== after.data[i] || before.data[i+1] !== after.data[i+1] ||
          before.data[i+2] !== after.data[i+2] || before.data[i+3] !== after.data[i+3]) changed++;
      if (before.data[i] < 100 && before.data[i+1] < 100 && before.data[i+2] < 100) dark++;
    }
    assert.ok(dark > 100, result.viewport + ': blank reference');
    assert.equal(changed, 0, result.viewport + ': XLSX ' + variant + ' rendering differs');
  }
  process.stdout.write(await run(['diff', 'agent', reportPath, '--no-history']));
  }
} finally {
  await new Promise(resolve => server.close(resolve));
}
