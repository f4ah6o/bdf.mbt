import assert from "node:assert/strict";
import { test } from "node:test";

import { ConvertError, PluginError } from "../src/contract.js";
import { createFormatRegistry } from "../src/registry.js";
import { createConverterHost, outgoingBytes } from "../src/host.js";
import { makePlugin, mulberry32, text, Transport } from "./helpers.mjs";

function makeHost({ registry, transport = new Transport(), postMessage } = {}) {
  const host = createConverterHost({
    registry,
    postMessage: postMessage ?? transport.postMessage,
  });
  return { host, transport };
}

const settle = () => new Promise(resolve => setImmediate(resolve));

test("a Buffer output transfers only its exact bytes: fresh intrinsic copy", async () => {
  const transport = new Transport();
  const pooled = Buffer.alloc(64); // small buffers share Node's 8 KiB pool
  for (let i = 0; i < pooled.length; i += 1) {
    pooled[i] = i;
  }
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "buffered",
        description: "d",
        // a Node Buffer view over its pooled backing store, like a delegate
        // built on Buffer would hand over
        convert: async () => ({ bdf: pooled.subarray(4, 8), summary: "pooled" }),
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "convert", data: new ArrayBuffer(0), options: { format: "buffered" } });
  const reply = transport.reply(1);
  assert.equal(reply.ok, true, reply.error);
  assert.deepEqual(Array.from(reply.result.bdf), [4, 5, 6, 7]);
  assert.equal(reply.result.bdf.length, 4);
  assert.equal(reply.result.bdf.byteOffset, 0);
  // the transferred buffer holds only the plugin's four bytes, not the pool
  const transferred = transport.transfers[1][0];
  assert.ok(transferred instanceof ArrayBuffer);
  assert.equal(transferred.byteLength, 4);
});

test("outgoingBytes itself makes an exact intrinsic copy of any view", () => {
  const plugin = { name: "x" };
  const pooled = Buffer.alloc(8192);
  const view = pooled.subarray(100, 116);
  const copy = outgoingBytes(plugin, view, "bdf");
  assert.ok(copy instanceof Uint8Array);
  assert.equal(Buffer.isBuffer(copy), false);
  assert.equal(copy.length, 16);
  assert.equal(copy.buffer.byteLength, 16);
});

test("input byte views: the plugin sees exactly the sent range, isolated from the caller", async () => {
  const transport = new Transport();
  let seen = null;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "echo",
        description: "d",
        convert: async bytes => {
          seen = bytes;
          return { bdf: bytes.slice(), summary: "s" };
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  const backing = new Uint8Array(32);
  for (let i = 0; i < backing.length; i += 1) {
    backing[i] = i;
  }
  const view = backing.subarray(8, 21); // byteOffset 8, length 13
  await host.handle({ id: 2, type: "convert", data: view, options: { format: "echo" } });
  const reply = transport.reply(2);
  assert.equal(reply.ok, true);
  assert.equal(seen.length, 13);
  assert.deepEqual(Array.from(seen), Array.from(backing.slice(8, 21)));
  // the plugin's bytes are a copy: later caller writes do not show up in a
  // result produced from them
  for (let i = 0; i < backing.length; i += 1) {
    backing[i] = 255;
  }
  assert.deepEqual(Array.from(reply.result.bdf), Array.from(new Uint8Array(13).map((_, i) => i + 8)));
});

test("open resolving after dispose: no reply, no lease, handle released once", async () => {
  const transport = new Transport();
  let releaseLateOpen;
  const opens = [];
  const cleans = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slow",
        description: "d",
        convert: async bytes => ({ bdf: bytes.slice(0, 1), summary: "s" }),
        open: (bytes) => new Promise(resolve => {
          opens.push(resolve);
          releaseLateOpen = () => resolve({ bdf: new Uint8Array([1]), summary: "late", warnings: [], pages: 2, stream: { id: "h1" } });
        }),
        page: async () => ({ bdf: new Uint8Array(1) }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async stream => {
          cleans.push(stream.id);
          await settle();
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  const pending = host.handle({ id: 70, type: "open", data: new ArrayBuffer(0), options: { format: "slow" } });
  const disposal = host.dispose("gone");
  releaseLateOpen();
  await pending;
  await disposal;
  assert.equal(transport.replies.length, 1, "only the init reply must be visible");
  assert.equal(host.streamCount, 0);
  assert.deepEqual(cleans, ["h1"]);
});

test("page resolving after dispose of its lease: dropped, handle released exactly once", async () => {
  const transport = new Transport();
  const cleans = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slow",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { id: "h2" } }),
        page: (stream, index) => new Promise(resolve => {
          queueMicrotask(() => resolve({ bdf: new Uint8Array([9]) }));
        }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async stream => {
          cleans.push(stream.id);
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 80, type: "open", data: new ArrayBuffer(0), options: { format: "slow" } });
  const stream = transport.reply(80).result.stream;
  const pendingPage = host.handle({ id: 81, type: "page", stream, index: 0 });
  const disposal = host.dispose("test");
  await pendingPage;
  await disposal;
  assert.deepEqual(cleans, ["h2"], "one release for the disposed lease");
  const replyIds = transport.replies.map(reply => reply.id).filter(id => id !== 0);
  assert.deepEqual(replyIds, [80], "the late page reply is not posted");
});

test("a transport failure after lease allocation releases the lease and its handle", async () => {
  const cleans = [];
  let opens = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "streamed",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => {
          opens += 1;
          return { bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { id: `h${opens}` } };
        },
        page: async () => ({ bdf: new Uint8Array(1) }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async stream => {
          cleans.push(stream.id);
        },
      },
    ],
  });
  let broken = false;
  const transport = new Transport();
  const { host } = makeHost({
    registry,
    transport,
    postMessage: (message, transfer) => {
      if (broken && message.id !== 0) {
        throw new Error("transport is gone");
      }
      transport.postMessage(message, transfer);
    },
  });
  await host.handle({ type: "init" });
  await host.handle({ id: 90, type: "open", data: new ArrayBuffer(0), options: { format: "streamed" } });
  const stream = transport.reply(90).result.stream;
  assert.equal(host.streamCount, 1);
  broken = true;
  // the open cannot be answered; its lease and handle are released, and the
  // transport error itself is surfaced to the installer, not swallowed
  await assert.rejects(
    host.handle({ id: 91, type: "open", data: new ArrayBuffer(0), options: { format: "streamed" } }),
    /transport is gone/,
  );
  assert.equal(host.streamCount, 1, "the failed open leaked no lease");
  // the failed second open released exactly its own handle
  assert.deepEqual(cleans, ["h2"]);
  broken = false;
  await host.handle({ id: 92, type: "page", stream, index: 0 });
  assert.equal(transport.reply(92).ok, true);
  // the pre-existing lease still works and still cleans up once
  await host.handle({ id: 93, type: "close", stream });
  assert.deepEqual(cleans, ["h2", "h1"]);
  assert.equal(host.streamCount, 0);
});

