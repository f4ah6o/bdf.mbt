// Type declarations for the `adapters/mermaid` export path
// (src/adapters/mermaid.js). That runtime module exports exactly the
// Mermaid flowchart adapter factory and its three format constants; nothing
// else may be declared here, so importing a nonexistent export fails
// type-checking for the consumer instead of passing and crashing at runtime.

import type { FormatPlugin } from "./index.d.ts";

export declare const MERMAID_FORMAT_NAME: "mermaid";
export declare const MERMAID_EXTENSIONS: readonly [".mmd", ".mermaid"];
export declare const MERMAID_DESCRIPTION: string;

/**
 * The bounded static Mermaid flowchart adapter as a versioned (apiVersion 1)
 * plugin descriptor. `detect` is synchronous and never throws; `convert`
 * converts strict-UTF-8 Mermaid flowchart text into a single-page BDF and
 * throws ConvertErrors carrying `.code` "invalid-input" or "too-large".
 */
export declare function mermaidPlugin(): Readonly<FormatPlugin>;
