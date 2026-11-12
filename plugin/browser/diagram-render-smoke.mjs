// Browser smoke for the multi-page diagram document encoder: real Chromium
// drives BOTH sides of the contract — encodeDiagramDocument runs in the
// browser, and the produced bytes are opened and rendered by the upstream
// @bdfkit packages (core reader + @bdfkit/render's real PageRenderer), not
// by any code of this repository. The embedded images must be visible at
// the exact rectangles the image primitives placed them at, and BOTH
// accepted formats (PNG and a genuinely decodable baseline JPEG) go through
// the browser's real image decoder.
//
//   node plugin/browser/diagram-render-smoke.mjs
//
// The raster fixtures are synthetic solid-color PNGs generated from the PNG
// specification (plugin/test/synthetic-image.mjs); no real files.

import { createServer } from "node:http";
import { mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { extname, resolve } from "node:path";
import { chromium } from "playwright";

import { syntheticJpeg, syntheticPng, syntheticProgressiveJpeg } from "../test/synthetic-image.mjs";

const root = resolve(import.meta.dirname, "../..");
const RED = [220, 30, 30];
const GREEN = [20, 180, 90];
const GRAY = [128, 128, 128];

const mime = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
};

const allowed = [
  "/plugin/src/",
  "/plugin/browser/",
  "/plugin/test/synthetic-image.mjs",
  "/node_modules/@bdfkit/",
  "/_scratch/diagram-render-smoke/",
];

const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const file = resolve(root, "." + pathname);
  if (!allowed.some(prefix => file.startsWith(resolve(root, "." + prefix.replace(/\/$/, "")) + (prefix.endsWith("/") ? "/" : "")))) {
    response.writeHead(403).end();
    return;
  }
  try {
    const body = readFileSync(file);
    response.writeHead(200, { "content-type": mime[extname(file)] ?? "application/octet-stream" });
    response.end(body);
  } catch {
    response.writeHead(404).end();
  }
});

await new Promise((resolvePromise, reject) => {
  server.once("error", reject);
  server.listen(0, "127.0.0.1", resolvePromise);
});
const base = `http://127.0.0.1:${server.address().port}`;

// The import map resolves the one bare specifier of @bdfkit/render's dist
// bundle (@bdfkit/core); dist files themselves are relative imports.
const scratch = resolve(root, "_scratch/diagram-render-smoke");
mkdirSync(scratch, { recursive: true });
writeFileSync(resolve(scratch, "blank.html"), [
  "<!doctype html><title>diagram render smoke</title>",
  '<script type="importmap">',
  JSON.stringify({
    imports: {
      "@bdfkit/core": "/node_modules/@bdfkit/core/dist/index.js",
      "@bdfkit/render": "/node_modules/@bdfkit/render/dist/index.js",
    },
  }),
  "</script>",
  "",
].join("\n"));

const red = syntheticPng(16, 16, RED);
const green = syntheticPng(16, 16, GREEN);
// a genuinely decodable baseline JPEG (solid mid-gray): both accepted
// formats are exercised end to end
const grayJpeg = process.env.PROGRESSIVE_JPEG === "1" ? syntheticProgressiveJpeg() : syntheticJpeg(16, 16);