test("stream ids are unique and never reused: property test over random op sequences", async () => {
  const random = mulberry32(424242);
  for (let round = 0; round < 50; round += 1) {
    const transport = new Transport();
    const opened = makePlugin({ name: "streamed", open: true, detectAccepts: null });
    const registry = createFormatRegistry({ plugins: [opened.plugin] });
    const { host } = makeHost({ registry, transport });
    await host.handle({ type: "init" });
    const leases = [];
    const model = new Map();
    let expectedId = 1;
    for (let step = 0; step < 30; step += 1) {
      const roll = random.next();
      const live = [...model.keys()];
      if (roll < 0.35 || live.length === 0) {
        await host.handle({
          id: 100 + step,
          type: "open",
          data: text(`doc ${round} ${step}`).buffer,
        });
        const reply = transport.reply(100 + step);
        assert.equal(reply.ok, true);
        assert.equal(reply.result.stream, expectedId, `round ${round} step ${step}`);
        leases.push(expectedId);
        model.set(expectedId, true);
        expectedId += 1;
      } else if (roll < 0.6) {
        const target = live[random.integer(live.length)];
        await host.handle({ id: 200 + step, type: "close", stream: target });
        assert.deepEqual(transport.reply(200 + step), { id: 200 + step, ok: true, result: null });
        model.delete(target);
      } else if (roll < 0.85) {
        const target = live[random.integer(live.length)];
        await host.handle({ id: 300 + step, type: "page", stream: target, index: 0 });
        assert.equal(transport.reply(300 + step).ok, true);
      } else {
        const target = random.pick([...model.keys(), ...leases, 999]);
        await host.handle({ id: 400 + step, type: "finish", stream: target });
        const reply = transport.reply(400 + step);
        if (model.has(target)) {
          assert.equal(reply.ok, true, `live stream ${target} must finish`);
        } else {
          assert.equal(reply.error, `no conversion ${target}`);
        }
      }
      assert.equal(host.streamCount, model.size);
    }
    const report = await host.dispose("round done");
    // the leases still open at disposal are in the report...
    assert.equal(report.released.length, model.size);
    // ...and every handle the round ever allocated was released exactly once
    assert.equal(opened.cleaned.streams, expectedId - 1, "every handle released exactly once");
    assert.equal(host.streamCount, 0);
  }
});

test("byte view boundaries are exact under random splits: property test", async () => {
  const random = mulberry32(13579);
  const transport = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "views",
        description: "d",
        convert: async bytes => {
          // echo the tail as a view over a bigger buffer: the reply must copy
          const size = bytes.length;
          const big = new Uint8Array(size + 64);
          big.set(bytes, 32);
          return { bdf: big.subarray(32, 32 + size), summary: "view", warnings: [] };
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  for (let round = 0; round < 100; round += 1) {
    const length = 1 + random.integer(512);
    const backing = new Uint8Array(4096);
    for (let i = 0; i < backing.length; i += 1) {
      backing[i] = random.next() * 256;
    }
    const offset = random.integer(4000 - length);
    const view = backing.subarray(offset, offset + length);
    await host.handle({ id: 500 + round, type: "convert", data: view, options: { format: "views" } });
    const reply = transport.reply(500 + round);
    assert.equal(reply.ok, true, reply.error);
    assert.deepEqual(Array.from(reply.result.bdf), Array.from(view));
    assert.equal(reply.result.bdf.buffer.byteLength, length);
    // request ids rise with rounds, replies carry the plugin's exact bytes
    const transfer = transport.transfers.at(-1);
    assert.equal(transfer[0].byteLength, length);
  }
});

test("registry-level dispose: exactly once, async included, failures reported", async () => {
  const calls = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "ok",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        dispose: async () => {
          calls.push("ok");
          await settle();
          return "done";
        },
      },
      {
        apiVersion: 1,
        name: "bad",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        dispose: async () => {
          calls.push("bad");
          throw new Error("nope");
        },
      },
    ],
  });
  const [first, second] = await Promise.all([
    registry.dispose("reason"),
    registry.dispose("also"),
  ]);
  assert.equal(first, second, "repeated dispose returns the same report");
  assert.deepEqual(calls, ["ok", "bad"]);
  assert.deepEqual(first.outcomes.map(outcome => outcome.name), ["ok", "bad"]);
  assert.equal(first.outcomes[0].ok, true);
  assert.equal(first.outcomes[0].returned, "done");
  assert.equal(first.outcomes[1].ok, false);
  assert.equal(first.reason, "reason", "the first call's reason wins");
});

