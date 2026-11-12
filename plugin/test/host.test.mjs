import assert from "node:assert/strict";
import { test } from "node:test";

import { ConvertError, PluginError } from "../src/contract.js";
import { createFormatRegistry } from "../src/registry.js";
import { createConverterHost } from "../src/host.js";
import { docuworksPlugin } from "../src/adapters/docuworks.js";
import { makePlugin, mulberry32, text, Transport } from "./helpers.mjs";

const docuworks = () => docuworksPlugin({
  delegate: {
    detect: bytes => bytes[0] === 0x60,
    convert: async bytes => ({ bdf: bytes.slice(), summary: "DocuWorks", warnings: [] }),
  },
});

function hostWith({ plugins, registry, transport }) {
  const post = { transport: new Transport() };
  const host = createConverterHost({
    registry: registry ?? createFormatRegistry({ plugins }),
    postMessage: (transport ?? post.transport).postMessage,
  });
  return { host, registry, post };
}

async function send(host, message) {
  return host.handle(message);
}

test("init answers the formats of the registry at id 0", async () => {
  const { host, post } = hostWith({ plugins: [docuworks()] });
  await send(host, { type: "init" });
  assert.deepEqual(post.transport.replies, [
    {
      id: 0,
      ok: true,
      formats: [
        {
          name: "xdw",
          description:
            "DocuWorks document (vector and scanned pages with annotations; binder .xbd)",
          extensions: [".xdw", ".xbd"],
        },
      ],
    },
  ]);
});

test("requests before init are refused with the existing message", async () => {
  const { host, post } = hostWith({ plugins: [docuworks()] });
  await send(host, { id: 7, type: "convert", data: new ArrayBuffer(0) });
  const reply = post.transport.reply(7);
  assert.equal(reply.ok, false);
  assert.equal(reply.error, "converter is not ready");
});

test("unknown requests and wire registration are refused by name", async () => {
  const { host, post } = hostWith({ plugins: [docuworks()] });
  await send(host, { type: "init" });
  await send(host, { id: 3, type: "zoom" });
  await send(host, { id: 4, type: "register", plugins: [] });
  assert.equal(post.transport.reply(3).error, "unknown request zoom");
  const register = post.transport.reply(4);
  assert.equal(register.error, "registration is only available at worker startup");
  assert.equal(register.code, "registration-at-startup");
});

test("convert: detection, result shape and format identity", async () => {
  const transport = new Transport();
  const { host } = hostWith({ plugins: [docuworks()], transport });
  await send(host, { type: "init" });
  const bytes = new Uint8Array([0x60, 0x03, 0x80, 1, 2, 3]);
  await send(host, { id: 1, type: "convert", data: bytes.buffer, options: { name: "a.xdw" } });
  const reply = transport.reply(1);
  assert.equal(reply.ok, true);
  assert.equal(reply.result.format, "xdw");
  assert.equal(reply.result.summary, "DocuWorks");
  assert.deepEqual(reply.result.warnings, []);
  assert.equal(reply.result.protected, false);
  assert.deepEqual(Array.from(reply.result.bdf), [0x60, 0x03, 0x80, 1, 2, 3]);
  // the byte result is transferred, the init reply is not
  assert.equal(transport.transfers[0].length, 0);
  assert.equal(transport.transfers[1].length, 1);
  assert.ok(transport.transfers[1][0] instanceof ArrayBuffer);
});

test("convert: an explicit unknown format keeps the existing error message", async () => {
  const transport = new Transport();
  const { host } = hostWith({ plugins: [docuworks()], transport });
  await send(host, { type: "init" });
  await send(host, { id: 2, type: "convert", data: new ArrayBuffer(0), options: { format: "nope" } });
  const reply = transport.reply(2);
  assert.equal(reply.ok, false);
  assert.equal(reply.error, 'unknown format "nope"');
  assert.equal(reply.code, "unknown-format");
});

test("convert: no detection match is an explicit new error", async () => {
  const transport = new Transport();
  const { host } = hostWith({ plugins: [docuworks()], transport });
  await send(host, { type: "init" });
  await send(host, { id: 5, type: "convert", data: new ArrayBuffer(0), options: { name: "m.zzz" } });
  assert.equal(transport.reply(5).error, 'no format matched "m.zzz"');
});

test("open without plugin streaming answers a complete document with pages 0", async () => {
  const transport = new Transport();
  const { host } = hostWith({ plugins: [docuworks()], transport });
  await send(host, { type: "init" });
  await send(host, { id: 8, type: "open", data: new Uint8Array([0x60]).buffer });
  const reply = transport.reply(8);
  assert.equal(reply.ok, true);
  assert.equal(reply.result.pages, 0);
  assert.equal(reply.result.stream, undefined);
  assert.equal(host.streamCount, 0);
});

