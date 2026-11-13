// このサイトのブラウザテスト（Playwright）。
//
//   npm run build:site
//   node site/test.mjs
//   BDF_CHROMIUM=/path/to/chrome node site/test.mjs   # 手元のブラウザを使うとき
//
// _build/pages を /bdf.mbt/ の下で配り、トップページ・ビューア・サムネイル・
// 検索テキスト・wasm-gc・ドキュメントを実際に動かして確かめる。
import assert from "node:assert/strict";
import { createReadStream } from "node:fs";
import { readFile, stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve } from "node:path";
import { inflateRawSync } from "node:zlib";
import { chromium } from "playwright";

const root = resolve(import.meta.dirname, "../_build/pages");
// 再配布できる同梱の書体を、FontData の代わりに使う（ホストのフォントは読まない）。
const stix = await readFile(resolve(import.meta.dirname, "../compat/font/fixtures/stix.ttf"));
const stixBase64 = stix.toString("base64");
const csvSample = await readFile(resolve(import.meta.dirname, "../site/samples/basic.csv"));
const docxSample = await readFile(resolve(import.meta.dirname, "../site/samples/basic.docx"));
const pptxSample = await readFile(resolve(import.meta.dirname, "../site/samples/basic.pptx"));
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
  ".webp": "image/webp",
  ".ttf": "font/ttf",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".csv": "text/csv",
  ".md": "text/markdown",
};
const server = createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");
  if (!url.pathname.startsWith("/bdf.mbt/")) {
    response.writeHead(404).end();
    return;
  }
  let path = decodeURIComponent(url.pathname.slice("/bdf.mbt/".length));
  if (path === "" || path.endsWith("/")) path += "index.html";
  const file = resolve(root, path);
  if (!file.startsWith(root + "/")) {
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
let failures = 0;
const errors = [];
let current = null;

/** BDF_ONLY=form で、フォームのページの段だけを動かす。 */
const only = process.env.BDF_ONLY ?? "";

async function step(name, fn) {
  if (only && !name.startsWith(only)) {
    console.log("skip " + name);
    return;
  }
  const started = Date.now();
  try {
    await fn();
    console.log("ok   " + name + " (" + ((Date.now() - started) / 1000).toFixed(1) + "s)");
  } catch (error) {
    failures += 1;
    console.log("FAIL " + name + ": " + (error.message ?? error).split("\n")[0]);
    try {
      const state = await current.evaluate(() => ({
        url: location.href,
        status: document.querySelector("#status")?.textContent ?? null,
        error: document.querySelector("#status")?.classList.contains("error") ?? null,
        page: document.querySelector("#page-number")?.textContent ?? null,
        pageNum: document.querySelector("#pageNum")?.textContent ?? null,
        pages: document.querySelectorAll("#demo div[data-bdf-page]").length,
        chips: [...document.querySelectorAll("#samples button")].map((node) => node.textContent).slice(0, 6),
      }));
      console.log("     state: " + JSON.stringify(state));
    } catch {}
    for (const message of errors.slice(-3)) console.log("     console: " + message.slice(0, 200));
  }
}

let page = null;
/** ページごとに新しいコンテキストを使う（wasm のインスタンスとメモリを持ち越さない）。 */
async function fresh() {
  if (page) {
    const old = page;
    page = null;
    await old.context().close().catch(() => {});
  }
  const context = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  page = await context.newPage();
  current = page;
  page.setDefaultTimeout(120000);
  page.on("pageerror", (error) => errors.push(String(error)));
  page.on("console", (message) => {
    if (message.type() !== "error") return;
    const text = message.text();
    if (text.includes("favicon")) return;
    if (/render worker terminated|BdfWorkerError/.test(text)) return; // 片付けのときの通知
    errors.push(text);
  });
  return page;
}

/** 画像の読み込みを待たせる: file.arrayBuffer() を、テストが終わらせるまで返さない。 */
async function deferPictureReads() {
  await page.evaluate(() => {
    const original = File.prototype.arrayBuffer;
    window.__reads = [];
    File.prototype.arrayBuffer = function () {
      const file = this;
      return new Promise((resolve, reject) => {
        window.__reads.push({
          name: file.name,
          settle: () => original.call(file).then(resolve, reject),
        });
      });
    };
  });
}

/** 待たせた読みを終わらせる（0 が最初の読み）。 */
async function settlePictureRead(index = 0) {
  await page.evaluate((i) => window.__reads[i].settle(), index);
}

/** 保存できるものの状態（表示中のタブに関係なく、DOM の hidden と disabled を読む）。 */
async function exportState() {
  return page.evaluate(() => ({
    bdfHidden: document.querySelector("#saveBdf").hidden,
    bdfHref: document.querySelector("#saveBdf").getAttribute("href"),
    pdfDisabled: document.querySelector("#savePdf").disabled,
    bdftDisabled: document.querySelector("#saveBdft").disabled,
  }));
}

/** 記入済みの BDF を、ページのブロブから読む。 */
async function readBdf() {
  const b64 = await page.evaluate(async () => {
    const href = document.querySelector("#saveBdf").getAttribute("href");
    const bytes = new Uint8Array(await (await fetch(href)).arrayBuffer());
    let s = "";
    for (const b of bytes) s += String.fromCharCode(b);
    return btoa(s);
  });
  return Buffer.from(b64, "base64");
}

/** BDF のマニフェスト（ヘッダーの位置と長さから読む）。 */
function bdfManifest(bytes) {
  assert.equal(bytes.subarray(0, 4).toString("hex"), "62646600", "the file is not a BDF");
  const offset = Number(bytes.readBigUInt64LE(8));
  const length = Number(bytes.readBigUInt64LE(16));
  let raw = bytes.subarray(offset, offset + length);
  if (bytes[24] === 1) raw = inflateRawSync(raw);
  return JSON.parse(raw.toString("utf8"));
}

/** BDF の部品（マニフェストの off と len から読む）。 */
function bdfPart(bytes, manifest, part) {
  const start = Number(bytes.readBigUInt64LE(8)) + Number(bytes.readBigUInt64LE(16));
  const raw = bytes.subarray(start + part.off, start + part.off + part.len);
  return part.enc === "deflate-raw" ? inflateRawSync(raw) : raw;
}

try {
  await fresh();

  await step("top page draws demo.bdf", async () => {
    await page.goto(base + "index.html", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#demo canvas", { timeout: 120000 });
    await page.waitForFunction(() => /^1 \/ \d+$/.test(document.querySelector("#pageNum")?.textContent ?? ""), null, { timeout: 120000 });
    // The text layer adds internal-link anchors that also carry data-bdf-page.
    // Count page frames, and wait until every page frame is present.
    await page.waitForFunction(() => document.querySelectorAll("#demo div[data-bdf-page]").length === 20, null, { timeout: 120000 });
    const total = await page.locator("#demo div[data-bdf-page]").count();
    assert.equal(total, 20);
  });

  await step("top page counts page frames, not text-layer links", async () => {
    // Internal-link anchors in the text layer also carry data-bdf-page. Wait
    // until they exist, then prove the page count is the frame count.
    await page.waitForFunction(() => document.querySelectorAll("#demo a[data-bdf-page]").length > 0, null, { timeout: 120000 });
    const frames = await page.locator("#demo div[data-bdf-page]").count();
    const all = await page.locator("#demo [data-bdf-page]").count();
    assert.equal(frames, 20);
    assert.ok(all > frames, "text-layer link anchors also carry data-bdf-page");
  });

  await step("top page searches the document", async () => {
    await page.fill("#q", "canvas");
    await page.press("#q", "Enter");
    await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector("#hits")?.textContent ?? ""), null, { timeout: 60000 });
    assert.match(await page.locator("#hits").textContent(), /^\d+ \/ \d+/);
  });

  await step("top page writes the document back out (wasm-gc)", async () => {
    await page.click('[role="tab"]:has-text("検索用テキスト")');
    await page.click('[data-export-run="text"]');
    await page.waitForFunction(() => (document.querySelector("[data-export-text]")?.value ?? "").length > 100, null, { timeout: 120000 });
    const text = await page.locator("[data-export-text]").inputValue();
    const parsed = JSON.parse(text);
    assert.ok(Array.isArray(parsed.views) && parsed.views.length > 0);
    const pages = parsed.views.flatMap((view) => view.pages ?? []).length;
    assert.equal(pages, 20);
  });

  await step("top page keeps upstream's benchmarks and appends bdf.mbt", async () => {
    const html = await page.content();
    assert.match(html, /LibreOffice \+ Poppler/);
    assert.match(html, /BDF（Go）/);
    assert.match(html, /bdf\.mbt（JS）/);
    assert.match(html, /bdf\.mbt の往復/);
  });

  await step("top page forwards the old ?src= links to the viewer", async () => {
    await fresh();
    await page.goto(base + "?src=" + encodeURIComponent("samples/demo.pdf") + "&layout=scroll", { waitUntil: "domcontentloaded" });
    assert.match(page.url(), /\/viewer\/\?src=/);
    await page.waitForFunction(() => /^1 \/ \d+$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal(await page.locator("#layout").inputValue(), "continuous");
  });

  await step("viewer opens the demo PDF", async () => {
    await fresh();
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
  });

  await step("viewer converts the Mermaid demo through the plugin Worker", async () => {
    await fresh();
    await page.goto(base + "viewer/?file=samples/flowchart.mmd", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "flowchart.mmd", null, { timeout: 120000 });
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.waitForFunction(() => /^1 \/ 1$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    const status = await page.locator("#status").textContent();
    assert.match(status, /表示しました/);
    assert.match(status, /layered approximation/);
    assert.equal(await page.locator("#download").isHidden(), false);
  });

  await step("viewer converts the Excalidraw demo through the plugin Worker", async () => {
    await fresh();
    await page.goto(base + "viewer/?file=samples/shapes.excalidraw", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "shapes.excalidraw", null, { timeout: 120000 });
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.waitForFunction(() => /^1 \/ 1$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    assert.match(await page.locator("#status").textContent(), /表示しています/);
    assert.equal(await page.locator("#download").isHidden(), false);
  });

  await step("native formats still convert after a plugin diagram", async () => {
    await fresh();
    await page.goto(base + "viewer/?file=samples/flowchart.mmd", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "flowchart.mmd", null, { timeout: 120000 });
    // Word is page-based, so the page counter proves the native Worker ran.
    await page.click('#samples button:text-is("Word")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    await page.waitForFunction(() => !document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    assert.doesNotMatch(await page.locator("#view").inputValue(), /^sheet/);
    await page.waitForFunction(() => /^\d+ \/ \d+$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 60000 });
  });

  await step("a rejected Mermaid file leaves the native converter working", async () => {
    await fresh();
    await page.goto(base + "viewer/?file=samples/flowchart.mmd", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "flowchart.mmd", null, { timeout: 120000 });
    await page.setInputFiles("#file", {
      name: "unsupported.mmd",
      mimeType: "text/plain",
      buffer: Buffer.from("sequenceDiagram\n  A->>B: hello\n"),
    });
    await page.waitForSelector("dialog.first-font-choice");
    await page.click("dialog.first-font-choice button:has-text('フォントなしで続ける')");
    await page.waitForFunction(() => /unsupported\.mmd を開けませんでした/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.match(await page.locator("#status").textContent(), /mermaid/);
    await page.click('#samples button:text-is("Word")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    await page.waitForFunction(() => !document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    assert.doesNotMatch(await page.locator("#view").inputValue(), /^sheet/);
    await page.waitForFunction(() => /^\d+ \/ \d+$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 60000 });
  });

  await step("first user file offers a local font choice before preview", async () => {
    await fresh();
    await page.addInitScript((base64) => {
      const binary = atob(base64);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      window.__fontQueryCalls = 0;
      window.queryLocalFonts = async () => {
        window.__fontQueryCalls += 1;
        return [{
          postscriptName: "STIXTwoText-Regular",
          fullName: "STIX Two Text",
          family: "STIX Two Text",
          style: "Regular",
          blob: async () => new Blob([bytes], { type: "font/ttf" }),
        }];
      };
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    }, stixBase64);
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0, "the built-in demo does not prompt");
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    assert.equal(await page.evaluate(() => window.__fontQueryCalls), 0, "no query before the gesture");
    await page.click("dialog.first-font-choice button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click("dialog.first-font-choice button:has-text('この設定で続ける')");
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fontFiles.length, 1);
    assert.equal(posted.fontFiles[0].postscriptName, "STIXTwoText-Regular");
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0);
  });

  await step("first preview waits for a selected font file to finish loading", async () => {
    await fresh();
    await page.addInitScript(() => {
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
      const read = File.prototype.arrayBuffer;
      File.prototype.arrayBuffer = async function () {
        if (this.name === "STIX test.ttf") {
          await new Promise((resolve) => { window.__releaseFont = resolve; });
        }
        return read.call(this);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    const baseline = await page.evaluate(() => window.__posted.length);
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.locator('#local-fonts input[type="file"]').setInputFiles({ name: "STIX test.ttf", mimeType: "font/ttf", buffer: stix });
    await page.waitForFunction(() => typeof window.__releaseFont === "function");
    const use = page.getByRole("button", { name: "この設定で続ける" });
    assert.equal(await use.isDisabled(), true);
    assert.equal(await page.evaluate(() => window.__posted.length), baseline);
    await page.evaluate(() => window.__releaseFont());
    await page.waitForFunction(() => /1 ファイルを読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await use.isEnabled(), true);
    await use.click();
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fontFiles.length, 1);
    assert.equal(posted.fontFiles[0].name, "STIX test.ttf");
    assert.equal(posted.fontFiles[0].postscriptName, undefined);
  });

  await step("denied local fonts fall back and later files do not prompt again", async () => {
    await fresh();
    await page.addInitScript(() => {
      window.__fontQueryCalls = 0;
      window.queryLocalFonts = async () => {
        window.__fontQueryCalls += 1;
        throw new DOMException("denied", "NotAllowedError");
      };
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.click("dialog.first-font-choice button:has-text('ローカルフォントを選ぶ')");
    await page.waitForFunction(() => /許可されませんでした/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click("dialog.first-font-choice button:has-text('フォントなしで続ける')");
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined);
    await page.setInputFiles("#file", { name: "basic.docx", mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", buffer: docxSample });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0, "repeat conversions do not prompt");
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined);
  });

  await step("two selections while the first choice is open convert only the newest", async () => {
    await fresh();
    await page.addInitScript(() => {
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    const baseline = await page.evaluate(() => window.__posted.length);
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.setInputFiles("#file", { name: "basic.docx", mimeType: "application/vnd.openxmlformats-officedocument.wordprocessingml.document", buffer: docxSample });
    await page.waitForTimeout(400);
    assert.equal(await page.locator("dialog.first-font-choice").count(), 1, "both selections share one dialog");
    assert.equal(await page.evaluate(() => window.__posted.length), baseline, "no conversion bypasses the choice");
    await page.click("dialog.first-font-choice button:has-text('フォントなしで続ける')");
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    await page.waitForTimeout(500);
    assert.equal(await page.locator("#document-name").textContent(), "basic.docx", "the stale first selection does not convert");
    const names = await page.evaluate((start) => window.__posted.slice(start).map((options) => options.name), baseline);
    assert.deepEqual(names, ["basic.docx"]);
  });

  await step("closing the first choice settles it and converts without fonts", async () => {
    await fresh();
    await page.addInitScript(() => {
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.evaluate(() => document.querySelector("dialog.first-font-choice").close());
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0);
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined);
  });

  await step("a throwing showModal falls back to conversion", async () => {
    await fresh();
    await page.addInitScript(() => {
      HTMLDialogElement.prototype.showModal = function () { throw new Error("modal blocked"); };
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0);
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined);
  });

  await step("a skipped first file does not skip fonts for the next file", async () => {
    await fresh();
    await page.addInitScript((base64) => {
      const binary = atob(base64);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      window.queryLocalFonts = async () => [{
        postscriptName: "STIXTwoText-Regular",
        fullName: "STIX Two Text",
        family: "STIX Two Text",
        style: "Regular",
        blob: async () => new Blob([bytes], { type: "font/ttf" }),
      }];
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    }, stixBase64);
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.setInputFiles("#file", { name: "basic.csv", mimeType: "text/csv", buffer: csvSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.click("dialog.first-font-choice button:has-text('フォントなしで続ける')");
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined);
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.setInputFiles("#file", { name: "basic.pptx", mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation", buffer: pptxSample });
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.pptx", null, { timeout: 180000 });
    assert.equal(await page.locator("dialog.first-font-choice").count(), 0, "the next file does not prompt");
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fontFiles.length, 1);
    assert.equal(posted.fontFiles[0].postscriptName, "STIXTwoText-Regular");
  });

  await step("viewer converts Word, Excel, CSV and fonts", async () => {
    // シート（Excel・CSV）はページではなくシートとして開くので、ページ数は「–」のまま。
    for (const [label, file, kind] of [
      ["Word", "basic.docx", "pages"],
      ["Excel", "basic.xlsx", "sheet"],
      ["CSV", "basic.csv", "sheet"],
      ["フォント", "stix.ttf", "pages"],
    ]) {
      await page.click('#samples button:text-is("' + label + '")');
      // 開き終わるまで待つ: 文書名が変わってから中身を見る
      await page.waitForFunction((name) => document.querySelector("#document-name")?.textContent === name, file, { timeout: 180000 });
      await page.waitForFunction(() => !document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
      const view = await page.locator("#view").inputValue();
      if (kind === "sheet") {
        assert.match(view, /^sheet/, label + " opens a sheet");
      } else {
        assert.doesNotMatch(view, /^sheet/, label + " opens pages");
        await page.waitForFunction(() => /^\d+ \/ \d+$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 60000 });
      }
    }
  });

  await step("viewer passes the selected local font to the real Worker (CSV)", async () => {
    await fresh();
    await page.addInitScript((base64) => {
      const binary = atob(base64);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      window.queryLocalFonts = async () => [{
        postscriptName: "STIXTwoText-Regular",
        fullName: "STIX Two Text",
        family: "STIX Two Text",
        style: "Regular",
        blob: async () => new Blob([bytes], { type: "font/ttf" }),
      }];
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    }, stixBase64);
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    const before = await page.evaluate(() => window.__posted[0]);
    assert.equal(before.fontFiles, undefined, "no selection keeps the old options");
    assert.equal(before.fonts, undefined);
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await page.locator("#local-fonts-summary").textContent(), "変換に使う書体: STIX Two Text");
    await page.click('#samples button:text-is("CSV")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    await page.waitForFunction(() => /basic\.csv を表示しています|警告/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 60000 });
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fonts, undefined, "the URL option is not combined with fontFiles");
    assert.equal(posted.fontFiles.length, 1);
    assert.equal(posted.fontFiles[0].name, "STIXTwoText-Regular.ttf");
    assert.equal(posted.fontFiles[0].postscriptName, "STIXTwoText-Regular");
    assert.equal(posted.fontFiles[0].bytes.byteLength, stix.length);
    const status = await page.locator("#status").textContent();
    assert.doesNotMatch(status, /no fonts found/, "the selected font replaces the missing-font warning");
    assert.equal(await page.locator("#local-fonts-summary").textContent(), "変換に使う書体: STIX Two Text");
    await page.click("#local-fonts button:has-text('選択を解除')");
    await page.waitForFunction(() => /選択を解除しました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await page.locator("#local-fonts-summary").isHidden(), true);
    await page.click('#samples button:text-is("Word")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    const after = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(after.fontFiles, undefined, "a cleared selection is not sent");
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await page.locator("#local-fonts-summary").textContent(), "変換に使う書体: STIX Two Text");
  });

  await step("viewer converts CSV using an explicitly selected font file", async () => {
    await fresh();
    await page.addInitScript(() => {
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    });
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.locator('#local-fonts input[type="file"]').setInputFiles({ name: "STIX test.ttf", mimeType: "font/ttf", buffer: stix });
    await page.waitForFunction(() => /1 ファイルを読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await page.locator("#local-fonts-summary").textContent(), "変換に使う書体: STIX test.ttf");
    await page.click('#samples button:text-is("CSV")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    await page.waitForFunction(() => /basic\.csv を表示しています|警告/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 60000 });
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fontFiles.length, 1);
    assert.equal(posted.fontFiles[0].name, "STIX test.ttf");
    assert.equal(posted.fontFiles[0].postscriptName, undefined);
    assert.equal(posted.fontFiles[0].bytes.byteLength, stix.length);
    assert.doesNotMatch(await page.locator("#status").textContent(), /no fonts found/);
  });

  await step("selected fonts are not sent for PDF or Word aliases but are sent for CSV", async () => {
    await fresh();
    await page.addInitScript((base64) => {
      const binary = atob(base64);
      const bytes = new Uint8Array(binary.length);
      for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
      window.queryLocalFonts = async () => [{
        postscriptName: "STIXTwoText-Regular",
        fullName: "STIX Two Text",
        family: "STIX Two Text",
        style: "Regular",
        blob: async () => new Blob([bytes], { type: "font/ttf" }),
      }];
      window.__posted = [];
      const post = Worker.prototype.postMessage;
      Worker.prototype.postMessage = function (message, transfer) {
        if (message?.type === "convert") window.__posted.push(message.options);
        return post.call(this, message, transfer);
      };
    }, stixBase64);
    await page.goto(base + "viewer/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => /^1 \/ 20$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click('#samples button:text-is("PDF（20 ページ）")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "demo.pdf", null, { timeout: 180000 });
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined, "PDF gets no fontFiles");
    await page.click('#samples button:text-is("Word")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined, "DOCX gets no fontFiles");
    await page.setInputFiles("#file", { name: "basic.docm", mimeType: "application/vnd.ms-word.document.macroEnabled.12", buffer: docxSample });
    await page.waitForSelector("dialog.first-font-choice");
    await page.click("dialog.first-font-choice button:has-text('この設定で続ける')");
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docm", null, { timeout: 180000 });
    assert.equal((await page.evaluate(() => window.__posted.at(-1))).fontFiles, undefined, "DOCM alias gets no fontFiles");
    await page.click('#samples button:text-is("CSV")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.csv", null, { timeout: 180000 });
    const posted = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(posted.fontFiles.length, 1, "CSV still receives the retained selection");
    assert.equal(posted.fontFiles[0].postscriptName, "STIXTwoText-Regular");
  });

  await step("viewer searches and saves the BDF", async () => {
    await page.click('#samples button:text-is("PDF（20 ページ）")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "demo.pdf", null, { timeout: 180000 });
    await page.fill("#search", "canvas");
    await page.click('#search-form button[type="submit"]');
    await page.waitForFunction(() => /\d+ \/ \d+/.test(document.querySelector("#search-status")?.textContent ?? ""), null, { timeout: 60000 });
    const [download] = await Promise.all([page.waitForEvent("download", { timeout: 60000 }), page.click("#download")]);
    assert.match(download.suggestedFilename(), /\.bdf$/);
  });

  await step("viewer writes the open BDF back to PDF and Markdown", async () => {
    await page.click('[data-export-run="pdf"]');
    await page.waitForFunction(() => !document.querySelector("[data-export-frame]")?.hidden, null, { timeout: 180000 });
    const source = await page.locator("[data-export-frame]").getAttribute("src");
    assert.match(source ?? "", /^blob:/);
    await page.click('[role="tab"]:has-text("Markdown")');
    await page.click('[data-export-run="md"]');
    await page.waitForFunction(() => (document.querySelector("[data-export-markdown]")?.value ?? "").length > 100, null, { timeout: 180000 });
  });

  await step("viewer opens an encrypted PDF with the sample password", async () => {
    await page.click('#samples button:has-text("暗号化 PDF")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "pdf-encrypted.pdf", null, { timeout: 120000 });
    await page.waitForFunction(() => /^1 \/ 1$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal(await page.locator("#status").evaluate((node) => node.classList.contains("error")), false);
  });

  await step("thumbnail page draws four sizes", async () => {
    await fresh();
    await page.goto(base + "thumbnail/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector(".thumbs figure img", { timeout: 120000 });
    await page.waitForFunction(() => document.querySelectorAll(".thumbs figure").length >= 4, null, { timeout: 120000 });
    const sizes = await page.locator(".thumbs figcaption strong").allTextContents();
    assert.ok(sizes.length >= 4, sizes.join(","));
    const blank = await page.evaluate(() => {
      const image = document.querySelector(".thumbs img");
      return !image || image.naturalWidth === 0;
    });
    assert.equal(blank, false);
  });

  await step("search text page returns a record a page", async () => {
    await fresh();
    await page.goto(base + "text/", { waitUntil: "domcontentloaded" });
    await page.waitForFunction(() => (document.querySelector("#output")?.value ?? "").length > 100, null, { timeout: 120000 });
    const parsed = JSON.parse(await page.locator("#output").inputValue());
    const pages = parsed.views.flatMap((view) => view.pages ?? []).length;
    assert.equal(pages, 20);
  });

  await step("wasm-gc page converts a PDF", async () => {
    await fresh();
    await page.goto(base + "wasm-gc.html", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.setInputFiles("#pdf-file", { name: "demo.pdf", mimeType: "application/pdf", buffer: await (async () => {
      return readFile(resolve(root, "samples/demo.pdf"));
    })() });
    await page.click("#pdf-convert");
    await page.waitForFunction(() => /→ BDF/.test(document.querySelector("#wasm-status")?.textContent ?? ""), null, { timeout: 180000 });
  });

  await step("form page opens a sample and draws the filled form", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-rows.docx']", { timeout: 60000 });
    await page.click("#presets button[title='form-rows.docx']");
    await page.waitForFunction(() => /ページ、/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    // the form is made of the schema of the tags
    assert.ok((await page.locator("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])").count()) > 3);
    assert.ok((await page.locator("#schema").textContent()).includes('"properties"'));
    // the recipe that the page shows passes the data itself to Options::new
    const recipe = await page.locator("#api").textContent();
    assert.ok(recipe.includes("@form.Options::new(data=data)"), "the recipe does not pass data=data");
    assert.ok(!recipe.includes("Options::new(data=Some("), "the recipe passes Some(data) to Options::new");
    assert.ok(recipe.includes("@form.schema_of(template, Some(data))"), "the recipe does not pass Some(data) to schema_of");
    // and the preview draws the filled BDF
    await page.click("#tabPreview");
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.waitForFunction(() => /^\d+ \/ \d+$/.test(document.querySelector("#page-number")?.textContent ?? ""), null, { timeout: 120000 });
    assert.ok(await page.locator("#saveBdf").isVisible());
    assert.ok(await page.locator("#savePdf").isEnabled());
    // the page count is not the drawing: the canvas has ink on it
    await page.waitForFunction(() => {
      const canvas = document.querySelector("#preview canvas");
      if (!canvas || !canvas.width || !canvas.height) return false;
      const { data } = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height);
      let dark = 0;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i] < 128 && data[i + 1] < 128 && data[i + 2] < 128) dark += 1;
      }
      return dark > 100;
    }, null, { timeout: 120000 });
  });

  await step("form page fills what is typed into the form", async () => {
    await page.click("#tabData");
    const input = page.locator("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])").first();
    await input.fill("テスト 123");
    await page.waitForFunction(() => !document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    await page.click("#tabJson");
    const data = JSON.parse(await page.locator("#json").inputValue());
    assert.ok(JSON.stringify(data).includes("テスト 123"), "the typed value is not in the data");
    await page.click("#tabForm");
  });

  await step("form page stops offering the old document as soon as the data changes", async () => {
    await page.click("#tabData");
    // the edit and the check happen in one turn of the page, before the fill
    // that the page waits 250 ms to start
    const state = await page.evaluate(() => {
      const input = document.querySelector("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])");
      input.value = "別の値";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      const bdf = document.querySelector("#saveBdf");
      return {
        hidden: bdf.hidden,
        href: bdf.getAttribute("href"),
        pdf: document.querySelector("#savePdf").disabled,
        bdft: document.querySelector("#saveBdft").disabled,
      };
    });
    assert.equal(state.hidden, true, "the .bdf link is still shown");
    assert.equal(state.href, null, "the .bdf link still points at the old document");
    assert.equal(state.pdf, true, "the PDF button is still enabled");
    assert.equal(state.bdft, true, "the .bdft button is still enabled");
    // and the fill that follows offers the new document
    await page.waitForFunction(() => !document.querySelector("#saveBdf").hidden, null, { timeout: 60000 });
    assert.equal(await page.locator("#savePdf").isEnabled(), true);
  });

  await step("form page stops offering the document when the data is not JSON", async () => {
    await page.click("#tabJson");
    const good = await page.locator("#json").inputValue();
    const state = await page.evaluate(() => {
      const box = document.querySelector("#json");
      box.value = "{ not json";
      box.dispatchEvent(new Event("input", { bubbles: true }));
      const bdf = document.querySelector("#saveBdf");
      return {
        hidden: bdf.hidden,
        href: bdf.getAttribute("href"),
        pdf: document.querySelector("#savePdf").disabled,
        status: document.querySelector("#status").textContent,
      };
    });
    assert.equal(state.hidden, true, "the .bdf link is still shown");
    assert.equal(state.href, null, "the .bdf link still points at the old document");
    assert.equal(state.pdf, true, "the PDF button is still enabled");
    assert.match(state.status, /JSON/);
    // the data that the page had still fills
    await page.fill("#json", good);
    await page.waitForFunction(() => !document.querySelector("#saveBdf").hidden, null, { timeout: 60000 });
    assert.equal(await page.locator("#savePdf").isEnabled(), true);
    await page.click("#tabForm");
  });

  await step("form page does not fill the old data after the JSON turns malformed", async () => {
    const good = await page.locator("#json").inputValue();
    await page.click("#tabData");
    await page.click("#tabForm");
    // a valid edit schedules a fill 250 ms out
    await page.evaluate(() => {
      const input = document.querySelector("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])");
      input.value = "途中";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    // and the JSON turns malformed before that fill runs
    await page.click("#tabJson");
    await page.evaluate(() => {
      const box = document.querySelector("#json");
      box.value = "{ not json";
      box.dispatchEvent(new Event("input", { bubbles: true }));
    });
    // the fill that was scheduled must not run
    await page.waitForTimeout(700);
    assert.equal(await page.locator("#saveBdf").isVisible(), false, "the .bdf link came back");
    assert.equal(await page.locator("#savePdf").isDisabled(), true, "the PDF button came back");
    assert.equal(await page.locator("#saveBdft").isDisabled(), true, "the .bdft button came back");
    // a tab switch does not bring it back
    await page.click("#tabForm");
    await page.waitForTimeout(400);
    assert.equal(await page.locator("#saveBdf").isVisible(), false, "a tab switch brought the .bdf link back");
    assert.equal(await page.locator("#savePdf").isDisabled(), true, "a tab switch brought the PDF button back");
    // nor does a name left for another person
    const box = page.locator("#fields .handon input[type='checkbox']").first();
    await box.check();
    await page.waitForTimeout(400);
    assert.equal(await page.locator("#saveBdf").isVisible(), false, "a name left open brought the .bdf link back");
    assert.equal(await page.locator("#savePdf").isDisabled(), true, "a name left open brought the PDF button back");
    await box.uncheck();
    // valid data fills again
    await page.click("#tabJson");
    await page.fill("#json", good);
    await page.waitForFunction(() => !document.querySelector("#saveBdf").hidden, null, { timeout: 60000 });
    assert.equal(await page.locator("#savePdf").isEnabled(), true);
    await page.click("#tabForm");
  });

  await step("form page saves the filled form as BDF and PDF", async () => {
    await page.click("#tabPreview");
    const [bdf] = await Promise.all([
      page.waitForEvent("download", { timeout: 60000 }),
      page.click("#saveBdf"),
    ]);
    assert.match(bdf.suggestedFilename(), /\.bdf$/);
    const [pdf] = await Promise.all([
      page.waitForEvent("download", { timeout: 180000 }),
      page.click("#savePdf"),
    ]);
    assert.match(pdf.suggestedFilename(), /\.pdf$/);
    await page.waitForFunction(() => /\.pdf を .* で書き出しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 180000 });
    // a page form writes a PDF with pages, not an empty file
    assert.match(await page.locator("#status").textContent(), /[1-9]\d* ページ/);
  });

  await step("form page writes a text form as a PDF with pages", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='text-slip.txt']", { timeout: 60000 });
    await page.click("#presets button[title='text-slip.txt']");
    await page.waitForFunction(() => /text-slip\.txt を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal((await exportState()).pdfDisabled, false, "the PDF button is disabled for a text form");
    await page.click("#tabPreview");
    const [pdf] = await Promise.all([
      page.waitForEvent("download", { timeout: 180000 }),
      page.click("#savePdf"),
    ]);
    assert.match(pdf.suggestedFilename(), /\.pdf$/);
    await page.waitForFunction(() => /\.pdf を .* で書き出しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 180000 });
    assert.match(await page.locator("#status").textContent(), /[1-9]\d* ページ/);
  });

  await step("form page leaves a name for another person", async () => {
    await page.click("#tabData");
    await page.click("#tabForm");
    const box = page.locator("#fields .handon input[type='checkbox']").first();
    await box.check();
    await page.waitForFunction(() => /記入途中の帳票/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 60000 });
    assert.match(await page.locator("#saveBdf").textContent(), /\.bdff/);
    await box.uncheck();
    await page.waitForFunction(() => !/記入途中の帳票/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 60000 });
    assert.match(await page.locator("#saveBdf").textContent(), /\.bdf/);
  });

  await step("form page opens a template from a file", async () => {
    await page.setInputFiles("#file", {
      name: "form-fixed.xlsx",
      mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      buffer: await readFile(resolve(root, "forms/form-fixed.xlsx")),
    });
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal(await page.locator("#document-name").textContent(), "form-fixed.xlsx");
  });

  await step("form page previews an Excel sheet and does not offer a PDF", async () => {
    // サンプルのデータで開く（ローカルのファイルはサンプルを持たない）
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    // シート表示の帳票: BDF は保存できるが、PDF にはまだ書き出せない
    const state = await exportState();
    assert.equal(state.bdfHidden, false, "the .bdf link is not offered");
    assert.equal(state.pdfDisabled, true, "the PDF button is enabled for a sheet view");
    assert.equal(state.bdftDisabled, false, "the .bdft button is disabled");
    // 「0 ページ」ではなく、シートとして数える
    assert.match(await page.locator("#status").textContent(), /シート 1 枚（明細書）/);
    assert.equal(await page.locator("#page-number").textContent(), "シート");
    // なぜ PDF を出せないかを、画面に書く
    assert.equal(await page.evaluate(() => document.querySelector("#pdfNote").hidden), false, "the PDF note is hidden");
    assert.match(await page.locator("#pdfNote").textContent(), /PDF への書き出しはまだできません/);
    // プレビューはシートを描いている（空の升目ではない）
    await page.waitForFunction(() => {
      const canvas = document.querySelector("#preview canvas");
      if (!canvas || !canvas.width || !canvas.height) return false;
      const { data } = canvas.getContext("2d").getImageData(0, 0, canvas.width, canvas.height);
      let dark = 0;
      for (let i = 0; i < data.length; i += 4) {
        if (data[i] < 128 && data[i + 1] < 128 && data[i + 2] < 128) dark += 1;
      }
      return dark > 100;
    }, null, { timeout: 120000 });
    // そして BDF は、シートの題と中身を持っている
    const bdf = await readBdf();
    const manifest = bdfManifest(bdf);
    const sheets = manifest.views.filter((view) => view.kind === "sheet");
    assert.equal(sheets.length, 1, "the BDF has no sheet view");
    assert.equal(sheets[0].title, "明細書");
    assert.ok(sheets[0].cols.length > 0 && sheets[0].rows.length > 0, "the sheet has no cells");
    const table = manifest.parts.find((part) => part.t === "table");
    assert.ok(table, "the BDF has no table part");
    const cells = bdfPart(bdf, manifest, table).toString("utf8");
    assert.match(cells, /明細書/);
    assert.match(cells, /株式会社みなと商事/);
  });

  await step("form page rejects a zero-page PDF export before download", async () => {
    let downloaded = false;
    const onDownload = () => { downloaded = true; };
    page.once("download", onDownload);
    // ボタンは無効だが、押された場合も 0 ページの PDF を出さない
    await page.evaluate(() => {
      const button = document.querySelector("#savePdf");
      button.disabled = false;
      button.click();
    });
    await page.waitForFunction(() => /PDF にできるページがありません/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 180000 });
    assert.equal(downloaded, false, "a zero-page PDF was downloaded");
    assert.equal(await page.locator("#savePdf").isDisabled(), true, "the PDF button is still enabled");
    page.off("download", onDownload);
  });

  await step("form page refuses a picture that pdfme cannot read", async () => {
    // form-fixed.xlsx has a picture field
    const pick = page.locator("#fields .picture input[type='file']").first();
    assert.equal(await pick.count(), 1, "the template has no picture field");
    const before = await page.locator("#fields .picture input:not([type='file'])").first().inputValue();
    await pick.setInputFiles({ name: "mark.gif", mimeType: "image/gif", buffer: Buffer.from("GIF89a") });
    await page.waitForFunction(() => /PNG・JPEG・SVG/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 30000 });
    assert.equal(await page.locator("#fields .picture input:not([type='file'])").first().inputValue(), before);
    // a PNG is taken
    const png = await readFile(resolve(root, "forms/brand-mark.png"));
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: png });
    await page.waitForFunction(() => (document.querySelector("#fields .picture input:not([type='file'])")?.value ?? "").startsWith("data:image/png;base64,"), null, { timeout: 30000 });
  });

  await step("form page shows a template that bdf.mbt cannot fill, and offers no document", async () => {
    await page.setInputFiles("#file", {
      name: "form-fixed.pptx",
      mimeType: "application/vnd.openxmlformats-officedocument.presentationml.presentation",
      buffer: await readFile(resolve(root, "forms/form-fixed.pptx")),
    });
    await page.waitForFunction(() => document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    assert.match(await page.locator("#status").textContent(), /_last/);
    assert.equal(await page.locator("#saveBdf").isVisible(), false);
    assert.equal(await page.locator("#savePdf").isDisabled(), true);
    assert.equal(await page.locator("#saveBdft").isDisabled(), true);
  });

  await step("form page keeps the last sample that was chosen", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-rows.docx']", { timeout: 60000 });
    // the invoice comes slowly, the slip at once: the slip is what stays
    await page.route("**/forms/form-rows.docx", async (route) => {
      await new Promise((done) => setTimeout(done, 1500));
      await route.continue();
    });
    await page.click("#presets button[title='form-rows.docx']");
    await page.click("#presets button[title='text-slip.txt']");
    await page.waitForFunction(() => /text-slip\.txt を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 60000 });
    await page.waitForTimeout(2500);
    assert.equal(await page.locator("#document-name").textContent(), "text-slip.txt");
    assert.match(await page.locator("#status").textContent(), /text-slip\.txt/);
    await page.unroute("**/forms/form-rows.docx");
  });

  await step("form page does not restore the old document while a slow template opens", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-rows.docx']", { timeout: 60000 });
    await page.click("#presets button[title='form-rows.docx']");
    await page.waitForFunction(() => /form-rows\.docx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    const before = await exportState();
    assert.equal(before.bdfHidden, false, "the .bdf link is not offered");
    assert.equal(before.pdfDisabled, false, "the PDF button is disabled");
    // 打ち込むと、記入は 250 ms 待ってから始まる。その間に遅いテンプレートを選ぶ
    await page.route("**/forms/form-pages.docx", async (route) => {
      await new Promise((done) => setTimeout(done, 1500));
      await route.continue();
    });
    await page.evaluate(() => {
      const input = document.querySelector("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])");
      input.value = "待っている間の値";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      document.querySelector("#presets button[title='form-pages.docx']").click();
    });
    // 前のテンプレートの記入が走っても、前の文書は戻らない
    await page.waitForTimeout(700);
    const during = await exportState();
    assert.equal(during.bdfHidden, true, "the old .bdf link came back");
    assert.equal(during.bdfHref, null, "the old .bdf link still points at the old document");
    assert.equal(during.pdfDisabled, true, "the old PDF button came back");
    assert.equal(during.bdftDisabled, true, "the old .bdft button came back");
    assert.doesNotMatch(await page.locator("#status").textContent(), /form-rows\.docx を .* で記入しました/, "the old template was filled again");
    assert.equal(await page.locator("#document-name").textContent(), "–", "the old template is still named");
    // 新しいテンプレートは、ちゃんと開いて記入する
    await page.waitForFunction(() => /form-pages\.docx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal(await page.locator("#document-name").textContent(), "form-pages.docx");
    const after = await exportState();
    assert.equal(after.bdfHidden, false, "the new .bdf link is not offered");
    assert.equal(after.pdfDisabled, false, "the new PDF button is disabled");
    await page.unroute("**/forms/form-pages.docx");
  });

  await step("form page keeps the old document away when a template fails to open", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-rows.docx']", { timeout: 60000 });
    await page.click("#presets button[title='form-rows.docx']");
    await page.waitForFunction(() => /form-rows\.docx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal((await exportState()).bdfHidden, false);
    // 打ち込んでから、読めないテンプレートを開く
    await page.evaluate(() => {
      const input = document.querySelector("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])");
      input.value = "失敗する前の値";
      input.dispatchEvent(new Event("input", { bubbles: true }));
    });
    await page.setInputFiles("#file", {
      name: "broken.xlsx",
      mimeType: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      buffer: Buffer.from("not a zip"),
    });
    await page.waitForFunction(() => document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    // 前のテンプレートには戻らない
    await page.waitForTimeout(700);
    const state = await exportState();
    assert.equal(state.bdfHidden, true, "the old .bdf link came back");
    assert.equal(state.bdfHref, null, "the old .bdf link still points at the old document");
    assert.equal(state.pdfDisabled, true, "the old PDF button came back");
    assert.equal(state.bdftDisabled, true, "the old .bdft button came back");
    assert.equal(await page.locator("#document-name").textContent(), "–", "the old template is still named");
    assert.equal(await page.locator("#fields input, #fields textarea, #fields select").count(), 0, "the old form is still there");
    assert.match(await page.locator("#status").textContent(), /^error/);
  });

  await step("form page keeps the old document away when a sample cannot be read", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-rows.docx']", { timeout: 60000 });
    await page.click("#presets button[title='form-rows.docx']");
    await page.waitForFunction(() => /form-rows\.docx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    assert.equal((await exportState()).bdfHidden, false);
    // サンプルのデータが JSON でない: 取ってきたテンプレートは開かない
    await page.route("**/forms/form-pages.json", (route) => route.fulfill({ status: 200, contentType: "application/json", body: "{ not json" }));
    await page.evaluate(() => {
      const input = document.querySelector("#fields textarea, #fields input:not([type='checkbox']):not([type='file'])");
      input.value = "読めないサンプルの前の値";
      input.dispatchEvent(new Event("input", { bubbles: true }));
      document.querySelector("#presets button[title='form-pages.docx']").click();
    });
    await page.waitForFunction(() => document.querySelector("#status")?.classList.contains("error"), null, { timeout: 60000 });
    await page.waitForTimeout(700);
    const state = await exportState();
    assert.equal(state.bdfHidden, true, "the old .bdf link came back");
    assert.equal(state.bdfHref, null, "the old .bdf link still points at the old document");
    assert.equal(state.pdfDisabled, true, "the old PDF button came back");
    assert.equal(state.bdftDisabled, true, "the old .bdft button came back");
    assert.equal(await page.locator("#document-name").textContent(), "–", "the old template is still named");
    await page.unroute("**/forms/form-pages.json");
  });

  await step("form page discards a picture read that finishes after another template opens", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、別のテンプレートを開く
    await page.click("#tabTemplate");
    await page.click("#presets button[title='form-rows.docx']");
    await page.waitForFunction(() => /form-rows\.docx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await settlePictureRead();
    await page.waitForTimeout(300);
    const json = await page.locator("#json").inputValue();
    assert.doesNotMatch(json, /data:image/, "the old picture came into the new data");
    assert.match(json, /INV-2026-1014/, "the new data is gone");
    assert.equal(await page.locator("#document-name").textContent(), "form-rows.docx");
  });

  await step("form page discards a picture read that finishes after the JSON is replaced", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、JSON を別のデータに置き換える
    await page.click("#tabJson");
    const replaced = JSON.parse(await page.locator("#json").inputValue());
    replaced.customer.name = "新しい値";
    await page.fill("#json", JSON.stringify(replaced));
    await page.waitForFunction(() => !document.querySelector("#saveBdf").hidden, null, { timeout: 60000 });
    await settlePictureRead();
    await page.waitForTimeout(300);
    const json = JSON.parse(await page.locator("#json").inputValue());
    assert.equal(json.customer.name, "新しい値", "the replaced data is gone");
    assert.equal(json.photo, "brand-mark.png", "the old picture came into the replaced data");
  });

  await step("form page discards a picture read that finishes after a row is removed", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、明細の行を 1 つ消す
    const rows = page.locator("#fields table tbody tr");
    const before = await rows.count();
    assert.ok(before > 1, "the template has no rows to remove");
    await page.locator("#fields .remove").first().click();
    await page.waitForFunction((n) => document.querySelectorAll("#fields table tbody tr").length === n - 1, before, { timeout: 30000 });
    await settlePictureRead();
    await page.waitForTimeout(300);
    const json = JSON.parse(await page.locator("#json").inputValue());
    assert.equal(json.photo, "brand-mark.png", "the old picture came into the data after the row was removed");
    assert.equal(json.tags.length, before - 1, "the removed row came back");
  });

  await step("form page keeps the last picture when two reads finish out of order", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    const svg = Buffer.from('<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"><rect width="1" height="1"/></svg>');
    await pick.setInputFiles({ name: "dot.svg", mimeType: "image/svg+xml", buffer: svg });
    await page.waitForFunction(() => window.__reads.length === 2, null, { timeout: 30000 });
    // あとの読みを先に、前の読みを後に終わらせる: 前の読みは捨てる
    await settlePictureRead(1);
    await page.waitForTimeout(100);
    await settlePictureRead(0);
    await page.waitForTimeout(300);
    const json = JSON.parse(await page.locator("#json").inputValue());
    assert.match(json.photo, /^data:image\/svg\+xml;base64,/, "the first picture won");
  });

  await step("form page discards a picture read that finishes after malformed JSON", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、JSON を読めない形にする
    await page.click("#tabJson");
    await page.fill("#json", "{ not json");
    await page.waitForFunction(() => document.querySelector("#status")?.classList.contains("error"), null, { timeout: 30000 });
    await settlePictureRead();
    await page.waitForTimeout(300);
    assert.equal(await page.locator("#json").inputValue(), "{ not json", "the malformed JSON was overwritten");
    assert.match(await page.locator("#status").textContent(), /JSON/);
    const state = await exportState();
    assert.equal(state.bdfHidden, true, "the old document came back");
    assert.equal(state.pdfDisabled, true, "the PDF button came back");
  });

  await step("form page discards a picture read that finishes after non-object JSON", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、JSON を配列（オブジェクトでない）にする
    await page.click("#tabJson");
    await page.fill("#json", "[]");
    await page.waitForFunction(() => /JSON のオブジェクト/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 30000 });
    await settlePictureRead();
    await page.waitForTimeout(300);
    assert.equal(await page.locator("#json").inputValue(), "[]", "the non-object JSON was overwritten");
    assert.equal((await exportState()).bdfHidden, true, "the old document came back");
  });

  await step("form page discards a picture read that finishes after the picture name is typed", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#presets button[title='form-fixed.xlsx']", { timeout: 60000 });
    await page.click("#presets button[title='form-fixed.xlsx']");
    await page.waitForFunction(() => /form-fixed\.xlsx を .* で記入しました/.test(document.querySelector("#status")?.textContent ?? ""), null, { timeout: 120000 });
    await deferPictureReads();
    const pick = page.locator("#fields .picture input[type='file']").first();
    await pick.setInputFiles({ name: "brand-mark.png", mimeType: "image/png", buffer: await readFile(resolve(root, "forms/brand-mark.png")) });
    await page.waitForFunction(() => window.__reads.length === 1, null, { timeout: 30000 });
    // 読みが終わる前に、画像の名前を打ち込む
    const name = page.locator("#fields .picture input:not([type='file'])").first();
    await name.fill("data:image/png;base64,dHlwZWQ=");
    await settlePictureRead();
    await page.waitForTimeout(300);
    assert.equal(await name.inputValue(), "data:image/png;base64,dHlwZWQ=", "the typed picture was overwritten");
    const json = JSON.parse(await page.locator("#json").inputValue());
    assert.equal(json.photo, "data:image/png;base64,dHlwZWQ=", "the typed picture is not in the data");
  });

  await step("form page offers only the PDF it can write", async () => {
    await fresh();
    await page.goto(base + "form/", { waitUntil: "domcontentloaded" });
    // タグ付き PDF は書き出せないので、選ばせない
    assert.equal(await page.locator("#pdfKind").count(), 0, "the PDF kind selector is still there");
    assert.equal(await page.locator("#previewPanel [value='tagged']").count(), 0, "a tagged PDF option is still there");
    assert.equal(await page.locator("#previewPanel select").count(), 0, "the preview still offers a PDF kind");
    assert.match(await page.locator("#limits").textContent(), /タグ付き PDF も書き出せません/);
  });


  await step("top page names the plugin diagram formats", async () => {
    await fresh();
    await page.goto(base + "index.html", { waitUntil: "domcontentloaded" });
    const html = await page.content();
    assert.match(html, /Mermaid/);
    assert.match(html, /Excalidraw/);
  });

  await step("diagram docs describe the plugin subsets and link the API docs", async () => {
    await fresh();
    await page.goto(base + "docs/formats/diagram.html", { waitUntil: "domcontentloaded" });
    const html = await page.content();
    assert.match(html, /Mermaid/);
    assert.match(html, /Excalidraw/);
    assert.match(html, /静的なフローチャートの一部/);
    // Pipes inside a GFM table must not truncate this supported edge syntax.
    assert.match((await page.locator("table td").allTextContents()).join("\n"), /A -->\|text\| B/);
    assert.match(html, /手書き風の線/);
    assert.match(html, /docs\/diagram-plugins\.md/);
    assert.match(html, /docs\/format-plugin-api\.md/);
    assert.match(html, /plugin\/library\/README\.md/);
    await page.goto(base + "docs/api.html", { waitUntil: "domcontentloaded" });
    const api = await page.content();
    assert.match(api, /プラグイン API/);
    assert.match(api, /bdf\.mbt\/plugin\/adapters\/mermaid/);
    assert.match(api, /docs\/diagram-plugins\.md/);
  });

  await step("docs pages show the sidebar and the outline", async () => {
    await fresh();
    await page.goto(base + "docs/index.html", { waitUntil: "domcontentloaded" });
    assert.ok((await page.locator(".sidebar a").count()) > 20);
    await page.goto(base + "docs/formats/pdf.html", { waitUntil: "domcontentloaded" });
    assert.ok((await page.locator(".toc a").count()) > 2);
  });

  await step("the pages fit a phone", async () => {
    const phone = await browser.newPage({ viewport: { width: 375, height: 812 } });
    try {
      for (const path of ["index.html", "viewer/", "form/", "thumbnail/", "text/", "docs/index.html", "docs/formats/pdf.html"]) {
        await phone.goto(base + path, { waitUntil: "domcontentloaded" });
        const overflow = await phone.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
        assert.ok(overflow <= 1, path + " overflows by " + overflow + "px");
      }
    } finally {
      await phone.close();
    }
  });
} finally {
  await browser.close();
  await new Promise((done) => server.close(done));
}

if (errors.length) {
  console.log(errors.length + " console error(s):");
  for (const error of errors.slice(0, 10)) console.log("  " + error);
  failures += 1;
}
console.log(failures ? failures + " failure(s)" : "all site tests passed");
process.exit(failures ? 1 : 0);