test("host dispose is idempotent and async-safe across concurrent calls", async () => {
  const transport = new Transport();
  const opened = makePlugin({ name: "streamed", open: true, detectAccepts: null });
  const registry = createFormatRegistry({ plugins: [opened.plugin] });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 600, type: "open", data: text("x").buffer });
  const reportOne = host.dispose("first");
  const reportTwo = host.dispose("second");
  const [one, two] = await Promise.all([reportOne, reportTwo]);
  assert.equal(one, two, "the same settled report object comes back");
  assert.equal(one.reason, "first");
  assert.equal(one.released.length, 1);
  assert.equal(one.released[0].ok, true);
  assert.equal(opened.cleaned.disposed, 1, "plugin dispose ran exactly once");
  assert.equal(opened.cleaned.streams, 1, "the handle was released exactly once");
  // the disposed host refuses further work
  await host.handle({ type: "init" });
  assert.equal(transport.replies.filter(reply => reply.id === 0).length, 1);
});

test("a failing async disposer is the close request's failure, never an unhandled rejection", async () => {
  const transport = new Transport();
  const rejections = [];
  process.on("unhandledRejection", rejections.push);
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "grumpy",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { id: "g" } }),
        page: async () => ({ bdf: new Uint8Array(1) }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async stream => {
          await settle();
          throw new Error(`cannot release ${stream.id}`);
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 320, type: "open", data: new ArrayBuffer(0), options: { format: "grumpy" } });
  const stream = transport.reply(320).result.stream;
  await host.handle({ id: 321, type: "close", stream });
  const reply = transport.reply(321);
  process.off("unhandledRejection", rejections.push);
  assert.equal(reply.ok, false, "the async disposer's failure is the reply");
  assert.equal(reply.error, "cannot release g");
  assert.equal(host.streamCount, 0, "the lease is gone, like the existing contract");
  assert.deepEqual(rejections, [], "no unhandled rejection escapes the host");
  // a subsequent close id is a successful no-op on the released lease
  await host.handle({ id: 322, type: "close", stream });
  assert.deepEqual(transport.reply(322), { id: 322, ok: true, result: null });
});

test("an async detector is a contract error, never a silent miss", async () => {
  const registry = createFormatRegistry();
  // an async function detector is knowably unsatisfiable, so it is refused
  // when the plugin is admitted — not discovered on the first request
  assert.throws(
    () =>
      registry.register({
        apiVersion: 1,
        name: "async-detector",
        description: "d",
        detect: async () => true,
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
      }),
    error =>
      error instanceof PluginError &&
      error.message.includes('plugin "async-detector" detect must be synchronous'),
  );
  // a detector that returns a promise at runtime (a plain synchronous
  // function whose body constructs one) is the detect-time contract error
  registry.register({
    apiVersion: 1,
    name: "promise-detector",
    description: "d",
    detect: () => Promise.resolve(true),
    convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
  });
  assert.throws(
    () => registry.detect(new Uint8Array(1)),
    error => error instanceof PluginError && error.code === "async-detect",
  );
});

///|
// A factory for open paths that hand over a resource-like handle while other
// parts of the result are malformed; the host must claim and release the
// handle on every rejected outcome.
function leakyOpenPlugin({ result, disposeImpl }) {
  const released = [];
  return {
    released,
    plugin: {
      apiVersion: 1,
      name: "leaky",
      description: "d",
      convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
      open: async () => result,
      page: async () => ({ bdf: new Uint8Array(1) }),
      finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
      disposeStream: async handle => {
        released.push(handle.resource);
        if (disposeImpl) {
          await settle();
          await disposeImpl();
        }
      },
    },
  };
}

test("a malformed open result with a handle releases that handle exactly once", async () => {
  // failing before: the handle was dropped without release
  const transport = new Transport();
  const leaky = leakyOpenPlugin({
    result: { bdf: "bad", summary: "", pages: 1, stream: { resource: 41 } },
  });
  const registry = createFormatRegistry({ plugins: [leaky.plugin] });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 330, type: "open", data: new ArrayBuffer(0), options: { format: "leaky" } });
  const reply = transport.reply(330);
  assert.equal(reply.ok, false, "the malformed result must be rejected");
  assert.match(reply.error, /malformed output/);
  assert.deepEqual(leaky.released, [41], "no lease does not mean no resource: the handle is released");
  assert.equal(host.streamCount, 0);
  // released exactly once: no close needed, and none is coming
  await host.handle({ id: 331, type: "close", stream: 1 });
  assert.deepEqual(transport.reply(331), { id: 331, ok: true, result: null });
  assert.deepEqual(leaky.released, [41]);
});

test("an open result with invalid or zero pages plus a handle is rejected and released", async () => {
  for (const pages of [-1, 2.5, 0]) {
    const transport = new Transport();
    const leaky = leakyOpenPlugin({
      result: { bdf: new Uint8Array(1), summary: "s", pages, stream: { resource: 7 } },
    });
    const registry = createFormatRegistry({ plugins: [leaky.plugin] });
    const { host } = makeHost({ registry, transport });
    await host.handle({ type: "init" });
    await host.handle({ id: 340, type: "open", data: new ArrayBuffer(0), options: { format: "leaky" } });
    const reply = transport.reply(340);
    assert.equal(reply.ok, false, `pages ${pages}`);
    assert.match(reply.error, /malformed output/, `pages ${pages}`);
    assert.deepEqual(leaky.released, [7], `pages ${pages} releases the handle`);
    assert.equal(host.streamCount, 0, `pages ${pages} leaked no lease`);
  }
});

