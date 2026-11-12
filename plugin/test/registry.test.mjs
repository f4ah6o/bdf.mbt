import assert from "node:assert/strict";
import { test } from "node:test";

import { ConvertError, PluginError } from "../src/contract.js";
import { createFormatRegistry } from "../src/registry.js";
import { docuworksPlugin } from "../src/adapters/docuworks.js";
import { makePlugin, mulberry32, text } from "./helpers.mjs";

const docuworks = () => docuworksPlugin({
  delegate: {
    detect: bytes => bytes[0] === 0x60,
    convert: async bytes => ({ bdf: bytes.slice(), summary: "xdw", warnings: [] }),
  },
});

test("explicit registration reports what the registry holds", () => {
  const registry = createFormatRegistry();
  registry.register(docuworks(), "builtin");
  assert.equal(registry.length, 1);
  assert.deepEqual(registry.formats(), [
    {
      name: "xdw",
      description:
        "DocuWorks document (vector and scanned pages with annotations; binder .xbd)",
      extensions: [".xdw", ".xbd"],
    },
  ]);
  assert.deepEqual(registry.registrations(), [
    { source: "builtin", name: "xdw", extensions: [".xdw", ".xbd"] },
  ]);
});

test("a duplicate format name is a registration error, both parties named", () => {
  const registry = createFormatRegistry();
  registry.register(docuworks(), "builtin");
  assert.throws(
    () => registry.register(docuworks(), "downstream"),
    error =>
      error instanceof PluginError &&
      error.message.includes('"xdw"') &&
      error.message.includes("downstream") &&
      error.message.includes("builtin"),
  );
  // the failed registration leaves the registry untouched
  assert.equal(registry.length, 1);
});

test("a duplicate extension claim is a registration error", () => {
  const registry = createFormatRegistry();
  const { plugin: first } = makePlugin({ name: "first", extensions: [".dup", ".one"] });
  registry.register(first, "a");
  const { plugin: second } = makePlugin({ name: "second", extensions: [".dup"] });
  assert.throws(
    () => registry.register(second, "b"),
    error =>
      error instanceof PluginError &&
      error.message.includes('".dup"') &&
      error.message.includes('plugin "second" (b)') &&
      error.message.includes('plugin "first" (a)'),
  );
  assert.equal(registry.length, 1);
  // a claim nobody holds yet still registers, so exclusivity is not ownership
  const { plugin: third } = makePlugin({ name: "third", extensions: [".three"] });
  registry.register(third, "c");
  assert.equal(registry.length, 2);
});

test("an api version mismatch fails registration with both versions named", () => {
  const registry = createFormatRegistry();
  const future = {
    apiVersion: 2,
    name: "future",
    description: "a plugin from a newer host",
    extensions: [".future"],
    convert: async () => ({}),
  };
  assert.throws(() => registry.register(future), /api version 2, this host supports 1/);
  assert.equal(registry.length, 0);
});

test("a descriptor with serialized functions cannot be registered", () => {
  const registry = createFormatRegistry();
  assert.throws(
    () => registry.register({
      apiVersion: 1,
      name: "shipped",
      description: "arrived as data",
      extensions: [".shipped"],
      convert: "()=>{}",
    }),
    /operation "convert" must be a function, not string/,
  );
});

test("deterministic detection: detectors run before name claims", () => {
  const registry = createFormatRegistry();
  const { plugin: named } = makePlugin({ name: "named", extensions: [".named"] });
  const { plugin: sniffer } = makePlugin({ name: "sniffer", detectAccepts: new Set(["sniff-me"]) });
  registry.register(named, "named");
  registry.register(sniffer, "sniffer");
  assert.equal(registry.detect(text("sniff-me"), "file.named").plugin.name, "sniffer");
  assert.equal(registry.detect(text("nothing"), "file.named").plugin.name, "named");
  assert.equal(registry.detect(text("nothing"), "file.named").via, "name");
});

test("deterministic detection: registration order breaks detector ties", () => {
  const registryOne = createFormatRegistry();
  const registryTwo = createFormatRegistry();
  const accepts = new Set(["samekey"]);
  const first = makePlugin({ name: "first", detectAccepts: accepts });
  const second = makePlugin({ name: "second", detectAccepts: accepts });
  registryOne.register(first.plugin, "one");
  registryOne.register(second.plugin, "one");
  registryTwo.register(second.plugin, "one");
  registryTwo.register(first.plugin, "one");
  assert.equal(registryOne.detect(text("samekey")).plugin.name, "first");
  assert.equal(registryTwo.detect(text("samekey")).plugin.name, "second");
});

