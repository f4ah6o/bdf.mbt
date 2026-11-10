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
import { chromium } from "playwright";

const root = resolve(import.meta.dirname, "../_build/pages");
// 再配布できる同梱の書体を、FontData の代わりに使う（ホストのフォントは読まない）。
const stix = await readFile(resolve(import.meta.dirname, "../compat/font/fixtures/stix.ttf"));
const stixBase64 = stix.toString("base64");
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

async function step(name, fn) {
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
    await page.click("#local-fonts button:has-text('選択を解除')");
    await page.waitForFunction(() => /選択を解除しました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click('#samples button:text-is("Word")');
    await page.waitForFunction(() => document.querySelector("#document-name")?.textContent === "basic.docx", null, { timeout: 180000 });
    const after = await page.evaluate(() => window.__posted.at(-1));
    assert.equal(after.fontFiles, undefined, "a cleared selection is not sent");
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
      const { readFile } = await import("node:fs/promises");
      return readFile(resolve(root, "samples/demo.pdf"));
    })() });
    await page.click("#pdf-convert");
    await page.waitForFunction(() => /→ BDF/.test(document.querySelector("#wasm-status")?.textContent ?? ""), null, { timeout: 180000 });
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
      for (const path of ["index.html", "viewer/", "thumbnail/", "text/", "docs/index.html", "docs/formats/pdf.html"]) {
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
