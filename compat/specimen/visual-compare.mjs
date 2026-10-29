import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createReadStream, mkdtempSync, readFileSync, mkdirSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = process.cwd();
const allowed = ['/compat/specimen/', '/node_modules/@bdfkit/', '/_build/js/debug/build/compat/specimen/'];
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json' };
const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname);
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
    response.writeHead(403).end(); return;
  }
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
  stream.pipe(response);
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
const base = 'http://127.0.0.1:' + server.address().port + '/compat/specimen/';
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
    for (const name of ['visual-baseline', 'visual-moon']) {
      const page = await browser.newPage();
      await page.goto(base + name + '.html', { waitUntil: 'networkidle' });
      await page.waitForFunction(() => window.bdfStatus === 'ready' || window.bdfStatus === 'error');
      const result = await page.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, count: document.querySelectorAll('canvas').length }));
      assert.equal(result.status, 'ready', result.error);
      assert.equal(result.count, 7);
      await page.close();
    }
  } finally { await browser.close(); }
  const rootOutput = path.join(root, '_build/visual-diff');
  mkdirSync(rootOutput, { recursive: true });
  const output = mkdtempSync(path.join(rootOutput, 'specimen-'));
  await run(['diff', 'html', '--url', base + 'visual-baseline.html', '--current-url', base + 'visual-moon.html', '--output-dir', output, '--no-paint-tree']);
  const reportPath = path.join(output, 'diff-report.json');
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.results.length, 3);
  for (const result of report.results) {
    const before = PNG.sync.read(readFileSync(path.join(output, 'compat_specimen_visual-baseline-' + result.viewport + '.png')));
    const after = PNG.sync.read(readFileSync(path.join(output, 'compat_specimen_visual-moon-' + result.viewport + '.png')));
    assert.equal(before.width, after.width);
    assert.equal(before.height, after.height);
    let changed = 0, dark = 0;
    for (let i = 0; i < before.data.length; i += 4) {
      if (before.data[i] !== after.data[i] || before.data[i+1] !== after.data[i+1] ||
          before.data[i+2] !== after.data[i+2] || before.data[i+3] !== after.data[i+3]) changed++;
      if (before.data[i] < 100 && before.data[i+1] < 100 && before.data[i+2] < 100) dark++;
    }
    assert.ok(dark > 100, result.viewport + ': blank reference');
    assert.equal(changed, 0, result.viewport + ': font rendering differs');
  }
  process.stdout.write(await run(['diff', 'agent', reportPath, '--no-history']));
} finally {
  await new Promise(resolve => server.close(resolve));
}