test("a longer extension claim wins and unclaimed names of a known form fail", () => {
  const registry = createFormatRegistry();
  registry.register(makePlugin({ name: "drawio", extensions: [".drawio.png"] }).plugin, "a");
  registry.register(makePlugin({ name: "image", extensions: [".png"] }).plugin, "b");
  assert.equal(registry.detect(text("x"), "diagram.drawio.png").plugin.name, "drawio");
  assert.equal(registry.detect(text("x"), "photo.png").plugin.name, "image");
});

test("no match is an explicit error naming the file", () => {
  const registry = createFormatRegistry();
  assert.throws(() => registry.detect(text("x"), "mystery.zzz"), error =>
    error instanceof ConvertError && error.message === 'no format matched "mystery.zzz"',
  );
  assert.throws(() => registry.detect(text("x"), ""), /no format matched the input/);
});

test("explicit format option bypasses detection and unknown names fail exactly", () => {
  const registry = createFormatRegistry();
  registry.register(docuworks(), "builtin");
  const { plugin } = makePlugin({ name: "claimed", detectAccepts: new Set(["any"]) });
  registry.register(plugin, "other");
  assert.equal(registry.detect(text("any"), "file.xyz", "claimed").plugin.name, "claimed");
  assert.equal(
    registry.detect(text("never claimed"), "", "claimed").via,
    "format-option",
  );
  assert.throws(
    () => registry.detect(text("x"), "", "missing"),
    error => error instanceof ConvertError && error.message === 'unknown format "missing"',
  );
});

test("detection is a pure function of the registry: property test", () => {
  const random = mulberry32(20261111);
  const sounds = ["alpha", "beta", "gamma", "delta", "omega"];
  const detectors = ["alpha", "beta", "gamma"];
  for (let round = 0; round < 200; round += 1) {
    const order = random.shuffle(sounds);
    const built = order.map(name => ({
      name,
      plugin: makePlugin({
        name,
        extensions: [`.${name}`],
        detectAccepts: new Set([random.pick(detectors)]),
      }).plugin,
    }));
    const registryA = createFormatRegistry();
    const registryB = createFormatRegistry();
    for (const { plugin } of built) {
      registryA.register(plugin, "a");
      registryB.register(plugin, "b");
    }
    for (const probe of [...detectors, "none"]) {
      for (const name of ["", `file.${probe}`]) {
        const answer = registry => {
          try {
            return registry.detect(text(probe), name).plugin.name;
          } catch (error) {
            return error.message;
          }
        };
        const resultA = answer(registryA);
        const resultB = answer(registryB);
        assert.equal(resultA, resultB, `round ${round} probe ${probe} name ${name}`);
        // the answer is always the first registered plugin whose detector
        // accepts the bytes, else the extension claim owner, else the error.
        const accepting = built.find(
          ({ plugin }) =>
            typeof plugin.detect === 'function' && plugin.detect(text(probe)) === true,
        );
        const claimed = built.find(({ name: pluginName }) => name === `file.${pluginName}`);
        const expected = accepting
          ? accepting.name
          : claimed
            ? claimed.name
            : name === ""
              ? "no format matched the input"
              : `no format matched "${name}"`;
        assert.equal(resultA, expected, `round ${round} probe ${probe} name "${name}"`);
      }
    }
  }
});

test("collision property test: a shuffled draw of duplicate claims throws exactly once each", () => {
  const random = mulberry32(97531);
  for (let round = 0; round < 100; round += 1) {
    const names = random.shuffle(["one", "two", "three", "one", "two"]);
    const registry = createFormatRegistry();
    let registered = 0;
    let errors = 0;
    for (const name of names) {
      try {
        registry.register(makePlugin({ name, extensions: [`.${name}`, ".shared"] }).plugin, "drawing");
        registered += 1;
      } catch (error) {
        errors += 1;
        assert.ok(error instanceof PluginError, "collisions must be PluginErrors");
        assert.match(error.message, /already claimed by/);
      }
    }
    // names repeat and every non-first registration also holds `.shared`,
    // so exactly one registration succeeds whatever the order
    assert.equal(registered, 1, `round ${round}: ${registered} ok, ${errors} errors`);
    assert.equal(errors, names.length - 1);
    assert.equal(registry.length, 1);
    // the registry still works after collisions
    assert.ok(Array.isArray(registry.formats()));
    assert.equal(typeof registry.register, "function");
  }
});

