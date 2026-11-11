// Type declarations for the `adapters/excalidraw` export path
// (src/adapters/excalidraw.js). The runtime module exports exactly the
// Excalidraw adapter factory and its three format constants; nothing else may
// be declared here, so importing a nonexistent export fails type-checking for
// the consumer instead of passing and crashing at runtime.

import type { FormatPlugin } from "./index.d.ts";

export declare const EXCALIDRAW_FORMAT_NAME: "excalidraw";
export declare const EXCALIDRAW_EXTENSIONS: readonly [".excalidraw", ".excalidraw.json"];
export declare const EXCALIDRAW_DESCRIPTION: string;

/** The largest input the adapter accepts (8 MiB). */
export declare const EXCALIDRAW_INPUT_LIMIT: number;

/**
 * Build the Excalidraw format plugin: total synchronous detection over the
 * JSON scene shape, conversion of the drawable elements into shared diagram
 * primitives, and thrown errors carrying `code` (`"invalid-input"` |
 * `"too-large"` | `"invalid-options"`). The returned descriptor is validated
 * and frozen by `defineFormatPlugin`.
 */
export declare function excalidrawPlugin(): Readonly<FormatPlugin>;