test("a handle released for a rejected open does not hide its own cleanup failure", async () => {
  const transport = new Transport();
  const leaky = leakyOpenPlugin({
    result: { bdf: "bad", summary: "", pages: 1, stream: { resource: 5 } },
    disposeImpl: () => {
      throw new Error("release exploded");
    },
  });
  const registry = createFormatRegistry({ plugins: [leaky.plugin] });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 350, type: "open", data: new ArrayBuffer(0), options: { format: "leaky" } });
  const reply = transport.reply(350);
  assert.equal(reply.ok, false);
  assert.match(reply.error, /malformed output/);
  assert.match(reply.error, /releasing the rejected open's stream handle failed: release exploded/);
  assert.deepEqual(leaky.released, [5]);
});

test("close waits for the in-flight page, and the page reply comes first", async () => {
  const transport = new Transport();
  let releasePage;
  const released = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slowpage",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 9 } }),
        page: (stream, index) =>
          new Promise(resolve => {
            releasePage = () => resolve({ bdf: new Uint8Array([index]), warnings: [] });
          }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async handle => {
          released.push(handle.resource);
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 360, type: "open", data: new ArrayBuffer(0), options: { format: "slowpage" } });
  const stream = transport.reply(360).result.stream;
  const pendingPage = host.handle({ id: 361, type: "page", stream, index: 3 });
  const pendingClose = host.handle({ id: 362, type: "close", stream });
  await settle();
  // the close must not free the handle while the page still uses it
  assert.deepEqual(released, [], "the handle is not released under an active call");
  releasePage();
  await Promise.all([pendingPage, pendingClose]);
  const order = transport.replies.map(reply => reply.id).filter(id => id !== 0 && id !== 360);
  assert.deepEqual(order, [361, 362], "the page answer precedes the close answer");
  assert.deepEqual(released, [9], "the handle is released exactly once, after the in-flight page");
  assert.equal(host.streamCount, 0);
  await host.handle({ id: 363, type: "page", stream, index: 0 });
  assert.equal(transport.reply(363).error, "no conversion 1");
});

test("a page dispatched after close started is stale, not lost", async () => {
  const transport = new Transport();
  let releaseClose;
  const released = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slowclose",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 3 } }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async handle => {
          released.push(handle.resource);
          await new Promise(resolve => {
            releaseClose = resolve;
          });
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 370, type: "open", data: new ArrayBuffer(0), options: { format: "slowclose" } });
  const stream = transport.reply(370).result.stream;
  const pendingClose = host.handle({ id: 371, type: "close", stream });
  await settle();
  // the close is running; a late page on this stream must be refused, and
  // must never run against the handle being released
  await host.handle({ id: 372, type: "page", stream, index: 0 });
  assert.equal(transport.reply(372).error, "no conversion 1");
  releaseClose();
  await pendingClose;
  assert.deepEqual(released, [3]);
  assert.deepEqual(transport.reply(371), { id: 371, ok: true, result: null });
});

test("dispose waits for in-flight stream calls before releasing handles", async () => {
  const transport = new Transport();
  let releasePage;
  const released = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slowfinish",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 11 } }),
        page: () =>
          new Promise(resolve => {
            releasePage = () => resolve({ bdf: new Uint8Array(1), warnings: [] });
          }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async handle => {
          released.push(handle.resource);
        },
      },
    ],
  });
  const { host } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 380, type: "open", data: new ArrayBuffer(0), options: { format: "slowfinish" } });
  const stream = transport.reply(380).result.stream;
  const pendingPage = host.handle({ id: 381, type: "page", stream, index: 0 });
  const disposal = host.dispose("teardown");
  await settle();
  assert.deepEqual(released, [], "dispose does not release a handle under an active call");
  releasePage();
  await Promise.all([pendingPage, disposal]);
  assert.deepEqual(released, [11], "the handle is released exactly once after the in-flight call");
  const afterDispose = transport.replies.map(reply => reply.id).filter(id => id === 381);
  assert.deepEqual(afterDispose, [], "a reply after dispose is still dropped");
});

///|
// Independent-review blocker: a wire close deletes the lease before awaiting
// the plugin's (async) disposeStream, so a racing host.dispose saw no stream,
// called the plugin's dispose and resolved while the stream cleanup was still
// running. Disposal must wait for in-flight releases before plugin dispose.
test("host disposal waits for an in-flight stream release before disposing plugins", async () => {
  const events = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slowclean",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 42 } }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          events.push("stream-dispose-start");
          await new Promise(resolve => setTimeout(resolve, 25));
          events.push("stream-dispose-end");
        },
        dispose: async () => {
          events.push("plugin-dispose");
        },
      },
    ],
  });
  const { host, transport } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "slowclean" } });
  const stream = transport.reply(1).result.stream;
  // the close releases the lease and starts the slow async disposeStream...
  const closing = host.handle({ id: 2, type: "close", stream });
  // ...and the disposal races it from the next tick
  const disposal = host.dispose("teardown");
  await Promise.all([closing, disposal]);
  assert.ok(
    events.indexOf("stream-dispose-end") < events.indexOf("plugin-dispose"),
    `plugin dispose must wait for the stream release; got ${events.join(" -> ")}`,
  );
  assert.ok(
    events.indexOf("plugin-dispose") < events.length,
    "the plugin dispose must run at all",
  );
  assert.equal(events.filter(event => event === "stream-dispose-start").length, 1, "the stream is released exactly once");
});

