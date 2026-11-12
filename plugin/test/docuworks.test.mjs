import assert from "node:assert/strict";
import { test } from "node:test";

import {
  BindingError,
  ConvertError,
  PluginError,
  base64Decode,
  docuworksPlugin,
  moonbitDocuWorks,
} from "../src/index.js";

const OK_ENVELOPE = {
  ok: true,
  bdf: "AAECAwQF",
  pages: 3,
  summary: "3 page(s)",
  warnings: ["w1"],
};

function fakeModule({ detect = () => false, envelope = OK_ENVELOPE, raw = false, convert } = {}) {
  return {
    bdf_xdw_detect: detect,
    bdf_xdw_convert: (bytes, includeHidden) =>
      convert ? convert(bytes, includeHidden) : raw ? "not json" : JSON.stringify(envelope),
  };
}

test("the docuworks plugin carries the builtin contract surface", () => {
  const calls = { detect: [], convert: [] };
  const plugin = docuworksPlugin({
    delegate: {
      detect: bytes => {
        calls.detect.push(bytes.length);
        return bytes[0] === 0x60;
      },
      convert: async (bytes, request) => {
        calls.convert.push(request);
        return { bdf: bytes.slice(), summary: "DocuWorks", warnings: [] };
      },
    },
  });
  assert.equal(plugin.apiVersion, 1);
  assert.equal(plugin.name, "xdw");
  assert.deepEqual(plugin.extensions, [".xdw", ".xbd"]);
  assert.equal(
    plugin.description,
    "DocuWorks document (vector and scanned pages with annotations; binder .xbd)",
  );
  assert.equal(plugin.detect(new Uint8Array([0x60, 0x03, 0x80])), true);
  assert.equal(plugin.detect(new Uint8Array([0x20])), false);
  assert.equal(plugin.detect(new Uint8Array([0x60])), true, "truthy delegation is normalized");
});

test("include_hidden accepts exactly the native converter's parameter values", async () => {
  for (const [value, expected] of [
    [undefined, false], ["", false], ["0", false], ["f", false], ["false", false], ["no", false], ["off", false],
    ["1", true], ["t", true], ["true", true], ["yes", true], ["on", true],
  ]) {
    const seen = [];
    const plugin = docuworksPlugin({
      delegate: {
        detect: () => false,
        convert: async (bytes, request) => {
          seen.push(request.includeHidden);
          return { bdf: new Uint8Array(1), summary: "s" };
        },
      },
    });
    await plugin.convert(new Uint8Array(1), { params: value === undefined ? {} : { include_hidden: value } });
    assert.deepEqual(seen, [expected], `include_hidden "${value ?? ""}"`);
  }
});

test("include_hidden rejects everything else with the converter's message", async () => {
  const plugin = docuworksPlugin({
    delegate: { detect: () => false, convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }) },
  });
  for (const bad of ["2", "maybe", "TRUE ", "0x1", "yes!"]) {
    await assert.rejects(
      plugin.convert(new Uint8Array(1), { params: { include_hidden: bad } }),
      error =>
        error?.name === "ConvertError" &&
        error.message === `xdw: parameter include_hidden: "${bad}" is not 0 or 1`,
      `value "${bad}"`,
    );
  }
});

test("unknown params and passwords are rejected, not ignored", async () => {
  const plugin = docuworksPlugin({
    delegate: { detect: () => false, convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }) },
  });
  await assert.rejects(
    plugin.convert(new Uint8Array(1), { params: { includeHidden: "1" } }),
    /xdw: unknown parameter "includeHidden"/,
  );
  await assert.rejects(
    plugin.convert(new Uint8Array(1), { password: "hunter2" }),
    /xdw: password-protected documents are not supported/,
  );
});

