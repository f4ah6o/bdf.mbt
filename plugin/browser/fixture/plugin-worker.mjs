// Plugin host worker fixture: registers the DocuWorks builtin adapter over
// the repository's MoonBit JS export, importing only statically served
// modules. Registration happens here, in worker code at startup.

import { installPluginConverterWorker } from "/plugin/src/worker.js";
import { moonbitDocuWorks } from "/plugin/src/bindings/moonbit.js";
import { docuworksPlugin } from "/plugin/src/adapters/docuworks.js";
import * as xdw from "/_build/js/debug/build/plugin/moonbit/docuworks_js/docuworks_js.js";

installPluginConverterWorker([docuworksPlugin({ delegate: moonbitDocuWorks(xdw) })]);
