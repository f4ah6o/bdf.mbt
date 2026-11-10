#!/usr/bin/env node
// Reproducible differential render harness for the document converters.
//
// It fixes the input bytes, the baseline (published @bdfkit 0.2.1) and the
// current implementation (the MoonBit build at the checked-out commit), the
// browser, the scale and the viewport, and separates conversion from
// rendering with a 2x2 factorial:
//
//   A  upstream BDF + upstream renderer   (baseline)
//   B  upstream BDF + MoonBit renderer    (render-only delta)
//   C  MoonBit BDF  + upstream renderer   (conversion-only delta)
//   D  MoonBit BDF  + MoonBit renderer    (end to end)
//
// Every render is repeated so the harness reports its own noise floor. The
// control case renders one BDF with both renderers and must be identical.
//
// Usage:
//   node compat/parity/render-diff.mjs [--case=pdf/cairo-cff] [--pages=1]
//                                      [--scale=1] [--repeat=2] [--dump]
//                                      [--json] [--list]
//
// The report is written to _scratch/render-diff/report.json. The default run
// exits 0 even when differences are found; pass --strict to exit 1 on any
// non-zero conversion, render or end-to-end difference.

import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createServer } from 'node:http';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { extname, resolve } from 'node:path';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../..');
const scratch = resolve(root, '_scratch/render-diff');

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
    response.end('<!doctype html><title>render-diff</title>');
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
  const args = { case: null, pages: 1, scale: 1, repeat: 2, dump: false, json: false, list: false, strict: false, cad: false };
  for (const arg of argv) {
    if (arg === '--dump') args.dump = true;
    else if (arg === '--json') args.json = true;
    else if (arg === '--list') args.list = true;
    else if (arg === '--strict') args.strict = true;
    else if (arg === '--cad') args.cad = true;
    else if (arg.startsWith('--case=')) args.case = arg.slice(7);
    else if (arg.startsWith('--pages=')) args.pages = Number(arg.slice(8));
    else if (arg.startsWith('--scale=')) args.scale = Number(arg.slice(8));
    else if (arg.startsWith('--repeat=')) args.repeat = Number(arg.slice(9));
    else throw new Error('unknown argument: ' + arg);
  }
  if (!Number.isFinite(args.pages) || args.pages < 1) throw new Error('--pages must be >= 1');
  if (!Number.isFinite(args.scale) || args.scale <= 0) throw new Error('--scale must be > 0');
  if (!Number.isFinite(args.repeat) || args.repeat < 1) throw new Error('--repeat must be >= 1');
  return args;
}
const args = parseArgs(process.argv.slice(2));

// The smallest representative fixture of each format, plus the render-only
// control. The control is the same BDF for both converters, so its
// conversion delta is zero by construction and its render delta is the
// renderer's own floor.
const CASES = [
  { id: 'control/bdf-fixture', format: 'bdf', file: 'compat/visual/fixture.bdf', control: true },
  { id: 'pdf/cairo-cff', format: 'pdf', file: 'compat/parity/fixtures/pdf/cairo-cff.pdf' },
  { id: 'pdf/reportlab-mixed', format: 'pdf', file: 'compat/parity/fixtures/pdf/reportlab-mixed.pdf' },
  { id: 'docx/basic', format: 'docx', file: 'compat/parity/fixtures/docx/basic.docx' },
  { id: 'pptx/basic', format: 'pptx', file: 'compat/parity/fixtures/pptx/basic.pptx' },
  { id: 'xlsx/basic', format: 'xlsx', file: 'compat/parity/fixtures/xlsx/basic.xlsx' },
  { id: 'jww/old', format: 'jww', file: 'compat/jww/fixtures/old.jww' },
  { id: 'jww/shapes', format: 'jww', file: 'compat/jww/fixtures/shapes.jww' },
  // Ordinary CAD, kept in scope; run with --cad.
  { id: 'dxf/shapes', format: 'dxf', file: 'compat/dxf/fixtures/shapes.dxf', cad: true },
  { id: 'sxf/shapes', format: 'sxf', file: 'compat/sxf/fixtures/shapes.sfc', cad: true },
  { id: 'cgm/shapes', format: 'cgm', file: 'compat/cgm/fixtures/shapes.cgm', cad: true },
  { id: 'hpgl/shapes', format: 'hpgl', file: 'compat/hpgl/fixtures/shapes.plt', cad: true },
];

let cases = CASES.filter(c => args.cad || !c.cad);
if (args.case) cases = cases.filter(c => c.id === args.case);
if (cases.length === 0) {
  console.error('no cases selected');
  process.exit(2);
}
if (args.list) {
  for (const c of cases) console.log(c.id, c.file);
  server.close();
  process.exit(0);
}

