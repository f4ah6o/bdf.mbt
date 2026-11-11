# bdf format plugin API

A versioned JavaScript plugin API for adding input file formats to the BDF
converter without patching converter dispatch code. The builtin DocuWorks
(`.xdw`) adapter is expressed with the same contract. The design, boundaries,
trust model, option/result validation and lifecycle semantics live in
[`docs/format-plugin-api.md`](../docs/format-plugin-api.md) of the repository.

## Pre-release status

The public deliverable for consumers is the **`bdf.mbt`** library package: its
npm name is final, and it is **not published** — staging artifacts are built as
`bdf.mbt@0.0.0-staging` with `"private": true`, the release version and the
npm publisher account are pending, and publication is not authorized while
release-candidate validation is still pending. This plugin API release
candidate is not ready for publication.

This directory additionally builds an **internal staging package** named
`bdf-format-plugin-api` (`plugin/package.json`): its tarball exists only for
this repository's own pack-and-smoke pipeline (`plugin/tools/pack.mjs`,
`plugin/tools/smoke.mjs`). It is not the public deliverable, its identity is
internal, and no downstream consumer should depend on that name. The staging
name is configurable at pack time and never selects files by name.

Both packages ship the same modules under different export shapes; the
recommended imports below are the public `bdf.mbt` ones.

## Use (Worker, through the public library)

```js
// plugin-worker.js — built and served by the deployer
import { installPluginConverterWorker } from "bdf.mbt/plugin/worker";
import { docuworksPlugin } from "bdf.mbt/plugin/adapters/docuworks";
import { moonbitDocuWorks } from "bdf.mbt/plugin";
import * as xdw from "bdf.mbt/xdw"; // the compiled MoonBit DocuWorks JS export

installPluginConverterWorker([docuworksPlugin({ delegate: moonbitDocuWorks(xdw) })]);
```

The worker speaks the same converter envelope as `native_converter_worker`
(`init`/`convert`/`open`/`page`/`finish`/`close`), so the existing converter
clients drive it unchanged. Plugins are registered only in worker code at
startup: the envelope rejects a `register` message, and no API ever imports a
URL or evaluates a descriptor arriving as data.

A downstream adapter implements the same delegate functions (`detect`,
`convert`) with its own converter and registers the descriptor under its own
format name — no patching of the registry or host dispatch, and no private code
shipped here. A third-party plugin composes next to the builtin DocuWorks
adapter; see the composition example in
[`docs/format-plugin-api.md`](../docs/format-plugin-api.md) and the
downstream-worker emitter documented in
[`plugin/library/README.md`](library/README.md).

## Internal staging variant (repository pipeline only)

Inside this repository the same modules carry the internal staging manifest
`bdf-format-plugin-api`, with export map `.` (registry, host, contract,
DocuWorks helpers), `./worker` (`installPluginConverterWorker`) and
`./adapters/docuworks` (adapter and constants):

```js
// repository-internal staging smoke only — not a consumer import contract
import { installPluginConverterWorker } from "bdf-format-plugin-api/worker";
import { docuworksPlugin } from "bdf-format-plugin-api/adapters/docuworks";
import { moonbitDocuWorks } from "bdf-format-plugin-api";
```

Downstream code should target the `bdf.mbt` entries instead; the staging name
is subject to internal change without notice.

## Host page (unchanged clients)

```js
// the shipped client from the library package's root export, or the page's
// own Converter-class client — the envelope is unchanged
import { bdf_create_native_converter } from "bdf.mbt";

const workerUrl = "/assets/plugin-worker.js"; // served, module type implied
const client = bdf_create_native_converter(workerUrl);
const formats = await client.ready; // [{name: "xdw", ...}]
const { bdf, format, summary, warnings } = await client.convert(bytes, { name: "sample.xdw" });
```

## Implementing a plugin: checklist

`defineFormatPlugin` and the host validate the descriptor, option and result
**shapes** before and after your plugin runs; the behavioral rules below are
yours to honor as the plugin implementor. The full rules are in
[`docs/format-plugin-api.md`](../docs/format-plugin-api.md).

