// Type declarations for the `adapters/docuworks` export path
// (src/adapters/docuworks.js). That runtime module exports exactly the
// DocuWorks adapter factory and its three format constants; nothing else may
// be declared here, so importing a nonexistent export fails type-checking for
// the consumer instead of passing and crashing at runtime.

import type { DocuWorksDelegate, FormatPlugin } from "./index.d.ts";

export declare const DOCUWORKS_FORMAT_NAME: "xdw";
export declare const DOCUWORKS_EXTENSIONS: readonly [".xdw", ".xbd"];
export declare const DOCUWORKS_DESCRIPTION: string;

/** Wrap a DocuWorks converter delegate in the versioned plugin contract. */
export declare function docuworksPlugin(options: {
  delegate: DocuWorksDelegate;
  name?: string;
  description?: string;
  extensions?: readonly string[];
  version?: string;
  vendor?: string;
}): Readonly<FormatPlugin>;