test("dispose calls every plugin once and reports failures without stopping", async () => {
  const registry = createFormatRegistry();
  const a = makePlugin({ name: "a" });
  registry.register(a.plugin, "a");
  const b = makePlugin({ name: "b" });
  b.plugin.dispose = () => {
    throw new Error("nope");
  };
  registry.register(b.plugin, "b");
  const report = await registry.dispose("test done");
  assert.deepEqual(
    report.outcomes.map(outcome => outcome.name),
    ["a", "b"],
  );
  assert.equal(report.outcomes[0].ok, true);
  assert.equal(report.outcomes[1].ok, false);
  assert.equal(a.cleaned.disposed, 1);
  assert.equal(b.cleaned.disposed, 0);
  // repeated dispose is the same settled report
  const again = await registry.dispose("never");
  assert.equal(again, report);
  assert.equal(a.cleaned.disposed, 1);
});

///|
// Independent-review blocker: a runtime promise-returning detector threw the
// contract error but its rejected promise was never consumed, which can
// terminate Node with an unhandled rejection. The promise must be consumed
// safely alongside the contract error.
test("a rejected detector promise is consumed, not left unhandled", async () => {
  const unhandled = [];
  const onUnhandled = (reason) => unhandled.push(String(reason));
  process.on("unhandledRejection", onUnhandled);
  try {
    const registry = createFormatRegistry({
      plugins: [
        {
          apiVersion: 1,
          name: "asyncdetect",
          description: "d",
          convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
          detect: () => Promise.reject(new Error("detector exploded asynchronously")),
        },
      ],
    });
    assert.throws(
      () => registry.detect(text("x"), "x.bin"),
      error => error instanceof PluginError && error.code === "async-detect",
    );
    // a thenable rejection is equally consumed
    const thenableRegistry = createFormatRegistry({
      plugins: [
        {
          apiVersion: 1,
          name: "thenabledetect",
          description: "d",
          convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
          detect: () => ({ then(onOk, onFail) { return Promise.reject(new Error("thenable boom")).catch(onFail); } }),
        },
      ],
    });
    assert.throws(
      () => thenableRegistry.detect(text("x"), "x.bin"),
      error => error instanceof PluginError && error.code === "async-detect",
    );
  } finally {
    await new Promise(resolve => setTimeout(resolve, 50));
    process.off("unhandledRejection", onUnhandled);
  }
  assert.deepEqual(unhandled, [], "no rejected detector promise may strand");
});

test("an async function detector is refused at registration time", () => {
  const registry = createFormatRegistry();
  assert.throws(
    () =>
      registry.register({
        apiVersion: 1,
        name: "neverasync",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        detect: async () => true,
      }),
    error => error instanceof PluginError
      && /detect must be synchronous/.test(error.message)
      && /async function/.test(error.message),
  );
  assert.equal(registry.length, 0, "nothing was registered");
});

test("registering after the registry disposal is refused, not silently lost", async () => {
  const disposed = [];
  const registry = createFormatRegistry({
    plugins: [
      {
        apiVersion: 1,
        name: "first",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        dispose: async () => {
          disposed.push("first");
        },
      },
    ],
  });
  await registry.dispose("teardown");
  assert.throws(
    () =>
      registry.register({
        apiVersion: 1,
        name: "late",
        description: "d",
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
        dispose: async () => {
          disposed.push("late");
        },
      }),
    error => error instanceof PluginError && /registry is disposed/.test(error.message),
  );
  assert.equal(registry.length, 1, "the late registration was refused");
  assert.deepEqual(disposed, ["first"], "the late plugin is never disposed: it was never admitted");
});


test("registry disposal publishes its completion before deferred cleanup", async () => {
  const events = [];
  const registry = createFormatRegistry({ plugins: [{
    apiVersion: 1,
    name: "cleanup",
    description: "test cleanup ordering",
    convert: async () => ({ bdf: new Uint8Array(0), summary: "" }),
    dispose: () => { events.push("disposed"); },
  }] });
  const first = registry.dispose("first");
  assert.deepEqual(events, [], "cleanup starts only after the completion is published");
  assert.equal(registry.dispose("second"), first);
  assert.throws(() => registry.register({
    apiVersion: 1, name: "late", description: "late",
    convert: async () => ({ bdf: new Uint8Array(0), summary: "" }),
  }), /registry is disposed/);
  const report = await first;
  assert.deepEqual(events, ["disposed"]);
  assert.equal(report.reason, "first");
  assert.equal(report.outcomes.length, 1);
  assert.equal(report.outcomes[0].ok, true);
  assert.equal(registry.dispose("third"), first);
});
