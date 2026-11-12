// Browser smoke for the plugin converter host: a real Chromium Worker driven
// by the upstream @bdfkit/convert Converter client, converting a synthetic
// DocuWorks file through the MoonBit binding.
//
//   node plugin/browser/plugin-smoke.mjs [--installed <dir>]
//
// Without --installed the worker imports the repository sources; with it, a
// generated second worker imports the tarball-installed package instead.

import { createServer } from "node:http";
import { existsSync, mkdirSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { extname, resolve } from "node:path";
import { chromium } from "playwright";

const root = resolve(import.meta.dirname, "../..");
const args = process.argv.slice(2);
const installedAt = args.indexOf("--installed") !== -1 ? args.at(args.indexOf("--installed") + 1) : null;

const mime = {
  ".html": "text/html",
  ".js": "text/javascript",
  ".mjs": "text/javascript",
  ".json": "application/json",
};

const allowed = [
  "/plugin/src/",
  "/plugin/browser/",
  "/plugin/test/fixture-xdw.mjs",
  "/_build/js/debug/build/plugin/moonbit/docuworks_js/",
  "/node_modules/@bdfkit/",
  "/_scratch/plugin-smoke-browser/",
];
if (installedAt) {
  const relative = installedAt.slice(root.length + 1);
  allowed.push(`/${relative}/`);
}

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

const generated = resolve(root, "_scratch/plugin-smoke-browser");
const workers = [["repository sources", "/plugin/browser/fixture/plugin-worker.mjs"]];
if (installedAt) {
  mkdirSync(generated, { recursive: true });
  const relative = installedAt.slice(root.length + 1);
  const file = resolve(generated, "plugin-worker-installed.mjs");
  writeFileSync(
    file,
    [
      `import { installPluginConverterWorker } from "/${relative}/src/worker.js";`,
      `import { moonbitDocuWorks } from "/${relative}/src/bindings/moonbit.js";`,
      `import { docuworksPlugin } from "/${relative}/src/adapters/docuworks.js";`,
      `import * as xdw from "/_build/js/debug/build/plugin/moonbit/docuworks_js/docuworks_js.js";`,
      `installPluginConverterWorker([docuworksPlugin({ delegate: moonbitDocuWorks(xdw) })]);`,
      "",
    ].join("\n"),
  );
  workers.push(["tarball-installed package", "/_scratch/plugin-smoke-browser/plugin-worker-installed.mjs"]);
}

const browser = await chromium.launch({ headless: true });
const failures = [];
try {
  const page = await browser.newPage();
  page.on("pageerror", error => failures.push(String(error)));
  await page.goto(base + "/plugin/browser/fixture/blank.html");

  for (const [label, workerUrl] of workers) {
    const result = await page.evaluate(async ({ base, workerUrl, label }) => {
      const { Converter } = await import("/node_modules/@bdfkit/convert/dist/index.js");
      const { BdfDocument, BufferSource } = await import("/node_modules/@bdfkit/core/dist/index.js");
      const { syntheticXdw } = await import("/plugin/test/fixture-xdw.mjs");
      const outcomes = [];
      const check = (name, ok, detail = "") => outcomes.push({ name: `${label}: ${name}`, ok, detail });
      const client = new Converter(new Worker(workerUrl, { type: "module" }), "");
      const formats = await client.ready;
      check(
        "ready formats",
        formats.length === 1 && formats[0].name === "xdw" &&
          JSON.stringify(formats[0].extensions) === JSON.stringify([".xdw", ".xbd"]),
        JSON.stringify(formats),
      );
      const xdw = syntheticXdw();
      const converted = await client.convert(xdw, { name: "sample.xdw" });
      check("convert format", converted.format === "xdw", converted.format);
      check("convert summary", converted.summary.includes("1 page"), converted.summary);
      const document = await BdfDocument.open(new BufferSource(converted.bdf));
      const pageView = document.manifest.views[0].pages[0];
      check(
        "convert page size",
        Math.abs(pageView.w - 595.2756) < 0.01 && Math.abs(pageView.h - 841.8898) < 0.01,
        `${pageView.w}x${pageView.h}`,
      );
      const opened = await client.open(xdw, { name: "sample.xdw" });
      check("open pages complete document", opened.pages === 0 && opened.stream === undefined, JSON.stringify({ pages: opened.pages }));
      let unknown = "";
      try {
        await client.convert(xdw, { format: "nope" });
      } catch (error) {
        unknown = error.message;
      }
      check("unknown format error", unknown === 'unknown format "nope"', unknown);
      let noMatch = "";
      let noMatchCode = "";
      try {
        await client.convert(new TextEncoder().encode("plain text"), {});
      } catch (error) {
        noMatch = error.message;
        noMatchCode = error.code ?? "";
      }
      check("no match error", noMatch === "no format matched the input", noMatch);
      check("no match code", noMatchCode === "no-format-matched", noMatchCode);
      let param = "";
      try {
        await client.convert(xdw, { format: "xdw", params: { include_hidden: "maybe" } });
      } catch (error) {
        param = error.message;
      }
      check("adapter parameter error", param === 'xdw: parameter include_hidden: "maybe" is not 0 or 1', param);
      const includeHidden = await client.convert(xdw, { format: "xdw", params: { include_hidden: "on" } });
      check("include_hidden accepted", includeHidden.format === "xdw", includeHidden.format);
      return outcomes;
    }, { base, workerUrl, label });

    for (const outcome of result) {
      console.log(`${outcome.ok ? "PASS" : "FAIL"} ${outcome.name}${outcome.ok || !outcome.detail ? "" : " :: " + outcome.detail}`);
      if (!outcome.ok) {
        failures.push(outcome.name + (outcome.detail ? ` (${outcome.detail})` : ""));
      }
    }
  }
} finally {
  await browser.close();
  server.close();
}
if (failures.length > 0) {
  throw new Error(`browser smoke failed:\n${failures.join("\n")}`);
}
console.log("plugin browser smoke passed");
