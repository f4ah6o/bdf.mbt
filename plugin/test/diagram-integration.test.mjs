// Cross-adapter host integration owned by the coordinator: both diagram
// adapters registered beside the builtin DocuWorks plugin in one registry,
// driven through the host envelope the way a real worker drives it. This is
// the check that catches integration drift between the two adapters and the
// shared encoder that the per-format test files cannot see (extension claim
// collisions, format identity over the wire, detection precedence).

import assert from "node:assert/strict";
import { test } from "node:test";

import { createFormatRegistry } from "../src/registry.js";
import { createConverterHost } from "../src/host.js";
import { docuworksPlugin } from "../src/adapters/docuworks.js";
import { excalidrawPlugin } from "../src/adapters/excalidraw.js";
import { mermaidPlugin } from "../src/adapters/mermaid.js";
import { openDiagram } from "./diagram-reader.mjs";

const text = value => new TextEncoder().encode(value);

function hostWith(plugins) {
  const replies = [];
  const host = createConverterHost({
    registry: createFormatRegistry({ plugins }),
    postMessage: message => replies.push(message),
  });
  return { host, replies };
}

const excalidrawBytes = () => text(JSON.stringify({
  type: "excalidraw",
  version: 2,
  appState: {},
  elements: [
    { id: "r1", type: "rectangle", x: 10, y: 10, width: 90, height: 40, strokeColor: "#1e1e1e", backgroundColor: "#a5d8ff", fillStyle: "solid" },
  ],
}));

const mermaidBytes = () => text("flowchart TD\n開始 --> 処理中\n処理中 -->|承認済み| 完了\n");

test("both diagram plugins register beside docuworks without claim collisions", async () => {
  const delegate = { detect: () => false, convert: async () => ({ bdf: new Uint8Array(0), summary: "", warnings: [] }) };
  const { host, replies } = hostWith([docuworksPlugin({ delegate }), excalidrawPlugin(), mermaidPlugin()]);
  await host.handle({ type: "init" });
  const formats = replies[0].formats;
  const names = formats.map(format => format.name).sort();
  assert.deepEqual(names, ["excalidraw", "mermaid", "xdw"]);
  const extensions = formats.flatMap(format => format.extensions);
  assert.equal(new Set(extensions).size, extensions.length, `extension claims collide: ${extensions.join(",")}`);
  for (const expected of [".xdw", ".xbd", ".excalidraw"]) {
    assert.ok(extensions.includes(expected), `${extensions.join(",")} must include ${expected}`);
  }
});

test("content detection routes an excalidraw scene through the host", async () => {
  const plugins = [excalidrawPlugin(), mermaidPlugin()];
  const { host, replies } = hostWith(plugins);
  await host.handle({ type: "init" });
  const before = replies.length;
  await host.handle({ id: 1, type: "convert", data: excalidrawBytes().slice() });
  const reply = replies[replies.length - 1];
  assert.equal(reply.id, 1);
  assert.equal(reply.ok, true, reply.error);
  assert.equal(reply.result.format, "excalidraw");
  const opened = await openDiagram(reply.result.bdf);
  assert.notEqual(opened.ops.filter(op => op.op === "fillRect" || op.op === "strokeRect").length, 0);
});

test("extension fallback routes a Mermaid file, and its Japanese labels survive the wire", async () => {
  const plugins = [excalidrawPlugin(), mermaidPlugin()];
  const { host, replies } = hostWith(plugins);
  await host.handle({ type: "init" });
  await host.handle({ id: 2, type: "convert", data: mermaidBytes().slice(), name: "flow.mmd" });
  const reply = replies[replies.length - 1];
  assert.equal(reply.id, 2);
  assert.equal(reply.ok, true, reply.error);
  assert.equal(reply.result.format, "mermaid");
  const opened = await openDiagram(reply.result.bdf);
  const texts = opened.ops.filter(op => op.op === "fillText").map(op => op.args[0]);
  for (const expected of ["開始", "処理中", "完了", "承認済み"]) {
    assert.ok(texts.includes(expected), `${JSON.stringify(texts)} must include ${expected}`);
  }
});

test("unknown format names are refused, not guessed", async () => {
  const plugins = [excalidrawPlugin(), mermaidPlugin()];
  const { host, replies } = hostWith(plugins);
  await host.handle({ type: "init" });
  await host.handle({ id: 3, type: "convert", data: mermaidBytes().slice(), options: { format: "excalidraw" } });
  const reply = replies[replies.length - 1];
  // Mermaid bytes under an explicit excalidraw format name: the excalidraw
  // plugin is addressed directly and must reject the bytes as not a scene.
  assert.equal(reply.ok, false);
});

test("invalid diagram input through the host answers an error, not a crash", async () => {
  const { host, replies } = hostWith([mermaidPlugin()]);
  await host.handle({ type: "init" });
  await host.handle({ id: 4, type: "convert", data: text("subgraph inner\nA-->B\nend\n").slice(), name: "bad.mmd" });
  const reply = replies[replies.length - 1];
  assert.equal(reply.id, 4);
  assert.equal(reply.ok, false);
  assert.equal(typeof reply.error, "string");
  assert.notEqual(reply.error, "");
});