function fileSha256(path) {
  try {
    return execFileSync('sha256sum', [path], { encoding: 'utf8' }).split(' ')[0];
  } catch {
    return null;
  }
}

function command(command, args) {
  try {
    return execFileSync(command, args, { encoding: 'utf8', cwd: root }).trim();
  } catch {
    return null;
  }
}

const environment = {
  gitCommit: command('git', ['rev-parse', 'HEAD']),
  gitStatus: command('git', ['status', '--porcelain']),
  node: process.version,
  moon: command('moon', ['version']),
  playwright: JSON.parse(await readFile(resolve(root, 'node_modules/playwright/package.json'), 'utf8')).version,
  packages: Object.fromEntries(
    await Promise.all(['core', 'render', 'convert', 'convert-all', 'convert-office', 'viewer'].map(async name => [
      '@bdfkit/' + name,
      JSON.parse(await readFile(resolve(root, 'node_modules/@bdfkit', name, 'package.json'), 'utf8')).version,
    ])),
  ),
  build: {
    browser: fileSha256(resolve(root, '_build/js/debug/build/browser/browser.js')),
    nativeConverterWorker: fileSha256(resolve(root, '_build/js/debug/build/native_converter_worker/native_converter_worker.js')),
    renderWorker: fileSha256(resolve(root, '_build/js/debug/build/render_worker/render_worker.js')),
  },
  fonts: {
    count: Number(command('fc-list', [])?.split('\n').filter(Boolean).length ?? 0),
    digest: command('sh', ['-c', 'fc-list | sort | sha256sum']),
  },
};

