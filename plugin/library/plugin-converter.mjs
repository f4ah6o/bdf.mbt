// A prebuilt Worker script for the format plugin API, shipped in the library
// package as `dist/workers/plugin-converter.mjs`. It imports only files that
// ship alongside it in the same package, so a consumer needs no MoonBit
// toolchain to convert DocuWorks files or diagram inputs through the plugin
// host. Instantiate it from a served URL, not an npm package subpath
// (`bdf.mbt/dist/...` is deliberately not an export entry): after copying the
// package `dist` tree to static served paths as the README quickstart shows —
//
//   new Worker("/bdf.mbt-dist/workers/plugin-converter.mjs",
//             { type: "module" });
//
// The startup list registers the builtin DocuWorks adapter and the Excalidraw
// and Mermaid diagram adapters (documented input subsets, see the package's
// docs/diagram-plugins.md). Their extension claims do not collide.
// This file is a packaging input, not an entry point of the plugin package
// itself: its imports resolve inside the staged `dist/` tree.

import { installPluginConverterWorker } from "../plugin/worker.js";
import { moonbitDocuWorks } from "../plugin/bindings/moonbit.js";
import { docuworksPlugin } from "../plugin/adapters/docuworks.js";
import { excalidrawPlugin } from "../plugin/adapters/excalidraw.js";
import { mermaidPlugin } from "../plugin/adapters/mermaid.js";
import * as xdw from "../xdw/docuworks_js.js";

installPluginConverterWorker([
  docuworksPlugin({ delegate: moonbitDocuWorks(xdw) }),
  excalidrawPlugin(),
  mermaidPlugin(),
]);
