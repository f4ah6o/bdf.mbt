// ローカルフォント UI のブラウザテスト（Playwright）。
//
//   node site/local-fonts-test.mjs
//
// site/assets/local-fonts.js をそのまま配り、queryLocalFonts と FontData を
// 差し替えて確かめる。実機のフォントは列挙しない。書体はテストが作った
// 合成バイト列だけで、ホストのフォントにも権限にも触れない。
import assert from "node:assert/strict";
import { createReadStream } from "node:fs";
import { stat } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve } from "node:path";
import { chromium } from "playwright";

const assets = resolve(import.meta.dirname, "assets");
const requests = [];
const server = createServer(async (request, response) => {
  const url = new URL(request.url, "http://localhost");
  requests.push(url.pathname);
  if (url.pathname === "/harness.html") {
    response.writeHead(200, { "Content-Type": "text/html; charset=utf-8" });
    response.end(HARNESS);
    return;
  }
  if (url.pathname === "/assets/local-fonts.js") {
    const file = resolve(assets, "local-fonts.js");
    const info = await stat(file);
    response.writeHead(200, { "Content-Type": "text/javascript; charset=utf-8", "Content-Length": info.size });
    createReadStream(file).pipe(response);
    return;
  }
  response.writeHead(404).end();
});
await new Promise((done, fail) => {
  server.once("error", fail);
  server.listen(0, "127.0.0.1", done);
});
const base = "http://127.0.0.1:" + server.address().port;

const HARNESS = `<!doctype html>
<html lang="ja"><head><meta charset="utf-8"><title>local fonts</title></head>
<body><main>
<section id="local-fonts" aria-labelledby="local-fonts-title">
<h2 id="local-fonts-title">ローカルフォント</h2>
<p class="note" id="local-fonts-note">説明</p>
</section>
<section id="insecure" aria-labelledby="insecure-title">
<h2 id="insecure-title">安全でない接続</h2>
</section>
<section id="limits" aria-labelledby="limits-title">
<h2 id="limits-title">上限</h2>
</section>
</main>
<script type="module">
import { createLocalFontsUI, localFontsSupport, faceLabel } from "/assets/local-fonts.js";
window.__module = { createLocalFontsUI, localFontsSupport, faceLabel };
window.__ui = createLocalFontsUI({ root: document.querySelector("#local-fonts") });
window.__insecureCalls = 0;
window.__insecure = createLocalFontsUI({
  root: document.querySelector("#insecure"),
  scope: { isSecureContext: false, queryLocalFonts: async () => { window.__insecureCalls += 1; return []; } },
});
const limits = new URLSearchParams(location.search).get("limits");
if (limits) {
  window.__limitsUI = createLocalFontsUI({
    root: document.querySelector("#limits"),
    limits: JSON.parse(limits),
  });
}
window.__ready = true;
</script></body></html>`;

// 合成フォント（sfnt の版と目印だけ）。実在の書体ではない。
const SYNTHETIC = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x53, 0x59, 0x4e, 0x54];
const SYNTHETIC_B = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x53, 0x59, 0x4e, 0x42];
const FACES = [
  { postscriptName: "SyntheticTest-Regular", fullName: "Synthetic Test", family: "Synthetic Test", style: "Regular", bytes: SYNTHETIC },
  { postscriptName: "SyntheticTest-Bold", fullName: "Synthetic Test Bold", family: "Synthetic Test", style: "Bold", bytes: SYNTHETIC_B },
];

const browser = await chromium.launch({ headless: true, ...(process.env.BDF_CHROMIUM ? { executablePath: process.env.BDF_CHROMIUM } : {}) });
let failures = 0;
let page = null;

async function step(name, fn) {
  const started = Date.now();
  try {
    await fn();
    console.log("ok   " + name + " (" + ((Date.now() - started) / 1000).toFixed(1) + "s)");
  } catch (error) {
    failures += 1;
    console.log("FAIL " + name + ": " + (error.message ?? error).split("\n")[0]);
  }
}

async function fresh() {
  if (page) {
    const old = page;
    page = null;
    await old.context().close().catch(() => {});
  }
  const context = await browser.newContext({ viewport: { width: 1000, height: 800 } });
  page = await context.newPage();
  page.setDefaultTimeout(15000);
  return page;
}

