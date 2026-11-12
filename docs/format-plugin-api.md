# File format plugin API

Add input formats to a BDF converter Worker with imported JavaScript plugins.
This reference describes **plugin API version 1** and the public exports of
`bdf.mbt`.
For installation and complete browser, Node, and TypeScript examples, see
[the library quickstart](../plugin/library/README.md).

The npm package name is `bdf.mbt`; it has **not been published**.
The default staging artifact is `bdf.mbt@0.0.0-staging` with `"private": true`.
Releases use CalVer (`YYYY.MM.PATCH`) and npm Trusted Publishing.
See the [release procedure](npm-release.md) for artifact validation and initial setup.
`apiVersion: 1` identifies the plugin contract, not the npm package version;
plugin `version` metadata is independent of both.
The host requires an exact API version match and does not negotiate versions.

## Architecture and imports

A browser client sends converter messages to one Worker URL.
Inside a plugin Worker, four components have distinct responsibilities:

1. **Registry:** `createFormatRegistry` validates registrations, rejects name
   and extension conflicts, and selects a plugin deterministically.
2. **Host:** `createConverterHost` validates requests and results, invokes the
   selected plugin, posts replies, and manages stream leases and cleanup.
3. **Installer:** `installPluginConverterWorker` registers imported plugins at
   startup, creates a host, and attaches its handler to a Worker target.
4. **Adapter:** a plugin translates a converter's own API into this contract.
   `docuworksPlugin({ delegate })` handles DocuWorks options and delegate
   errors; `moonbitDocuWorks(xdw)` adapts the compiled MoonBit JSON interface.

Use these exported entry points, without `.js` suffixes:

| Import | Runtime exports / purpose | Declaration module |
| --- | --- | --- |
| `bdf.mbt/plugin` | `FORMAT_PLUGIN_API_VERSION`, `defineFormatPlugin`, `createFormatRegistry`, `createConverterHost`, `pluginContext`, `PluginError`, `ConvertError`, `errorText`, `toBytes`, `outgoingBytes`; also the DocuWorks adapter/constants, `moonbitDocuWorks`, `base64Decode`, `BindingError` | `types/index.d.ts` |
| `bdf.mbt/plugin/worker` | `installPluginConverterWorker` only | `types/worker.d.ts` |
| `bdf.mbt/plugin/diagram-bdf` | `encodeDiagram`, the primitive limits, `DiagramEncodeError` | `types/diagram-bdf.d.ts` |
| `bdf.mbt/plugin/adapters/docuworks` | `docuworksPlugin`, `DOCUWORKS_FORMAT_NAME`, `DOCUWORKS_EXTENSIONS`, `DOCUWORKS_DESCRIPTION` only | `types/docuworks.d.ts` |
| `bdf.mbt/plugin/adapters/excalidraw` | `excalidrawPlugin`, `EXCALIDRAW_FORMAT_NAME`, `EXCALIDRAW_EXTENSIONS`, `EXCALIDRAW_DESCRIPTION`, `EXCALIDRAW_INPUT_LIMIT` only | `types/excalidraw.d.ts` |
| `bdf.mbt/plugin/adapters/mermaid` | `mermaidPlugin`, `MERMAID_FORMAT_NAME`, `MERMAID_EXTENSIONS`, `MERMAID_DESCRIPTION` only | `types/mermaid.d.ts` |
| `bdf.mbt/xdw` | `bdf_xdw_detect`, `bdf_xdw_convert` | `dist/xdw/docuworks_js.d.ts` |

Types such as `FormatPlugin`, `ConverterWireOptions`, `PluginContext`,
`PluginConvertResult`, `PluginOpenResult`, `FormatRegistry`, `ConverterHost`,
`DocuWorksDelegate`, and `DocuWorksMoonBitModule` are type-only imports from
`bdf.mbt/plugin`.
The installer is not exported from that entry point.
Deep package paths not listed in the export map are unsupported.

A bundler-resolved Worker entry can compose the builtin adapter and another
plugin as follows:

```js
import { installPluginConverterWorker } from "bdf.mbt/plugin/worker";
import { docuworksPlugin } from "bdf.mbt/plugin/adapters/docuworks";
import { moonbitDocuWorks } from "bdf.mbt/plugin";
import * as xdw from "bdf.mbt/xdw";
import { plugin } from "./zine-plugin.mjs";

const host = installPluginConverterWorker([
  plugin,
  docuworksPlugin({ delegate: moonbitDocuWorks(xdw) }),
]);
```

