// Worker-side startup installer. Plugins are imported by the worker script
// and handed over as objects holding real functions; nothing in this file
// evaluates code, serializes functions, or imports a URL supplied at runtime.
//
//   import { installPluginConverterWorker } from "bdf-format-plugin-api/worker";
//   import * as xdw from "./xdw_js.js";
//   installPluginConverterWorker([docuworksPlugin(moonbitDocuWorks(xdw))]);

import { PluginError, defineFormatPlugin } from "./contract.js";
import { createConverterHost } from "./host.js";
import { createFormatRegistry } from "./registry.js";

function defaultTarget() {
  const target = globalThis.self ?? globalThis;
  if (typeof target !== "object" || target === null) {
    throw new PluginError("no worker global found to install the converter host into");
  }
  return target;
}

///|
// Install a plugin-driven converter protocol in a Worker. Every descriptor is
// validated before the first message is handled, so a malformed plugin fails
// the worker script at startup instead of a request later.
export function installPluginConverterWorker(
  plugins = [],
  {
    target = defaultTarget(),
    postMessage = (message, transfer) => target.postMessage(message, transfer),
    registry = createFormatRegistry(),
    source = "worker",
  } = {},
) {
  if (!Array.isArray(plugins)) {
    throw new PluginError("installPluginConverterWorker expects an array of plugin descriptors");
  }
  for (const [plugin, index] of plugins.map((value, index) => [value, index])) {
    try {
      registry.register(plugin, source);
    } catch (error) {
      if (error instanceof PluginError) {
        error.message = `plugin [${index}]: ${error.message}`;
      }
      throw error;
    }
  }
  const host = createConverterHost({ registry, postMessage });
  if (typeof target.onmessage !== "undefined" && target.onmessage !== null) {
    throw new PluginError("the target already has an onmessage handler");
  }
  target.onmessage = event => {
    host.handle(event.data);
  };
  return host;
}
