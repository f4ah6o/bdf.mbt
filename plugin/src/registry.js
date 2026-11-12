// The format registry: explicit registration, deterministic detection.
//
// Detection is a pure function of the registry contents and the input: result
// order is registration order, never map iteration order or probe timing.
// Registration never overrides: a name or extension claimed twice is an
// error, whether the first claimant is a builtin or a third party.

import {
  ConvertError,
  PluginError,
  defineFormatPlugin,
  FORMAT_PLUGIN_API_VERSION,
  pluginContext,
} from "./contract.js";

export function createFormatRegistry({ plugins = [], source = "registry" } = {}) {
  const ordered = [];
  const byName = new Map();
  const byExtension = new Map();

  function label(registration) {
    return `plugin "${registration.plugin.name}" (${registration.source})`;
  }

  function register(rawPlugin, pluginSource = source) {
    if (typeof pluginSource !== "string" || pluginSource === "") {
      throw new PluginError("plugin source label must be a non-empty string");
    }
    if (disposalPromise !== null) {
      // A registration admitted now would never be disposed: the disposal
      // already ran over the registered set. Refuse it rather than leak it.
      throw new PluginError(
        `the registry is disposed: registering plugin "${String(rawPlugin?.name ?? "?")}" after disposal is refused`,
      );
    }
    const plugin = defineFormatPlugin(rawPlugin);
    const incoming = `plugin "${plugin.name}" (${pluginSource})`;
    if (byName.has(plugin.name)) {
      const existing = byName.get(plugin.name);
      throw new PluginError(
        `${incoming} claims format name "${plugin.name}", already claimed by ${label(existing)}`,
      );
    }
    for (const extension of plugin.extensions) {
      const existing = byExtension.get(extension);
      if (existing) {
        throw new PluginError(
          `${incoming} claims extension "${extension}", already claimed by ${label(existing)}`,
        );
      }
    }
    const registration = Object.freeze({ plugin, source: pluginSource });
    ordered.push(registration);
    byName.set(plugin.name, registration);
    for (const extension of plugin.extensions) {
      byExtension.set(extension, registration);
    }
    return plugin;
  }

  function plugin(name) {
    const found = byName.get(name);
    return found ? found.plugin : null;
  }

  ///|
  // The plugin a file name's extension claims, taking the longest claim so a
  // `.drawio.png` can coexist with a `.png`. The registry keeps claims
  // exclusive, so this cannot be ambiguous.
  function byNameClaim(name) {
    if (typeof name !== "string" || name === "") {
      return null;
    }
    const lower = name.toLowerCase();
    let best = null;
    let bestLength = 0;
    for (const extension of byExtension.keys()) {
      if (lower.endsWith(extension) && extension.length > bestLength) {
        best = byExtension.get(extension);
        bestLength = extension.length;
      }
    }
    return best;
  }

  ///|
  // Deterministic detection: an explicit format wins, then content detection
  // in registration order, then the file-name claim as the last resort.
  // Returns the plugin and how it was chosen, or throws ConvertError.
  function detect(bytes, name = "", formatOption = "") {
    if (formatOption !== "") {
      const registration = byName.get(formatOption);
      if (!registration) {
        throw new ConvertError(`unknown format "${formatOption}"`, "unknown-format");
      }
      return { plugin: registration.plugin, via: "format-option" };
    }
    for (const registration of ordered) {
      const { detect } = registration.plugin;
      if (typeof detect !== "function") {
        continue;
      }
      const verdict = detect(bytes, context);
      if (verdict !== null && typeof verdict?.then === "function") {
        // An asynchronous or thenable detector would have to be awaited to be
        // honored, and an unawaited one silently never claims. Determinism
        // forbids both, so it is an explicit plugin contract error. Its fate
        // is consumed here too: a value nobody awaits can still reject, and
        // an unhandled rejection from inside the registry would terminate a
        // Node host long after this error was answered.
        Promise.resolve(verdict).catch(() => undefined);
        throw new PluginError(
          `plugin "${registration.plugin.name}" detect must be synchronous: it returned a promise`,
          "async-detect",
        );
      }
      if (verdict === true) {
        return { plugin: registration.plugin, via: "detect" };
      }
    }
    const claimed = byNameClaim(name);
    if (claimed) {
      return { plugin: claimed.plugin, via: "name" };
    }
    const subject = name === "" ? "the input" : `"${name}"`;
    throw new ConvertError(`no format matched ${subject}`, "no-format-matched");
  }

  function formats() {
    return ordered.map(({ plugin }) => ({
      name: plugin.name,
      description: plugin.description,
      extensions: [...plugin.extensions],
    }));
  }

  function registrations() {
    return ordered.map((registration) => ({
      source: registration.source,
      name: registration.plugin.name,
      extensions: [...registration.plugin.extensions],
    }));
  }

  const context = pluginContext();
  let disposalPromise = null;

  for (const [plugin, pluginSource] of plugins.map(value =>
    Array.isArray(value) ? value : [value, source],
  )) {
    register(plugin, pluginSource);
  }

  ///|
  // Every plugin's dispose runs exactly once, in registration order, await
  // included; calls made while a disposal is running or after it settled
  // all get the same report instead of disposing again.
  function disposeOnce(reason) {
    if (disposalPromise === null) {
      disposalPromise = (async () => {
        const outcomes = [];
        for (const registration of ordered) {
          const { dispose } = registration.plugin;
          if (typeof dispose !== "function") {
            continue;
          }
          const outcome = { name: registration.plugin.name };
          try {
            const returned = await dispose(context, reason);
            Object.assign(outcome, { ok: true, returned });
          } catch (error) {
            Object.assign(outcome, { ok: false, error });
          }
          outcomes.push(outcome);
        }
        return { reason, outcomes };
      })();
    }
    return disposalPromise;
  }

  return {
    apiVersion: FORMAT_PLUGIN_API_VERSION,
    register,
    detect,
    plugin,
    formats,
    registrations,
    dispose: disposeOnce,
    get length() {
      return ordered.length;
    },
  };
}