test("open with plugin streaming leases an id from 1 and keeps the handle", async () => {
  const transport = new Transport();
  const opened = makePlugin({ name: "pages", open: true, detectAccepts: null });
  const { host } = hostWith({ plugins: [opened.plugin], transport });
  await send(host, { type: "init" });
  await send(host, { id: 10, type: "open", data: text("document").buffer });
  let first = transport.reply(10);
  assert.equal(first.result.pages, 2);
  assert.equal(first.result.stream, 1);
  await send(host, { id: 11, type: "open", data: text("again").buffer });
  first = transport.reply(11);
  assert.equal(first.result.stream, 2);
  assert.equal(host.streamCount, 2);
  await send(host, { id: 12, type: "close", stream: 1 });
  assert.deepEqual(transport.reply(12), { id: 12, ok: true, result: null });
  assert.equal(host.streamCount, 1);
  await send(host, { id: 13, type: "close", stream: 1 });
  assert.deepEqual(transport.reply(13), { id: 13, ok: true, result: null });
  assert.equal(host.streamCount, 1);
});

test("page and finish: success, unknown id, out-of-range index", async () => {
  const transport = new Transport();
  const opened = makePlugin({ name: "pages", open: true, detectAccepts: null });
  const { host } = hostWith({ plugins: [opened.plugin], transport });
  await send(host, { type: "init" });
  await send(host, { id: 20, type: "open", data: text("abc").buffer });
  const stream = transport.reply(20).result.stream;
  await send(host, { id: 21, type: "page", stream, index: 1 });
  const page = transport.reply(21);
  assert.deepEqual(Array.from(page.result.bdf), Array.from(text("abc").slice(0, 6)));
  assert.deepEqual(page.result.warnings, []);
  assert.equal("format" in page.result, false);
  await send(host, { id: 22, type: "finish", stream });
  const finish = transport.reply(22);
  assert.equal(finish.ok, true);
  assert.equal(finish.result.format, "pages");
  await send(host, { id: 23, type: "page", stream: 777, index: 0 });
  await send(host, { id: 24, type: "finish", stream: 777 });
  assert.equal(transport.reply(23).error, "no conversion 777");
  assert.equal(transport.reply(24).error, "no conversion 777");
  await send(host, { id: 25, type: "page", stream, index: 9 });
  assert.equal(transport.reply(25).ok, false);
  assert.equal(transport.reply(25).error, "pages: page 9 is out of range");
  await send(host, { id: 26, type: "page", stream, index: -1 });
  assert.equal(transport.reply(26).error, "page: invalid index -1");
  await send(host, { id: 27, type: "page", stream, index: 2.5 });
  assert.equal(transport.reply(27).error, "page: invalid index 2.5");
  // finish keeps the lease: the stream can still be closed
  assert.equal(host.streamCount, 1);
  await send(host, { id: 28, type: "close", stream });
  assert.equal(transport.reply(28).ok, true);
  assert.equal(host.streamCount, 0);
});

test("async plugin failures keep their message and code, sync throws included", async () => {
  const boom = () => {
    const error = new Error("engine exploded");
    error.code = "engine";
    throw error;
  };
  const plugins = [
    { apiVersion: 1, name: "sync-throw", description: "d", convert: boom },
    { apiVersion: 1, name: "async-throw", description: "d", convert: async () => boom() },
    { apiVersion: 1, name: "async-reject", description: "d", convert: () => Promise.reject("raw string") },
    { apiVersion: 1, name: "open-throw", description: "d", convert: () => ({}), open: async () => {
      const error = new Error("open failed");
      error.code = "open";
      throw error;
    }, page: async () => ({}), finish: async () => ({}) },
  ];
  const transport = new Transport();
  const { host } = hostWith({ plugins, transport });
  await send(host, { type: "init" });
  await send(host, { id: 30, type: "convert", data: new ArrayBuffer(0), options: { format: "sync-throw" } });
  await send(host, { id: 31, type: "convert", data: new ArrayBuffer(0), options: { format: "async-throw" } });
  await send(host, { id: 32, type: "convert", data: new ArrayBuffer(0), options: { format: "async-reject" } });
  await send(host, { id: 33, type: "open", data: new ArrayBuffer(0), options: { format: "open-throw" } });
  assert.deepEqual(transport.reply(30), { id: 30, ok: false, error: "engine exploded", code: "engine" });
  assert.deepEqual(transport.reply(31), { id: 31, ok: false, error: "engine exploded", code: "engine" });
  assert.deepEqual(transport.reply(32), { id: 32, ok: false, error: "raw string" });
  await send(host, { id: 34, type: "convert", data: null, options: { format: "sync-throw" } });
  assert.equal(transport.reply(34).error, "input data must be an ArrayBuffer or a typed array view");
  assert.equal(transport.reply(33).error, "open failed");
  assert.equal(transport.reply(33).code, "open");
});

