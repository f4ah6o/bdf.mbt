// The site's plugin converter Worker. It is the official plugin host with the
// two diagram adapters registered, and nothing else: the native Worker keeps
// Visio, draw.io and every other builtin format. The viewer routes only the
// diagram extensions here, so a plugin failure can never take the native
// formats down with it.
//
// The imports are served files copied from plugin/src by site/build.mjs. No
// network conversion, no dynamic import, no evaluation of user input: the
// adapters parse bytes into bounded primitives and the shared encoder writes
// the BDF.

import { installPluginConverterWorker } from "./plugin/worker.js";
import { excalidrawPlugin } from "./plugin/adapters/excalidraw.js";
import { mermaidPlugin } from "./plugin/adapters/mermaid.js";

installPluginConverterWorker([excalidrawPlugin(), mermaidPlugin()]);
