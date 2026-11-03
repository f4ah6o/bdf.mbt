import { createReadStream } from 'node:fs';
import { stat, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { resolve, extname } from 'node:path';
import os from 'node:os';
import { chromium } from 'playwright';

const root = resolve(import.meta.dirname, '../_build/pages');
const output = resolve(import.meta.dirname, 'benchmarks.json');
const iterations = 7;
const warmup = 2;
const types = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.wasm': 'application/wasm',
  '.bdf': 'application/octet-stream',
  '.pdf': 'application/pdf',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
};
const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (!url.pathname.startsWith('/bdf.mbt/')) { res.writeHead(404).end(); return; }
  const file = resolve(root, decodeURIComponent(url.pathname.slice('/bdf.mbt/'.length)) || 'benchmark.html');
  if (!file.startsWith(root + '/')) { res.writeHead(403).end(); return; }
  try {
    const info = await stat(file);
    if (!info.isFile()) throw new Error('not a file');
    res.writeHead(200, { 'Content-Type': types[extname(file)] ?? 'application/octet-stream', 'Content-Length': info.size });
    createReadStream(file).pipe(res);
  } catch { res.writeHead(404).end(); }
});
await new Promise((resolvePromise, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolvePromise); });
const url = `http://127.0.0.1:${server.address().port}/bdf.mbt/`;

