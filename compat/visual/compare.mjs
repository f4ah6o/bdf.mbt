import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { createReadStream, mkdirSync, mkdtempSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { stripVTControlCharacters } from 'node:util';
import { chromium } from 'playwright';
import { PNG } from 'pngjs';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const outputRoot = path.join(root, '_build/visual-diff');
mkdirSync(outputRoot, { recursive: true });
const output = mkdtempSync(path.join(outputRoot, 'run-'));
const executable = path.join(root, 'node_modules/.bin/vlmkit');
const allowed = ['/compat/visual/', '/node_modules/@bdfkit/', '/_build/js/debug/build/browser/'];
const mime = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.bdf': 'application/octet-stream' };

function run(args) {
  return new Promise((resolve, reject) => {
    const child = spawn(executable, args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '', stderr = '';
    child.stdout.setEncoding('utf8').on('data', chunk => { stdout += chunk; });
    child.stderr.setEncoding('utf8').on('data', chunk => { stderr += chunk; });
    child.once('error', reject);
    child.once('close', (code, signal) => {
      // actrun stores output as JSON; raw ANSI escapes corrupt its run record.
      process.stdout.write(stripVTControlCharacters(stdout));
      process.stderr.write(stripVTControlCharacters(stderr));
      code === 0 ? resolve() : reject(new Error(`vlmkit failed: ${signal ?? code}`));
    });
  });
}

const server = createServer((request, response) => {
  let pathname;
  try { pathname = decodeURIComponent(new URL(request.url, 'http://localhost').pathname); }
  catch { response.writeHead(400).end(); return; }
  const file = path.resolve(root, '.' + pathname);
  if (!allowed.some(prefix => file.startsWith(path.resolve(root, '.' + prefix) + path.sep))) {
    response.writeHead(403).end(); return;
  }
  const stream = createReadStream(file);
  stream.once('error', () => { if (!response.headersSent) response.writeHead(404); response.end(); });
  response.setHeader('Content-Type', mime[path.extname(file)] ?? 'application/octet-stream');
  stream.pipe(response);
});

await new Promise((resolve, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolve);
});
const base = `http://127.0.0.1:${server.address().port}/compat/visual/`;
try {
  // A visual diff is not evidence if both pages failed or were still blank.
  const browser = await chromium.launch({ headless: true });
  try {
    for (const name of ['baseline', 'moon']) {
      const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
      const errors = [];
      page.on('pageerror', error => errors.push(String(error)));
      await page.goto(`${base}${name}.html`, { waitUntil: 'networkidle' });
      await page.waitForFunction(() => window.bdfStatus === 'ready' || window.bdfStatus === 'error');
      const result = await page.evaluate(() => ({ status: window.bdfStatus, error: window.bdfError, canvases: document.querySelectorAll('canvas').length }));
      assert.equal(result.status, 'ready', `${name}: ${result.error ?? errors.join('; ')}`);
      assert.equal(result.canvases, 1, `${name}: expected a rendered canvas`);
      assert.deepEqual(errors, [], `${name}: browser errors`);
      await page.close();
    }
  } finally {
    await browser.close();
  }
  await run(['diff', 'html', '--url', `${base}baseline.html`, '--current-url', `${base}moon.html`, '--output-dir', output, '--no-paint-tree']);
  const reportPath = path.join(output, 'diff-report.json');
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.results.length, 3, 'expected three vlmkit viewports');
  for (const result of report.results) {
    const baseline = PNG.sync.read(readFileSync(path.join(output, `compat_visual_baseline-${result.viewport}.png`)));
    const current = PNG.sync.read(readFileSync(path.join(output, `compat_visual_moon-${result.viewport}.png`)));
    assert.equal(baseline.width, current.width);
    assert.equal(baseline.height, current.height);
    const sample = (80 * baseline.width + 40) * 4;
    assert.ok(baseline.data[sample + 2] > 100 && baseline.data[sample] < 100 && baseline.data[sample + 3] === 255, 'baseline capture is blank or incomplete');
    if (baseline.width > 540) {
      const svg = (280 * baseline.width + 510) * 4;
      assert.ok(baseline.data[svg] > 200 && baseline.data[svg + 1] > 150 && baseline.data[svg + 2] < 140, 'SVG was not rendered');
      let fontPixels = 0;
      for (let y = 340; y < 390; y++) for (let x = 385; x < 480; x++) {
        const i = (y * baseline.width + x) * 4;
        if (baseline.data[i] < 100 && baseline.data[i + 1] < 100 && baseline.data[i + 2] < 120) fontPixels++;
      }
      assert.ok(fontPixels > 200, 'embedded font was not rendered');
    }
    let changed = 0;
    for (let i = 0; i < baseline.data.length; i += 4) {
      if (baseline.data[i] !== current.data[i] || baseline.data[i + 1] !== current.data[i + 1] || baseline.data[i + 2] !== current.data[i + 2] || baseline.data[i + 3] !== current.data[i + 3]) changed++;
    }
    // Normalize to the visible document area, not the surrounding white viewport.
    const visibleArea = Math.min(baseline.width, 640) * Math.min(baseline.height, 400);
    const ratio = changed / visibleArea;
    console.log(`${result.viewport}: ${changed} pixels changed (${(ratio * 100).toFixed(4)}%)`);
    assert.ok(ratio <= 0.0005, `${result.viewport}: visual difference exceeds 0.05%`);
  }
  assert.ok(report.domEquivalence.every(item => item.result.ok), 'DOM equivalence warnings');
  await run(['diff', 'agent', reportPath, '--no-history']);
} finally {
  await new Promise(resolve => server.close(resolve));
}
