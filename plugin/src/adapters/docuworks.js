// The builtin DocuWorks adapter, expressed with the same contract a
// third-party adapter implements. The heavy lifting stays in a delegate
// supplied by the embedder, because the converter itself is not part of this
// package: this repository binds the MoonBit `convert/xdw` JS export (see
// `./bindings/moonbit.js`), while a downstream adapter can supply its own
// private converter without patching this registry's dispatch code.

import { PluginError, defineFormatPlugin, errorText } from "../contract.js";
import {
  AdapterError,
  acceptedParams,
  booleanParam,
  noPassword,
} from "../adapter-options.js";

export const DOCUWORKS_FORMAT_NAME = "xdw";
export const DOCUWORKS_EXTENSIONS = [".xdw", ".xbd"];
export const DOCUWORKS_DESCRIPTION =
  "DocuWorks document (vector and scanned pages with annotations; binder .xbd)";

function delegateFunction(delegate, key, what) {
  const value = delegate?.[key];
  if (typeof value !== "function") {
    throw new PluginError(
      `docuworks delegate must provide a ${what} function as "${key}", not ${value === undefined ? "nothing" : typeof value}`,
    );
  }
  return value;
}

///|
// Wrap a DocuWorks converter delegate in the plugin contract. The delegate is
// `{detect(bytes) -> boolean-ish, convert(bytes, {includeHidden, name}) -> {bdf, ...}}`;
// detection must be synchronous (the registry's detection loop cannot await),
// while conversion may be asynchronous. The returned plugin's own validation
// makes the delegate's output obey the host contract regardless of its origin.
export function docuworksPlugin({
  delegate,
  name = DOCUWORKS_FORMAT_NAME,
  description = DOCUWORKS_DESCRIPTION,
  extensions = DOCUWORKS_EXTENSIONS,
  version = "",
  vendor = "",
}) {
  const detectDelegate = delegateFunction(delegate, "detect", "detection");
  const convertDelegate = delegateFunction(delegate, "convert", "conversion");

  const plugin = {
    apiVersion: 1,
    name,
    description,
    extensions: [...extensions],
    ...(version === "" ? {} : { version }),
    ...(vendor === "" ? {} : { vendor }),
    detect(bytes) {
      // The registry runs plugin detection synchronously, and the MoonBit
      // binding is synchronous too. An async (or thenable) delegate here
      // could only be silently missed or hung behind an unawaitable answer,
      // so it is rejected explicitly instead — and its fate is consumed, so
      // a rejection nobody awaits cannot terminate the host.
      const verdict = detectDelegate(bytes);
      if (verdict !== null && typeof verdict?.then === "function") {
        Promise.resolve(verdict).catch(() => undefined);
        throw new PluginError(
          "the DocuWorks detect delegate must be synchronous: it returned a promise",
          "async-detect",
        );
      }
      return verdict === true;
    },
    async convert(bytes, options) {
      acceptedParams(options, ["include_hidden"], name);
      noPassword(options, name);
      const includeHidden = booleanParam((options?.params ?? {}), name, "include_hidden");
      let value;
      try {
        value = await convertDelegate(bytes, {
          includeHidden,
          name: options?.name ?? "",
        });
      } catch (error) {
        // The delegate's failures cross the wire as plain errors; nothing of
        // the delegate's internals is assumed, and its error code is kept.
        const wrapped = new Error(`docuworks: ${errorText(error)}`);
        const code = error?.code;
        if (typeof code === "string" && code !== "") {
          wrapped.code = code;
        }
        throw wrapped;
      }
      // The host performs the full result validation (bdf shape, warnings,
      // format identity); the adapter only forwards what the delegate made.
      return value;
    },
  };
  return defineFormatPlugin(plugin);
}
