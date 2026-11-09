// ギャラリーのカードに使うプレビュー画像を作る。site/home.mjs の GALLERY が唯一の一覧。
//
//   node site/build.mjs            # _build/pages を作る
//   node site/make-previews.mjs    # site/previews/*.png を書き直す
//   node site/make-previews.mjs --check   # 書き換えず、ずれていないかだけ見る
//
// ビルドしたサイトのビューアでサンプルを開き、1 ページ目の canvas を 640×400 に
// 切り出して写す。プレビューはサイト自身の出力になる。
import { createReadStream } from "node:fs";
import { readFile, stat, writeFile } from "node:fs/promises";
import { createServer } from "node:http";
import { extname, resolve } from "node:path";
import { PNG } from "pngjs";
import { chromium } from "playwright";
import { GALLERY } from "./home.mjs";

const page = resolve(import.meta.dirname);
const root = resolve(page, "..");
const built = resolve(root, "_build/pages");
const previews = resolve(page, "previews");
const WIDTH = 640;
const HEIGHT = 400;
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
  ".ttf": "font/ttf",
  ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
  ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
  ".epub": "application/epub+zip",
  ".drawio": "application/xml",
  ".dxf": "application/dxf",
  ".kicad_pcb": "application/octet-stream",
  ".musicxml": "application/vnd.recordare.musicxml+xml",
  ".mp3": "audio/mpeg",
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

/** 左上から 16:10 に切り出し、640×400 に箱型で縮める。 */
function frame(source) {
  const scale = Math.max(WIDTH / source.width, HEIGHT / source.height);
  const cropWidth = Math.min(source.width, Math.round(WIDTH / scale));
  const cropHeight = Math.min(source.height, Math.round(HEIGHT / scale));
  const out = new PNG({ width: WIDTH, height: HEIGHT });
  for (let y = 0; y < HEIGHT; y += 1) {
    const sy0 = Math.floor((y * cropHeight) / HEIGHT);
    const sy1 = Math.max(sy0 + 1, Math.floor(((y + 1) * cropHeight) / HEIGHT));
    for (let x = 0; x < WIDTH; x += 1) {
      const sx0 = Math.floor((x * cropWidth) / WIDTH);
      const sx1 = Math.max(sx0 + 1, Math.floor(((x + 1) * cropWidth) / WIDTH));
      let r = 0;
      let g = 0;
      let b = 0;
      let count = 0;
      for (let sy = sy0; sy < sy1; sy += 1) {
        for (let sx = sx0; sx < sx1; sx += 1) {
          const at = (sy * source.width + sx) * 4;
          r += source.data[at];
          g += source.data[at + 1];
          b += source.data[at + 2];
          count += 1;
        }
      }
      const to = (y * WIDTH + x) * 4;
      out.data[to] = Math.round(r / count);
      out.data[to + 1] = Math.round(g / count);
      out.data[to + 2] = Math.round(b / count);
      out.data[to + 3] = 255;
    }
  }
  return out;
}

/**
 * 比較は 16×10 の区画の平均色で行う。字形やにじみは OS のフォントで変わる
 * ので、画素そのものではなく区画の明るさで見る。しきい値は区画あたりの
 * 1 段。真っ白・真っ黒・別の文書といった違いはこれで弾ける。
 */
const CELLS = 16 * 10;
const TOLERANCE = 48;

/** 区画ごとの平均色。戻り値は RGB の並びで cells × 3。 */
function signature(image) {
  const cellW = Math.max(1, Math.floor(image.width / 16));
  const cellH = Math.max(1, Math.floor(image.height / 10));
  const sums = new Float64Array(CELLS * 3);
  const counts = new Float64Array(CELLS);
  for (let y = 0; y < image.height; y += 1) {
    const row = Math.min(9, Math.floor(y / cellH));
    for (let x = 0; x < image.width; x += 1) {
      const column = Math.min(15, Math.floor(x / cellW));
      const cell = row * 16 + column;
      const at = (y * image.width + x) * 4;
      sums[cell * 3] += image.data[at];
      sums[cell * 3 + 1] += image.data[at + 1];
      sums[cell * 3 + 2] += image.data[at + 2];
      counts[cell] += 1;
    }
  }
  const out = new Array(CELLS * 3);
  for (let cell = 0; cell < CELLS; cell += 1) {
    const count = Math.max(1, counts[cell]);
    out[cell * 3] = sums[cell * 3] / count;
    out[cell * 3 + 1] = sums[cell * 3 + 1] / count;
    out[cell * 3 + 2] = sums[cell * 3 + 2] / count;
  }
  return out;
}

/** 区画の平均色が、台形ごとに誤差 TOLERANCE 以内で揃っているか。 */
function sameShape(left, right) {
  if (left.length !== right.length) return false;
  for (let index = 0; index < left.length; index += 1) {
    if (Math.abs(left[index] - right[index]) > TOLERANCE) return false;
  }
  return true;
}

const browser = await chromium.launch({ headless: true, ...(process.env.BDF_CHROMIUM ? { executablePath: process.env.BDF_CHROMIUM } : {}) });
let stale = 0;
try {
  const page = await browser.newPage({ viewport: { width: 1280, height: 900 }, deviceScaleFactor: 2 });
  page.setDefaultTimeout(120000);
  for (const item of GALLERY) {
    await page.goto(base + "viewer/?file=samples/" + encodeURIComponent(item.sample), { waitUntil: "domcontentloaded" });
    await page.waitForSelector("#preview canvas", { timeout: 120000 });
    await page.waitForTimeout(700);
    const shot = await page.locator("#preview canvas").first().screenshot();
    const rendered = frame(PNG.sync.read(shot));
    const bytes = PNG.sync.write(rendered);
    const target = resolve(previews, item.shot);
    if (check) {
      let same = false;
      try {
        const existing = PNG.sync.read(await readFile(target));
        same = existing.width === rendered.width && existing.height === rendered.height &&
          sameShape(signature(existing), signature(rendered));
      } catch {
        same = false;
      }
      if (!same) {
        stale += 1;
        console.log("stale " + item.shot + " (" + item.sample + ")");
      } else {
        console.log("ok    " + item.shot);
      }
    } else {
      await writeFile(target, bytes);
      console.log("wrote " + item.shot + " from " + item.sample + " (" + (bytes.length / 1024).toFixed(1) + " KB)");
    }
  }
} finally {
  await browser.close();
  server.close();
}
if (check && stale) process.exit(1);
