import assert from "node:assert/strict";
import { test } from "node:test";

import {
  FORMAT_PLUGIN_API_VERSION,
  PluginError,
  defineFormatPlugin,
  pluginContext,
} from "../src/contract.js";

const base = {
  apiVersion: FORMAT_PLUGIN_API_VERSION,
  name: "example",
  description: "an example format",
  convert: async () => ({ bdf: new Uint8Array(1), summary: "ok", warnings: [] }),
};

const bad = (mutate, pattern) => {
  const error = (() => {
    try {
      defineFormatPlugin({ ...base, ...mutate });
    } catch (thrown) {
      return thrown;
    }
  })();
  assert.ok(error instanceof PluginError, `expected PluginError for ${JSON.stringify(mutate)}`);
  if (pattern) {
    assert.match(error.message, pattern);
  }
  return error;
};

test("api version is pinned to 1", () => {
  assert.equal(FORMAT_PLUGIN_API_VERSION, 1);
});

test("a valid descriptor passes and is frozen", () => {
  const plugin = defineFormatPlugin({ ...base, extensions: [".abc", ".abcd"] });
  assert.equal(Object.isFrozen(plugin), true);
  assert.deepEqual(plugin.extensions, [".abc", ".abcd"]);
});

test("api version mismatch is an explicit error", () => {
  bad({ apiVersion: 2 }, /api version 2/);
  bad({ apiVersion: 0 }, /api version 0/);
  bad({ apiVersion: "1" }, /api version/);
});

test("names must be lowercase wire-safe identifiers", () => {
  bad({ name: "CSV" }, /name "CSV"/);
  bad({ name: "" }, /name ""/);
  bad({ name: "1csv" }, /name "1csv"/);
  bad({ name: "with space" }, /name "with space"/);
});

test("extensions must be lowercase, dotted and unique; claims are optional", () => {
  bad({ extensions: [".XDW"] }, /must be lowercase/);
  bad({ extensions: ["xdw"] }, /must be lowercase/);
  bad({ extensions: [""] }, /extension ""/);
  bad({ extensions: [".a", ".a"] }, /duplicate extensions/);
  bad({ extensions: [". a"] }, /extension "\. a"/);
  bad({ extensions: "not an array" }, /must be an array/);
  // no claims at all: detection and explicit format option only
  assert.deepEqual(defineFormatPlugin({ ...base, extensions: [] }).extensions, []);
  assert.deepEqual(defineFormatPlugin({ ...base }).extensions, []);
});

test("operation keys must be functions: serialized code is rejected", () => {
  bad({ convert: "async () => {}" }, /operation "convert" must be a function/);
  bad({ convert: { toString: () => "function () {}" } }, /operation "convert" must be a function/);
  bad({ detect: "bytes => true" }, /operation "detect" must be a function/);
  bad({ dispose: null }, /operation "dispose"/);
});

test("convert is the only required operation", () => {
  bad({ convert: undefined }, /must define a convert/);
  const detectorOnly = defineFormatPlugin({
    ...base,
    detect: () => true,
  });
  assert.equal(typeof detectorOnly.detect, "function");
});

test("a plugin that declares open must also provide page and finish", () => {
  bad({ open: async () => ({}) }, /missing page/);
  const partial = { ...base, open: async () => ({}) };
  bad({ ...partial, page: async () => ({ bdf: new Uint8Array() }) }, /missing finish/);
  assert.equal(
    typeof defineFormatPlugin({
      ...base,
      open: async () => ({}),
      page: async () => ({ bdf: new Uint8Array() }),
      finish: async () => ({ bdf: new Uint8Array(), summary: "x" }),
    }).open,
    "function",
  );
});

test("unknown descriptor keys are rejected, not ignored", () => {
  bad({ fonts: "url" }, /unknown key "fonts"/);
  bad({ detectTimeout: 10 }, /unknown key "detectTimeout"/);
});

test("metadata must be strings when present", () => {
  bad({ version: 1 }, /version must be a string/);
  bad({ vendor: 42 }, /vendor must be a string/);
});

test("description must be a string", () => {
  bad({ description: null }, /description must be a string/);
});

test("descriptor must be a plain object", () => {
  assert.throws(() => defineFormatPlugin(null), PluginError);
  assert.throws(() => defineFormatPlugin([]), PluginError);
  assert.throws(() => defineFormatPlugin(() => {}), PluginError);
});

test("plugin context carries host facts only", () => {
  const context = pluginContext();
  assert.equal(Object.isFrozen(context), true);
  assert.equal(context.hostApiVersion, FORMAT_PLUGIN_API_VERSION);
  assert.deepEqual(Object.keys(context), ["hostApiVersion"]);
});