This source requires package-specifier resolution by a bundler.
For a plain browser, use the quickstart's static-file emitter instead;
page import maps do not resolve bare imports inside Workers.
Register only the plugins you want to expose.
An alternative implementation cannot override an existing registration.

## Descriptor contract

`defineFormatPlugin(descriptor)` validates a descriptor and returns a shallowly
frozen copy with a copied `extensions` array.
It does not deeply freeze plugin state or the array; treat metadata as immutable
once registered.
Unknown descriptor keys are errors.

| Field | Requirement |
| --- | --- |
| `apiVersion` | Exactly `FORMAT_PLUGIN_API_VERSION` (`1`, a number). |
| `name` | Required string matching `^[a-z][a-z0-9-]*$`; the wire format identity. |
| `description` | Required string, returned in format listings. |
| `extensions` | Lowercase suffixes matching `^\.[a-z0-9][a-z0-9._-]*$`, without duplicates. Runtime omission becomes `[]`; supply `[]` when using `FormatPlugin`. |
| `version`, `vendor` | Optional strings; informational metadata. |
| `convert` | Required function, even for a streaming plugin. |
| Other operations | Optional functions; `open` requires both `page` and `finish`. |

Operation signatures are:

```ts
// Result and context types are exported by bdf.mbt/plugin.
detect(bytes: Uint8Array, context: Readonly<PluginContext>): boolean;
convert(bytes: Uint8Array, options: Readonly<ConverterWireOptions>,
        context: Readonly<PluginContext>): PluginConvertResult | Promise<PluginConvertResult>;
open(bytes: Uint8Array, options: Readonly<ConverterWireOptions>,
     context: Readonly<PluginContext>): PluginOpenResult | Promise<PluginOpenResult>;
page(stream: object, index: number, context: Readonly<PluginContext>):
  { bdf: Uint8Array; warnings?: string[] } |
  Promise<{ bdf: Uint8Array; warnings?: string[] }>;
finish(stream: object, context: Readonly<PluginContext>):
  PluginConvertResult | Promise<PluginConvertResult>;
disposeStream(stream: object, context: Readonly<PluginContext>,
              reason?: string): void | Promise<void>;
dispose(context: Readonly<PluginContext>, reason?: string): void | Promise<unknown>;
```

These signatures describe object methods, not a standalone TypeScript module.
The quickstart provides a complete `satisfies FormatPlugin` example.

- `detect` is synchronous and only a literal `true` claims the input.
  An `async` detector is rejected at registration.
  A regular function returning a promise/thenable fails when called with
  `async-detect`; rejection of that unused promise is consumed.
  Detector exceptions abort selection rather than trying the next plugin.
- Other operations may be synchronous or asynchronous.
- The default context is frozen `{ hostApiVersion: 1 }`; retain plugin state
  in your own closures or stream objects, not in the context.
- Descriptors contain real functions, not JSON, serialized function bodies,
  or module URLs supplied by clients.

### Deterministic selection and conflicts

For each conversion or open request:

1. A nonempty `options.format` selects that exact registered name, bypassing
   detection and filename fallback. An unknown name fails with `unknown-format`.
2. Otherwise, detectors run in **registration order**. The first `true` wins.
3. If no detector claims the input, choose the **longest registered suffix**
   matching the filename, case-insensitively. For example, `.drawio.png` wins
   over `.png` for `diagram.DRAWIO.PNG`.
4. Without a match, fail with `no-format-matched`.

A name or exact extension claimed twice is a registration error naming both
registrations and their source labels.
Overlapping suffixes of different lengths are allowed.
There is no override flag.
A plugin with `extensions: []` can still be selected by content or explicit name.

All detectors for a request see the same copied byte array; treat it as read-only.
A mutating detector can affect later detectors and conversion in that request.
Registration order is fixed, but deterministic behavior also requires your
plugin to avoid time-dependent or mutable detection results.

## Options and result validation

Client options are an object with only these keys:

| Key | Accepted input and normalized value |
| --- | --- |
| `format` | String, default `""`; replaced with the selected plugin name before invocation. |
| `name` | String, default `""`; filename used for suffix fallback and plugin metadata. |
| `password` | String, default `""`; support is the selected plugin's responsibility. |
| `pages` | Only `""` or omission. Page selection is not part of API v1. |
| `params` | Object whose values are primitive strings, numbers, or booleans. Each becomes `String(value)`; default `{}`. |

