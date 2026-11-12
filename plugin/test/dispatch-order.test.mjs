// Narrow regression tests for dispatch acceptance ordering in the converter
// host: an accepted convert/open is registered in the host's active-call set
// before any plugin code runs, so a disposal started immediately after the
// accept still awaits the in-flight work, its cleanup, and its failure
// accounting — in that order — before the disposal report settles.
// Plain synthetic plugins only: plugin callbacks record events and hand back
// externally settled promises. No test reaches back into the host from
// plugin code (synchronous reentrancy), and none drives teardown from inside
// a plugin callback.

import assert from "node:assert/strict";
import { test } from "node:test";

import { createFormatRegistry } from "../src/registry.js";
import { createConverterHost } from "../src/host.js";
import { Transport } from "./helpers.mjs";

const settle = () => new Promise(resolve => setImmediate(resolve));

// Wait until a plain synthetic callback has started and handed back its
// settle function, without any timeout math of its own.
async function untilStarted(started, what) {
  const deadline = Date.now() + 5000;
  while (started.value === null && Date.now() < deadline) {
    await settle();
  }
  assert.ok(started.value !== null, `${what} never started`);
  return started.value;
}

function makeHost(plugin) {
  const transport = new Transport();
  const registry = createFormatRegistry({ plugins: [plugin] });
  const host = createConverterHost({ registry, postMessage: transport.postMessage });
  return { host, transport };
}

const repliesTo = (transport, id) => transport.replies.filter(reply => reply.id === id);

test("immediate disposal after an accepted convert awaits the plugin, then reports teardown", async () => {
  const events = [];
  const started = { value: null };
  const plugin = {
    apiVersion: 1,
    name: "slow",
    description: "slow test format",
    extensions: [],
    detect: bytes => new TextDecoder().decode(bytes) === "slow:input",
    convert: bytes => {
      events.push("convert-start");
      return new Promise(resolve => { started.value = resolve; });
    },
    dispose: async () => { events.push("plugin-disposed"); },
  };
  const { host, transport } = makeHost(plugin);
  await host.handle({ type: "init" });

  const handled = host.handle({
    id: 1,
    type: "convert",
    data: new TextEncoder().encode("slow:input"),
    options: {},
  });
  assert.deepEqual(events, [], "plugin invocation is deferred until after dispatch registration");
  // an ordinary external disposal, started immediately after the accept
  const disposal = host.dispose("test: immediate dispose after accept");
  let reported = false;
  const reportDone = disposal.then(report => {
    reported = true;
    return report;
  });

  // the accepted call still runs, although the disposal already started
  const finish = await untilStarted(started, "convert");
  assert.equal(reported, false, "the disposal report must wait for the accepted convert");

  finish({ bdf: new Uint8Array([1, 2, 3]), summary: "converted", warnings: [] });
  const report = await reportDone;
  await handled;

  // completion ordering: the accepted convert settles, then plugin teardown
  assert.deepEqual(events, ["convert-start", "plugin-disposed"]);
  // the disposal took the reply channel: no reply for the accepted call
  assert.equal(repliesTo(transport, 1).length, 0);
  assert.deepEqual(report.dropped, []);
  assert.ok(report.plugins.some(outcome => outcome.name === "slow" && outcome.ok === true),
    "the report must carry the plugin's dispose outcome");
});

test("immediate disposal after an accepted open releases its claimed stream once, after the open settles", async () => {
  const events = [];
  const started = { value: null };
  const stream = { tag: "stream-1" };
  const plugin = {
    apiVersion: 1,
    name: "opened",
    description: "opened test format",
    extensions: [],
    detect: bytes => new TextDecoder().decode(bytes) === "open:input",
    convert: async bytes => ({ bdf: bytes.slice(), summary: "converted", warnings: [] }),
    open: bytes => {
      events.push("open-start");
      return new Promise(resolve => { started.value = resolve; });
    },
    disposeStream: async handle => {
      events.push(`disposeStream:${handle.tag}`);
    },
    // open requires page/finish in the same descriptor; these tests never
    // reach them, so plain stubs
    page: async () => ({ bdf: new Uint8Array(0), warnings: [] }),
    finish: async () => ({ bdf: new Uint8Array(0), summary: "f", warnings: [] }),
    dispose: async () => { events.push("plugin-disposed"); },
  };
  const { host, transport } = makeHost(plugin);
  await host.handle({ type: "init" });

  const handled = host.handle({
    id: 1,
    type: "open",
    data: new TextEncoder().encode("open:input"),
    options: {},
  });
  const disposal = host.dispose("test: immediate dispose after accept");
  let reported = false;
  const reportDone = disposal.then(report => {
    reported = true;
    return report;
  });

  const finish = await untilStarted(started, "open");
  assert.equal(reported, false, "the disposal report must wait for the accepted open");

  finish({
    bdf: new Uint8Array([9, 8]),
    summary: "opened",
    warnings: [],
    pages: 2,
    stream,
  });
  const report = await reportDone;
  await handled;

  // ordering: open settles, the claimed handle is released, then the plugin
  // tears down; the release happened exactly once
  assert.deepEqual(events, ["open-start", "disposeStream:stream-1", "plugin-disposed"]);
  assert.equal(repliesTo(transport, 1).length, 0);
  const released = report.released.filter(entry => entry.name === "opened");
  assert.equal(released.length, 1, "exactly one release record for the claimed handle");
  assert.equal(released[0].ok, true, released[0].error);
  assert.equal(released[0].how, "post-dispose");
  assert.deepEqual(report.dropped, []);
  assert.ok(report.plugins.some(outcome => outcome.name === "opened" && outcome.ok === true));
});