async function open({ mode = "ok", faces = FACES, unsupported = false, limits = null } = {}) {
  await fresh();
  await page.addInitScript(({ mode, faces, unsupported }) => {
    window.__fontCalls = { query: 0, blob: [], read: [] };
    window.__net = [];
    window.__storage = [];
    window.__queryMode = mode;
    window.__faces = faces;
    if (unsupported) delete window.queryLocalFonts;
    else {
      window.queryLocalFonts = async () => {
        window.__fontCalls.query += 1;
        if (window.__queryMode === "deny") throw new DOMException("denied", "NotAllowedError");
        if (window.__queryMode === "slow") await new Promise((done) => setTimeout(done, 400));
        return window.__faces.map((spec) => ({
          postscriptName: spec.postscriptName,
          fullName: spec.fullName,
          family: spec.family,
          style: spec.style,
          blob: async () => {
            window.__fontCalls.blob.push(spec.postscriptName);
            if (spec.fail) throw new Error("blob failed");
            return {
              size: spec.size ?? spec.bytes.length,
              type: spec.type ?? "font/ttf",
              arrayBuffer: async () => {
                window.__fontCalls.read.push(spec.postscriptName);
                return new Uint8Array(spec.actual ?? spec.bytes).buffer;
              },
            };
          },
        }));
      };
    }
    const record = (kind, value) => window.__net.push(kind + ":" + String(value));
    window.fetch = async (input) => { record("fetch", input?.url ?? input); throw new Error("network disabled"); };
    window.XMLHttpRequest = class { open(method, url) { record("xhr", url); } send() { record("xhr-send", ""); } };
    navigator.sendBeacon = (url) => { record("beacon", url); return false; };
    window.WebSocket = class { constructor(url) { record("websocket", url); } };
    Storage.prototype.setItem = function (key) { window.__storage.push("setItem:" + key); };
    Storage.prototype.getItem = function (key) { window.__storage.push("getItem:" + key); return null; };
    indexedDB.open = (...args) => { window.__storage.push("indexedDB:" + args[0]); throw new Error("storage disabled"); };
  }, { mode, faces, unsupported });
  await page.goto(base + "/harness.html" + (limits ? "?limits=" + encodeURIComponent(JSON.stringify(limits)) : ""), { waitUntil: "domcontentloaded" });
  await page.waitForFunction(() => window.__ready === true);
  return page;
}

const statusText = () => page.locator("#local-fonts .status").textContent();
const calls = () => page.evaluate(() => window.__fontCalls);