const browser = await chromium.launch({ headless: true });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.setDefaultTimeout(180000);
  await page.goto(url + 'benchmark.html', { waitUntil: 'networkidle' });
  const data = await page.evaluate(async ({ iterations, warmup }) => {
    const base64 = bytes => {
      let text = '';
      const chunk = 0x8000;
      for (let index = 0; index < bytes.length; index += chunk) {
        text += String.fromCharCode(...bytes.subarray(index, index + chunk));
      }
      return btoa(text);
    };
    const fetchBytes = async path => new Uint8Array(await (await fetch(path)).arrayBuffer());
    const bdfBytes = await fetchBytes('./samples/upstream-demo.bdf');
    const pdfBytes = await fetchBytes('./samples/upstream-demo.pdf');
    const bdf = base64(bdfBytes);
    const pdf = base64(pdfBytes);
    const js = await import('./export.js');
    const wasmHost = await import('./wasm-gc.js');
    const wasm = await wasmHost.createWasm('./wasm-gc.wasm');

    const median = values => {
      const sorted = [...values].sort((a, b) => a - b);
      return sorted[Math.floor(sorted.length / 2)];
    };
    const measure = fn => {
      for (let index = 0; index < warmup; index += 1) fn();
      const times = [];
      for (let index = 0; index < iterations; index += 1) {
        const start = performance.now();
        fn();
        times.push(performance.now() - start);
      }
      return median(times);
    };

    const jsPdf = measure(() => JSON.parse(js.bdf_wasm_export_pdf(bdf, 0)));
    const wasmPdf = measure(() => wasm.exportPdf(bdf, false));
    const jsMarkdown = measure(() => JSON.parse(js.bdf_wasm_markdown(bdf, 'zip')));
    const wasmMarkdown = measure(() => wasm.markdown(bdf, 'zip'));
    const jsText = measure(() => JSON.parse(js.bdf_wasm_search_text(bdf)));
    const wasmText = measure(() => wasm.searchText(bdf));
    const jsPdfToBdf = measure(() => JSON.parse(js.bdf_wasm_pdf(pdf, '')));
    const wasmPdfToBdf = measure(() => wasm.convertPdf(pdf, ''));

    const pdfResult = JSON.parse(js.bdf_wasm_export_pdf(bdf, 0));
    const markdownResult = JSON.parse(js.bdf_wasm_markdown(bdf, 'zip'));
    const textResult = JSON.parse(js.bdf_wasm_search_text(bdf));
    const converted = JSON.parse(js.bdf_wasm_pdf(pdf, ''));
    const text = JSON.parse(textResult.text);
    const records = [];
    for (const view of text.views ?? []) {
      for (const page of view.pages ?? []) {
        if (page.text) records.push({ id: view.id + ':' + (page.page ?? 1), page: page.page ?? 1, view: view.id, title: view.title ?? '', text: page.text });
      }
    }
    const MiniSearch = (await import('./minisearch/index.js')).default;
    const normalize = value => value.normalize('NFKC').toLowerCase().replace(/[\u3041-\u3096]/g, char => String.fromCharCode(char.charCodeAt(0) + 0x60));
    const tokenize = value => {
      const tokens = [];
      for (const part of normalize(value).split(/[^\p{L}\p{N}]+/u)) {
        if (!part) continue;
        if (/^[\p{Script=Latin}\p{N}]+$/u.test(part)) tokens.push(part);
        else if (/[\u3040-\u30ff\u3400-\u9fff]/u.test(part)) {
          const chars = [...part];
          if (chars.length === 1) tokens.push(part);
          else for (let index = 0; index + 1 < chars.length; index += 1) tokens.push(chars[index] + chars[index + 1]);
        } else tokens.push(part);
      }
      return tokens;
    };
    const makeIndex = () => {
      const index = new MiniSearch({
        fields: ['text', 'title'],
        storeFields: ['page', 'view', 'title'],
        tokenize,
        processTerm: term => term.normalize('NFKC').toLowerCase(),
        searchOptions: { prefix: true, fuzzy: 0.2 },
      });
      index.addAll(records);
      return index;
    };
    const indexMs = measure(makeIndex);
    const searchIndex = makeIndex();
    const queries = ['canvas', 'フォント', 'ぶらうざ', 'PDF', 'BDF', 'テーブル', 'リンク', 'ページ', 'renderer', '文書'];
    const searchTotal = measure(() => {
      for (const query of queries) searchIndex.search(query, { prefix: true, fuzzy: 0.2 });
    });
    const searchMs = searchTotal / queries.length;

    const userAgent = navigator.userAgent;
    const version = userAgent.match(/(?:Chrome|Chromium)\/(\d+(?:\.\d+)*)/);
    return {
      measuredAt: new Date().toISOString(),
      environment: {
        browser: version ? 'Chromium ' + version[1] : userAgent.split(' ')[0],
        userAgent,
        platform: navigator.platform,
        hardwareConcurrency: navigator.hardwareConcurrency ?? null,
        deviceMemory: navigator.deviceMemory ?? null,
      },
      times: {
        jsPdf, wasmPdf, jsMarkdown, wasmMarkdown, jsText, wasmText, jsPdfToBdf, wasmPdfToBdf, indexMs, searchMs,
      },
      sizes: {
        bdfBytes: bdfBytes.length,
        pdfBytes: atob(pdfResult.pdf).length,
        markdownChars: markdownResult.markdown.length,
        textChars: textResult.text.length,
        convertedBdfBytes: atob(converted.bdf).length,
      },
      details: {
        bdfPages: 20,
        pdfPages: pdfResult.pages,
        pdfToBdfPages: converted.pages,
        markdownFiles: markdownResult.files.length,
        textPages: textResult.pages,
        records: records.length,
      },
    };
  }, { iterations, warmup });

  const round = value => Math.round(value * 100) / 100;
  const formatBytes = value => value >= 1024 * 1024 ? (value / 1024 / 1024).toFixed(1) + 'MB' : Math.round(value / 1024) + 'KB';
  const payload = {
    schemaVersion: 1,
    measuredAt: data.measuredAt,
    environment: {
      browser: data.environment.browser,
      platform: data.environment.platform,
      cpu: os.cpus()[0]?.model ?? 'unknown',
      hardwareConcurrency: data.environment.hardwareConcurrency,
      deviceMemory: data.environment.deviceMemory,
      node: process.version,
      userAgent: data.environment.userAgent,
    },
    methodology: {
      inputBdf: 'upstream-demo.bdf',
      inputPdf: 'upstream-demo.pdf',
      iterations,
      warmup,
      statistic: 'median',
      miniSearchQueries: 10,
      note: 'BDF 20ページ、PDF 20ページ。JS と wasm-gc は同じ MoonBit 実装。値はこの環境での参考値。',
    },
    results: [
      { id: 'bdf-pdf', label: 'BDF → PDF', js: round(data.times.jsPdf), wasm: round(data.times.wasmPdf), detail: data.details.pdfPages + 'ページ / ' + formatBytes(data.sizes.pdfBytes) },
      { id: 'bdf-markdown', label: 'BDF → Markdown', js: round(data.times.jsMarkdown), wasm: round(data.times.wasmMarkdown), detail: data.sizes.markdownChars.toLocaleString('ja-JP') + '文字' },
      { id: 'bdf-text', label: 'BDF → 検索テキスト', js: round(data.times.jsText), wasm: round(data.times.wasmText), detail: data.details.textPages + 'ページ' },
      { id: 'pdf-bdf', label: 'PDF → BDF', js: round(data.times.jsPdfToBdf), wasm: round(data.times.wasmPdfToBdf), detail: data.details.pdfToBdfPages + 'ページ / ' + formatBytes(data.sizes.convertedBdfBytes) },
      { id: 'minisearch-index', label: 'MiniSearch 索引', js: round(data.times.indexMs), wasm: null, detail: data.details.records + 'ページ' },
      { id: 'minisearch-search', label: 'MiniSearch 検索（1回）', js: round(data.times.searchMs), wasm: null, detail: '10クエリの平均' },
    ],
    sizes: data.sizes,
    details: data.details,
  };
  await writeFile(output, JSON.stringify(payload, null, 2) + '\n');
  console.log('Measured ' + payload.results.map(result => result.label + ' JS ' + result.js + 'ms' + (result.wasm == null ? '' : ' / wasm ' + result.wasm + 'ms')).join('\n  '));
  console.log('Wrote ' + output);
} finally {
  await browser.close();
  await new Promise(resolvePromise => server.close(resolvePromise));
}