test("a convert failure settling under immediate disposal is kept in the report, not lost", async () => {
  const events = [];
  const started = { value: null };
  const plugin = {
    apiVersion: 1,
    name: "later-fails",
    description: "later failing test format",
    extensions: [],
    detect: bytes => new TextDecoder().decode(bytes) === "fail:input",
    convert: bytes => {
      events.push("convert-start");
      return new Promise((resolve, reject) => { started.value = reject; });
    },
    dispose: async () => { events.push("plugin-disposed"); },
  };
  const { host, transport } = makeHost(plugin);
  await host.handle({ type: "init" });

  const handled = host.handle({
    id: 7,
    type: "convert",
    data: new TextEncoder().encode("fail:input"),
    options: {},
  });
  const disposal = host.dispose("test: immediate dispose after accept");
  let reported = false;
  const reportDone = disposal.then(report => {
    reported = true;
    return report;
  });

  const finish = await untilStarted(started, "convert");
  assert.equal(reported, false, "the disposal report must wait for the failing convert");

  finish(new Error("late failure"));
  const report = await reportDone;
  // the disposal took the reply, and the host suppresses the rejection it
  // has no channel for: the handled call settles quietly
  await handled;

  assert.deepEqual(events, ["convert-start", "plugin-disposed"]);
  assert.equal(repliesTo(transport, 7).length, 0);
  // the failure the disposal took is the report's to keep
  assert.deepEqual(report.dropped, [
    { name: "later-fails", type: "convert", id: 7, error: "late failure" },
  ]);
});

test("an accepted open whose result is malformed is cleaned up once under immediate disposal", async () => {
  const events = [];
  const started = { value: null };
  const stream = { tag: "stream-2" };
  const plugin = {
    apiVersion: 1,
    name: "malopened",
    description: "malformed open test format",
    extensions: [],
    detect: bytes => new TextDecoder().decode(bytes) === "mal:input",
    convert: async bytes => ({ bdf: bytes.slice(), summary: "converted", warnings: [] }),
    open: bytes => {
      events.push("open-start");
      return new Promise(resolve => { started.value = resolve; });
    },
    disposeStream: async handle => {
      events.push(`disposeStream:${handle.tag}`);
    },
    page: async () => ({ bdf: new Uint8Array(0), warnings: [] }),
    finish: async () => ({ bdf: new Uint8Array(0), summary: "f", warnings: [] }),
    dispose: async () => { events.push("plugin-disposed"); },
  };
  const { host, transport } = makeHost(plugin);
  await host.handle({ type: "init" });

  const handled = host.handle({
    id: 2,
    type: "open",
    data: new TextEncoder().encode("mal:input"),
    options: {},
  });
  const disposal = host.dispose("test: immediate dispose after accept");
  let reported = false;
  const reportDone = disposal.then(report => {
    reported = true;
    return report;
  });
  const finish = await untilStarted(started, "open");

  // malformed: a stream handle with a page count, but no bdf bytes
  finish({ summary: "opened", warnings: [], pages: 1, stream });
  const report = await reportDone;
  await handled;

  assert.deepEqual(events, ["open-start", "disposeStream:stream-2", "plugin-disposed"]);
  assert.equal(repliesTo(transport, 2).length, 0);
  // the rejected open's cleanup is one tracked release, reported ok
  const released = report.released.filter(entry => entry.name === "malopened");
  assert.equal(released.length, 1, "exactly one release record for the rejected open");
  assert.equal(released[0].ok, true, released[0].error);
  assert.equal(released[0].how, "rejected-open");
  // the malformed output's failure is kept with the call that lost its reply
  assert.equal(report.dropped.length, 1);
  assert.equal(report.dropped[0].name, "malopened");
  assert.equal(report.dropped[0].type, "open");
  assert.equal(report.dropped[0].id, 2);
  assert.match(report.dropped[0].error, /malformed output/);
});