const launchArgs = [
  '--disable-gpu',
  '--disable-lcd-text',
  '--font-render-hinting=none',
  '--disable-font-subpixel-positioning',
  '--force-color-profile=srgb',
  '--hide-scrollbars',
];
const browser = await chromium.launch({ headless: true, args: launchArgs });
const chromiumVersion = browser.version();
const results = [];
let failed = 0;
let page;
try {
  page = await browser.newPage({ viewport: { width: 1280, height: 1024 }, deviceScaleFactor: 1 });
  page.setDefaultTimeout(0);
  if (process.env.RENDER_DIFF_DEBUG_CONSOLE) {
    page.on('console', message => console.log('console:', message.text()));
  }
  await page.goto(base + '/blank.html');

  const ready = await page.evaluate(async () => {
    try {
      const { Converter } = await import('/node_modules/@bdfkit/convert/dist/index.js');
      const { BdfWorkerClient } = await import('/node_modules/@bdfkit/render/dist/client.js');
      const { bdf_create_native_converter, bdf_create_render_worker } = await import('/_build/js/debug/build/browser/browser.js');
      const upstreamConverter = new Converter(
        new Worker('/node_modules/@bdfkit/convert/dist/worker.js', { type: 'module' }),
        '/node_modules/@bdfkit/convert-all/dist/converter.wasm',
      );
      const moonConverter = bdf_create_native_converter('/_build/js/debug/build/native_converter_worker/native_converter_worker.js');
      await Promise.all([upstreamConverter.ready, moonConverter.ready]);
      const upstreamRender = new BdfWorkerClient(new Worker('/node_modules/@bdfkit/render/dist/worker.js', { type: 'module' }));
      const moonRender = bdf_create_render_worker('/_build/js/debug/build/render_worker/render_worker.js');
      globalThis.__renderDiff = { upstreamConverter, moonConverter, upstreamRender, moonRender };
      return { ok: true };
    } catch (error) {
      return { ok: false, error: String(error?.stack ?? error) };
    }
  });
  if (!ready.ok) throw new Error('setup failed: ' + ready.error);

  const payload = await page.evaluate(async ({ cases, scale, pages, repeat, dump }) => {
    const { BdfDocument, BufferSource } = await import('/node_modules/@bdfkit/core/dist/index.js');
    const { upstreamConverter, moonConverter, upstreamRender, moonRender } = globalThis.__renderDiff;

    const sha256 = async bytes => {
      const digest = await crypto.subtle.digest('SHA-256', bytes);
      return [...new Uint8Array(digest)].map(b => b.toString(16).padStart(2, '0')).join('');
    };
    const toBase64 = bytes => {
      let out = '';
      const chunk = 0x8000;
      for (let i = 0; i < bytes.length; i += chunk) out += String.fromCharCode(...bytes.subarray(i, i + chunk));
      return btoa(out);
    };

    async function convert(converter, bytes, options) {
      try {
        const result = await converter.convert(bytes, options);
        return {
          ok: true,
          bdf: result.bdf,
          format: result.format,
          summary: result.summary,
          warnings: result.warnings,
          protected: result.protected,
        };
      } catch (error) {
        return { ok: false, error: String(error?.message ?? error) };
      }
    }

    async function inspect(bdf) {
      const doc = await BdfDocument.open(new BufferSource(bdf));
      const view = doc.manifest.views[0];
      return {
        viewId: view.id,
        kind: view.kind,
        pages: (view.pages ?? []).map(p => ({ w: p.w, h: p.h })),
        tile: view.tile ?? null,
        cols: view.cols ?? null,
        rows: view.rows ?? null,
        gridlines: view.gridlines ?? null,
        parts: doc.manifest.parts.length,
        textIndex: view.textIndex ?? null,
      };
    }

    async function render(client, bdf, viewId, pageIndex, kind, viewport) {
      const manifest = await client.open({ kind: 'buffer', buffer: bdf.slice().buffer });
      const view = manifest.views.find(v => v.id === viewId) ?? manifest.views[0];
      let bitmap;
      if (kind === 'sheet') bitmap = await client.sheet(view.id, viewport, scale);
      else bitmap = await client.page(view.id, pageIndex, scale);
      const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
      const ctx = canvas.getContext('2d');
      ctx.drawImage(bitmap, 0, 0);
      bitmap.close();
      const image = ctx.getImageData(0, 0, canvas.width, canvas.height);
      return { width: canvas.width, height: canvas.height, data: image.data };
    }

    function diff(a, b) {
      const width = Math.max(a.width, b.width);
      const height = Math.max(a.height, b.height);
      let changed = 0;
      let maxDelta = 0;
      let minX = width;
      let minY = height;
      let maxX = -1;
      let maxY = -1;
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const ia = x < a.width && y < a.height ? (y * a.width + x) * 4 : -1;
          const ib = x < b.width && y < b.height ? (y * b.width + x) * 4 : -1;
          const ra = ia < 0 ? 0 : a.data[ia];
          const ga = ia < 0 ? 0 : a.data[ia + 1];
          const ba = ia < 0 ? 0 : a.data[ia + 2];
          const aa = ia < 0 ? 0 : a.data[ia + 3];
          const rb = ib < 0 ? 0 : b.data[ib];
          const gb = ib < 0 ? 0 : b.data[ib + 1];
          const bb = ib < 0 ? 0 : b.data[ib + 2];
          const ab = ib < 0 ? 0 : b.data[ib + 3];
          const delta = Math.max(Math.abs(ra - rb), Math.abs(ga - gb), Math.abs(ba - bb), Math.abs(aa - ab));
          if (delta !== 0) {
            changed++;
            if (delta > maxDelta) maxDelta = delta;
            if (x < minX) minX = x;
            if (x > maxX) maxX = x;
            if (y < minY) minY = y;
            if (y > maxY) maxY = y;
          }
        }
      }
      return {
        width,
        height,
        total: width * height,
        changed,
        ratio: width * height === 0 ? 0 : changed / (width * height),
        maxDelta,
        bbox: maxX < 0 ? null : { x: minX, y: minY, w: maxX - minX + 1, h: maxY - minY + 1 },
      };
    }

    function diffPng(a, b) {
      const width = Math.max(a.width, b.width);
      const height = Math.max(a.height, b.height);
      const canvas = new OffscreenCanvas(width, height);
      const ctx = canvas.getContext('2d');
      const image = ctx.createImageData(width, height);
      for (let y = 0; y < height; y++) {
        for (let x = 0; x < width; x++) {
          const ia = x < a.width && y < a.height ? (y * a.width + x) * 4 : -1;
          const ib = x < b.width && y < b.height ? (y * b.width + x) * 4 : -1;
          const ra = ia < 0 ? 0 : a.data[ia];
          const ga = ia < 0 ? 0 : a.data[ia + 1];
          const ba = ia < 0 ? 0 : a.data[ia + 2];
          const aa = ia < 0 ? 0 : a.data[ia + 3];
          const rb = ib < 0 ? 0 : b.data[ib];
          const gb = ib < 0 ? 0 : b.data[ib + 1];
          const bb = ib < 0 ? 0 : b.data[ib + 2];
          const ab = ib < 0 ? 0 : b.data[ib + 3];
          const delta = Math.max(Math.abs(ra - rb), Math.abs(ga - gb), Math.abs(ba - bb), Math.abs(aa - ab));
          const o = (y * width + x) * 4;
          if (delta === 0) {
            image.data[o] = 255;
            image.data[o + 1] = 255;
            image.data[o + 2] = 255;
            image.data[o + 3] = 255;
          } else {
            image.data[o] = 255;
            image.data[o + 1] = Math.max(0, 255 - delta);
            image.data[o + 2] = Math.max(0, 255 - delta);
            image.data[o + 3] = 255;
          }
        }
      }
      ctx.putImageData(image, 0, 0);
      return canvas.convertToBlob({ type: 'image/png' }).then(blob => new Promise(resolve => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.readAsDataURL(blob);
      }));
    }

    const out = [];
    for (const c of cases) {
      const bytes = new Uint8Array(await (await fetch(c.url)).arrayBuffer());
      const entry = {
        id: c.id,
        format: c.format,
        file: c.file,
        control: Boolean(c.control),
        options: c.options ?? {},
        input: { bytes: bytes.length, sha256: await sha256(bytes) },
        conversion: null,
        render: null,
        error: null,
      };
      try {
        let upBdf;
        let moonBdf;
        if (c.control) {
          upBdf = bytes;
          moonBdf = bytes;
          entry.conversion = { control: true, bdf: { bytes: bytes.length, sha256: entry.input.sha256 } };
        } else {
          const [up, mo] = await Promise.all([
            convert(upstreamConverter, bytes, c.options),
            convert(moonConverter, bytes, c.options),
          ]);
          entry.conversion = {
            upstream: up.ok
              ? { ok: true, format: up.format, summary: up.summary, warnings: up.warnings, protected: up.protected, bdf: { bytes: up.bdf.length, sha256: await sha256(up.bdf) } }
              : { ok: false, error: up.error },
            moon: mo.ok
              ? { ok: true, format: mo.format, summary: mo.summary, warnings: mo.warnings, protected: mo.protected, bdf: { bytes: mo.bdf.length, sha256: await sha256(mo.bdf) } }
              : { ok: false, error: mo.error },
          };
          if (!up.ok || !mo.ok) {
            entry.error = 'conversion failed';
            out.push(entry);
            continue;
          }
          upBdf = up.bdf;
          moonBdf = mo.bdf;
          entry.conversion.bdfEqual = entry.conversion.upstream.bdf.sha256 === entry.conversion.moon.bdf.sha256;
          entry.conversion.formatEqual = up.format === mo.format;
          entry.conversion.summaryEqual = up.summary === mo.summary;
          entry.conversion.warningsEqual = JSON.stringify(up.warnings) === JSON.stringify(mo.warnings);
          if (dump) {
            entry.conversion.upstream.bdfBase64 = toBase64(upBdf);
            entry.conversion.moon.bdfBase64 = toBase64(moonBdf);
          }
        }

        const upInfo = await inspect(upBdf);
        const moonInfo = await inspect(moonBdf);
        entry.conversion.upstreamInfo = upInfo;
        entry.conversion.moonInfo = moonInfo;
        entry.conversion.viewKindEqual = upInfo.kind === moonInfo.kind;
        entry.conversion.pageCountEqual = upInfo.pages.length === moonInfo.pages.length;
        entry.conversion.pageSizesEqual = JSON.stringify(upInfo.pages) === JSON.stringify(moonInfo.pages);
        if (upInfo.pages.length && moonInfo.pages.length) {
          const upArea = upInfo.pages.reduce((sum, p) => sum + p.w * p.h, 0);
          const moonArea = moonInfo.pages.reduce((sum, p) => sum + p.w * p.h, 0);
          entry.conversion.areaRatio = upArea === 0 ? null : moonArea / upArea;
        }

        const kind = upInfo.kind;
        const sheetViewport = { x: 0, y: 0, w: 800, h: 600 };
        const pageCount = kind === 'sheet' ? 1 : Math.min(pages, upInfo.pages.length, moonInfo.pages.length);
        const renders = [];
        for (let index = 0; index < pageCount; index++) {
          const viewport = kind === 'sheet' ? sheetViewport : null;
          const a = await render(upstreamRender, upBdf, upInfo.viewId, index, kind, viewport);
          const b = await render(moonRender, upBdf, upInfo.viewId, index, kind, viewport);
          const c2 = await render(upstreamRender, moonBdf, moonInfo.viewId, index, kind, viewport);
          const d = await render(moonRender, moonBdf, moonInfo.viewId, index, kind, viewport);
          const repeats = [];
          for (let r = 1; r < repeat; r++) {
            const again = await render(upstreamRender, upBdf, upInfo.viewId, index, kind, viewport);
            repeats.push(diff(a, again));
          }
          const record = {
            index,
            viewport,
            upstream: { width: a.width, height: a.height },
            moon: { width: d.width, height: d.height },
            renderOnly: diff(a, b),
            conversionOnly: diff(a, c2),
            endToEnd: diff(a, d),
            determinism: repeats,
          };
          if (dump) {
            record.renderOnlyPng = await diffPng(a, b);
            record.conversionOnlyPng = await diffPng(a, c2);
            record.endToEndPng = await diffPng(a, d);
          }
          renders.push(record);
        }
        entry.render = renders;
      } catch (error) {
        entry.error = String(error?.stack ?? error);
      }
      out.push(entry);
    }
    return out;
  }, { cases: cases.map(c => ({ ...c, url: '/' + c.file })), scale: args.scale, pages: args.pages, repeat: args.repeat, dump: args.dump });

  for (const entry of payload) {
    results.push(entry);
    if (entry.error) {
      failed += 1;
      console.log('FAIL '.padEnd(5), entry.id, entry.error.split('\n')[0]);
      continue;
    }
    const conversion = entry.conversion;
    const renders = entry.render ?? [];
    const worst = key => renders.reduce((max, r) => Math.max(max, r[key].ratio), 0);
    const renderOnly = worst('renderOnly');
    const conversionOnly = worst('conversionOnly');
    const endToEnd = worst('endToEnd');
    const noise = renders.reduce((max, r) => Math.max(max, ...r.determinism.map(d => d.ratio)), 0);
    const area = conversion.areaRatio ?? 1;
    const flags = [];
    if (conversion.bdfEqual === false) flags.push('bdf');
    if (conversion.summaryEqual === false) flags.push('summary');
    if (conversion.warningsEqual === false) flags.push('warnings');
    if (conversion.pageSizesEqual === false) flags.push('page-size');
    if (conversion.viewKindEqual === false) flags.push('view-kind');
    if (renderOnly > 0) flags.push('render');
    if (conversionOnly > 0) flags.push('conversion');
    if (endToEnd > 0) flags.push('end-to-end');
    if (noise > 0) flags.push('noise');
    if (flags.length) failed += 1;
    console.log(
      (flags.length ? 'DIFF ' : 'ok   ').padEnd(5),
      entry.id.padEnd(24),
      'conv=' + (conversionOnly * 100).toFixed(4) + '%',
      'render=' + (renderOnly * 100).toFixed(4) + '%',
      'e2e=' + (endToEnd * 100).toFixed(4) + '%',
      'area=' + area.toFixed(4),
      'noise=' + (noise * 100).toFixed(4) + '%',
      flags.length ? '[' + flags.join(',') + ']' : '',
    );
  }
} finally {
  try {
    await page?.evaluate(() => {
      globalThis.__renderDiff?.upstreamConverter?.terminate();
      globalThis.__renderDiff?.moonConverter?.terminate();
      globalThis.__renderDiff?.upstreamRender?.terminate();
      globalThis.__renderDiff?.moonRender?.terminate();
    });
  } catch {
    // the page may be gone
  }
  await browser.close();
  server.close();
}

