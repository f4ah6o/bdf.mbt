import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { mkdtempSync, mkdirSync, readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import path from 'node:path';
import { gunzipSync } from 'node:zlib';
import { PNG } from 'pngjs';
import { load_font, truetype_outline, load_cff_outlines, cff_outline } from '../../_build/js/debug/build/compat/font/font.js';

const root = process.cwd();
const fixtures = JSON.parse(gunzipSync(readFileSync('compat/font/outlines.json.gz')));
const fonts = fixtures.filter(f => ['stix.ttf', 'variable.ttf', 'color.ttf'].includes(f.name));
const paths = { baseline: [], moon: [] };
const cffFixtures = JSON.parse(gunzipSync(readFileSync('compat/font/cff-outlines.json.gz')));
const cffFixture = cffFixtures.find(f => f.name === 'stix.otf');
const cff = load_cff_outlines(load_font(gunzipSync(Buffer.from(cffFixture.input, 'base64')), 0));
const cffChosen = cffFixture.cases.filter(c => c.ok && c.commands.length >= 4).slice(0, 24);
assert.equal(cffChosen.length, 24);
for (const c of cffChosen) {
  paths.baseline.push(c.commands);
  const result = JSON.parse(cff_outline(cff, c.glyph));
  assert.equal(result.ok, true);
  paths.moon.push(result.commands);
}
for (const fixture of fonts) {
  const font = load_font(gunzipSync(Buffer.from(fixture.input, 'base64')), fixture.index);
  const chosen = fixture.cases.filter(c => c.ok && c.commands.length >= 4).slice(0, 24);
  assert.equal(chosen.length, 24);
  for (const c of chosen) {
    paths.baseline.push(c.commands);
    const result = JSON.parse(truetype_outline(font, c.glyph));
    assert.equal(result.ok, true);
    paths.moon.push(result.commands);
  }
}
function page(items) {
  const shapes = items.map((commands, i) => {
    const d = commands.map(([op, ...coords]) => op + coords.join(' ')).join(' ');
    const x = (i % 8) * 110 + 12, y = Math.floor(i / 8) * 110 + 88;
    return `<path transform="translate(${x} ${y}) scale(.08 -.08)" d="${d}"/>`;
  }).join('');
  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><title>Outline comparison</title><style>html,body{margin:0;background:white}svg{display:block;width:880px;height:1320px}</style></head><body><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 880 1320">${shapes}</svg></body></html>`;
}
const pages = { '/baseline.html': page(paths.baseline), '/moon.html': page(paths.moon) };
const server = createServer((request, response) => {
  const html = pages[new URL(request.url, 'http://localhost').pathname];
  if (!html) return response.writeHead(404).end();
  response.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' }).end(html);
});
await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
const base = `http://127.0.0.1:${server.address().port}`;
const run = args => new Promise((resolve, reject) => {
  const child = spawn(path.join(root, 'node_modules/.bin/vlmkit'), args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
  let output = ''; child.stdout.on('data', chunk => output += chunk); child.stderr.on('data', chunk => output += chunk);
  child.once('error', reject); child.once('close', code => code === 0 ? resolve(output) : reject(new Error(output)));
});
try {
  const outputRoot = path.join(root, '_build/visual-diff'); mkdirSync(outputRoot, {recursive:true});
  const output = mkdtempSync(path.join(outputRoot, 'outlines-'));
  await run(['diff', 'html', '--url', `${base}/baseline.html`, '--current-url', `${base}/moon.html`, '--output-dir', output, '--no-paint-tree']);
  const reportPath = path.join(output, 'diff-report.json');
  const report = JSON.parse(readFileSync(reportPath, 'utf8'));
  assert.equal(report.results.length, 3);
  for (const result of report.results) {
    const before = PNG.sync.read(readFileSync(path.join(output, `baseline-${result.viewport}.png`)));
    const after = PNG.sync.read(readFileSync(path.join(output, `moon-${result.viewport}.png`)));
    assert.equal(before.width, after.width); assert.equal(before.height, after.height);
    let dark = 0, changed = 0;
    for (let i = 0; i < before.data.length; i += 4) {
      if (before.data[i] < 100 && before.data[i+1] < 100 && before.data[i+2] < 100) dark++;
      if (before.data[i] !== after.data[i] || before.data[i+1] !== after.data[i+1] || before.data[i+2] !== after.data[i+2] || before.data[i+3] !== after.data[i+3]) changed++;
    }
    assert.ok(dark > 100, `${result.viewport}: blank baseline`);
    assert.equal(changed, 0, `${result.viewport}: outline pixels differ`);
  }
  process.stdout.write(await run(['diff', 'agent', reportPath, '--no-history']));
} finally { await new Promise(resolve => server.close(resolve)); }