For example, client input `params: { include_hidden: true, limit: 10 }` becomes
`{ include_hidden: "true", limit: "10" }` for the plugin.
Arrays, nested objects, `null`, and `undefined` parameter values are rejected.
Unknown top-level options, including font options, are rejected.
Each plugin must separately validate its parameter keys and supported values.

The plugin receives normalized `ConverterWireOptions`, including
`detectedVia: "format-option" | "detect" | "name"`.
`Readonly` in the declarations expresses a caller contract; the host does not
freeze options at runtime.
Do not mutate them.

`convert` and `finish` return `{ bdf, summary, warnings? }`:

- `bdf` must be a `Uint8Array`, including a subarray or Node `Buffer`.
- `summary` must be a string.
- `warnings` must contain only strings; omission normalizes to `[]`.
- A runtime `format` field, if provided, must equal the registered name.
  The host sets the wire result's identity itself.

`open` returns the same fields plus optional `pages` and `stream`.
`pages` is a non-negative integer, defaulting to zero:

- `pages: 0` means `bdf` is the complete document, with no stream object.
- `pages > 0` requires an object-valued `stream` handle and enables page calls.
- A handle with zero pages is invalid and is released if a disposer exists.

`page` returns `{ bdf, warnings? }` and uses the same byte/warning validation.
Indices are zero-based; the host checks for a non-negative integer, while the
plugin must enforce its own upper bound.

The host validates shapes, not BDF document semantics.
Returning arbitrary bytes in `bdf` does not make those bytes a valid BDF.
Input `ArrayBuffer` or array-buffer views are copied over their exact byte
range; shared-buffer input is rejected.
Output bytes are copied into a fresh intrinsic `Uint8Array` before transfer,
so a subarray or pooled Node `Buffer` cannot expose its entire backing buffer.

## Registry, host, and installer reference

### Registry

```js
const registry = createFormatRegistry({ plugins: [], source: "app" });
registry.register(plugin, "zine module");
const chosen = registry.detect(bytes, "demo.zine", "");
// chosen: { plugin, via: "format-option" | "detect" | "name" }
```

Initial `plugins` accepts descriptors or `[descriptor, sourceLabel]` pairs.
`register` returns the validated descriptor; labels must be nonempty strings.
`registry.plugin(name)` returns a descriptor or `null`.
`formats()` returns `{ name, description, extensions }[]` in registration order;
`registrations()` returns `{ source, name, extensions }[]` for diagnostics.
`apiVersion` and `length` are read-only properties.

`registry.dispose(reason)` calls plugin-level disposers in registration order
and returns `{ reason, outcomes }`, recording success or failure per disposer.
Repeated or concurrent calls return the same disposal result; later registration
is refused.
A registry does not own host leases: dispose a live host through `host.dispose`,
not by calling its registry's disposer first.

### Host and transport

```js
const host = createConverterHost({
  registry,
  postMessage(message, transfer) {
    self.postMessage(message, transfer);
  },
});
await host.handle({ type: "init" });
```

`createConverterHost` accepts an optional `context`, defaulting to
`pluginContext()`.
Use the default unless you intentionally control the embedding context.
The host exposes `handle(request)`, `formats()`, `streamCount`, and
`dispose(reason = "host dispose")`.
The transport must be a functioning `postMessage` callback; plugin errors can
be reported over it, but a broken transport cannot guarantee a failure reply.

| Request | Success reply |
| --- | --- |
| `{ type: "init" }` | `{ id: 0, ok: true, formats }` |
| `{ type: "convert", id, data, options? }` | `{ id, ok: true, result: { bdf, format, summary, warnings, protected: false } }` |
| `{ type: "open", id, data, options? }` | Same result plus `pages`, and `stream` only when a lease exists. |
| `{ type: "page", id, stream, index }` | `{ id, ok: true, result: { bdf, warnings } }` |
| `{ type: "finish", id, stream }` | Same result shape as `convert`. |
| `{ type: "close", id, stream }` | `{ id, ok: true, result: null }` |

