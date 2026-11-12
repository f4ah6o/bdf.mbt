// Tests against the tarball-installed copy of the package, not the repo
// source. Enabled by pointing BDF_PLUGIN_INSTALLED at the installed package
// directory (see plugin/tools/smoke.mjs); without it, the tests skip so the
// plain unit suite never depends on packing.

import assert from "node:assert/strict";
import { test } from "node:test";

const installed = process.env.BDF_PLUGIN_INSTALLED;
const xdwModule = process.env.BDF_XDW_MODULE;
const name = process.env.BDF_PLUGIN_STAGING_NAME ?? "bdf-format-plugin-api";

if (!installed) {
  test("installed tarball smoke (skipped: no BDF_PLUGIN_INSTALLED)", { skip: true }, () => {});
} else {
  const manifest = await import(`${installed}/package.json`, { with: { type: "json" } }).then(m => m.default);

  test("the installed package is the staged, publication-blocked artifact", () => {
    assert.equal(manifest.name, name);
    assert.equal(manifest.private, true, "the staged package must keep private: true");
    assert.equal(typeof manifest.exports["./worker"], "object");
    assert.equal(manifest.types, "./types/index.d.ts");
  });

  const api = await import(`${installed}/src/index.js`);
  const { docuworksPlugin } = await import(`${installed}/src/adapters/docuworks.js`);
  const { excalidrawPlugin } = await import(`${installed}/src/adapters/excalidraw.js`);
  const { mermaidPlugin } = await import(`${installed}/src/adapters/mermaid.js`);
  const diagramBdf = await import(`${installed}/src/diagram-bdf.js`);
  const { installPluginConverterWorker } = await import(`${installed}/src/worker.js`);

  test("the installed package has all stated exports", () => {
    assert.equal(api.FORMAT_PLUGIN_API_VERSION, 1);
    assert.equal(typeof api.createFormatRegistry, "function");
    assert.equal(typeof api.createConverterHost, "function");
    assert.equal(typeof docuworksPlugin, "function");
    assert.equal(typeof installPluginConverterWorker, "function");
    assert.equal(typeof api.moonbitDocuWorks, "function");
    assert.equal(typeof excalidrawPlugin, "function");
    assert.equal(typeof mermaidPlugin, "function");
    assert.equal(typeof diagramBdf.encodeDiagram, "function");
    assert.equal(typeof diagramBdf.encodeDiagramDocument, "function");
    assert.equal(typeof diagramBdf.DiagramEncodeError, "function");
  });

  test("the installed diagram exports match the export map entries", () => {
    assert.equal(typeof manifest.exports["./diagram-bdf"], "object");
    assert.equal(typeof manifest.exports["./adapters/excalidraw"], "object");
    assert.equal(typeof manifest.exports["./adapters/mermaid"], "object");
    const excalidraw = excalidrawPlugin();
    const mermaid = mermaidPlugin();
    assert.equal(excalidraw.name, "excalidraw");
    assert.deepEqual(excalidraw.extensions, [".excalidraw", ".excalidraw.json"]);
    assert.equal(mermaid.name, "mermaid");
    assert.deepEqual(mermaid.extensions, [".mmd", ".mermaid"]);
  });

  const { Transport } = await import("./helpers.mjs");

  test("installed registry rejects collisions exactly like the repo build", () => {
    const registry = api.createFormatRegistry();
    const delegate = { detect: () => false, convert: async bytes => ({ bdf: bytes, summary: "s" }) };
    registry.register(docuworksPlugin({ delegate }), "builtin");
    assert.throws(
      () => registry.register(docuworksPlugin({ delegate }), "downstream"),
      /claims format name "xdw", already claimed by plugin "xdw" \(builtin\)/,
    );
  });

  test("installed host converts with the real DocuWorks MoonBit binding", async () => {
    if (!xdwModule) {
      test.skip("no BDF_XDW_MODULE; conversion smoke needs the built module");
      return;
    }
    const xdw = await import(xdwModule);
    const { syntheticXdw } = await import("./fixture-xdw.mjs");
    const { BdfDocument, BufferSource } = await import("@bdfkit/core");
    const registry = api.createFormatRegistry({
      plugins: [docuworksPlugin({ delegate: api.moonbitDocuWorks(xdw) })],
    });
    const transport = new Transport();
    const host = api.createConverterHost({ registry, postMessage: transport.postMessage });
    await host.handle({ type: "init" });
    await host.handle({ id: 1, type: "convert", data: syntheticXdw().buffer, options: { name: "sample.xdw" } });
    const reply = transport.reply(1);
    assert.equal(reply.ok, true, reply.error);
    assert.equal(reply.result.format, "xdw");
    const document = await BdfDocument.open(new BufferSource(reply.result.bdf));
    const page = document.manifest.views[0].pages[0];
    assert.ok(Math.abs(page.w - 595.2756) < 0.01 && Math.abs(page.h - 841.8898) < 0.01, `page ${page.w}x${page.h}`);
    // open: a complete document, no stream lease
    await host.handle({ id: 2, type: "open", data: syntheticXdw().buffer });
    const opened = transport.reply(2);
    assert.equal(opened.ok, true);
    assert.equal(opened.result.pages, 0);
    assert.equal(opened.result.stream, undefined);
  });
}