const MALFORMED_CASES = [
  ["bdf missing", value => ({ summary: "s" }), "bdf must be a Uint8Array, not undefined"],
  ["bdf is a plain array", value => ({ bdf: [1, 2, 3], summary: "s" }), "bdf must be a Uint8Array, not object"],
  ["summary missing", value => ({ bdf: new Uint8Array(1) }), "the convert result's summary must be a string"],
  ["warnings is a string", value => ({ bdf: new Uint8Array(1), summary: "s", warnings: "nope" }), "warnings must be an array of strings"],
  ["warnings hold numbers", value => ({ bdf: new Uint8Array(1), summary: "s", warnings: [1] }), "warnings must only hold strings"],
  ["result is null", value => null, "the convert result must be a plain object, not null"],
  ["result is a number", value => 42, "the convert result must be a plain object, not number"],
];

for (const [what, convert, message] of MALFORMED_CASES) {
  test(`malformed plugin output: ${what}`, async () => {
    const transport = new Transport();
    const registry = createFormatRegistry({
      plugins: [{ apiVersion: 1, name: "broken", description: "d", convert: async () => convert() }],
    });
    const { host } = hostWith({ registry, transport });
    await send(host, { type: "init" });
    await send(host, { id: 40, type: "convert", data: new ArrayBuffer(0), options: { format: "broken" } });
    const reply = transport.reply(40);
    assert.equal(reply.ok, false);
    assert.match(reply.error, new RegExp(`plugin "broken" returned malformed output: ${message}`));
    // the host keeps working after a plugin's garbage
    await send(host, { id: 41, type: "convert", data: new ArrayBuffer(0), options: { format: "missing" } });
    assert.match(transport.reply(41).error, /unknown format "missing"/);
  });
}

test("malformed plugin output: a forged format is rejected, not passed through", async () => {
  const transport = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "honest",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s", format: "someone-else" }),
      },
    ],
  });
  const { host } = hostWith({ registry, transport });
  await send(host, { type: "init" });
  await send(host, { id: 42, type: "convert", data: new ArrayBuffer(0), options: { format: "honest" } });
  assert.match(
    transport.reply(42).error,
    /cannot leave a plugin registered as "honest"/,
  );
});

test("malformed open output: pages and stream handle rules", async () => {
  const transport = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "opener",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", pages: 3 }),
        page: async () => ({ bdf: new Uint8Array(1) }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
      },
    ],
  });
  const { host } = hostWith({ registry, transport });
  await send(host, { type: "init" });
  await send(host, { id: 43, type: "open", data: new ArrayBuffer(0), options: { format: "opener" } });
  assert.match(transport.reply(43).error, /an open result with pages must carry a stream handle object/);
  assert.equal(host.streamCount, 0);
});

test("options validation: unknown keys, wrong types, pages and params", async () => {
  const transport = new Transport();
  const { host } = hostWith({ plugins: [docuworks()], transport });
  await send(host, { type: "init" });
  const cases = [
    [{ fonts: "https://x" }, 'options: unknown key "fonts"'],
    [{ format: 7 }, "options.format must be a string"],
    [{ name: 7 }, "options.name must be a string"],
    [{ password: 7 }, "options.password must be a string"],
    [{ pages: 7 }, "options.pages must be a string"],
    [{ pages: "1-2" }, "options.pages: page selection is not part of the plugin contract yet"],
    [{ params: "x" }, "options.params must be a plain object"],
    [{ params: { what: null } }, "options.params.what must be a string, number or boolean"],
  ];
  let id = 50;
  for (const [options, message] of cases) {
    id += 1;
    await send(host, { id, type: "convert", data: new ArrayBuffer(0), options });
    assert.equal(transport.reply(id).error, message, `case ${JSON.stringify(options)}`);
    assert.equal(transport.reply(id).code, "invalid-options");
  }
  // valid params reach the plugin as strings
  const seen = [];
  const transport2 = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "echo",
        description: "d",
        convert: async (bytes, options) => {
          seen.push(options);
          return { bdf: new Uint8Array(1), summary: "s" };
        },
      },
    ],
  });
  const { host: second } = hostWith({ registry, transport: transport2 });
  await send(second, { type: "init" });
  await send(second, { id: 60, type: "convert", data: new ArrayBuffer(0), options: { format: "echo", params: { flag: true, count: 3 } } });
  assert.equal(transport2.reply(60).ok, true);
  assert.deepEqual(seen[0].params, { flag: "true", count: "3" });
  assert.equal(seen[0].detectedVia, "format-option");
  assert.equal(seen[0].pages, "");
});