Use unique numeric request IDs and numeric stream IDs returned by `open`.
Initialization must precede conversion and stream requests.
Byte results carry the fresh typed array and transfer its buffer.
The `protected: false` field is protocol metadata, not a security guarantee.

Failures are `{ id, ok: false, error, code? }`.
The host preserves exception messages where available and copies a nonempty
`error.code`; non-Error throws are also normalized.
Common codes are `invalid-plugin`, `async-detect`, `unknown-format`,
`no-format-matched`, `invalid-options`, `not-ready`, `no-conversion`,
`registration-at-startup`, and `unknown-request`.
Not every validation error has a code; handle missing codes and show the message.
The browser client rejects the corresponding promise with a `ConvertError`.

### Worker installer

`installPluginConverterWorker(plugins, options?)` returns the host.
Options are `target`, `postMessage`, `registry`, and `source`.
The default target is `self` or `globalThis`; the default registry is empty,
source label is `"worker"`, and transport calls `target.postMessage`.
The installer validates and registers the array before processing messages,
then assigns `target.onmessage`.
An existing non-null handler is an error.
Invalid registrations receive a `plugin [index]:` error prefix.

The protocol does not allow remote plugin registration.
A `register` request fails with `registration-at-startup`; there is no wire
`dispose` operation either.
Host teardown is an embedding API, not a browser-client method.

## Streaming and resource ownership

A convert-only plugin needs no streaming methods: `open` falls back to `convert`
and returns the complete BDF with `pages: 0` and no stream ID.
For a streaming plugin, the host retains the opaque object while the client
receives only a monotonically increasing positive numeric lease ID.

Ownership transitions are explicit:

1. Until `open` resolves with an object containing a recognizable stream
   handle, the plugin owns its resource. If `open` throws or rejects before
   returning that handle, **the plugin must clean it up itself**.
2. Once the result provides a handle, the host claims it **before validation**.
   Invalid bytes, summary, warnings, identity, or page metadata trigger
   `disposeStream(handle, context, "rejected-open")`, when provided.
   A cleanup failure is appended to the primary validation error.
3. Only a valid result with `pages > 0` receives a numeric lease ID.
   Failed reply posting releases that lease with reason `"post-failure"`.
4. `page` and `finish` for one lease run in arrival order.
   Different leases and separate conversions can run concurrently.
   A page/finish error does not close the lease.
5. `finish` produces a result but **does not release the stream**.
   Always close it in `finally`.
6. `close` marks the lease closed immediately, drains already accepted
   operations, and then awaits `disposeStream(..., "close")`.
   Later page/finish requests fail with `no-conversion`.
   A disposer failure rejects close, but the lease is gone either way;
   closing an unknown or already released ID succeeds as a no-op.

A browser-client pattern that handles streaming and convert-only plugins:

```js
async function convertWithPages(converter, bytes, name, onPage) {
  const opened = await converter.open(bytes, { name });
  if (opened.pages === 0) return opened;
  try {
    for (let index = 0; index < opened.pages; index += 1) {
      await onPage(index, await converter.page(opened.stream, index));
    }
    return await converter.finish(opened.stream);
  } finally {
    await converter.close(opened.stream);
  }
}
```

`host.dispose(reason)` suppresses further replies, closes leases, drains their
accepted operations, awaits tracked stream cleanups, and then calls
`registry.dispose(reason)`.
It is idempotent and concurrent-safe, returning
`{ reason, released, dropped, plugins }` with cleanup outcomes instead of rejecting on
disposer failure.
Stream release records contain `id`, `name`, `ok`, `error`, and sometimes `how`;
ID `0` denotes a claimed handle that never became a lease.
A tracked close or rejected-open cleanup racing disposal is awaited before
plugin teardown and included in `released`, even if it settles while disposal
is draining another lease.
Its `how` identifies the path (`"wire-close"`, `"rejected-open"`, or
`"post-failure"`), and disposer failures remain visible as `ok: false` when
there is no longer a request reply to carry them.

Disposal awaits every `convert`/`open` call accepted before shutdown and its
claimed-handle cleanup before calling plugin-level teardown. A late open
result receives no lease or reply, but its handle is released exactly once
and cleanup failures remain in `released`. Failed convert/open calls whose
replies shutdown suppressed are retained in `dropped` with `id`, `name`,
`type`, and `error`. Accepted page/finish failures are retained with their
lease's release outcome, including when stream cleanup also fails.