test("a racing close and host disposal together release the handle once, in order", async () => {
  const events = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "raceclean",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 2, stream: { resource: 7 } }),
        page: async () => {
          await new Promise(resolve => setTimeout(resolve, 10));
          return { bdf: new Uint8Array(1), warnings: [] };
        },
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          events.push("stream-dispose-start");
          await new Promise(resolve => setTimeout(resolve, 25));
          events.push("stream-dispose-end");
        },
        dispose: async () => {
          events.push("plugin-dispose");
        },
      },
    ],
  });
  const { host, transport } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "raceclean" } });
  const stream = transport.reply(1).result.stream;
  const inFlightPage = host.handle({ id: 2, type: "page", stream, index: 0 });
  const closing = host.handle({ id: 3, type: "close", stream });
  const disposal = host.dispose("teardown");
  await Promise.all([inFlightPage, closing, disposal]);
  assert.equal(events.filter(event => event === "stream-dispose-start").length, 1, "exactly one release under a close/dispose race");
  assert.ok(
    events.indexOf("stream-dispose-end") < events.indexOf("plugin-dispose"),
    `plugin dispose must wait for the stream release; got ${events.join(" -> ")}`,
  );
});

///|
// Independent-review blocker: a wire close whose async disposeStream REJECTS
// while the host disposal races it used to be swallowed — disposed=true made
// the close's catch drop the error, and the disposal report showed neither
// the release nor its failure (released: [], plugins all ok). The disposal
// report must carry the release settlement result.
test("a close-disposer failure racing host disposal is reported, not swallowed", async () => {
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "failingclean",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 5 } }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          await new Promise(resolve => setTimeout(resolve, 20));
          const error = new Error("disposer exploded during disposal");
          error.code = "dispose-boom";
          throw error;
        },
        dispose: async () => {},
      },
    ],
  });
  const { host, transport } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "failingclean" } });
  const stream = transport.reply(1).result.stream;
  const closing = host.handle({ id: 2, type: "close", stream });
  const report = await Promise.all([host.dispose("teardown"), closing]).then(([disposed]) => disposed);
  const releases = report.released.filter(entry => entry.name === "failingclean");
  assert.equal(releases.length, 1, "the racing stream release appears in the disposal report");
  assert.equal(releases[0].ok, false, "the failing release is reported as failed");
  assert.match(releases[0].error ?? "", /disposer exploded during disposal/);
  // the failure is visible exactly once: the dropped close reply is no
  // longer the only place it existed
  const posts = transport.replies.filter(reply => reply.id === 2);
  assert.deepEqual(posts, [], "the wire close reply stays dropped after disposal began");
});

///|
// Independent-review blocker: a tracked release (a wire close's disposer)
// that settled while the disposal was still waiting for ANOTHER lease's
// in-flight call was removed from the pending set the moment it settled,
// and awaitReleases — which only ran after the drain — collected nothing.
// The first lease's release failure vanished from the report. A settled
// record must be kept until the disposal collects it.
test("a close disposer failing while disposal drains another lease stays in the report", async () => {
  let rejectFirst;
  let releasePage;
  let handles = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "twoleases",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => {
          handles += 1;
          return { bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: handles } };
        },
        page: async () => new Promise(resolve => {
          // the in-flight call of the second lease: controlled by the test
          releasePage = resolve;
        }).then(() => ({ bdf: new Uint8Array(1), warnings: [] })),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async stream => {
          if (stream.resource === 1) {
            // the first lease's disposer: settles only when the test drives it
            await new Promise((_, reject) => {
              rejectFirst = reject;
            });
            throw new Error("first close disposer failed mid-drain");
          }
        },
        dispose: async () => {},
      },
    ],
  });
  const { host, transport } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "twoleases" } });
  await host.handle({ id: 2, type: "open", data: new ArrayBuffer(0), options: { format: "twoleases" } });
  const first = transport.reply(1).result.stream;
  const second = transport.reply(2).result.stream;
  // the second lease keeps one call in flight: the disposal must wait for it
  const inFlightPage = host.handle({ id: 3, type: "page", stream: second, index: 0 });
  await settle();
  await settle();
  assert.ok(releasePage, "the second lease's call is in flight");
  // the first lease gets a wire close whose async disposer stays pending
  const closing = host.handle({ id: 4, type: "close", stream: first });
  await settle();
  await settle();
  assert.ok(rejectFirst, "the first lease's disposer started");
  // the disposal begins and parks on the second lease's in-flight call...
  const disposal = host.dispose("teardown");
  await settle();
  // ...while it parks, the first release settles as a FAILURE
  rejectFirst(new Error("first close disposer failed mid-drain"));
  await settle();
  await settle();
  releasePage();
  const report = await disposal;
  await Promise.all([inFlightPage, closing]);
  const failed = report.released.find(entry => entry.id === first);
  assert.ok(failed, `the mid-drain release failure must be in the report: ${JSON.stringify(report.released)}`);
  assert.equal(failed.ok, false, "the release failure is reported as failed");
  assert.match(failed.error ?? "", /first close disposer failed mid-drain/);
  assert.equal(failed.how, "wire-close");
});