try {
  await step("does not enumerate fonts on page load", async () => {
    await open();
    await page.waitForTimeout(250);
    assert.deepEqual(await calls(), { query: 0, blob: [], read: [] });
    assert.equal(await page.locator("#local-fonts .local-font-list").isHidden(), true);
  });

  await step("unsupported browser explains and never queries", async () => {
    await open({ unsupported: true });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForFunction(() => /対応していません/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual(await calls(), { query: 0, blob: [], read: [] });
    assert.equal(await page.locator("#local-fonts button:has-text('ローカルフォントを選ぶ')").isDisabled(), true);
  });

  await step("insecure context is refused before querying", async () => {
    await open();
    await page.click("#insecure button:has-text('ローカルフォントを選ぶ')");
    await page.waitForFunction(() => /安全な接続/.test(document.querySelector("#insecure .status")?.textContent ?? ""));
    assert.equal(await page.evaluate(() => window.__insecureCalls), 0);
  });

  await step("permission denial is reported without reading bytes", async () => {
    await open({ mode: "deny" });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForFunction(() => /許可されませんでした/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual(await calls(), { query: 1, blob: [], read: [] });
    assert.equal(await page.locator("#local-fonts .local-font-list").isHidden(), true);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
  });

  await step("lists faces without selecting any", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    assert.equal(await page.locator("#local-fonts .local-font-face input").count(), 2);
    assert.equal(await page.locator("#local-fonts .local-font-face input:checked").count(), 0);
    assert.equal(await page.locator("#local-fonts button:has-text('選択した書体を使う')").isDisabled(), true);
    assert.match(await statusText(), /2 書体/);
    assert.deepEqual(await calls(), { query: 1, blob: [], read: [] });
  });

  await step("keyboard selection reads only the selected face", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.focus("#local-fonts-face-0");
    await page.keyboard.press("Space");
    assert.equal(await page.locator("#local-fonts-face-0").isChecked(), true);
    assert.equal(await page.locator("#local-fonts button:has-text('選択した書体を使う')").isEnabled(), true);
    await page.focus("#local-fonts button:has-text('選択した書体を使う')");
    await page.keyboard.press("Enter");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).blob, ["SyntheticTest-Regular"]);
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => ({ name: file.name, postscriptName: file.postscriptName, bytes: [...file.bytes] })));
    assert.deepEqual(files, [{ name: "SyntheticTest-Regular.ttf", postscriptName: "SyntheticTest-Regular", bytes: SYNTHETIC }]);
    assert.match(await page.locator("#local-fonts-summary").textContent(), /SyntheticTest-Regular\.ttf/);
  });

  await step("no selection is rejected without reading bytes", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.evaluate(() => window.__ui.apply());
    await page.waitForFunction(() => /書体が選ばれていません/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).blob, []);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
  });

  await step("clearing drops the selection and the list", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click("#local-fonts button:has-text('選択を解除')");
    await page.waitForFunction(() => /選択を解除しました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
    assert.equal(await page.locator("#local-fonts .local-font-list").isHidden(), true);
    assert.equal(await page.locator("#local-fonts-summary").isHidden(), true);
  });

  await step("a failed read keeps the previous selection", async () => {
    await open({ faces: [FACES[0], { ...FACES[1], fail: true }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-1");
    await page.check("#local-fonts-face-1");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /読み込めませんでした/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => file.name));
    assert.deepEqual(files, ["SyntheticTest-Regular.ttf"]);
  });

  await step("stale query results are ignored after a reset", async () => {
    await open({ mode: "slow" });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.evaluate(() => window.__ui.clear({ announce: false }));
    await page.waitForTimeout(600);
    assert.equal(await page.locator("#local-fonts .local-font-list").isHidden(), true);
    assert.equal(await page.locator("#local-fonts .local-font-face input").count(), 0);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
  });

  await step("labels, legend and live status are accessible", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    assert.equal(await page.locator("#local-fonts legend").textContent(), "使う書体");
    const labelled = await page.evaluate(() => [...document.querySelectorAll("#local-fonts .local-font-face input")].every((input) => input.labels?.length === 1));
    assert.equal(labelled, true);
    assert.equal(await page.locator("#local-fonts .status").getAttribute("role"), "status");
    assert.equal(await page.locator("#local-fonts .status").getAttribute("aria-live"), "polite");
    assert.equal(await page.locator("#local-fonts button:has-text('ローカルフォントを選ぶ')").getAttribute("aria-describedby"), "local-fonts-note");
    assert.equal(await page.locator("#local-fonts").getAttribute("aria-busy"), "false");
  });

  await step("no network, storage or console exfiltration", async () => {
    await open();
    const consoleMessages = [];
    page.on("console", (message) => consoleMessages.push(message.text()));
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual(await page.evaluate(() => window.__net), []);
    assert.deepEqual(await page.evaluate(() => window.__storage), []);
    assert.deepEqual(consoleMessages, []);
    assert.deepEqual([...new Set(requests)], ["/harness.html", "/assets/local-fonts.js"]);
  });

  await step("returned buffers are copies and stay intact", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts .local-font-face input");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const result = await page.evaluate(() => {
      const first = window.__ui.getFontFiles();
      const second = window.__ui.getFontFiles();
      first[0].bytes[0] = 99;
      return {
        distinct: first !== second && first[0].bytes !== second[0].bytes,
        second: [...second[0].bytes],
        third: [...window.__ui.getFontFiles()[0].bytes],
      };
    });
    assert.equal(result.distinct, true);
    assert.deepEqual(result.second, SYNTHETIC);
    assert.deepEqual(result.third, SYNTHETIC);
  });
  await step("rejects more faces than the worker accepts before reading", async () => {
    await open({ limits: { maxFiles: 2 }, faces: [FACES[0], FACES[1], { ...FACES[0], postscriptName: "SyntheticTest-Italic" }] });
    await page.click("#limits button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#limits-face-0");
    for (const id of ["#limits-face-0", "#limits-face-1", "#limits-face-2"]) await page.check(id);
    await page.click("#limits button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /選べる書体は 2 まで/.test(document.querySelector("#limits .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).blob, []);
    assert.deepEqual((await calls()).read, []);
    assert.equal(await page.evaluate(() => window.__limitsUI.getFontFiles()), null);
  });

  await step("rejects an oversized face from blob.size before allocating", async () => {
    await open({ limits: { maxFileBytes: 8 }, faces: [{ ...FACES[0], size: 9 }] });
    await page.click("#limits button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#limits-face-0");
    await page.check("#limits-face-0");
    await page.click("#limits button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体 8 バイト/.test(document.querySelector("#limits .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).read, []);
    assert.equal(await page.evaluate(() => window.__limitsUI.getFontFiles()), null);
  });

  await step("rejects an oversized total from blob.size before allocating", async () => {
    await open({ limits: { maxTotalBytes: 12 }, faces: [{ ...FACES[0], size: 8 }, { ...FACES[1], size: 8 }] });
    await page.click("#limits button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#limits-face-0");
    await page.check("#limits-face-0");
    await page.check("#limits-face-1");
    await page.click("#limits button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /合計が 12 バイト/.test(document.querySelector("#limits .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).read, []);
    assert.equal(await page.evaluate(() => window.__limitsUI.getFontFiles()), null);
  });

  await step("checks the actual byteLength and keeps the previous selection", async () => {
    await open({ limits: { maxFileBytes: 8 }, faces: [{ ...FACES[0], bytes: [1, 2, 3, 4] }, { ...FACES[1], size: 4, actual: [1, 2, 3, 4, 5, 6, 7, 8, 9] }] });
    await page.click("#limits button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#limits-face-0");
    await page.check("#limits-face-0");
    await page.click("#limits button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#limits .status")?.textContent ?? ""));
    await page.click("#limits button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#limits-face-1");
    await page.check("#limits-face-1");
    await page.click("#limits button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /実体が 1 書体 8 バイト/.test(document.querySelector("#limits .status")?.textContent ?? ""));
    const files = await page.evaluate(() => window.__limitsUI.getFontFiles().map((file) => file.name));
    assert.deepEqual(files, ["SyntheticTest-Regular.ttf"]);
  });

  await step("sanitized postscript names stay distinct", async () => {
    await open({ faces: [{ ...FACES[0], postscriptName: "Synthetic/Test" }, { ...FACES[1], postscriptName: "Synthetic:Test" }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.check("#local-fonts-face-1");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /2 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => ({ name: file.name, postscriptName: file.postscriptName })));
    assert.deepEqual(files, [
      { name: "Synthetic_Test.ttf", postscriptName: "Synthetic/Test" },
      { name: "Synthetic_Test-2.ttf", postscriptName: "Synthetic:Test" },
    ]);
  });

  await step("sends each face's actual postscriptName separately from the file name", async () => {
    await open();
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.check("#local-fonts-face-1");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /2 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => ({ name: file.name, postscriptName: file.postscriptName })));
    assert.deepEqual(files, [
      { name: "SyntheticTest-Regular.ttf", postscriptName: "SyntheticTest-Regular" },
      { name: "SyntheticTest-Bold.ttf", postscriptName: "SyntheticTest-Bold" },
    ]);
  });

  await step("rejects a face without a postscriptName before reading bytes", async () => {
    await open({ faces: [{ ...FACES[0], postscriptName: "" }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /PostScript 名が取得できない/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).blob, []);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
    assert.match(await statusText(), /書体は選ばれていません/);
  });

  await step("keeps the previous selection when a later face has no postscriptName", async () => {
    await open({ faces: [FACES[0], { ...FACES[1], postscriptName: "   " }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-1");
    await page.check("#local-fonts-face-1");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /PostScript 名が取得できない/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.match(await statusText(), /前の選択をそのまま使います/);
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => file.name));
    assert.deepEqual(files, ["SyntheticTest-Regular.ttf"]);
  });

  await step("caps long names at 255 units without splitting surrogate pairs", async () => {
    await open({ faces: [{ ...FACES[0], postscriptName: "A".repeat(300) }, { ...FACES[1], postscriptName: "A".repeat(250) + "😀" + "B".repeat(10) }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.check("#local-fonts-face-1");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /2 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const names = await page.evaluate(() => window.__ui.getFontFiles().map((file) => file.name));
    assert.equal(names[0].length, 255);
    assert.match(names[0], /\.ttf$/);
    assert.ok(names[1].length <= 255);
    assert.equal(await page.evaluate((name) => name.isWellFormed(), names[1]), true);
  });

  await step("replaces DEL and control characters in file names", async () => {
    await open({ faces: [{ ...FACES[0], postscriptName: "Bad\u007fName\u0001X" }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /1 書体を読み込みました/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    const files = await page.evaluate(() => window.__ui.getFontFiles().map((file) => ({ name: file.name, postscriptName: file.postscriptName })));
    assert.deepEqual(files, [{ name: "Bad_Name_X.ttf", postscriptName: "Bad\u007fName\u0001X" }]);
  });

  await step("rejects an empty blob before reading", async () => {
    await open({ faces: [{ ...FACES[0], size: 0 }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /データが空/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).read, []);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
  });

  await step("rejects zero actual bytes after reading", async () => {
    await open({ faces: [{ ...FACES[0], size: 4, actual: [] }] });
    await page.click("#local-fonts button:has-text('ローカルフォントを選ぶ')");
    await page.waitForSelector("#local-fonts-face-0");
    await page.check("#local-fonts-face-0");
    await page.click("#local-fonts button:has-text('選択した書体を使う')");
    await page.waitForFunction(() => /データが空/.test(document.querySelector("#local-fonts .status")?.textContent ?? ""));
    assert.deepEqual((await calls()).read, ["SyntheticTest-Regular"]);
    assert.equal(await page.evaluate(() => window.__ui.getFontFiles()), null);
  });

} finally {
  await browser.close();
  await new Promise((done) => server.close(done));
}

console.log(failures ? failures + " failure(s)" : "all local font tests passed");
process.exit(failures ? 1 : 0);
