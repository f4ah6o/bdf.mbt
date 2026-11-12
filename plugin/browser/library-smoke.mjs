// Browser smoke for the staged main library package (`bdf.mbt`): four real
// Chromium module Workers and the served PDF export path, all from the
// tarball-installed package; the converter Workers are driven by the
// upstream @bdfkit/convert Converter client:
//
//   1. the shipped native converter Worker — the 24 builtin formats,
//      including the builtin DocuWorks converter;
//   2. the shipped prebuilt plugin Worker — the format plugin API with the
//      DocuWorks builtin and the diagram adapters;
//   3. a generated downstream demo Worker — a third-party plugin the
//      consumer writes, registered next to the shipped DocuWorks adapter
//      without patching the registry or replacing the builtins;
//   4. the public PDF export entry — the served package path a browser
//      consumer imports;
//   5. the shipped render Worker client — the sheetClipboard extension
//      must ship in the installed dist with its merged-cell fix intact.
//
//   node plugin/browser/library-smoke.mjs [--installed <dir>]
//
// The demo Worker is generated into _scratch (it is test scaffolding owned by
// the consumer, not package content); everything it imports is inside the
// installed package.

import { createServer } from "node:http";
import { existsSync, readFileSync } from "node:fs";
import { extname, resolve } from "node:path";
import { chromium } from "playwright";

const root = resolve(import.meta.dirname, "../..");
const args = process.argv.slice(2);
const installedAt = args.indexOf("--installed") !== -1 ? args.at(args.indexOf("--installed") + 1) : null;
if (!installedAt) {
  throw new Error("library smoke needs --installed <dir> (run plugin/tools/library-smoke.mjs)");
}
// The downstream demo Worker is the exact file the packaged
// emit-downstream-worker tool produced from the README's zine plugin module
// (--emitted-worker); the browser must drive it unchanged.
const emittedWorker = args.indexOf("--emitted-worker") !== -1 && args.at(args.indexOf("--emitted-worker") + 1)
  ? args.at(args.indexOf("--emitted-worker") + 1)
  : null;
if (!emittedWorker) {
  throw new Error("library smoke needs --emitted-worker <file> produced by the shipped emitter");
}
const emittedWorkerUrl = `/_scratch/library-smoke-browser/${emittedWorker.split("/").pop()}`;
const relative = installedAt.slice(root.length + 1);

const mime = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
};

const allowed = [
  "/node_modules/@bdfkit/",
  "/plugin/browser/fixture/blank.html",
  "/plugin/test/fixture-xdw.mjs",
  "/_scratch/library-smoke-browser/",
];
if (installedAt) {
  allowed.push(`/${installedAt.slice(root.length + 1)}/`);
}
const allowedPaths = allowed.map(prefix => resolve(root, "." + prefix.replace(/\/$/, "")));

