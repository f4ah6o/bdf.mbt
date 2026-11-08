// bdf.mbt の計測。上流のベンチマーク（site/benchmarks/upstream.json）に追記する形で
// site/benchmarks/bdfmbt.json を書く。
//
//   npm run build:site
//   node site/benchmark.mjs            # 測って書き出す
//   node site/benchmark.mjs --check    # 前回の値と比べるだけ（大きく劣化していたら失敗）
//
// Office 文書（basic.docx・basic.pptx・basic.xlsx）の変換は、ブラウザのタブの中で
// bdf.mbt の変換 Worker を回して測る。往復（BDF → PDF・Markdown・テキスト、PDF → BDF、
// MiniSearch）は JS と wasm-gc の両方で測る。
import { createReadStream } from "node:fs";
import { stat, writeFile, readFile } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve } from "node:path";
import os from "node:os";
import { chromium } from "playwright";

const site = resolve(import.meta.dirname);
const root = resolve(site, "..");
const built = resolve(root, "_build/pages");
const output = resolve(site, "benchmarks/bdfmbt.json");
const iterations = 7;
const warmup = 2;
const check = process.argv.includes("--check");

const types = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".wasm": "application/wasm",
  ".bdf": "application/octet-stream",
  ".pdf": "application/pdf",
  ".png": "image/png",
  ".svg": "image/svg+xml",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
};
const server = createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");
  if (!url.pathname.startsWith("/bdf.mbt/")) {
    response.writeHead(404).end();
    return;
  }
  let path = decodeURIComponent(url.pathname.slice("/bdf.mbt/".length));
  if (path === "" || path.endsWith("/")) path += "index.html";
  const file = resolve(built, path);
  if (!file.startsWith(built + "/")) {
    response.writeHead(403).end();
    return;
  }
  try {
    const info = await stat(file);
    response.writeHead(200, { "Content-Type": types[extname(file)] ?? "application/octet-stream", "Content-Length": info.size });
    createReadStream(file).pipe(response);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((done, fail) => {
  server.once("error", fail);
  server.listen(0, "127.0.0.1", done);
});
const base = "http://127.0.0.1:" + server.address().port + "/bdf.mbt/";

const browser = await chromium.launch({ headless: true, ...(process.env.BDF_CHROMIUM ? { executablePath: process.env.BDF_CHROMIUM } : {}) });
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 } });
  page.setDefaultTimeout(600000);
  await page.goto(base + "index.html", { waitUntil: "domcontentloaded" });
  await page.waitForSelector("#demo canvas", { timeout: 120000 });

  const data = await page.evaluate(async ({ iterations, warmup }) => {
    const median = (values) => {
      const sorted = [...values].sort((a, b) => a - b);
      return sorted[Math.floor(sorted.length / 2)];
    };
    const bytesToBase64 = (bytes) => {
      let text = "";
      const chunk = 0x8000;
      for (let index = 0; index < bytes.length; index += chunk) {
        text += String.fromCharCode(...bytes.subarray(index, index + chunk));
      }
      return btoa(text);
    };
    const fetchBytes = async (path) => new Uint8Array(await (await fetch(path)).arrayBuffer());
    const measureSync = (fn) => {
      for (let index = 0; index < warmup; index += 1) fn();
      const times = [];
      for (let index = 0; index < iterations; index += 1) {
        const start = performance.now();
        fn();
        times.push(performance.now() - start);
      }
      return median(times);
    };
    const measureAsync = async (fn) => {
      for (let index = 0; index < warmup; index += 1) await fn();
      const times = [];
      for (let index = 0; index < iterations; index += 1) {
        const start = performance.now();
        await fn();
        times.push(performance.now() - start);
      }
      return median(times);
    };

    // --- 往復（BDF ↔ PDF・Markdown・テキスト） ---
    const bdfBytes = await fetchBytes("./samples/demo.bdf");
    const pdfBytes = await fetchBytes("./samples/demo.pdf");
    const bdf = bytesToBase64(bdfBytes);
    const pdf = bytesToBase64(pdfBytes);
    const js = await import("./export.js");
    const wasmHost = await import("./wasm-gc.js");
    const wasm = await wasmHost.createWasm("./wasm-gc.wasm");

    const jsPdf = measureSync(() => JSON.parse(js.bdf_wasm_export_pdf(bdf, 0)));
    const wasmPdf = measureSync(() => wasm.exportPdf(bdf, false));
    const jsMarkdown = measureSync(() => JSON.parse(js.bdf_wasm_markdown(bdf, "zip")));
    const wasmMarkdown = measureSync(() => wasm.markdown(bdf, "zip"));
    const jsText = measureSync(() => JSON.parse(js.bdf_wasm_search_text(bdf)));
    const wasmText = measureSync(() => wasm.searchText(bdf));
    const jsPdfToBdf = measureSync(() => JSON.parse(js.bdf_wasm_pdf(pdf, "")));
    const wasmPdfToBdf = measureSync(() => wasm.convertPdf(pdf, ""));

    const pdfResult = JSON.parse(js.bdf_wasm_export_pdf(bdf, 0));
    const markdownResult = JSON.parse(js.bdf_wasm_markdown(bdf, "zip"));
    const textResult = JSON.parse(js.bdf_wasm_search_text(bdf));
    const converted = JSON.parse(js.bdf_wasm_pdf(pdf, ""));
    const text = JSON.parse(textResult.text);
    const records = [];
    for (const view of text.views ?? []) {
      for (const entry of view.pages ?? []) {
        if (entry.text) records.push({ id: view.id + ":" + (entry.page ?? 1), page: entry.page ?? 1, view: view.id, title: view.title ?? "", text: entry.text });
      }
    }
    const MiniSearch = (await import("./minisearch/index.js")).default;
    const normalize = (value) => value.normalize("NFKC").toLowerCase().replace(/[\u3041-\u3096]/g, (char) => String.fromCharCode(char.charCodeAt(0) + 0x60));
    const tokenize = (value) => {
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
        fields: ["text", "title"],
        storeFields: ["page", "view", "title"],
        tokenize,
        processTerm: (term) => term.normalize("NFKC").toLowerCase(),
        searchOptions: { prefix: true, fuzzy: 0.2 },
      });
      index.addAll(records);
      return index;
    };
    const indexMs = measureSync(makeIndex);
    const searchIndex = makeIndex();
    const queries = ["canvas", "フォント", "ぶらうざ", "PDF", "BDF", "テーブル", "リンク", "ページ", "renderer", "文書"];
    const searchTotal = measureSync(() => {
      for (const query of queries) searchIndex.search(query, { prefix: true, fuzzy: 0.2 });
    });

    // --- Office 文書の変換（変換 Worker） ---
    const { bdf_create_native_converter } = await import("./browser.js");
    const converter = bdf_create_native_converter(new URL("./native_converter_worker.js", location.href).href);
    await converter.ready;
    const office = [];
    for (const name of ["basic.docx", "basic.pptx", "basic.xlsx"]) {
      const bytes = await fetchBytes("./samples/" + name);
      let pages = 0;
      let size = 0;
      const ms = await measureAsync(async () => {
        const result = await converter.convert(bytes, { name });
        size = result.bdf.length;
        if (!pages) pages = result.summary ? Number(/(\d+)\s*page/.exec(result.summary)?.[1] ?? 0) : 0;
      });
      office.push({ input: name, js: { ms }, wasm: null, bytes: size, pages });
    }
    converter.terminate();

    const userAgent = navigator.userAgent;
    const version = userAgent.match(/(?:Chrome|Chromium)\/(\d+(?:\.\d+)*)/);
    return {
      measuredAt: new Date().toISOString(),
      environment: {
        browser: version ? "Chromium " + version[1] : userAgent.split(" ")[0],
        userAgent,
        platform: navigator.platform,
        hardwareConcurrency: navigator.hardwareConcurrency ?? null,
        deviceMemory: navigator.deviceMemory ?? null,
      },
      office,
      times: { jsPdf, wasmPdf, jsMarkdown, wasmMarkdown, jsText, wasmText, jsPdfToBdf, wasmPdfToBdf, indexMs, searchMs: searchTotal / queries.length },
      sizes: {
        bdfBytes: bdfBytes.length,
        pdfBytes: atob(pdfResult.pdf).length,
        markdownChars: markdownResult.markdown.length,
        textChars: textResult.text.length,
        convertedBdfBytes: atob(converted.bdf).length,
      },
      details: {
        pdfPages: pdfResult.pages,
        pdfToBdfPages: converted.pages,
        markdownFiles: markdownResult.files.length,
        textPages: textResult.pages,
        records: records.length,
      },
    };
  }, { iterations, warmup });

  const round = (value) => Math.round(value * 100) / 100;
  const formatBytes = (value) => (value >= 1024 * 1024 ? (value / 1024 / 1024).toFixed(1) + "MB" : Math.round(value / 1024) + "KB");
  const payload = {
    schemaVersion: 1,
    measuredAt: data.measuredAt,
    environment: {
      browser: data.environment.browser,
      platform: data.environment.platform,
      cpu: os.cpus()[0]?.model ?? "unknown",
      hardwareConcurrency: data.environment.hardwareConcurrency,
      deviceMemory: data.environment.deviceMemory,
      node: process.version,
      userAgent: data.environment.userAgent,
    },
    methodology: {
      inputBdf: "demo.bdf",
      inputPdf: "demo.pdf",
      officeInputs: ["basic.docx", "basic.pptx", "basic.xlsx"],
      iterations,
      warmup,
      statistic: "median",
      miniSearchQueries: 10,
      note: "bdf.mbt（MoonBit）をブラウザのタブの中で測った。Office 文書は変換 Worker（JS）で、BDF→PDF・Markdown・テキストと PDF→BDF は JS と wasm-gc の両方で測った。サムネイルは canvas で描くため含まない。",
    },
    office: data.office.map((row) => ({
      input: row.input,
      js: { ms: round(row.js.ms) },
      wasm: null,
      bytes: row.bytes,
      pages: row.pages || null,
    })),
    roundtrip: [
      { id: "bdf-pdf", label: "BDF → PDF", js: round(data.times.jsPdf), wasm: round(data.times.wasmPdf), detail: data.details.pdfPages + "ページ / " + formatBytes(data.sizes.pdfBytes) },
      { id: "bdf-markdown", label: "BDF → Markdown", js: round(data.times.jsMarkdown), wasm: round(data.times.wasmMarkdown), detail: data.sizes.markdownChars.toLocaleString("ja-JP") + "文字" },
      { id: "bdf-text", label: "BDF → 検索テキスト", js: round(data.times.jsText), wasm: round(data.times.wasmText), detail: data.details.textPages + "ページ" },
      { id: "pdf-bdf", label: "PDF → BDF", js: round(data.times.jsPdfToBdf), wasm: round(data.times.wasmPdfToBdf), detail: data.details.pdfToBdfPages + "ページ / " + formatBytes(data.sizes.convertedBdfBytes) },
      { id: "minisearch-index", label: "MiniSearch 索引", js: round(data.times.indexMs), wasm: null, detail: data.details.records + "ページ" },
      { id: "minisearch-search", label: "MiniSearch 検索（1回）", js: round(data.times.searchMs), wasm: null, detail: "10 クエリの平均" },
    ],
    sizes: data.sizes,
    details: data.details,
  };

  if (check) {
    let previous = null;
    try {
      previous = JSON.parse(await readFile(output, "utf8"));
    } catch {
      console.log("no previous benchmark to compare; run without --check");
      process.exit(0);
    }
    // 記録と違う CPU（CI のランナーなど）では、同じ 3 倍の枠で比べても意味が
    // ない。数値の比較は飛ばして、測定が壊れていないことだけ確かめる。
    if ((previous.environment?.cpu ?? "unknown") !== (payload.environment.cpu ?? "unknown")) {
      console.log("benchmark ok (recorded on " + (previous.environment?.cpu ?? "unknown CPU") + "; this machine differs, so only the shape was checked)");
      process.exit(0);
    }
    const before = new Map((previous.roundtrip ?? []).map((row) => [row.id, row]));
    let failed = 0;
    for (const row of payload.roundtrip) {
      const old = before.get(row.id);
      if (!old || old.js == null || row.js == null) continue;
      const ratio = row.js / old.js;
      if (ratio > 3) {
        failed += 1;
        console.log("slower: " + row.label + " " + old.js + " ms → " + row.js + " ms");
      }
    }
    console.log(failed ? failed + " regression(s)" : "benchmark ok (within 3x of the recorded run)");
    process.exit(failed ? 1 : 0);
  }

  await writeFile(output, JSON.stringify(payload, null, 2) + "\n");
  console.log("Office: " + payload.office.map((row) => row.input + " " + row.js.ms + " ms").join(", "));
  console.log("Round trip: " + payload.roundtrip.map((row) => row.label + " JS " + row.js + " ms" + (row.wasm == null ? "" : " / wasm-gc " + row.wasm + " ms")).join("; "));
  console.log("Wrote " + output);
} finally {
  await browser.close();
  await new Promise((done) => server.close(done));
}
