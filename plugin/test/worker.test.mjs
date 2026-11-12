import assert from "node:assert/strict";
import { test } from "node:test";

import { PluginError } from "../src/contract.js";
import { createConverterHost } from "../src/host.js";
import { createFormatRegistry } from "../src/registry.js";
import { docuworksPlugin } from "../src/adapters/docuworks.js";
import { installPluginConverterWorker } from "../src/worker.js";
import { Transport } from "./helpers.mjs";

const delegate = () => ({
  detect: bytes => bytes[0] === 0x60,
  convert: async bytes => ({ bdf: bytes.slice(), summary: "DocuWorks", warnings: [] }),
});

test("installer validates every plugin before touching the target", () => {
  const first = docuworksPlugin({ delegate: delegate() });
  const target = {};
  assert.throws(
    () => installPluginConverterWorker([first, { apiVersion: 2, name: "x", description: "d", convert: () => ({}) }], {
      target,
      postMessage: () => {},
    }),
    error => error instanceof PluginError && error.message.includes("plugin [1]:"),
  );
  assert.equal(target.onmessage, undefined, "a failed startup leaves no handler installed");
});

test("installer refuses serialized-code plugins, exactly like registration", () => {
  assert.throws(
    () =>
      installPluginConverterWorker([{ apiVersion: 1, name: "shipped", description: "d", convert: "()" }], {
        target: {},
        postMessage: () => {},
      }),
    /operation "convert" must be a function, not string/,
  );
  assert.throws(() => installPluginConverterWorker("nope"), /expects an array/);
  // a target with no working transport cannot install a host
  assert.throws(() => createConverterHost({ registry: createFormatRegistry(), postMessage: undefined }), PluginError);
});

test("installer refuses a target that already owns onmessage", () => {
  const taken = { onmessage: () => {} };
  assert.throws(
    () =>
      installPluginConverterWorker([docuworksPlugin({ delegate: delegate() })], {
        target: taken,
        postMessage: () => {},
      }),
    /already has an onmessage handler/,
  );
});

test("an installed host answers the envelope over the target's message events", async () => {
  const transport = new Transport();
  const target = {};
  const host = installPluginConverterWorker([docuworksPlugin({ delegate: delegate() })], {
    target,
    postMessage: transport.postMessage,
  });
  assert.equal(typeof target.onmessage, "function");
  target.onmessage({ data: { type: "init" } });
  await new Promise(resolve => setImmediate(resolve));
  assert.deepEqual(transport.replies.at(-1), {
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
  });
  target.onmessage({ data: { id: 9, type: "register", plugins: [] } });
  await new Promise(resolve => setImmediate(resolve));
  assert.equal(transport.replies.at(-1).error, "registration is only available at worker startup");
  target.onmessage({ data: { id: 10, type: "convert", data: new Uint8Array([0x60, 1]).buffer, options: {} } });
  await new Promise(resolve => setTimeout(resolve, 20));
  const reply = transport.replies.find(message => message.id === 10);
  assert.equal(reply.ok, true);
  assert.equal(reply.result.format, "xdw");
  const report = await host.dispose("worker teardown");
  assert.equal(report.reason, "worker teardown");
});

///|
// A duplicate claim between two startup plugins stops the install with both
// named: no partially-initialized host exists.
test("duplicate startup registrations abort the whole install", () => {
  assert.throws(
    () =>
      installPluginConverterWorker(
        [docuworksPlugin({ delegate: delegate() }), docuworksPlugin({ delegate: delegate() })],
        { target: {}, postMessage: () => {} },
      ),
    /claims format name "xdw", already claimed by plugin "xdw" \(worker\)/,
  );
});