///|
// Independent-review blocker: releaseClaimedHandle caught the disposer's
// error and returned it as a FULFILLED value, so the tracked release settled
// as a success: a rejected open's cleanup failure racing the disposal was
// reported as {ok:true} (or lost), never as the failure it was. The tracked
// release must carry an explicit outcome, and a rejection must read as a
// rejection.
test("a rejected open's cleanup failure racing disposal is reported as failed", async () => {
  let rejectCleanup;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "leakyclean",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        // zero pages with a stream handle: malformed on purpose, and the
        // claimed handle must still be cleaned up
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 0, stream: { resource: 9 } }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          await new Promise((_, reject) => {
            rejectCleanup = reject;
          });
        },
        dispose: async () => {},
      },
    ],
  });
  const { host, transport } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  const opening = host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "leakyclean" } });
  await settle();
  await settle();
  assert.ok(rejectCleanup, "the malformed open claimed its handle and started its cleanup");
  const disposal = host.dispose("teardown");
  await settle();
  rejectCleanup(new Error("rejected-open cleanup exploded"));
  const report = await disposal;
  await opening;
  const entry = report.released.find(item => item.name === "leakyclean");
  assert.ok(entry, `the racing rejected-open cleanup is in the report: ${JSON.stringify(report.released)}`);
  assert.equal(entry.ok, false, "a cleanup failure must not settle as ok");
  assert.match(entry.error ?? "", /rejected-open cleanup exploded/);
  assert.equal(entry.how, "rejected-open");
  // the rejected open's error is dropped (the host is disposed); the report
  // is the only place its cleanup failure exists, and it holds the exact text
  assert.deepEqual(transport.replies.filter(reply => reply.id === 1), []);
});

///|
// Independent-review blocker: an in-flight page (or finish) that failed
// after the disposal began used to reach the report as a success: the
// serialization chain swallows each settled operation failure by design
// (the queue must keep running), and the disposal read the drained outcome
// from that same swallowed chain. The lease keeps the last settled
// operation's failure separately now, and the disposal report carries it.
test("a page failing during the disposal drain is reported, not recorded as ok", async () => {
  const transport = new Transport();
  let releasePage;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "drainedpage",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 3 } }),
        page: () => new Promise(resolve => {
          releasePage = resolve;
        }).then(() => {
          throw new Error("page exploded after dispose began");
        }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {},
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "drainedpage" } });
  const stream = replies.reply(1).result.stream;
  const pendingPage = host.handle({ id: 2, type: "page", stream, index: 0 });
  await settle();
  await settle();
  assert.ok(releasePage, "the page is in flight");
  const disposal = host.dispose("teardown");
  await settle();
  // the disposal is parked draining the page: it fails NOW
  releasePage();
  const report = await disposal;
  await pendingPage;
  assert.equal(report.released.length, 1, `exactly one release in the report: ${JSON.stringify(report.released)}`);
  const entry = report.released[0];
  assert.equal(entry.id, stream);
  assert.equal(entry.ok, false, "the drained call's failure must not become a success");
  assert.match(entry.error ?? "", /drained in-flight call failed: .*page exploded after dispose began/);
  // the page's reply was dropped (no reader once disposal began)
  assert.deepEqual(replies.replies.filter(reply => reply.id === 2), []);
});

///|
// Same blocker, finish path: the failure of an in-flight finish must be
// reported identically.
test("a finish failing during the disposal drain is reported, not recorded as ok", async () => {
  const transport = new Transport();
  let releaseFinish;
  let finishCount = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "drainedfinish",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 4 } }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: () => new Promise(resolve => {
          finishCount += 1;
          releaseFinish = resolve;
        }).then(() => {
          throw new Error("finish exploded after dispose began");
        }),
        disposeStream: async () => {},
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "drainedfinish" } });
  const stream = replies.reply(1).result.stream;
  const pendingFinish = host.handle({ id: 2, type: "finish", stream });
  await settle();
  await settle();
  assert.equal(finishCount, 1, "the finish is in flight");
  const disposal = host.dispose("teardown");
  await settle();
  releaseFinish();
  const report = await disposal;
  await pendingFinish;
  assert.equal(report.released.length, 1, JSON.stringify(report.released));
  assert.equal(report.released[0].ok, false, "the drained finish failure must not become a success");
  assert.match(report.released[0].error ?? "", /finish exploded after dispose began/);
});

///|
// The failure must not break the serialized queue: a failed operation that
// gets its error reply is answered normally, and the next operation on the
// same lease still runs.
test("a failed stream operation answers its error and the queue continues", async () => {
  const transport = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "queuekeeps",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 5 } }),
        page: async () => {
          throw new Error("page failed loudly");
        },
        finish: async () => ({ bdf: new Uint8Array(1), summary: "finished after a failure" }),
        disposeStream: async () => {},
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "queuekeeps" } });
  const stream = replies.reply(1).result.stream;
  await host.handle({ id: 2, type: "page", stream, index: 0 });
  assert.equal(replies.reply(2).ok, false);
  assert.match(replies.reply(2).error ?? "", /page failed loudly/);
  await host.handle({ id: 3, type: "finish", stream });
  assert.equal(replies.reply(3).ok, true, "the queue must continue after a failed operation");
  assert.equal(replies.reply(3).result.summary, "finished after a failure");
});

