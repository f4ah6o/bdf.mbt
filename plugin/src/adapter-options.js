// Convert option coercion shared by the adapters. The DocuWorks adapter
// accepts the same parameter surface the native converter worker accepts for
// xdw files: `params.include_hidden` (validated exactly like
// `convert/xdw`'s parameter parser) and nothing else. `password` is never
// accepted because the converter has no DocuWorks password support, and
// `options.pages` never reaches a plugin (the host rejects it first).
//
// Rejecting instead of ignoring is deliberate: a typo (`includeHidden`, or a
// future option an old plugin does not know) must fail loudly, never quietly
// change what a converted document holds.

const INCLUDE_HIDDEN_VALUES = new Map([
  ["", false], ["0", false], ["f", false], ["false", false], ["no", false], ["off", false],
  ["1", true], ["t", true], ["true", true], ["yes", true], ["on", true],
]);

export class AdapterError extends Error {
  constructor(message, code = "invalid-options") {
    super(message);
    this.name = "ConvertError";
    this.code = code;
  }
}

export function acceptedParams(options, acceptedKeys, pluginName) {
  const params = options?.params ?? {};
  for (const key of Object.keys(params)) {
    if (!acceptedKeys.includes(key)) {
      throw new AdapterError(`${pluginName}: unknown parameter "${key}"`);
    }
  }
  return params;
}

export function booleanParam(params, pluginName, key) {
  const raw = params[key] ?? "";
  const value = INCLUDE_HIDDEN_VALUES.get(raw);
  if (value === undefined) {
    throw new AdapterError(`${pluginName}: parameter ${key}: "${raw}" is not 0 or 1`);
  }
  return value;
}

export function noPassword(options, pluginName) {
  if (typeof options?.password === "string" && options.password !== "") {
    throw new AdapterError(
      `${pluginName}: password-protected documents are not supported`,
      "invalid-options",
    );
  }
}
