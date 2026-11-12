// Type declarations for the `worker` export path (src/worker.js). That
// runtime module exports exactly one function; nothing else may be declared
// here, so importing a nonexistent export fails type-checking for the
// consumer instead of passing and crashing at runtime.

import type { ConverterHost, FormatPlugin, FormatRegistry } from "./index.d.ts";

/** Register plugins at worker startup and install the converter protocol's
 *  onmessage handler. Every plugin is validated (defineFormatPlugin) before
 *  the first message is processed, labeled `plugin [i]:` on failure. The
 *  default target is the worker global (self or globalThis), so a Node
 *  consumer can pass a small `{ postMessage, onmessage }` self-adapter
 *  instead. A target that already has an onmessage handler is an error. */
export declare function installPluginConverterWorker(
  plugins: Array<FormatPlugin>,
  options?: {
    target?: object;
    postMessage?: (message: any, transfer?: Transferable[]) => void;
    registry?: FormatRegistry;
    source?: string;
  },
): ConverterHost;