Graceful disposal provides neither cancellation nor a timeout: a plugin
promise that never settles can delay it indefinitely. A caller that cannot
wait may terminate the worker abruptly, forfeiting graceful cleanup.
Do not reuse a stream object across independent opens; ownership is per open.
Provide `disposeStream` when a handle owns resources, since the host cannot
release converter-specific resources by itself.

`converter.terminate()` terminates the browser Worker and rejects pending client
requests. It is **not graceful disposal** and does not run plugin cleanup hooks.
Close active streams before terminating; applications needing plugin-level
shutdown must arrange their own trusted embedding lifecycle around `host.dispose`.

## DocuWorks adapter and binding

```js
import * as xdw from "bdf.mbt/xdw";
import { moonbitDocuWorks } from "bdf.mbt/plugin";
import { docuworksPlugin } from "bdf.mbt/plugin/adapters/docuworks";

const plugin = docuworksPlugin({ delegate: moonbitDocuWorks(xdw) });
```

The factory accepts `{ delegate, name?, description?, extensions?, version?, vendor? }`.
Defaults are name `"xdw"`, extensions `[".xdw", ".xbd"]`, and the builtin
DocuWorks description.
The delegate must implement:

```ts
detect(bytes: Uint8Array): boolean;
convert(bytes: Uint8Array, request: { includeHidden: boolean; name: string }):
  PluginConvertResult | Promise<PluginConvertResult>;
```

Detection must be synchronous; a promise-returning delegate fails at call time
with `async-detect`.
Conversion may be asynchronous.
The adapter accepts only `params.include_hidden`, with these exact strings:

- False: `""`, `"0"`, `"f"`, `"false"`, `"no"`, `"off"`.
- True: `"1"`, `"t"`, `"true"`, `"yes"`, `"on"`.

Values are case-sensitive and are not trimmed.
Host normalization also lets clients send booleans or `0`/`1`.
Unknown parameters, other values, and nonempty passwords fail explicitly.
Delegate conversion failures gain a `docuworks: ` message prefix and retain a
nonempty string error code.
This adapter implements `convert`, not streaming `open`.

The raw `bdf.mbt/xdw` functions are `bdf_xdw_detect(bytes)` and
`bdf_xdw_convert(bytes, includeHidden)`.
The latter returns a JSON success/error envelope, not BDF bytes directly.
`moonbitDocuWorks` parses it, validates required `bdf`/`summary` strings, and
strictly decodes canonical standard base64.
Missing warnings become `[]`; a non-array warnings value fails, while **array
entries are converted with `String`** before reaching the host's stricter
string-array check.
The binding returns a complete conversion result and does not expose the
raw envelope's page count as a streaming lease.

## Trust model and current limits

Plugins are trusted code, not sandboxed extensions.
The emitter imports the selected plugin and its dependencies in **Node during
generation**, executing top-level code with that process's permissions.
The emitted Worker imports and executes them again **at runtime**, where they
have the Worker's capabilities, including access to input document bytes and
available network APIs.
Review dependencies and deployed assets, restrict credentials and network
access as appropriate, and set a suitable CSP.
Validation and byte copies are correctness measures, not a security boundary.
The host does not use `eval`, `new Function`, or message-supplied module imports.

Current limits:

- The emitter writes imports; it is **not a bundler**. It neither rewrites a
  plugin's dependency graph nor makes Node-only dependencies browser-compatible.
- The native builtin Worker and plugin Worker have separate registries.
  There is no automatic router and no single Worker combining native dispatch
  with arbitrary JS plugins. Choose a Worker in your application or run both.
- API v1 adds no page-selection syntax, font-directory/`fontFiles` handling,
  native image/CSV fallback, asynchronous detection, or scored detection.
- No request cancellation, timeout, resource quota, or plugin isolation is
  provided by this contract. A hung operation can delay close/disposal.
- The shipped browser client requires a browser Worker interface.
  Node `worker_threads` is not a drop-in replacement; use direct bindings or
  supply your own compatible transport/target adapter.
- Type declarations describe the plugin contract, but generated browser-client
  declarations currently expose the converter object as `any`.

Adoption is opt-in: existing native Worker deployments can remain unchanged.
The staging package contains prebuilt modules and allowlisted licenses, not a
claim that all possible formats or deployment environments have been validated.
Publication requires a separate release decision and authorized npm identity.