await mkdir(scratch, { recursive: true });
const report = {
  generatedAt: new Date().toISOString(),
  environment: { ...environment, chromium: chromiumVersion, launchArgs, scale: args.scale, pages: args.pages, repeat: args.repeat },
  cases: results,
};
await writeFile(resolve(scratch, 'report.json'), JSON.stringify(report, null, 2));
if (args.dump) {
  for (const entry of results) {
    const dir = resolve(scratch, entry.id.replace(/[^a-z0-9_.-]+/gi, '_'));
    await mkdir(dir, { recursive: true });
    if (entry.conversion?.upstream?.bdfBase64) {
      await writeFile(resolve(dir, 'upstream.bdf'), Buffer.from(entry.conversion.upstream.bdfBase64, 'base64'));
      await writeFile(resolve(dir, 'moon.bdf'), Buffer.from(entry.conversion.moon.bdfBase64, 'base64'));
    }
    for (const record of entry.render ?? []) {
      for (const key of ['renderOnlyPng', 'conversionOnlyPng', 'endToEndPng']) {
        if (!record[key]) continue;
        const data = record[key].split(',')[1];
        await writeFile(resolve(dir, key.replace('Png', '') + '-' + record.index + '.png'), Buffer.from(data, 'base64'));
      }
    }
  }
}
console.log('');
console.log('Report: ' + resolve(scratch, 'report.json'));
if (args.json) console.log(JSON.stringify(report, null, 2));
if (args.strict && failed) process.exit(1);