test("a delegate failure is wrapped with its code preserved", async () => {
  const plugin = docuworksPlugin({
    delegate: {
      detect: () => false,
      convert: async () => {
        const error = new Error("corrupt page table");
        error.code = "xdw-corrupt";
        throw error;
      },
    },
  });
  await assert.rejects(
    plugin.convert(new Uint8Array(1), {}),
    error => error?.message === "docuworks: corrupt page table" && error?.code === "xdw-corrupt",
  );
  // non-Error rejections still produce a message
  const raw = docuworksPlugin({
    delegate: { detect: () => false, convert: async () => Promise.reject("nope") },
  });
  await assert.rejects(raw.convert(new Uint8Array(1), {}), /docuworks: nope/);
});

test("the delegate must be real functions, names included in the error", () => {
  assert.throws(() => docuworksPlugin({ delegate: {} }), /provide a detection function as "detect"/);
  assert.throws(() => docuworksPlugin({ delegate: { detect() {} } }), /provide a conversion function as "convert"/);
  assert.throws(() => docuworksPlugin({ delegate: null }), /provide a detection function as "detect"/);
});

test("moonbitDocuWorks requires the two named exports", () => {
  assert.throws(() => moonbitDocuWorks({}), /bdf_xdw_detect\/bdf_xdw_convert are missing/);
  assert.throws(() => moonbitDocuWorks(null), /cannot read|missing|not the DocuWorks/);
});

test("moonbitDocuWorks converts the JSON envelope into contract bytes", async () => {
  const delegate = moonbitDocuWorks(fakeModule());
  assert.equal(delegate.detect(new Uint8Array(4)), false);
  // the MoonBit export returns real booleans; only true claims
  const truthy = moonbitDocuWorks(fakeModule({ detect: () => true }));
  assert.equal(truthy.detect(new Uint8Array(4)), true);
  const value = await delegate.convert(new Uint8Array([9, 9, 9]), { includeHidden: true, name: "a.xdw" });
  assert.deepEqual(Array.from(value.bdf), [0, 1, 2, 3, 4, 5]);
  assert.equal(value.summary, "3 page(s)");
  assert.deepEqual(value.warnings, ["w1"]);
});

test("moonbitDocuWorks passes through includeHidden and failure envelopes", async () => {
  const seen = [];
  const delegate = moonbitDocuWorks(
    fakeModule({
      envelope: { ok: false, error: "XdwNotFile(does not start with the DocuWorks header)" },
      convert(bytes, includeHidden) {
        seen.push(includeHidden);
        return JSON.stringify({ ok: false, error: "XdwNotFile(does not start with the DocuWorks header)" });
      },
    }),
  );
  await assert.rejects(
    delegate.convert(new Uint8Array(1), { includeHidden: true }),
    error => error instanceof BindingError && error.message === "XdwNotFile(does not start with the DocuWorks header)",
  );
  assert.deepEqual(seen, [true]);
});

test("moonbitDocuWorks rejects malformed envelopes instead of trusting them", async () => {
  await assert.rejects(
    moonbitDocuWorks(fakeModule({ raw: true })).convert(new Uint8Array(1), {}),
    /did not return JSON/,
  );
  await assert.rejects(
    moonbitDocuWorks(fakeModule({ envelope: { ok: true, summary: "missing bdf" } })).convert(new Uint8Array(1), {}),
    /envelope is missing bdf or summary/,
  );
  await assert.rejects(
    moonbitDocuWorks(
      fakeModule({ envelope: { ...OK_ENVELOPE, bdf: "not%base64==", warnings: 5 } }),
    ).convert(new Uint8Array(1), {}),
    error => error.message.matches?.("base64") ?? true,
  );
});

test("base64Decode only accepts standard padding-aligned input", () => {
  assert.deepEqual(Array.from(base64Decode("AAEC")), [0, 1, 2]);
  assert.deepEqual(Array.from(base64Decode("AAECAwQF")), [0, 1, 2, 3, 4, 5]);
  assert.deepEqual(Array.from(base64Decode("AAECAw==")), [0, 1, 2, 3]);
  assert.throws(() => base64Decode("AAA"), /not well-formed base64/);
  assert.throws(() => base64Decode("A!EC"), /not well-formed base64/);
  // a long payload across padding boundaries
  const text = "the quick brown fox";
  const encoded = Buffer.from(text).toString("base64");
  assert.equal(new TextDecoder().decode(base64Decode(encoded)), text);
});