- Descriptor fields: `apiVersion`, `name`, `description` are required;
  `version` and `vendor` are optional strings. Unknown keys are errors — a
  descriptor with a typo'd key is refused, not silently half-registered.
- `apiVersion` must be exactly `1`: the host matches versions exactly and
  never negotiates.
- `name` matches `^[a-z][a-z0-9-]*$`; `extensions` (optional) is an array of
  unique lowercase suffix strings like `".xdw"`. A name or exact suffix
  claimed twice is a registration error naming both registrations.
- Selection is deterministic and ordered per request: a nonempty
  `options.format` selects that registered name directly (unknown names fail
  with `unknown-format`); otherwise the registered detectors run in
  registration order and the **first `true` wins** — the filename plays no
  part in breaking detector ties; only when no detector claims the input does
  the **longest registered suffix** matching the filename apply,
  case-insensitively. Without a match the request fails with
  `no-format-matched`.
- All detectors for a request see the same copied byte array; treat it as
  read-only. A detector that mutates it can affect later detectors and the
  conversion of that request — avoid time-dependent or mutable detection
  results.
- `convert` is required. Declaring `open` commits to `page` and `finish`.
- `detect` must be **synchronous**: an `async function` detector is refused at
  registration time, and a thenable returned at detect time is a detect-time
  contract error (`async-detect`).
- Every operation key must be a real function: descriptors that arrive as
  JSON or over a message can only be rejected — plugin code is imported, never
  transported.
- Options are validated before your plugin runs: `format`, `name`,
  `password` (strings), `params` (an object whose values are strings, numbers
  or booleans — each is normalized with `String(value)`), and for the v1
  plugin surface `pages` only as an empty string. Unknown option keys are
  errors, so your plugin cannot silently ignore a misspelled option.
- Results are validated after your plugin runs: `bdf` must be a `Uint8Array` —
  a subarray or a Node `Buffer` is fine, and any view is copied to exactly its
  byte range, so the reply always carries fresh bytes, never a view into a
  shared buffer; `summary` must be a string; `warnings` is optional and
  normalized to `[]` when omitted (it must contain only strings). Malformed
  output is an error naming your plugin, and a stream handle claimed by a
  malformed open result is released exactly once.
- Streaming leases: `open` resolving with `pages > 0` and a stream handle
  publishes a lease. Your `page(stream, index)` and `finish(stream)` receive
  your own opaque stream object — the host retains it, and the client never
  sees it. Client wire messages address the lease by its monotonically
  increasing numeric ID. Operations on one lease are serialized in arrival
  order. `disposeStream` may be asynchronous, and every handle is released
  exactly once across close, dispose and rejected opens — a failing release
  surfaces in the request's reply or in the disposal report and is never
  swallowed.
- Errors: throw `PluginError`/`ConvertError` (both exported) with an optional
  `code`; failure replies carry the producer's `code` when one is set. A
  plugin's thrown error becomes its request's error reply, with a failing
  cleanup **appended** to it — cleanup never replaces and never hides the
  primary error, and the primary error never hides the cleanup failure. A
  failure whose reply is already suppressed by disposal is retained in the
  disposal report instead.

## Limitations

- Plugin execution is **trusted code, not a sandbox**: a plugin has the
  worker's own authority. If you cannot trust an adapter's provenance, do not
  import it.
- The plugin Worker is a separate Worker from the native converter Worker —
  they speak the same envelope and coexist, with no combined single Worker;
  the builtin DocuWorks adapter and the native builtins are not merged.
- Unknown deep package paths are unsupported: the shipped export map is the
  complete surface. A browser Worker resolves URLs, never npm specifiers, so
  the deployer builds or emits the Worker file and serves it (see the emitter
  recipe in [`plugin/library/README.md`](library/README.md)).

## License

MIT: both staging tarballs pack the repository's root `LICENSE` file
unchanged, next to this README. Attribution for the upstream project and the
public DocuWorks sample corpus lives in [`NOTICE.md`](NOTICE.md).
