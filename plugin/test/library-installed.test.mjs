// Tests against the tarball-installed copy of the main library package
// (`bdf.mbt`), not the repo source. Enabled by pointing BDF_LIBRARY_INSTALLED
// at the installed package directory and BDF_LIBRARY_ADAPTER at the Node
// `self` adapter script (see plugin/tools/library-smoke.mjs); without them
// the tests skip so the plain unit suite never depends on packing.
//
// Everything here consumes only artifacts that shipped inside the tarball:
// the plugin API sources, the DocuWorks bundle and the two prebuilt Worker
// scripts. No _build path, no repository source.

import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { existsSync, readFileSync, readdirSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";
import { Worker } from "node:worker_threads";

const root = resolve(import.meta.dirname, "../..");
const installed = process.env.BDF_LIBRARY_INSTALLED;
const adapter = process.env.BDF_LIBRARY_ADAPTER;
const name = process.env.BDF_LIBRARY_STAGING_NAME ?? "bdf.mbt";

if (!installed || !adapter) {
  test("installed library tarball smoke (skipped: no BDF_LIBRARY_INSTALLED)", { skip: true }, () => {});
} else {
  const manifest = await import(`${installed}/package.json`, { with: { type: "json" } }).then(m => m.default);

  test("the installed library is the staged, publication-blocked artifact", () => {
    assert.equal(manifest.name, name);
    assert.equal(manifest.private, true, "the staged library must keep private: true");
    assert.deepEqual(
      Object.keys(manifest.exports).sort(),
      [".", "./forms", "./plugin", "./plugin/adapters/docuworks",
        "./plugin/adapters/excalidraw", "./plugin/adapters/mermaid",
        "./plugin/diagram-bdf", "./plugin/worker",
        "./tools/emit-downstream-worker", "./workers/native", "./workers/plugin",
        "./workers/render", "./xdw"].sort(),
    );
    assert.equal(manifest.types, "./dist/browser.d.ts");
  });

  test("the installed tarball ships the compiled-dependency license audit", () => {
    // The notice set was derived from the bundles' actual link inputs, not
    // from a hand list: every package compiled into the shipped JavaScript
    // must have a license text on disk and an attribution line in NOTICE.md.
    const expectedLicenses = [
      "Shibukawa-bdf.txt",
      "EZPZFile-xdw.txt",
      "Go-x-image.txt",
      "Go-x-text.txt",
      "WHATWG-Encoding.txt",
      "Adobe-CMap.txt",
      "Cephes.txt",
      "Apache-2.0.txt",
      "Mooncake-gaato-zstd-NOTICE.txt",
      "Brotli-dictionary-MIT.txt",
      "Mooncake-yaml-MIT.txt",
      "Mooncake-moonmarkdown-MIT.txt",
      "Mooncake-moonmarkdown-THIRD-PARTY-NOTICES.txt",
      "Mooncake-moon-encoding-WHATWG.txt",
      "MoonBit-core-NOTICE.txt",
    ];
    assert.deepEqual(
      readdirSync(resolve(installed, "licenses")).sort(),
      expectedLicenses.slice().sort(),
      "licenses/ must contain exactly the audited notice files",
    );
    const notice = readFileSync(resolve(installed, "NOTICE.md"), "utf8");
    for (const pkg of [
      "gaato/deflate",
      "gaato/brotli",
      "gaato/zstd",
      "gaato/codec",
      "Milky2018/xml",
      "LL728/moon_encoding",
      "moonbit-community/normalization",
      "moonbit-community/ucd",
      "moonbit-community/yaml",
      "allenli178/moon-qrcode",
      "moonbitlang/async",
      "moonbitlang/x",
      "moonbitlang/core",
      "oilleelssq-wq/moonmarkdown",
    ]) {
      assert.ok(notice.includes(pkg), `NOTICE.md must attribute ${pkg}`);
    }
  });

  test("the shipped API reference doc is usable inside the package", () => {
    // The packed copy: docs/format-plugin-api.md sits next to the package
    // root, its quickstart link resolves within the installed package, and
    // the import examples it documents remain valid export-map entries.
    const readme = readFileSync(resolve(installed, "README.md"), "utf8");
    assert.ok(readme.includes("](docs/format-plugin-api.md)"),
      "the library README must link the shipped API doc");
    for (const docFile of ["docs/format-plugin-api.md", "docs/diagram-plugins.md"]) {
      const docPath = resolve(installed, docFile);
      assert.ok(existsSync(docPath), `${docFile} must ship in the tarball`);
    }
    const doc = readFileSync(resolve(installed, "docs/format-plugin-api.md"), "utf8");
    // the source tree's link was rewritten for the packed layout
    assert.ok(!doc.includes("(../plugin/library/README.md)"),
      "the packed copy must not keep the source tree's relative link");
    assert.ok(doc.includes("](../README.md)"),
      "the packed copy's quickstart link must target the package root README");
    assert.ok(existsSync(resolve(installed, "README.md")), "the link target must exist");
    // the packed README's doc links were rewritten for the package layout
    assert.ok(!readme.includes("](../../docs/"),
      "the packed README must not keep the source tree's ../../docs links");
    const diagramDoc = readFileSync(resolve(installed, "docs/diagram-plugins.md"), "utf8");
    for (const internal of ["worktree", "subagent", "parent merge", "read-only symlink", "coordinator"]) {
      assert.ok(!diagramDoc.toLowerCase().includes(internal),
        `the shipped diagram doc must not describe internal coordination (${internal})`);
    }
    // every bdf.mbt import specifier the docs show is a real export entry
    const exportKeys = new Set(Object.keys(manifest.exports));
    for (const [label, text] of [["README.md", readme], ["docs/format-plugin-api.md", doc], ["docs/diagram-plugins.md", diagramDoc]]) {
      const matches = [...text.matchAll(/from "bdf\.mbt(\/[a-z0-9/._-]*)?"/g)];
      assert.ok(matches.length > 0,
        `the shipped ${label} must show bdf.mbt imports (found none)`);
      for (const match of matches) {
        const specifier = "bdf.mbt" + (match[1] ?? "");
        const key = match[1] === undefined ? "." : "." + match[1];
        assert.ok(exportKeys.has(key), `the docs' import "${specifier}" must be an export entry`);
      }
    }
    // the doc claims the api version the shipped modules implement
    assert.ok(doc.includes("plugin API version 1"), "the doc describes plugin API version 1");
  });

  test("the shipped diagram modules compose with the other plugins", async () => {
    const diagramEncoder = await import(`${installed}/dist/plugin/diagram-bdf.js`);
    const { excalidrawPlugin } = await import(`${installed}/dist/plugin/adapters/excalidraw.js`);
    const { mermaidPlugin } = await import(`${installed}/dist/plugin/adapters/mermaid.js`);
    assert.equal(typeof diagramEncoder.encodeDiagram, "function");
    assert.equal(typeof diagramEncoder.DiagramEncodeError, "function");
    const api = await import(`${installed}/dist/plugin/index.js`);
    const registry = api.createFormatRegistry({
      plugins: [excalidrawPlugin(), mermaidPlugin()],
    });
    assert.deepEqual(
      registry.formats().map(format => format.name).sort(),
      ["excalidraw", "mermaid"],
    );
    // both diagram descriptors register cleanly next to the docuworks builtin
    const composed = api.createFormatRegistry({
      plugins: [api.docuworksPlugin({ delegate: { detect: () => false, convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }) } }),
        excalidrawPlugin(), mermaidPlugin()],
    });
    assert.equal(composed.formats().length, 3);
  });

  const api = await import(`${installed}/dist/plugin/index.js`);
  const { syntheticXdw } = await import("./fixture-xdw.mjs");
  const { BdfDocument, BufferSource } = await import("@bdfkit/core");

  test("the shipped plugin API exports the versioned contract", () => {
    assert.equal(api.FORMAT_PLUGIN_API_VERSION, 1);
    for (const exportName of ["createFormatRegistry", "createConverterHost", "docuworksPlugin",
      "moonbitDocuWorks", "defineFormatPlugin", "PluginError", "ConvertError"]) {
      assert.equal(typeof api[exportName], "function", exportName);
    }
  });

  const xdw = await import(`${installed}/dist/xdw/docuworks_js.js`);

  test("the shipped DocuWorks bundle detects and converts in Node", () => {
    assert.equal(typeof xdw.bdf_xdw_detect, "function");
    assert.equal(xdw.bdf_xdw_detect(syntheticXdw()), true);
    assert.equal(xdw.bdf_xdw_detect(new Uint8Array([1, 2, 3])), false);
  });

  test("the shipped binding converts through the shipped plugin API stack", async () => {
    const registry = api.createFormatRegistry({
      plugins: [api.docuworksPlugin({ delegate: api.moonbitDocuWorks(xdw) })],
    });
    assert.deepEqual(
      registry.formats().map(format => format.name),
      ["xdw"],
    );
    // convert through the adapter's delegate directly: no host needed
    const delegate = api.moonbitDocuWorks(xdw);
    const converted = await delegate.convert(syntheticXdw(), { name: "sample.xdw" });
    const document = await BdfDocument.open(new BufferSource(converted.bdf));
    const page = document.manifest.views[0].pages[0];
    assert.ok(
      Math.abs(page.w - 595.2756) < 0.01 && Math.abs(page.h - 841.8898) < 0.01,
      `page ${page.w}x${page.h}`,
    );
  });

  ///|
  // Drive the shipped Worker scripts through a `self` adapter: the MoonBit
  // worker bundles speak self.postMessage/self.onmessage, which the browser
  // provides and Node worker_threads does not, so the adapter is the one
  // piece of glue a Node consumer writes. It also reports module load, so
  // a bundle that fails to import is distinguishable from silence.
  function runWorker(moduleUrl, requests = []) {
    return new Promise((resolve, reject) => {
      const worker = new Worker(adapter, {
        type: "module",
        env: { ...process.env, BDF_WORKER_MODULE: moduleUrl },
      });
      const answers = [];
      let loaded = false;
      let index = 0;
      const deadline = Date.now() + 30000;
      const done = () => loaded && answers.length >= requests.length;
      const sendNext = () => {
        if (loaded && index < requests.length) {
          worker.postMessage(requests[index]);
          index += 1;
        }
      };
      const timer = setInterval(() => {
        if (done() || Date.now() > deadline) {
          clearInterval(timer);
          worker.terminate();
          if (done()) {
            resolve(answers);
          } else {
            reject(new Error(
              `timed out in ${loaded ? "conversation" : "module load"} with ${answers.length}/${requests.length} answers`,
            ));
          }
        }
      }, 50);
      worker.on("message", answer => {
        if (answer?.type === "bdf-adapter-loaded") {
          loaded = true;
        } else {
          answers.push(answer);
        }
        sendNext();
      });
      worker.on("error", error => {
        clearInterval(timer);
        reject(error);
      });
      worker.on("exit", code => {
        if (code !== 0 && !done()) {
          reject(new Error(`worker exited with ${code}`));
        }
      });
    });
  }

  test("the shipped prebuilt plugin Worker converts in Node", async () => {
    const file = syntheticXdw();
    const scene = new TextEncoder().encode(
      JSON.stringify({ type: "excalidraw", elements: [
        { id: "r1", type: "rectangle", x: 0, y: 0, width: 120, height: 60 },
        { id: "t1", type: "text", x: 10, y: 16, text: "hello scene" },
      ] }),
    );
    const flowchart = new TextEncoder().encode("flowchart TD\n  a[Start] --> b[Done]\n");
    const [formatsReply, convertReply, openReply, badReply, excalidrawReply, mermaidReply] = await runWorker(
      `${installed}/dist/workers/plugin-converter.mjs`,
      [
        { type: "init" },
        { id: 1, type: "convert", data: file.buffer.slice(0), options: { name: "sample.xdw" } },
        { id: 2, type: "open", data: file.buffer.slice(0), options: { name: "sample.xdw" } },
        { id: 3, type: "convert", data: new Uint8Array(64).buffer, options: { name: "broken.xdw" } },
        { id: 4, type: "convert", data: scene.buffer.slice(0), options: { name: "scene.excalidraw" } },
        { id: 5, type: "convert", data: flowchart.buffer.slice(0), options: { name: "flow.mmd" } },
      ],
    );
    assert.equal(formatsReply.id, 0);
    assert.equal(formatsReply.ok, true);
    const formats = Object.fromEntries(
      formatsReply.formats.map(format => [format.name, format]),
    );
    assert.deepEqual(
      formatsReply.formats.map(format => format.name).sort(),
      ["excalidraw", "mermaid", "xdw"],
      "the prebuilt worker ships the DocuWorks builtin and both diagram plugins",
    );
    assert.deepEqual(
      formats.excalidraw.extensions.sort(),
      [".excalidraw", ".excalidraw.json"].sort(),
    );
    assert.deepEqual(formats.mermaid.extensions.sort(), [".mmd", ".mermaid"].sort());
    assert.equal(convertReply.id, 1);
    assert.equal(convertReply.ok, true, convertReply.error);
    assert.equal(convertReply.result.format, "xdw");
    const document = await BdfDocument.open(new BufferSource(convertReply.result.bdf));
    const page = document.manifest.views[0].pages[0];
    assert.ok(Math.abs(page.w - 595.2756) < 0.01 && Math.abs(page.h - 841.8898) < 0.01,
      `page ${page.w}x${page.h}`);
    assert.equal(openReply.ok, true);
    assert.equal(openReply.result.pages, 0, "the synthetic file is a complete document");
    assert.equal(openReply.result.stream, undefined);
    assert.equal(badReply.ok, false);
    assert.match(badReply.error, /XdwNotFile/);
    // the shipped diagram adapters convert through the same worker envelope
    assert.equal(excalidrawReply.id, 4);
    assert.equal(excalidrawReply.ok, true, excalidrawReply.error);
    assert.equal(excalidrawReply.result.format, "excalidraw");
    const excalidrawDocument = await BdfDocument.open(new BufferSource(excalidrawReply.result.bdf));
    assert.ok(excalidrawDocument.manifest.views.length > 0, "the scene encodes a real BDF document");
    assert.equal(mermaidReply.id, 5);
    assert.equal(mermaidReply.ok, true, mermaidReply.error);
    assert.equal(mermaidReply.result.format, "mermaid");
    const mermaidDocument = await BdfDocument.open(new BufferSource(mermaidReply.result.bdf));
    assert.ok(mermaidDocument.manifest.views.length > 0, "the flowchart encodes a real BDF document");
  });

  test("the shipped native converter Worker keeps all builtin formats in Node", async () => {
    const [formatsReply, convertReply] = await runWorker(
      `${installed}/dist/workers/native_converter_worker.js`,
      [
        { type: "init" },
        { id: 1, type: "convert", data: syntheticXdw().buffer.slice(0), options: { name: "sample.xdw" } },
      ],
    );
    assert.equal(formatsReply.id, 0);
    assert.equal(formatsReply.ok, true);
    const names = formatsReply.formats.map(format => format.name);
    assert.equal(names.length, 24, `expected the 24 builtin formats, got ${names.length}`);
    for (const builtin of ["csv", "pdf", "image", "xdw", "parquet"]) {
      assert.ok(names.includes(builtin), `builtin ${builtin} is missing`);
    }
    assert.equal(convertReply.ok, true, convertReply.error);
    assert.equal(convertReply.result.format, "xdw", "the native builtin converts DocuWorks too");
    assert.equal(typeof convertReply.result.bdf.byteLength, "number");
  });

  test("the shipped render Worker self-installs from the tarball", async () => {
    // The render bundle installs itself at import (like the native Worker);
    // a clean module load inside the self adapter proves the shipped file
    // imports and self-installs without a browser. A load or eval crash
    // rejects this promise instead of passing silently.
    await runWorker(`${installed}/dist/workers/render_worker.js`);
  });

  ///|
  // The exported MoonBit surfaces of the browser and form bundles: these are
  // what the "." and "./forms" export maps hand consumers. They import clean
  // in Node; the DOM is only needed when the functions are called.
  test("the shipped browser bundle exports the viewer surface", async () => {
    const browser = await import(`${installed}/dist/browser.js`);
    assert.ok(Object.keys(browser).length >= 40, `expected the full viewer surface, got ${Object.keys(browser).length}`);
    for (const exportName of ["mount_bdf_split_async", "Viewer", "bdf_create_render_worker",
      "bdf_selection_text", "unmount_bdf", "encrypt_bdf_password"]) {
      assert.equal(typeof browser[exportName], "function", exportName);
    }
    assert.equal(typeof browser.bdf_create_native_converter, "function");
  });

  test("the shipped form bundle describes and fills a public template", async () => {
    const { readFile } = await import("node:fs/promises");
    const form = await import(`${installed}/dist/form/form_page.js`);
    for (const exportName of ["bdf_form_describe", "bdf_form_fill", "bdf_form_compile"]) {
      assert.equal(typeof form[exportName], "function", exportName);
    }
    const template = new Uint8Array(
      await readFile(new URL("../../site/form/samples/form-fixed.xlsx", import.meta.url)),
    );
    const described = JSON.parse(form.bdf_form_describe(template, ""));
    assert.equal(described.ok, true, described.error);
    const data = new TextDecoder().decode(
      await readFile(new URL("../../site/form/samples/form-fixed.json", import.meta.url)),
    );
    const filled = JSON.parse(form.bdf_form_fill(template, data, "[]", false));
    assert.equal(filled.ok, true, filled.error);
    assert.ok(typeof filled.bdf === "string" && filled.bdf.length > 0, "expected a filled BDF payload");
  });

  test("every documented export specifier resolves, and nothing else does", () => {
    // Runs where node_modules/bdf.mbt lives, exactly as a consumer would:
    // the exports map is the resolution gate. The reviewer's failing form
    // (a raw "dist" path, such as new URL("bdf.mbt/dist/browser.js")) must
    // be refused; the documented entries must all resolve. Consumer
    // specifiers are "bdf.mbt/forms" etc. — the exports map keys carry the
    // leading dot, the import specifier does not.
    const consumerDir = resolve(installed, "..", "..");
    const subpaths = ["", "/forms", "/xdw", "/plugin", "/plugin/worker",
      "/plugin/diagram-bdf", "/plugin/adapters/docuworks",
      "/plugin/adapters/excalidraw", "/plugin/adapters/mermaid",
      "/tools/emit-downstream-worker",
      "/workers/plugin", "/workers/render", "/workers/native"];
    const probe = `
      const packageName = "bdf.mbt";
      const subpaths = [${subpaths.map(sp => JSON.stringify(sp)).join(", ")}];
      for (const subpath of subpaths) {
        import.meta.resolve(packageName + subpath);
      }
      try {
        import.meta.resolve("bdf.mbt/dist/browser.js");
        throw new Error("an undocumented raw dist path exports: dist/browser.js");
      } catch (error) {
        if (!String(error).includes("ERR_PACKAGE_PATH_NOT_EXPORTED")) {
          throw error;
        }
      }
      console.log("resolved " + subpaths.length + " documented entries");
    `;
    const run = spawnSync("node", ["--input-type=module", "-e", probe], {
      cwd: consumerDir,
      encoding: "utf8",
    });
    assert.equal(run.status, 0, `resolution probe failed:\n${run.stdout}\n${run.stderr}`);
    assert.match(run.stdout, /resolved 13 documented entries/);
  });

  test("the shipped type declarations cover the documented plugin imports", () => {
    // The README's imports, type-checked with tsc against the installed
    // tarball only — the declarations it ships must describe every entry,
    // including the worker installer both worker export paths point at.
    const consumerDir = resolve(installed, "..", "..");
    writeFileSync(
      resolve(consumerDir, "consumer-typecheck.ts"),
      [
        'import { createFormatRegistry, createConverterHost, docuworksPlugin as docuworksFromRoot, moonbitDocuWorks } from "bdf.mbt/plugin";',
        'import { installPluginConverterWorker } from "bdf.mbt/plugin/worker";',
        'import { docuworksPlugin, DOCUWORKS_FORMAT_NAME } from "bdf.mbt/plugin/adapters/docuworks";',
        'import { excalidrawPlugin, EXCALIDRAW_FORMAT_NAME } from "bdf.mbt/plugin/adapters/excalidraw";',
        'import { mermaidPlugin, MERMAID_FORMAT_NAME } from "bdf.mbt/plugin/adapters/mermaid";',
        'import { encodeDiagram, DiagramEncodeError, DiagramPrimitive } from "bdf.mbt/plugin/diagram-bdf";',
        'import { bdf_xdw_detect } from "bdf.mbt/xdw";',
        "// negative assertions: each entry exposes exactly its runtime module,",
        "// so cross-entry imports that do not exist at runtime must fail",
        "// type-checking (unused @ts-expect-error is itself an error, so",
        "// these flip the moment a wrong export appears)",
        "// @ts-expect-error installPluginConverterWorker lives in the worker entry, not the root",
        'import { installPluginConverterWorker as installFromRoot } from "bdf.mbt/plugin";',
        "// @ts-expect-error the worker entry exports only installPluginConverterWorker",
        'import { createFormatRegistry as registryFromWorker } from "bdf.mbt/plugin/worker";',
        "// @ts-expect-error the docuworks adapter entry exports only the adapter",
        'import { createConverterHost as hostFromAdapter } from "bdf.mbt/plugin/adapters/docuworks";',
        "// @ts-expect-error the docuworks adapter entry exports no moonbit binding",
        'import { moonbitDocuWorks as bindingFromAdapter } from "bdf.mbt/plugin/adapters/docuworks";',
        "// @ts-expect-error the diagram adapters live in their own entries, not the root",
        'import { excalidrawPlugin as excalidrawFromRoot } from "bdf.mbt/plugin";',
        "// @ts-expect-error the mermaid adapter entry exports only the adapter and constants",
        'import { createFormatRegistry as registryFromMermaid } from "bdf.mbt/plugin/adapters/mermaid";',
        "// @ts-expect-error the shared encoder is not re-exported by the excalidraw adapter",
        'import { encodeDiagram as encodeFromAdapter } from "bdf.mbt/plugin/adapters/excalidraw";',
        "",
        "const registry = createFormatRegistry();",
        "const plugin = docuworksPlugin({",
        "  delegate: {",
        "    detect: (bytes: Uint8Array): boolean => bytes.length > 0 && bdf_xdw_detect(bytes) === true,",
        "    convert: async (bytes: Uint8Array) => ({ bdf: bytes, summary: \"s\" }),",
        "  },",
        "});",
        "void DOCUWORKS_FORMAT_NAME;",
        "void moonbitDocuWorks;",
        "void docuworksFromRoot;",
        "registry.register(plugin, \"type-check\");",
        "const host = createConverterHost({",
        "  registry,",
        "  postMessage: (message: unknown) => void message,",
        "  context: { hostApiVersion: 1 },",
        "});",
        "void host.formats();",
        "const workerHost = installPluginConverterWorker([plugin], {",
        "  postMessage: (message: unknown) => void message,",
        "});",
        "void workerHost.formats();",
        "void workerHost.streamCount;",
        "",
      ].join("\n"),
    );
    writeFileSync(
      resolve(consumerDir, "tsconfig.json"),
      JSON.stringify({
        compilerOptions: {
          strict: true,
          target: "es2022",
          module: "esnext",
          moduleResolution: "bundler",
          noEmit: true,
          types: [],
        },
        files: ["consumer-typecheck.ts"],
      }, null, 2) + "\n",
    );
    const tsc = resolve(root, "node_modules", "typescript", "bin", "tsc");
    assert.ok(existsSync(tsc), "typescript (repository devDependency) is required for this check");
    const run = spawnSync("node", [tsc, "-p", "tsconfig.json"], {
      cwd: consumerDir,
      encoding: "utf8",
    });
    assert.equal(run.status, 0, `tsc found typing errors:\n${run.stdout}`);
  });
}
