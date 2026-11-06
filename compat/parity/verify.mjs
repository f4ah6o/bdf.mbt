#!/usr/bin/env node
// Upstream parity check for the five document formats.
//
// Converts the same fixture with the upstream TinyGo Wasm converter
// (@bdfkit/convert-all) and the MoonBit native converter worker in Chromium,
// then compares the canonical BDF (see canonical.mjs) plus summary, warnings
// and the protected flag. The default run writes _scratch/parity/report.json
// and exits 0 even when differences are found (a baseline report); pass
// --strict to fail on the first difference.
//
// Usage:
//   node compat/parity/verify.mjs [--format=pdf,docx,...] [--case=pdf/chrome-doc#default]
//                                 [--strict] [--dump] [--limit=40]

import { createServer } from 'node:http';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';
import { canonicalize, compareCanonical, digest } from './canonical.mjs';

const root = resolve(import.meta.dirname, '../..');
const fixtures = resolve(root, 'compat/parity/fixtures');
const scratch = resolve(root, '_scratch/parity');

const mime = {
  '.html': 'text/html',
  '.js': 'text/javascript',
  '.mjs': 'text/javascript',
  '.wasm': 'application/wasm',
  '.json': 'application/json',
};

const server = createServer(async (request, response) => {
  if (request.url === '/blank.html') {
    response.writeHead(200, { 'content-type': 'text/html' });
    response.end('<!doctype html><title>parity</title>');
    return;
  }
  try {
    const file = resolve(root, '.' + decodeURIComponent(new URL(request.url, 'http://x').pathname));
    if (!file.startsWith(root + '/')) {
      response.writeHead(403).end();
      return;
    }
    const data = await readFile(file);
    response.writeHead(200, {
      'content-type': mime[extname(file)] ?? 'application/octet-stream',
      'content-length': data.length,
    });
    response.end(data);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolvePromise, reject) => {
  server.once('error', reject);
  server.listen(0, '127.0.0.1', resolvePromise);
});
const base = 'http://127.0.0.1:' + server.address().port;

function parseArgs(argv) {
  const args = { formats: null, case: null, strict: false, dump: false, limit: 40 };
  for (const arg of argv) {
    if (arg === '--strict') args.strict = true;
    else if (arg === '--dump') args.dump = true;
    else if (arg.startsWith('--limit=')) args.limit = Number(arg.slice(8));
    else if (arg.startsWith('--format=')) args.formats = arg.slice(9).split(',').filter(Boolean);
    else if (arg.startsWith('--case=')) args.case = arg.slice(7);
    else throw new Error('unknown argument: ' + arg);
  }
  return args;
}
const args = parseArgs(process.argv.slice(2));

function caseList() {
  const cases = [];
  const add = (format, file, options = {}, suffix = 'default') => {
    cases.push({
      id: format + '/' + file.replace(/\.[^.]+$/, '') + '#' + suffix,
      format,
      file,
      name: file,
      options,
    });
  };
  for (const file of ['cairo-cff.pdf', 'cairo-type1.pdf', 'chrome-doc.pdf', 'chrome-masks.pdf',
    'chrome-slides.pdf', 'cjk-cmaps.pdf', 'images-jpx-jbig2.pdf', 'reportlab-master.pdf',
    'reportlab-mixed.pdf', 'reportlab-type1.pdf', 'weasyprint-webfonts.pdf']) add('pdf', file);
  add('pdf', 'chrome-doc.pdf', { params: { kind: 'flow' } }, 'flow');
  add('pdf', 'chrome-slides.pdf', { params: { box: 'media' } }, 'media-box');
  add('pdf', 'reportlab-mixed.pdf', { params: { 'no-share': 'true' } }, 'no-share');
  add('pdf', 'chrome-doc.pdf', { pages: '1' }, 'page-1');

  for (const file of ['basic.docx', 'styles.docx', 'grid.docx', 'vertical.docx', 'math.docx',
    'form-pages.docx', 'form-rows.docx', 'form-fixed.docx']) add('docx', file);
  add('docx', 'basic.docx', { params: { views: 'pages' } }, 'pages');
  add('docx', 'basic.docx', { params: { views: 'scroll' } }, 'scroll');
  add('docx', 'grid.docx', { pages: '1' }, 'page-1');
  add('docx', 'math.docx', { params: { views: 'pages' } }, 'pages-only');

  for (const file of ['basic.pptx', 'features.pptx', 'math.pptx', 'form-pages.pptx',
    'form-rows.pptx', 'form-fixed.pptx']) add('pptx', file);
  add('pptx', 'features.pptx', { params: { hidden: 'true' } }, 'hidden');
  add('pptx', 'basic.pptx', { pages: '1' }, 'slide-1');

  for (const file of ['basic.xlsx', 'features.xlsx', 'math.xlsx', 'print.xlsx',
    'form-pages.xlsx', 'form-rows.xlsx', 'form-fixed.xlsx']) add('xlsx', file);
  add('xlsx', 'print.xlsx', { params: { views: 'print' } }, 'print');
  add('xlsx', 'print.xlsx', { params: { views: 'both' } }, 'both');
  add('xlsx', 'basic.xlsx', { params: { hidden: 'true' } }, 'hidden');
  add('xlsx', 'basic.xlsx', { pages: '1' }, 'sheet-1');

  for (const file of ['basic.md', 'math.md', 'svg.md']) add('markdown', file);
  add('markdown', 'basic.md', { params: { views: 'pages' } }, 'pages');
  add('markdown', 'basic.md', { params: { views: 'both' } }, 'both');
  add('markdown', 'basic.md', { params: { width: '600' } }, 'width-600');
  return cases;
}

let cases = caseList();
if (args.formats) cases = cases.filter(c => args.formats.includes(c.format));
if (args.case) cases = cases.filter(c => c.id === args.case);
if (cases.length === 0) {
  console.error('no cases selected');
  process.exit(2);
}

function readFixture(c) {
  return readFile(resolve(fixtures, c.format, c.file));
}

function serializeResult(value) {
  if (!value) return { error: 'no result' };
  if (value.error) return { error: String(value.error) };
  return {
    // The page returns the BDF as base64 already.
    bdf: value.bdf,
    format: value.format ?? null,
    summary: value.summary ?? null,
    warnings: Array.isArray(value.warnings) ? value.warnings : [],
    protected: Boolean(value.protected),
  };
}

const browser = await chromium.launch({ headless: true });
const results = [];
let failed = 0;
let page;
try {
  page = await browser.newPage();
  page.setDefaultTimeout(0);
  if (process.env.PARITY_DEBUG_CONSOLE) {
    page.on('console', message => console.log('console:', message.text()));
  }
  await page.goto(base + '/blank.html');
  const ready = await page.evaluate(async () => {
    try {
      const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
      const { bdf_create_native_converter } = await import('/_build/js/debug/build/browser/browser.js');
      const upstream = new Converter(
        new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
        '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
      );
      const moon = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
      await Promise.all([upstream.ready, moon.ready]);
      globalThis.__parity = { upstream, moon };
      return { ok: true };
    } catch (error) {
      return { ok: false, error: String(error?.stack ?? error) };
    }
  });
  if (!ready.ok) throw new Error('converter setup failed: ' + ready.error);

  for (const format of ['pdf', 'docx', 'pptx', 'xlsx', 'markdown']) {
    const group = cases.filter(c => c.format === format);
    if (group.length === 0) continue;
    const inputs = [];
    for (const c of group) {
      inputs.push({
        id: c.id,
        data: Buffer.from(await readFixture(c)).toString('base64'),
        format: c.format,
        name: c.name,
        pages: c.options.pages ?? '',
        params: c.options.params ?? {},
      });
    }
    const converted = await page.evaluate(async inputs => {
      const { upstream, moon } = globalThis.__parity;
      const toBase64 = bytes => {
        let out = '';
        const chunk = 0x8000;
        for (let i = 0; i < bytes.length; i += chunk) {
          out += String.fromCharCode(...bytes.subarray(i, i + chunk));
        }
        return btoa(out);
      };
      const run = async (converter, data, options) => {
        try {
          const result = await converter.convert(data, options);
          return {
            bdf: toBase64(result.bdf),
            format: result.format,
            summary: result.summary,
            warnings: result.warnings,
            protected: result.protected,
          };
        } catch (error) {
          return { error: String(error?.message ?? error) };
        }
      };
      const out = [];
      for (const input of inputs) {
        const data = Uint8Array.from(atob(input.data), ch => ch.charCodeAt(0));
        const options = { format: input.format, name: input.name };
        if (input.pages) options.pages = input.pages;
        if (Object.keys(input.params).length) options.params = input.params;
        out.push({
          id: input.id,
          upstream: await run(upstream, data, options),
          moon: await run(moon, data, options),
        });
      }
      return out;
    }, inputs);

    for (const c of group) {
      const convertedCase = converted.find(x => x.id === c.id);
      const entry = {
        id: c.id,
        format: c.format,
        file: c.file,
        options: c.options,
        upstream: serializeResult(convertedCase?.upstream),
        moon: serializeResult(convertedCase?.moon),
        status: 'pass',
        diffs: [],
      };
      const up = entry.upstream;
      const mo = entry.moon;
      if (up.error || mo.error) {
        if (up.error && mo.error) {
          entry.status = 'both-error';
          entry.note = { upstreamError: up.error, moonError: mo.error };
        } else {
          entry.status = 'error';
          entry.note = { upstreamError: up.error ?? null, moonError: mo.error ?? null };
        }
      } else {
        if (process.env.PARITY_DEBUG) {
          const upBytes = Buffer.from(up.bdf, 'base64');
          const moBytes = Buffer.from(mo.bdf, 'base64');
          console.log('debug', c.id, 'up', upBytes.length, upBytes.subarray(0, 12).toString('hex'),
            'mo', moBytes.length, moBytes.subarray(0, 12).toString('hex'));
        }
        const upCanon = await canonicalize(Buffer.from(up.bdf, 'base64'));
        const moCanon = await canonicalize(Buffer.from(mo.bdf, 'base64'));
        entry.upstreamDigest = digest(upCanon);
        entry.moonDigest = digest(moCanon);
        const allDiffs = compareCanonical(upCanon, moCanon, { limit: 100000, tolerance: 0.01 });
        if (up.format !== mo.format) allDiffs.push({ path: '$.format', upstream: up.format, moon: mo.format });
        if (up.summary !== mo.summary) allDiffs.push({ path: '$.summary', upstream: up.summary, moon: mo.summary });
        if (JSON.stringify(up.warnings) !== JSON.stringify(mo.warnings)) {
          allDiffs.push({ path: '$.warnings', upstream: up.warnings, moon: mo.warnings });
        }
        if (up.protected !== mo.protected) allDiffs.push({ path: '$.protected', upstream: up.protected, moon: mo.protected });
        entry.diffCount = allDiffs.length;
        const categories = {};
        for (const diff of allDiffs) {
          const key = diff.path
            .replace(/\[[0-9]+\]/g, '[]')
            .split('.').slice(0, 5).join('.');
          categories[key] = (categories[key] ?? 0) + 1;
        }
        entry.diffCategories = Object.fromEntries(
          Object.entries(categories).sort((a, b) => b[1] - a[1]).slice(0, 12),
        );
        entry.diffs = allDiffs.slice(0, args.limit);
        if (allDiffs.length) entry.status = 'diff';
        if (args.dump) {
          await mkdir(resolve(scratch, 'canonical'), { recursive: true });
          const safe = c.id.replace(/[^a-z0-9_.-]+/gi, '_');
          await writeFile(resolve(scratch, 'canonical', safe + '.upstream.json'), JSON.stringify(upCanon, null, 2));
          await writeFile(resolve(scratch, 'canonical', safe + '.moon.json'), JSON.stringify(moCanon, null, 2));
          await writeFile(resolve(scratch, 'canonical', safe + '.upstream.bdf'), Buffer.from(up.bdf, 'base64'));
          await writeFile(resolve(scratch, 'canonical', safe + '.moon.bdf'), Buffer.from(mo.bdf, 'base64'));
        }
      }
      if (entry.status === 'diff' || entry.status === 'error') failed += 1;
      results.push(entry);
      const marker = entry.status === 'pass' ? 'ok  ' : entry.status === 'both-error' ? 'both' : 'FAIL';
      console.log(marker.padEnd(5), entry.id, entry.diffCount ? '(' + entry.diffCount + ' diffs)' : '');
      if (entry.status === 'diff') {
        for (const diff of entry.diffs.slice(0, 5)) {
          console.log('      ', diff.path, JSON.stringify(diff.upstream), '!=', JSON.stringify(diff.moon));
        }
      }
      if (entry.status === 'error') {
        console.log('      ', JSON.stringify(entry.note));
      }
    }
  }
} finally {
  try {
    await page.evaluate(() => {
      globalThis.__parity?.moon?.terminate();
      globalThis.__parity?.upstream?.terminate();
    });
  } catch {
    // the page may be gone
  }
  await browser.close();
  server.close();
}

await mkdir(scratch, { recursive: true });
await writeFile(resolve(scratch, 'report.json'), JSON.stringify({
  generatedAt: new Date().toISOString(),
  cases: results,
}, null, 2));
const passed = results.filter(r => r.status === 'pass').length;
const both = results.filter(r => r.status === 'both-error').length;
const diffed = results.filter(r => r.status === 'diff').length;
const errored = results.filter(r => r.status === 'error').length;
console.log('');
console.log('Parity: ' + passed + ' pass, ' + diffed + ' diff, ' + errored + ' one-sided error, ' + both + ' both-error');
console.log('Report: ' + resolve(scratch, 'report.json'));
if (args.strict && (diffed || errored)) process.exit(1);
