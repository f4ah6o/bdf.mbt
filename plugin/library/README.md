# bdf.mbt

Prebuilt ES modules for BDF conversion, viewing, rendering, forms, and a
versioned file-format plugin API.
Consumers do not need the MoonBit toolchain.

The unscoped package is published on [npm](https://www.npmjs.com/package/bdf.mbt).
The first release, `2026.11.1`, was published through npm Trusted Publishing.
The default staging package is `0.0.0-staging` with `"private": true`;
releases use YYYY.MM.PATCH CalVer in Asia/Tokyo and npm Trusted Publishing.
See [the release guide](https://github.com/f4ah6o/bdf.mbt/blob/main/docs/npm-release.md) for validation and publication.
The examples below pin the first public release for reproducibility.

## Package entry points

| Import | Purpose |
| --- | --- |
| `bdf.mbt` | Browser/viewer API, including `mount_bdf`, `Viewer`, selection, region rendering, and `bdf_create_native_converter`. |
| `bdf.mbt/workers/native` | Self-installing native builtin converter Worker. |
| `bdf.mbt/workers/render` | Page rasterizing Worker. |
| `bdf.mbt/workers/plugin` | Prebuilt plugin Worker with the builtin DocuWorks adapter and the Excalidraw and Mermaid diagram adapters registered. |
| `bdf.mbt/forms` | `bdf_form_describe`, `bdf_form_fill`, `bdf_form_compile`. |
| `bdf.mbt/xdw` | Raw `bdf_xdw_detect` and `bdf_xdw_convert` bindings. |
| `bdf.mbt/plugin` | Descriptor validation, registry, host, plugin types, and DocuWorks binding helpers. |
| `bdf.mbt/plugin/worker` | `installPluginConverterWorker`. |
| `bdf.mbt/plugin/diagram-bdf` | Shared bounded diagram-to-BDF encoder (`encodeDiagram`, limits, `DiagramEncodeError`). |
| `bdf.mbt/plugin/adapters/docuworks` | `docuworksPlugin` and its format constants. |
| `bdf.mbt/plugin/adapters/excalidraw` | `excalidrawPlugin`: Excalidraw scenes as vector primitives (documented subset). |
| `bdf.mbt/plugin/adapters/mermaid` | `mermaidPlugin`: static Mermaid flowcharts (documented subset). |
| `bdf.mbt/tools/emit-downstream-worker` | Node CLI script for emitting a browser-resolvable plugin Worker. |

Declarations are adjacent to the compiled bundles and in `types/index.d.ts`,
`types/worker.d.ts`, `types/diagram-bdf.d.ts`, `types/docuworks.d.ts`,
`types/excalidraw.d.ts`, and `types/mermaid.d.ts` for the plugin entries.
Each typed entry selects its own declaration through the export map.
The emitter and prebuilt plugin Worker are executable scripts, not typed APIs.
Do not import undocumented package subpaths.

The native Worker contains 24 formats: csv, xlsx, docx, pptx, font, pdf, image,
ai, tiff, psd, emf, xdw, idml, visio, markdown, html, audio, hpgl, jww, dxf,
sxf, cgm, drawio, and parquet.
The plugin Worker contains only explicitly registered plugins; its prebuilt
version registers the builtin `xdw` adapter (`.xdw` and `.xbd`) plus the
`excalidraw` and `mermaid` diagram adapters.
These are separate hosts, with **no automatic routing between them**.

## Browser quickstart: static files, no bundler

Install the package into your application, then copy its `dist` tree
unchanged into a directory your HTTP server serves:

```sh
npm install bdf.mbt@2026.11.1
mkdir -p public
cp -R node_modules/bdf.mbt/dist public/bdf.mbt-dist
```

Start with a clean `public/bdf.mbt-dist` destination and refresh it when updating
versions, preserving the directory structure and relative imports.
Serve `public` as your site root over HTTP(S), with JavaScript MIME types.
Do not open the page through a `file:` URL.
Save this complete example as `public/index.html`:

```html
<!doctype html>
<html lang="en">
<meta charset="utf-8">
<title>BDF conversion</title>
<input id="input" type="file" accept=".xdw,.xbd,.excalidraw,.excalidraw.json,.mmd,.mermaid">
<pre id="status">Loading converter…</pre>
<script type="module">
import { bdf_create_native_converter } from "/bdf.mbt-dist/browser.js";

const converter = bdf_create_native_converter(
  "/bdf.mbt-dist/workers/plugin-converter.mjs",
);
const input = document.querySelector("#input");
const status = document.querySelector("#status");
try {
  const formats = await converter.ready;
  status.textContent = `Ready: ${formats.map(entry => entry.name).join(", ")}`;
  input.addEventListener("change", async () => {
    const file = input.files[0];
    if (!file) return;
    input.disabled = true;
    try {
      const result = await converter.convert(await file.arrayBuffer(), {
        name: file.name,
      });
      status.textContent = JSON.stringify({
        format: result.format,
        summary: result.summary,
        warnings: result.warnings,
        bytes: result.bdf.byteLength,
      }, null, 2);
      // result.bdf is a Uint8Array for saving or passing to the viewer.
    } catch (error) {
      status.textContent = `${error.code ?? "conversion-error"}: ${error.message}`;
    } finally {
      input.disabled = false;
    }
  });
} catch (error) {
  status.textContent = error.message;
}
window.addEventListener("pagehide", () => converter.terminate(), { once: true });
</script>
</html>
```

The prebuilt plugin Worker converts all three registered input formats:
DocuWorks (`.xdw`, `.xbd`), Excalidraw scenes (`.excalidraw`,
`.excalidraw.json`) and static Mermaid flowcharts (`.mmd`, `.mermaid`).
Conversion `params` are per plugin: the builtin DocuWorks adapter accepts
`include_hidden` (default `false`), while the diagram adapters accept no
`params` keys at all, so the example passes none.

`new Worker()` fetches a URL; it does not resolve npm package specifiers.
The example imports a served file directly and passes a served Worker URL.
A bundler may resolve `import { bdf_create_native_converter } from "bdf.mbt"`
in application code, but must also emit the Worker assets or use these static
URLs. Page import maps do not apply inside Workers.

To use native builtins instead, choose
`/bdf.mbt-dist/workers/native_converter_worker.js` as the Worker URL and use
options supported by the selected native format.
The same client can drive either protocol-compatible browser Worker.
Input is an `ArrayBuffer` or typed-array view, **not a `File` or `Blob`**;
call `file.arrayBuffer()` first.
`ready` resolves to format-entry objects, not a string array.

## Add a plugin with the emitter

A plugin is an imported object containing real functions.
For a minimal **protocol demonstration only**, save `public/zine-plugin.mjs`:

```js
export const plugin = {
  apiVersion: 1,
  name: "zine",
  description: "Zine protocol demonstration",
  extensions: [".zine"],
  detect: bytes => bytes[0] === 0x5a,
  convert(bytes) {
    return { bdf: bytes.slice(), summary: "Echoed bytes; not a BDF document" };
  },
};
```

This echoes its input. It does **not** generate a valid BDF and must not be
used as a document converter or sent to a viewer.
Replace `convert` with a real parser/BDF producer for production use.

Emit a Worker into the same served directory:

```sh
node node_modules/bdf.mbt/dist/tools/emit-downstream-worker.mjs \
  --plugin ./public/zine-plugin.mjs \
  --out ./public/my-plugin-worker.mjs \
  --prefix /bdf.mbt-dist
```

The emitter selects the module's named `plugin` export, falling back to its
`default` export, validates the descriptor, and writes the Worker file.
`--plugin` must be inside the output Worker's directory or a descendant, so
its relative URL stays within the deployment tree.
`--prefix` is an absolute URL path for the copied package `dist` tree, not a
filesystem path or an npm specifier.
Create the output directory first.

The generated Worker registers the supplied plugin first and the builtin
DocuWorks adapter second, so names/extensions must not conflict with `xdw`,
`.xdw`, or `.xbd`.
Point the browser example at `/my-plugin-worker.mjs` to use it.
For a quick check from a page module:

```js
import { bdf_create_native_converter } from "/bdf.mbt-dist/browser.js";
const converter = bdf_create_native_converter("/my-plugin-worker.mjs");
try {
  console.log((await converter.ready).map(entry => entry.name)); // ["zine", "xdw"]
  const result = await converter.convert(new Uint8Array([0x5a, 1, 2]), {
    name: "demo.zine",
  });
  console.log(result.format, [...result.bdf]); // "zine", [90, 1, 2]
} finally {
  converter.terminate();
}
```

**The emitter is not a bundler.** It imports the plugin in Node during generation,
so top-level code and dependencies execute there.
They execute again in the browser Worker at runtime.
Only run the emitter with trusted code; make all dependencies resolvable in
both environments and browser-compatible.
Serve relative dependency files yourself, or bundle the plugin into a suitable
ES module first. The emitter does not rewrite bare imports, bundle dependencies,
or provide Node builtins in the browser.

## Node CLI: convert directly without a Worker

Use Node 20 or later. The direct DocuWorks binding avoids browser Worker APIs.
Save as `convert-xdw.mjs`:

```js
import { readFile, writeFile } from "node:fs/promises";
import { basename } from "node:path";
import * as xdw from "bdf.mbt/xdw";
import { moonbitDocuWorks } from "bdf.mbt/plugin";

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  throw new Error("Usage: node convert-xdw.mjs INPUT.xdw OUTPUT.bdf");
}
const converter = moonbitDocuWorks(xdw);
const bytes = new Uint8Array(await readFile(input));
const result = await converter.convert(bytes, {
  includeHidden: false,
  name: basename(input),
});
await writeFile(output, result.bdf, { flag: "wx" }); // Do not overwrite a file.
console.log(result.summary);
for (const warning of result.warnings ?? []) console.warn(warning);
```

```sh
node convert-xdw.mjs sample.xdw sample.bdf
```

This calls a delegate directly, so it uses `includeHidden`, not host
`params.include_hidden`, and bypasses registry selection and host validation.
The binding still validates its JSON envelope and base64 payload.
The raw `bdf_xdw_convert` returns JSON, not a `Uint8Array`.

The browser client needs `Worker`, `addEventListener`, and browser message
semantics. Node `worker_threads` does not provide that interface unchanged.
For a Node plugin host, use `createConverterHost` with your own transport or
pass an adapted `{ postMessage, onmessage }` target to the installer.
Do not call `bdf_create_native_converter` in Node expecting it to create a
`worker_threads` worker.

## TypeScript plugin checking

Import types from `bdf.mbt/plugin`; the installer and DocuWorks adapter have
separate runtime entry points as listed above.
With TypeScript installed in your application, save `src/zine-plugin.mts`:

```ts
import type { FormatPlugin } from "bdf.mbt/plugin";

export const plugin = {
  apiVersion: 1,
  name: "zine",
  description: "Zine protocol demonstration",
  extensions: [".zine"],
  detect(bytes) {
    return bytes[0] === 0x5a;
  },
  convert(bytes, options, context) {
    // params are normalized strings; the host supplies these other fields.
    const label = options.params.label ?? options.name;
    return {
      bdf: bytes.slice(), // Protocol demo only; replace with real BDF generation.
      summary: `${label}: ${options.detectedVia}, API ${context.hostApiVersion}`,
      warnings: [],
    };
  },
} satisfies FormatPlugin;
```

Use this `tsconfig.json`:

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "lib": ["ES2022", "DOM"],
    "strict": true,
    "rootDir": "src",
    "outDir": "public"
  },
  "include": ["src/zine-plugin.mts"]
}
```

Run `npx tsc --project tsconfig.json`, then use the emitter with
`public/zine-plugin.mjs` as above.
The type-only import disappears from the generated module, leaving no bare
runtime import for the browser to resolve.
`apiVersion: 1` is the contract version, separate from the npm package's
staging or release version.
Generated browser-client types currently return `any`; plugin descriptors have
the more specific declarations shown here.

## Lifecycle, limits, and reference

- Selection is explicit `format`, then detectors in registration order, then
  the longest case-insensitive filename suffix. No match is an error.
  Duplicate names or exact extension claims fail registration.
- Plugins are trusted code at generation time and runtime, not sandboxed.
  The host validates shapes and copies bytes; it does not validate that output
  is semantically valid BDF or constrain a plugin's permissions.
- API v1 options are `format`, `name`, `password`, `params`, and empty `pages`.
  Primitive string/number/boolean params normalize to strings. Unknown options,
  nonempty page selection, and font options fail explicitly.
- Convert-only plugins, including the builtin DocuWorks adapter, support `open`
  by returning a complete document with `pages: 0` and no lease.
  Streaming plugins require `open`, `page`, and `finish`; clients must `close`
  the stream in `finally`, even after `finish`.
- `terminate()` stops a Worker immediately; it is not graceful plugin disposal.
  A plugin whose `open` fails before returning a handle must release its own
  resources. The host can only clean up handles it has received.

For signatures, error codes, streaming examples, ownership transitions,
shutdown ordering, and the complete trust model, see
[`docs/format-plugin-api.md`](../../docs/format-plugin-api.md), which ships
inside this package. For the diagram input formats (Excalidraw scenes and
static Mermaid flowcharts) and their documented subset limits, see
[`docs/diagram-plugins.md`](../../docs/diagram-plugins.md), which also ships
inside this package.
The native Worker and JS-plugin registry remain separate; extending one does
not add formats to the other.

## Licenses

MIT; see `LICENSE`, `NOTICE.md`, and the shipped third-party license texts.
Packaging uses an explicit allowlist and excludes tests, sample corpora,
source maps, and local paths.
