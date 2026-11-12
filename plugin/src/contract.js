// The versioned plugin contract. Everything the host checks about a plugin
// descriptor lives here so that workers, embedders and tests all reject the
// same malformations with the same messages.
//
// A plugin descriptor is code, never data: every operation key must be an
// actual function. Descriptors that arrive as plain objects over a message,
// JSON files or similar can only be rejected, since honoring them would need
// some form of evaluation, which this API never does.

export const FORMAT_PLUGIN_API_VERSION = 1;

const NAME_PATTERN = /^[a-z][a-z0-9-]*$/;
const EXTENSION_PATTERN = /^\.[a-z0-9][a-z0-9._-]*$/;

const OPERATION_KEYS = [
  "convert",
  "detect",
  "open",
  "page",
  "finish",
  "disposeStream",
  "dispose",
];
const METADATA_KEYS = ["apiVersion", "name", "description", "extensions", "version", "vendor"];
const KNOWN_KEYS = [...METADATA_KEYS, ...OPERATION_KEYS];

export class PluginError extends Error {
  constructor(message, code = "invalid-plugin") {
    super(message);
    this.name = "PluginError";
    this.code = code;
  }
}

export class ConvertError extends Error {
  constructor(message, code) {
    super(message);
    this.name = "ConvertError";
    // Deliberately not always present: replies copy `code` only when the
    // producer set one.
    if (code !== undefined) {
      this.code = code;
    }
  }
}

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function fail(message) {
  throw new PluginError(message);
}

///|
// Validate a plugin descriptor and return the same object, descriptor frozen
// shallowly. Throws PluginError when the descriptor cannot be honored.
export function defineFormatPlugin(descriptor, { requireFunctions = true } = {}) {
  if (!isPlainObject(descriptor)) {
    fail("plugin descriptor must be a plain object");
  }
  for (const key of Object.keys(descriptor)) {
    if (!KNOWN_KEYS.includes(key)) {
      fail(`plugin descriptor has unknown key "${key}"`);
    }
  }
  const { apiVersion, name, description, extensions } = descriptor;
  if (apiVersion !== FORMAT_PLUGIN_API_VERSION) {
    fail(
      `plugin "${name ?? "?"}" targets api version ${String(apiVersion)}, this host supports ${FORMAT_PLUGIN_API_VERSION}`,
    );
  }
  if (typeof name !== "string" || !NAME_PATTERN.test(name)) {
    fail(`plugin name "${String(name ?? "")}" must match ${NAME_PATTERN.source}`);
  }
  if (typeof description !== "string") {
    fail(`plugin "${name}" description must be a string`);
  }
  if (extensions !== undefined && extensions !== null) {
    if (!Array.isArray(extensions)) {
      fail(`plugin "${name}" extensions must be an array`);
    }
    for (const extension of extensions) {
      if (typeof extension !== "string" || !EXTENSION_PATTERN.test(extension)) {
        fail(
          `plugin "${name}" extension "${String(extension)}" must be lowercase and start with a dot, matching ${EXTENSION_PATTERN.source}`,
        );
      }
    }
    const unique = new Set(extensions);
    if (unique.size !== extensions.length) {
      fail(`plugin "${name}" declares duplicate extensions`);
    }
  }
  for (const key of ["version", "vendor"]) {
    const value = descriptor[key];
    if (value !== undefined && typeof value !== "string") {
      fail(`plugin "${name}" ${key} must be a string`);
    }
  }
  for (const key of OPERATION_KEYS) {
    const value = descriptor[key];
    if (value === undefined) {
      continue;
    }
    if (requireFunctions && typeof value !== "function") {
      fail(
        `plugin "${name}" operation "${key}" must be a function, not ${typeof value}; descriptors cannot be transported, only imported`,
      );
    }
    if (!requireFunctions && typeof value !== "function" && value !== null) {
      fail(`plugin "${name}" operation "${key}" must be a function or null`);
    }
  }
  if (descriptor.detect !== undefined && typeof descriptor.detect === "function"
    && descriptor.detect.constructor?.name === "AsyncFunction") {
    // An async function can never answer synchronously, so this is knowable
    // here; expressing it at registration time beats discovering it on the
    // first request.
    fail(`plugin "${name}" detect must be synchronous: an async function can never return a verdict without awaiting`);
  }
  if (typeof descriptor.convert !== "function") {
    fail(`plugin "${name}" must define a convert function`);
  }
  if (descriptor.open !== undefined) {
    for (const key of ["page", "finish"]) {
      if (typeof descriptor[key] !== "function") {
        fail(`plugin "${name}" declares open but is missing ${key}`);
      }
    }
  }
  return Object.freeze({
    ...descriptor,
    extensions: Array.isArray(descriptor.extensions) ? [...descriptor.extensions] : [],
  });
}

///|
// The failure message of an exception, without trusting its shape.
export function errorText(error) {
  const value = error?.message;
  if (typeof value === "string" && value !== "") {
    return value;
  }
  if (typeof error === "string") {
    return error;
  }
  return String(error);
}

///|
// A context object handed to every plugin operation call. It carries host
// facts only: plugins must keep their own state on their own objects.
export function pluginContext() {
  return Object.freeze({ hostApiVersion: FORMAT_PLUGIN_API_VERSION });
}