const server = createServer((request, response) => {
  const pathname = decodeURIComponent(new URL(request.url, "http://localhost").pathname);
  const file = resolve(root, "." + pathname);
  if (!allowedPaths.some(base => file === base || file.startsWith(base + "/"))) {
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

// The downstream Worker is the README recipe's output: emitted by the tool
// that ships inside the tarball (library-smoke.mjs ran it against the
// installed package), from the zine plugin module documented in the README.
// Nothing is hand-written here.

const browser = await chromium.launch({ headless: true });
const failures = [];
const requested = [];
try {
  const page = await browser.newPage();
  page.on("pageerror", error => failures.push(String(error)));
  page.on("request", request => requested.push(request.url()));
  await page.goto(base + "/plugin/browser/fixture/blank.html");

  // The fallback font the expected-consuming test passes: the repository's
  // own OFL-licensed test font, handed to the page the way a consumer
  // hands their licensed font — the package never fetches one.
  const fontB64 = readFileSync(resolve(root, "site/form/fonts/MPLUS1p-Regular.ttf")).toString("base64");
  // The synthetic merged-span sheet fixture (compat/sheet/merge.bdf): its
  // A1:Z1 merge keeps its text in tile (0,0) while the selected Y1 is seven
  // tiles away, so a package that loses the render Worker, the client
  // method or the merged-cell fix fails the clipboard check below.
  const mergeB64 = readFileSync(resolve(root, "compat/sheet/merge.bdf")).toString("base64");

  const result = await page.evaluate(async ({ base, relative, emittedWorkerUrl, fontB64, mergeB64 }) => {
    // The shipped client from the installed package's root export — the exact
    // surface the README documents. @bdfkit/core is not part of the recipe;
    // it is used here only to verify the returned BDF bytes' shape.
    const { bdf_create_native_converter } = await import(`/${relative}/dist/browser.js`);
    const { BdfDocument, BufferSource } = await import("/node_modules/@bdfkit/core/dist/index.js");
    const { syntheticXdw } = await import("/plugin/test/fixture-xdw.mjs");
    const outcomes = [];
    const check = (name, ok, detail = "") => outcomes.push({ name, ok, detail });

    const xdw = syntheticXdw();
    const zine = new Uint8Array([0x5a, 0x49, 0x4e, 0x45, 0x01, 0x02, 0x03, 0x04]);

    // 1) the shipped native converter Worker: builtin formats, builtin xdw
    const nativeClient = bdf_create_native_converter(`/${relative}/dist/workers/native_converter_worker.js`);
    const nativeNames = (await nativeClient.ready).map(format => format.name).sort();
    check(
      "native: 24 builtin formats",
      nativeNames.length === 24 && ["csv", "pdf", "xdw", "parquet"].every(name => nativeNames.includes(name)),
      JSON.stringify(nativeNames),
    );
    const nativeConverted = await nativeClient.convert(xdw, { name: "sample.xdw" });
    check("native: builtin xdw format", nativeConverted.format === "xdw", nativeConverted.format);
    const nativeDocument = await BdfDocument.open(new BufferSource(nativeConverted.bdf));
    const nativePage = nativeDocument.manifest.views[0].pages[0];
    check(
      "native: builtin xdw page size",
      Math.abs(nativePage.w - 595.2756) < 0.01 && Math.abs(nativePage.h - 841.8898) < 0.01,
      `${nativePage.w}x${nativePage.h}`,
    );

    // 2) the shipped prebuilt plugin Worker: the DocuWorks builtin adapter
    //    and the two diagram adapters
    const pluginClient = bdf_create_native_converter(`/${relative}/dist/workers/plugin-converter.mjs`);
    const pluginFormats = await pluginClient.ready;
    check(
      "plugin worker: the docuworks, excalidraw and mermaid adapters registered",
      JSON.stringify(pluginFormats.map(format => format.name).sort())
        === JSON.stringify(["excalidraw", "mermaid", "xdw"]),
      JSON.stringify(pluginFormats.map(format => format.name)),
    );
    const pluginConverted = await pluginClient.convert(xdw, { name: "sample.xdw" });
    check("plugin worker: docuworks convert", pluginConverted.format === "xdw", pluginConverted.format);
    const pluginDocument = await BdfDocument.open(new BufferSource(pluginConverted.bdf));
    const pluginPage = pluginDocument.manifest.views[0].pages[0];
    check(
      "plugin worker: docuworks page size",
      Math.abs(pluginPage.w - 595.2756) < 0.01 && Math.abs(pluginPage.h - 841.8898) < 0.01,
      `${pluginPage.w}x${pluginPage.h}`,
    );
    const opened = await pluginClient.open(xdw, { name: "sample.xdw" });
    check("plugin worker: open of a complete document", opened.pages === 0 && opened.stream === undefined,
      JSON.stringify({ pages: opened.pages }));
    let unknownFormat = "";
    try {
      await pluginClient.convert(xdw, { format: "nope" });
    } catch (error) {
      unknownFormat = error.message;
    }
    check("plugin worker: unknown format still errors", unknownFormat === 'unknown format "nope"', unknownFormat);
    // the shipped diagram adapters convert through the same worker envelope
    const excalidrawScene = new TextEncoder().encode(
      JSON.stringify({ type: "excalidraw", elements: [
        { id: "r1", type: "rectangle", x: 0, y: 0, width: 120, height: 60 },
      ] }),
    );
    const excalidrawConverted = await pluginClient.convert(excalidrawScene, { name: "scene.excalidraw" });
    check(
      "plugin worker: excalidraw scene converts",
      excalidrawConverted.format === "excalidraw",
      JSON.stringify({ format: excalidrawConverted.format, summary: excalidrawConverted.summary }),
    );
    const mermaidText = new TextEncoder().encode("flowchart TD\n  a[Start] --> b[Done]\n");
    const mermaidConverted = await pluginClient.convert(mermaidText, { name: "flow.mmd" });
    check(
      "plugin worker: mermaid flowchart converts",
      mermaidConverted.format === "mermaid",
      JSON.stringify({ format: mermaidConverted.format, summary: mermaidConverted.summary }),
    );

    // 3) the downstream demo Worker: a third-party plugin next to the builtin
    const downstreamClient = bdf_create_native_converter(emittedWorkerUrl);
    const downstreamFormats = (await downstreamClient.ready).map(format => format.name).sort();
    check(
      "downstream: third-party plugin next to the docuworks builtin",
      JSON.stringify(downstreamFormats) === JSON.stringify(["xdw", "zine"]),
      JSON.stringify(downstreamFormats),
    );
    const zineConverted = await downstreamClient.convert(zine, { name: "demo.zine" });
    check("downstream: third-party format converts", zineConverted.format === "zine", zineConverted.format);
    check(
      "downstream: third-party summary",
      zineConverted.summary.startsWith("zine:") && zineConverted.warnings.length === 1,
      JSON.stringify(zineConverted),
    );
    const docuworksThroughDownstream = await downstreamClient.convert(xdw, { name: "sample.xdw" });
    check(
      "downstream: shipped docuworks adapter still converts",
      docuworksThroughDownstream.format === "xdw",
      docuworksThroughDownstream.format,
    );
    const downstreamDocument = await BdfDocument.open(new BufferSource(docuworksThroughDownstream.bdf));
    const downstreamPage = downstreamDocument.manifest.views[0].pages[0];
    check(
      "downstream: shipped docuworks page size",
      Math.abs(downstreamPage.w - 595.2756) < 0.01 && Math.abs(downstreamPage.h - 841.8898) < 0.01,
      `${downstreamPage.w}x${downstreamPage.h}`,
    );
    let collision = "";
    try {
      await downstreamClient.convert(xdw, { format: "nope" });
    } catch (error) {
      collision = error.message;
    }
    check("downstream: unknown format still errors", collision === 'unknown format "nope"', collision);

    // all three hosts answered while alive at once: no cross-talk
    const parallel = await Promise.all([
      nativeClient.convert(xdw, { name: "sample.xdw" }),
      pluginClient.convert(xdw, { name: "sample.xdw" }),
      downstreamClient.convert(zine, { name: "demo.zine" }),
    ]);
    check(
      "coexistence: three worker hosts answer in parallel",
      parallel.map(result => result.format).join(",") === "xdw,xdw,zine",
      parallel.map(result => result.format).join(","),
    );

    // 4) the public PDF export entry: the served package path a browser
    //    consumer imports, run on the BDF the native Worker converted.
    //    The save (a Blob download) stays the caller's job; here the bytes
    //    only come back to the page.
    const { exportPdf } = await import(`/${relative}/dist/pdf/index.js`);
    const fontBytes = Uint8Array.from(atob(fontB64), ch => ch.charCodeAt(0));
    const exportResult = await exportPdf(new Uint8Array(nativeConverted.bdf), {
      fallbackFont: fontBytes,
    });
    const header = new TextDecoder("latin1").decode(exportResult.bytes.slice(0, 5));
    check(
      "pdf: exportPdf of the converted document writes a one-page PDF",
      exportResult.bytes instanceof Uint8Array && header === "%PDF-" && exportResult.pages === 1,
      JSON.stringify({ header, pages: exportResult.pages }),
    );
    check(
      "pdf: the report carries the fonts count and the warnings array",
      exportResult.fonts >= 1 && Array.isArray(exportResult.warnings),
      JSON.stringify({ fonts: exportResult.fonts, warnings: exportResult.warnings }),
    );
    const again = await exportPdf(new Uint8Array(nativeConverted.bdf), {
      fallbackFont: fontBytes,
    });
    check(
      "pdf: the export is deterministic in the browser",
      again.bytes.length === exportResult.bytes.length &&
        again.pages === exportResult.pages && again.fonts === exportResult.fonts,
      `lengths ${again.bytes.length} / ${exportResult.bytes.length}`,
    );
    let pdfTypeError = "";
    try {
      await exportPdf("not bytes");
    } catch (error) {
      pdfTypeError = error instanceof TypeError ? "TypeError" : error.constructor.name;
    }
    check("pdf: exportPdf rejects a wrong input type", pdfTypeError === "TypeError", pdfTypeError);

    // 5) the shipped render Worker client: the sheetClipboard extension must
    //    ship in the installed dist. Far Y1 sits inside the A1:Z1 merge whose
    //    anchor is seven tiles away, so the clipboard answer proves both the
    //    client method and the merged-cell tile-table resolution arrived.
    const { bdf_render_worker_client } = await import(`/${relative}/dist/browser.js`);
    const sheetClient = bdf_render_worker_client(
      new Worker(`/${relative}/dist/workers/render_worker.js`, { type: "module" }),
    );
    const mergeBytes = Uint8Array.from(atob(mergeB64), ch => ch.charCodeAt(0));
    await sheetClient.open({ kind: "buffer", buffer: mergeBytes.buffer });
    const farCell = await sheetClient.sheetClipboard("cells", { row0: 0, col0: 24, row1: 0, col1: 24 });
    check(
      'sheet: far Y1 inside the A1:Z1 merge copies TSV "Long merged"',
      farCell.text === "Long merged",
      JSON.stringify(farCell),
    );
    check(
      "sheet: far Y1 inside the A1:Z1 merge copies the merged cell HTML",
      farCell.html === '<meta charset="utf-8"><table><tr><td>Long merged</td></tr></table>',
      farCell.html,
    );
    sheetClient.terminate();

    for (const client of [nativeClient, pluginClient, downstreamClient]) {
      client.terminate();
    }
    return outcomes;
  }, { base, relative, emittedWorkerUrl, fontB64, mergeB64 });

  for (const outcome of result) {
    console.log(`${outcome.ok ? "PASS" : "FAIL"} ${outcome.name}${outcome.ok || !outcome.detail ? "" : " :: " + outcome.detail}`);
    if (!outcome.ok) {
      failures.push(outcome.name + (outcome.detail ? ` (${outcome.detail})` : ""));
    }
  }
  // No fetch of the whole run left the local test server: network recording
  // the page asked nothing behind its back — no CDN fonts, no telemetry.
  for (const url of new Set(requested)) {
    if (!url.startsWith(base + "/")) {
      failures.push(`unexpected external request during the browser smoke: ${url}`);
    }
  }
} finally {
  await browser.close();
  server.close();
}
if (failures.length > 0) {
  throw new Error(`library browser smoke failed:\n${failures.join("\n")}`);
}
console.log("library browser smoke passed");