const browser = await chromium.launch({ headless: true });
const failures = [];
try {
  const page = await browser.newPage();
  page.on("pageerror", error => failures.push(String(error)));
  await page.goto(base + "/_scratch/diagram-render-smoke/blank.html");

  const result = await page.evaluate(async ({ red, green, gray, RED, GREEN, GRAY }) => {
    const bytesOf = value => Uint8Array.from(value);
    const outcomes = [];
    const check = (name, ok, detail = "") => outcomes.push({ name, ok, detail });
    const { encodeDiagramDocument } = await import("/plugin/src/diagram-bdf.js");
    const documentInput = {
      source: "render-smoke",
      title: "two pages, two images",
      pages: [
        {
          width: 300, height: 200,
          primitives: [
            { kind: "image", image: "red", x: 20, y: 20, w: 100, h: 80 },
            { kind: "image", image: "red-again", x: 150, y: 20, w: 40, h: 40, opacity: 0.5 },
          ],
        },
        {
          width: 300, height: 200,
          primitives: [
            { kind: "image", image: "green", x: 10, y: 10, w: 50, h: 60 },
            { kind: "image", image: "gray-jpeg", x: 80, y: 130, w: 50, h: 50 },
            { kind: "image", image: "red-again", x: 200, y: 60, w: 60, h: 50, angle: Math.PI / 8 },
            { kind: "rect", x: 200, y: 130, w: 60, h: 40, fill: { r: 0, g: 0, b: 0, a: 255 } },
          ],
        },
      ],
      images: [
        { id: "red", data: bytesOf(red) },
        { id: "red-again", data: bytesOf(red) }, // same content: deduplicated
        { id: "green", data: bytesOf(green) },
        { id: "gray-jpeg", data: bytesOf(gray) },
      ],
    };
    const bytes = await encodeDiagramDocument(documentInput);
    const again = await encodeDiagramDocument(documentInput);
    check("browser encoding is deterministic", bytes.length === again.length && bytes.every((byte, i) => byte === again[i]));

    const { BdfDocument, BufferSource } = await import("@bdfkit/core");
    const doc = await BdfDocument.open(new BufferSource(bytes));
    const view = doc.manifest.views[0];
    const parts = doc.manifest.parts;
    check("view is fixed with the document title", view.kind === "fixed" && view.title === "two pages, two images", JSON.stringify(view.title));
    check("view carries 2 pages", view.pages.length === 2, String(view.pages.length));
    const imgParts = parts.filter(part => part.t === "img");
    const objParts = parts.filter(part => part.t === "obj");
    check("two object parts, three image parts (deduplicated)", objParts.length === 2 && imgParts.length === 3,
      JSON.stringify(parts.map(part => part.t)));
    // the img parts' bytes are exactly the supplied rasters
    const supplied = [["red", bytesOf(red)], ["green", bytesOf(green)], ["jpeg", bytesOf(gray)]];
    const imgBytes = [];
    for (const part of imgParts) {
      imgBytes.push(new Uint8Array(await doc.part(part.h)));
    }
    for (const [id, source] of supplied) {
      const found = imgBytes.some(stored => stored.length === source.length && stored.every((byte, i) => byte === source[i]));
      check(`img part holds the actual ${id} bytes`, found, `${id}: ${source.length} bytes`);
    }
    // every image op names a real manifest img part through its table
    const tables = [];
    for (const docPage of view.pages) {
      const { decodeObject } = await import("@bdfkit/core");
      const object = decodeObject(await doc.part(docPage.layers[0].obj));
      tables.push(object.images);
      for (const hash of object.images) {
        check(`object image table names part ${hash.slice(0, 8)}`, parts.some(part => part.h === hash && part.t === "img"));
      }
    }

    // render both pages with the real PageRenderer and sample pixels
    const { PageRenderer } = await import("@bdfkit/render");
    const renderer = new PageRenderer(doc);
    const rendered = [];
    for (const index of [0, 1]) {
      const docPage = view.pages[index];
      const canvas = new OffscreenCanvas(300, 200);
      const ctx = canvas.getContext("2d");
      await renderer.renderPage(ctx, docPage, { scale: 1, background: "#ffffff" });
      const { data } = ctx.getImageData(0, 0, 300, 200);
      rendered.push(data);
    }
    renderer.dispose();
    const pixelAt = (pageData, x, y) => {
      const at = (y * 300 + x) * 4;
      return [pageData[at], pageData[at + 1], pageData[at + 2], pageData[at + 3]];
    };
    const near = (actual, [r, g, b], tolerance) =>
      Math.abs(actual[0] - r) <= tolerance && Math.abs(actual[1] - g) <= tolerance && Math.abs(actual[2] - b) <= tolerance && actual[3] === 255;
    // page 1: the opaque red image fills its rectangle
    check("page 1 shows the red image inside its rectangle", near(pixelAt(rendered[0], 70, 60), RED, 4),
      JSON.stringify(pixelAt(rendered[0], 70, 60)));
    check("page 1 shows the half-transparent red too", near(pixelAt(rendered[0], 170, 40),
      [255 - (255 - RED[0]) * 0.5, 255 - (255 - RED[1]) * 0.5, 255 - (255 - RED[2]) * 0.5], 6),
      JSON.stringify(pixelAt(rendered[0], 170, 40)));
    check("page 1 keeps the background white outside images", near(pixelAt(rendered[0], 5, 190), [255, 255, 255], 1),
      JSON.stringify(pixelAt(rendered[0], 5, 190)));
    // page 2: the green image, the rotated red image and the black rect
    check("page 2 shows the green image inside its rectangle", near(pixelAt(rendered[1], 35, 40), GREEN, 4),
      JSON.stringify(pixelAt(rendered[1], 35, 40)));
    check("page 2 shows the rotated red image", near(pixelAt(rendered[1], 240, 90), RED, 6),
      JSON.stringify(pixelAt(rendered[1], 240, 90)));
    check("page 2 shows the decodable gray JPEG at its rectangle", near(pixelAt(rendered[1], 105, 155), GRAY, 2),
      JSON.stringify(pixelAt(rendered[1], 105, 155)));
    check("page 2 shows the black rect", near(pixelAt(rendered[1], 230, 150), [0, 0, 0], 4),
      JSON.stringify(pixelAt(rendered[1], 230, 150)));
    return outcomes;
  }, { red: Array.from(red), green: Array.from(green), gray: Array.from(grayJpeg), RED, GREEN, GRAY });

  for (const outcome of result) {
    console.log(`${outcome.ok ? "PASS" : "FAIL"} ${outcome.name}${outcome.ok || !outcome.detail ? "" : " :: " + outcome.detail}`);
    if (!outcome.ok) {
      failures.push(outcome.name + (outcome.detail ? ` (${outcome.detail})` : ""));
    }
  }
} finally {
  await browser.close();
  server.close();
}
if (failures.length > 0) {
  throw new Error(`diagram render smoke failed:\n${failures.join("\n")}`);
}
console.log("diagram render smoke passed");