///|
// Independent-review ordering: a wire close and the disposal both wait for an
// in-flight operation that then fails. The lease is released exactly once
// (by the close), the disposal skips it, and the operation failure lands in
// the report exactly once — through the close's release outcome.
test("a close racing the disposal with a failing in-flight operation reports it exactly once", async () => {
  const events = [];
  let releasePage;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "racefailop",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 6 } }),
        page: () => new Promise(resolve => {
          releasePage = resolve;
        }).then(() => {
          throw new Error("racing operation failed");
        }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          events.push("stream-dispose");
        },
        dispose: async () => {
          events.push("plugin-dispose");
        },
      },
    ],
  });
  const { host: h, transport: replies } = makeHost({ registry, transport: new Transport() });
  await h.handle({ type: "init" });
  await h.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "racefailop" } });
  const stream = replies.reply(1).result.stream;
  const pendingPage = h.handle({ id: 2, type: "page", stream, index: 0 });
  await settle();
  await settle();
  const closing = h.handle({ id: 3, type: "close", stream });
  await settle();
  await settle();
  const disposal = h.dispose("teardown");
  await settle();
  releasePage(); // the operation fails while BOTH the close and disposal drain it
  const report = await Promise.all([disposal, closing, pendingPage]).then(([result]) => result);
  assert.equal(events.filter(event => event === "stream-dispose").length, 1, "the stream is released exactly once");
  assert.equal(events.indexOf("plugin-dispose") > -1, true);
  const leaseEntries = report.released.filter(entry => entry.id === stream);
  assert.equal(leaseEntries.length, 1, `the release is reported exactly once: ${JSON.stringify(report.released)}`);
  assert.equal(leaseEntries[0].how, "wire-close", "the close's tracked release carries the lease");
  assert.equal(leaseEntries[0].ok, false, "the racing operation failure is carried");
  assert.match(leaseEntries[0].error ?? "", /racing operation failed/);
});

///|
// Independent-review blocker: an open (or convert) that began BEFORE the
// disposal and settles after it used to be cleaned after plugin dispose, its
// records landing nowhere (`released: []`, silent plugin outcomes, no reply).
// Teardown now waits for operations begun before the disposal — no
// cancellation, no timeout — and their cleanup outcomes and failures are
// part of the same report.
test("an in-flight open settles before teardown: cleanup in the report, plugin dispose strictly last", async () => {
  const events = [];
  let resolveOpen;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "latevalidopen",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: () => new Promise(resolve => {
          resolveOpen = () => resolve({ bdf: new Uint8Array(1), summary: "late", warnings: [], pages: 1, stream: { id: "h9" } });
        }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async handle => {
          events.push(`stream:${handle.id}`);
        },
        dispose: async () => {
          events.push("plugin-dispose");
        },
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  const pendingOpen = host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "latevalidopen" } });
  await settle();
  await settle();
  assert.ok(resolveOpen, "the open is in flight");
  const disposal = host.dispose("teardown");
  await settle();
  assert.equal(events.length, 0, "teardown has not torn the plugin down yet");
  resolveOpen();
  const report = await disposal;
  await pendingOpen;
  // teardown order: the late open's handle cleanup happens BEFORE plugin dispose
  assert.deepEqual(events, ["stream:h9", "plugin-dispose"], `teardown order broke: ${events.join(" -> ")}`);
  const entry = report.released.find(item => item.how === "post-dispose");
  assert.ok(entry, `the late open's cleanup is in the report: ${JSON.stringify(report)}`);
  assert.equal(entry.ok, true);
  assert.deepEqual(replies.replies.filter(reply => reply.id === 1), [], "the late open never answered");
});

///|
// The late open resolving with a MALFORMED result: the primary failure is
// recorded among the dropped calls, and a cleanup disposer that throws is
// reported as a failed release — both exactly once.
test("a late invalid open: primary failure dropped-recorded, cleanup failure reported", async () => {
  let resolveOpen;
  let cleanups = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "lateinvalidopen",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: () => new Promise(resolve => {
          resolveOpen = () => resolve({ bdf: new Uint8Array(1), summary: "late", warnings: [], pages: 0, stream: { id: "h10" } });
        }),
        page: async () => ({ bdf: new Uint8Array(1), warnings: [] }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          cleanups += 1;
          throw new Error("late cleanup disposer exploded");
        },
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  const pendingOpen = host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "lateinvalidopen" } });
  await settle();
  await settle();
  const disposal = host.dispose("teardown");
  await settle();
  resolveOpen(); // malformed on purpose: zero pages with a handle
  const report = await disposal;
  await pendingOpen;
  assert.equal(cleanups, 1, "the claimed handle was cleaned exactly once");
  const cleanupEntry = report.released.find(item => item.how === "rejected-open");
  assert.ok(cleanupEntry, `the cleanup is in the report: ${JSON.stringify(report)}`);
  assert.equal(cleanupEntry.ok, false, "a failing cleanup is a failed release");
  assert.match(cleanupEntry.error ?? "", /late cleanup disposer exploded/);
  assert.ok(Array.isArray(report.dropped), "the report lists dropped calls");
  assert.equal(report.dropped.length, 1);
  assert.equal(report.dropped[0].name, "lateinvalidopen");
  assert.match(report.dropped[0].error ?? "", /stream handle must report pages/);
  assert.deepEqual(replies.replies.filter(reply => reply.id === 1), [], "the late open never answered");
});

///|
// The convert counterpart: a conversion begun before the disposal that
// fails while teardown waits lands in the report's dropped calls.
test("a failing convert racing the disposal lands in the report's dropped calls", async () => {
  let failConvert;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "slowconvert",
        description: "d",
        convert: () => new Promise((_, reject) => {
          failConvert = () => reject(new Error("convert exploded during teardown"));
        }),
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport: new Transport() });
  await host.handle({ type: "init" });
  const pendingConvert = host.handle({ id: 1, type: "convert", data: new ArrayBuffer(0), options: { format: "slowconvert" } });
  await settle();
  await settle();
  assert.ok(failConvert, "the convert is in flight");
  const disposal = host.dispose("teardown");
  await settle();
  failConvert();
  const report = await Promise.all([disposal, pendingConvert.catch(() => undefined)]).then(([result]) => result);
  assert.ok(Array.isArray(report.dropped), "the report lists dropped calls");
  assert.deepEqual(report.dropped, [
    { name: "slowconvert", type: "convert", id: 1, error: "convert exploded during teardown" },
  ]);
  assert.deepEqual(report.released, []);
  assert.deepEqual(replies.replies.filter(reply => reply.id === 1), [], "the racing convert never answered");
});