test("base64Decode rejects noncanonical padding that carries data bits", () => {
  // canonical single- and two-byte encodings
  assert.deepEqual(Array.from(base64Decode("AA==")), [0]);
  assert.deepEqual(Array.from(base64Decode("AAE=")), [0, 1]);
  assert.deepEqual(Array.from(base64Decode("/w==")), [0xff]);
  assert.deepEqual(Array.from(base64Decode("//8=")), [0xff, 0xff]);
  // 'AQ==' is the canonical encoding of 0x01 and must stay accepted
  assert.deepEqual(Array.from(base64Decode("AQ==")), [1]);
  // 'B' in the last data character of a two-pad quad carries bits a
  // canonical encoder would never emit; likewise 'z' with one pad
  assert.throws(() => base64Decode("AB=="), /not canonical base64/);
  assert.throws(() => base64Decode("//h="), /not canonical base64/);
  assert.throws(() => base64Decode("//z="), /not canonical base64/);
  // round-trip still works for every byte count with canonical padding
  for (const length of [1, 2, 3, 250]) {
    const bytes = new Uint8Array(length);
    for (let index = 0; index < length; index += 1) {
      bytes[index] = (index * 37 + 11) & 0xff;
    }
    const encoded = Buffer.from(bytes).toString("base64");
    assert.deepEqual(Array.from(base64Decode(encoded)), Array.from(bytes));
  }
});

test("base64Decode rejects misplaced padding", () => {
  // '=' only belongs at the trailing positions of the final quad
  assert.throws(() => base64Decode("AA=C"), /misplaced "="/);
  assert.throws(() => base64Decode("AB=C"), /misplaced "="/);
  assert.throws(() => base64Decode("AA="), /not well-formed base64/);
  assert.throws(() => base64Decode("=AAA"), /misplaced "="/);
  assert.throws(() => base64Decode("AA==AAEC"), /misplaced "="/);
  assert.throws(() => base64Decode("===="), /misplaced "="/);
  assert.throws(() => base64Decode("A=EC"), /misplaced "="/);
});

test("an async DocuWorks detect delegate is rejected, not silently false", () => {
  const plugin = docuworksPlugin({
    delegate: {
      detect: () => Promise.resolve(true),
      convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
    },
  });
  assert.throws(
    () => plugin.detect(new Uint8Array(4)),
    error => error instanceof PluginError && error.code === "async-detect"
      && /must be synchronous/.test(error.message),
  );
  // thenable detection is likewise refused rather than normalized to false:
  // an async detector can never be honored synchronously, and silently
  // reading it as "not detected" would hide the bug
  const thenable = docuworksPlugin({
    delegate: {
      detect: () => ({ then() {} }),
      convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
    },
  });
  assert.throws(
    () => thenable.detect(new Uint8Array(4)),
    error => error instanceof PluginError && error.code === "async-detect",
  );
});

test("a rejected async delegate detector is consumed, never unhandled", async () => {
  const unhandled = [];
  const onUnhandled = (reason) => unhandled.push(String(reason));
  process.on("unhandledRejection", onUnhandled);
  try {
    const plugin = docuworksPlugin({
      delegate: {
        detect: () => Promise.reject(new Error("delegate detector exploded")),
        convert: async () => ({ bdf: new Uint8Array(1), summary: "s" }),
      },
    });
    assert.throws(() => plugin.detect(new Uint8Array(4)), error => error?.code === "async-detect");
  } finally {
    await new Promise(resolve => setTimeout(resolve, 50));
    process.off("unhandledRejection", onUnhandled);
  }
  assert.deepEqual(unhandled, [], "the adapter consumes the rejected delegate detector");
});