///|
// Exactly-once guard: an operation that failed BEFORE the disposal and was
// answered with its error reply must not be reported again. The kept
// failure belongs to the report only from the moment the disposal took the
// reply, so a naive "always report the drained failure" variant fails here.
test("an operation failure answered before disposal is reported to its caller only", async () => {
  const transport = new Transport();
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "answeredearly",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 7 } }),
        page: async () => {
          throw new Error("page failed before disposal");
        },
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {},
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "answeredearly" } });
  const stream = replies.reply(1).result.stream;
  await host.handle({ id: 2, type: "page", stream, index: 0 });
  const answered = replies.reply(2);
  assert.equal(answered.ok, false, "the failure is answered on the wire");
  assert.match(answered.error ?? "", /page failed before disposal/);
  const report = await host.dispose("teardown");
  // the lease still needed disposal, but its release is a clean one: the
  // failure above was already delivered, so it must not appear again
  assert.equal(report.released.length, 1, JSON.stringify(report.released));
  assert.equal(report.released[0].id, stream);
  assert.equal(report.released[0].ok, true);
  assert.equal(report.released[0].error, null);
  assert.equal(report.dropped.length, 0, JSON.stringify(report.dropped));
  assert.equal(
    JSON.stringify(report).split("page failed before disposal").length - 1,
    0,
    "the answered failure must not be reported a second time",
  );
});

///|
// The drained failures of one lease must not vanish while the disposal
// drains another lease: two leases, both with in-flight failures, the
// second settling while the first still parks the loop.
test("drained failures of two leases are each reported exactly once", async () => {
  const transport = new Transport();
  const deferreds = new Map();
  let handles = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "twofailing",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => {
          handles += 1;
          return { bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: handles } };
        },
        page: stream => new Promise((_, reject) => {
          deferreds.set(stream.resource, () => reject(new Error(`page ${stream.resource} failed while draining`)));
        }).then(() => ({ bdf: new Uint8Array(1), warnings: [] })),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {},
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "twofailing" } });
  await host.handle({ id: 2, type: "open", data: new ArrayBuffer(0), options: { format: "twofailing" } });
  const first = replies.reply(1).result.stream;
  const second = replies.reply(2).result.stream;
  const pendingFirst = host.handle({ id: 3, type: "page", stream: first, index: 0 });
  const pendingSecond = host.handle({ id: 4, type: "page", stream: second, index: 0 });
  await settle();
  await settle();
  assert.equal(deferreds.size, 2, "both pages are in flight");
  const disposal = host.dispose("teardown");
  await settle();
  // lease 2's failure settles while the disposal still parks on lease 1's
  deferreds.get(2)();
  await settle();
  deferreds.get(1)();
  const report = await Promise.all([disposal, pendingFirst, pendingSecond]).then(([result]) => result);
  const textOne = JSON.stringify(report).split("page 1 failed while draining").length - 1;
  const textTwo = JSON.stringify(report).split("page 2 failed while draining").length - 1;
  assert.equal(textOne, 1, "lease 1's drained failure is reported exactly once");
  assert.equal(textTwo, 1, "lease 2's drained failure is reported exactly once");
  assert.deepEqual(report.released.map(entry => entry.id).sort(), [first, second].sort());
  for (const entry of report.released) {
    assert.equal(entry.ok, false, `drained failures must not be successes: ${JSON.stringify(entry)}`);
  }
});

///|
// A stream disposer failure AND a drained in-flight failure on the same
// lease: neither error may overwrite the other.
test("a disposer failure and a drained call failure are both reported", async () => {
  const transport = new Transport();
  let failPage;
  let streamDisposals = 0;
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "doublefail",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        open: async () => ({ bdf: new Uint8Array(1), summary: "s", warnings: [], pages: 1, stream: { resource: 8 } }),
        page: () => new Promise(resolve => {
          failPage = resolve;
        }).then(() => {
          throw new Error("drained operation failed too");
        }),
        finish: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        disposeStream: async () => {
          streamDisposals += 1;
          throw new Error("stream disposer exploded");
        },
        dispose: async () => {},
      },
    ],
  });
  const { host, transport: replies } = makeHost({ registry, transport });
  await host.handle({ type: "init" });
  await host.handle({ id: 1, type: "open", data: new ArrayBuffer(0), options: { format: "doublefail" } });
  const stream = replies.reply(1).result.stream;
  const pendingPage = host.handle({ id: 2, type: "page", stream, index: 0 });
  await settle();
  await settle();
  const disposal = host.dispose("teardown");
  await settle();
  failPage();
  const report = await Promise.all([disposal, pendingPage]).then(([result]) => result);
  assert.equal(streamDisposals, 1, "the handle is disposed exactly once");
  assert.equal(report.released.length, 1, JSON.stringify(report.released));
  const entry = report.released[0];
  assert.equal(entry.ok, false);
  const error = entry.error ?? "";
  assert.match(error, /stream disposer exploded/, "the disposer failure must survive");
  assert.match(error, /drained operation failed too/, "the drained failure must survive");
});
