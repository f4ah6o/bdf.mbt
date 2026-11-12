// Type declarations for the file format plugin API (apiVersion 1).

export const FORMAT_PLUGIN_API_VERSION: 1;

export declare class PluginError extends Error {
  constructor(message?: string, code?: string);
  name: "PluginError";
  code: string;
}

export declare class ConvertError extends Error {
  constructor(message?: string, code?: string);
  name: "ConvertError";
  code?: string;
}

/** Frozen host facts handed to every plugin operation. */
export declare interface PluginContext {
  readonly hostApiVersion: number;
}

/** Wire options, normalized by the host's option validation. */
export declare interface ConverterWireOptions {
  format: string;
  name: string;
  password: string;
  pages: string;
  params: Readonly<Record<string, string>>;
  /** how the plugin was chosen: "format-option" | "detect" | "name" */
  detectedVia: string;
}

export declare interface PluginConvertResult {
  bdf: Uint8Array;
  summary: string;
  warnings?: string[];
}

export declare interface PluginOpenResult extends PluginConvertResult {
  /** 0: the document is complete; > 0 requires `stream`, and pages can be
   *  pulled. The host claims the stream handle before validating the rest
   *  of the result and releases it exactly once on every rejected open —
   *  malformed output, invalid or zero pages with a `stream` object, plugin
   *  failure, or late resolution after dispose. */
  pages?: number;
  /** a plugin-owned object; it never crosses the message boundary. */
  stream?: object;
}

export declare interface FormatPlugin {
  readonly apiVersion: number;
  readonly name: string;
  readonly description: string;
  readonly extensions: readonly string[];
  readonly version?: string;
  readonly vendor?: string;
  readonly detect?: (bytes: Uint8Array, context: Readonly<PluginContext>) => boolean;
  readonly convert: (
    bytes: Uint8Array,
    options: Readonly<ConverterWireOptions>,
    context: Readonly<PluginContext>,
  ) => PluginConvertResult | Promise<PluginConvertResult>;
  readonly open?: (
    bytes: Uint8Array,
    options: Readonly<ConverterWireOptions>,
    context: Readonly<PluginContext>,
  ) => PluginOpenResult | Promise<PluginOpenResult>;
  readonly page?: (
    stream: object,
    index: number,
    context: Readonly<PluginContext>,
  ) => { bdf: Uint8Array; warnings?: string[] } | Promise<{ bdf: Uint8Array; warnings?: string[] }>;
  readonly finish?: (
    stream: object,
    context: Readonly<PluginContext>,
  ) => PluginConvertResult | Promise<PluginConvertResult>;
  /** May be asynchronous; the host awaits it and runs it exactly once per
   *  handle. Operations on one lease are serialized in arrival order, so a
   *  disposeStream never runs under an in-flight `page`/`finish` of the same
   *  lease. `reason` is "close" for a wire close, "rejected-open" when a
   *  claimed handle was released because its open result failed validation,
   *  or the host's dispose reason (default "host dispose") at teardown. A
   *  failure during a "rejected-open" release is appended to the request's
   *  primary error, never hidden. */
  readonly disposeStream?: (
    stream: object,
    context: Readonly<PluginContext>,
    reason?: string,
  ) => void | Promise<void>;
  /** May be asynchronous; the registry awaits it and runs it exactly once. */
  readonly dispose?: (
    context: Readonly<PluginContext>,
    reason?: string,
  ) => void | Promise<unknown>;
}

/**
 * Validate (and freeze) a plugin descriptor. Throws `PluginError` on an
 * unknown key, a bad name pattern, a non-lowercase extension claim, an
 * `apiVersion` mismatch, a non-function operation key (including serialized
 * function bodies, which can never be honored), or an `open` without
 * `page`/`finish`.
 */
export declare function defineFormatPlugin(
  descriptor: FormatPlugin,
  options?: { requireFunctions?: boolean },
): Readonly<FormatPlugin>;

/** Call a plugin operation and normalize without assuming Error.hood. */
export declare function errorText(error: unknown): string;

export declare function pluginContext(): Readonly<PluginContext>;

export declare interface FormatEntry {
  name: string;
  description: string;
  extensions: string[];
}

export declare interface Detected {
  plugin: Readonly<FormatPlugin>;
  via: "format-option" | "detect" | "name";
}

export declare interface FormatRegistry {
  readonly apiVersion: number;
  readonly length: number;
  register(plugin: FormatPlugin, source?: string): Readonly<FormatPlugin>;
  /** Deterministic detection: an explicit format, then content detection in
   *  registration order, then the file-name extension claim. Detectors must
   *  be synchronous: a promise-returning detect is a contract error. */
  detect(bytes: Uint8Array, name?: string, formatOption?: string): Detected;
  plugin(name: string): Readonly<FormatPlugin> | null;
  formats(): FormatEntry[];
  registrations(): { source: string; name: string; extensions: string[] }[];
  /** Async-safe and idempotent; every plugin dispose runs exactly once and
   *  repeated calls return the same settled report. */
  dispose(reason?: string): Promise<{ reason: string; outcomes: { name: string; ok: boolean; returned?: unknown; error?: unknown }[] }>;
}

export declare function createFormatRegistry(options?: {
  plugins?: Array<FormatPlugin | [FormatPlugin, string]>;
  source?: string;
}): FormatRegistry;

export declare interface ConverterHost {
  /** One converter envelope message; every failure becomes a failure reply.
   *  Work that resolves after `dispose` is dropped and its late stream
   *  handle is released exactly once. */
  handle(request: unknown): Promise<void>;
  /** Async-safe and idempotent. Releases every lease (calling the owning
   *  plugin's disposeStream exactly once per handle) and settles every
   *  plugin dispose exactly once; concurrent or repeated calls return the
   *  same settled report. Releases that a wire close or a rejected open
   *  started before disposal settles are awaited before any plugin dispose
   *  runs, and each contributes an entry to `released`; a close-disposer
   *  failure racing the disposal is reported there (`how: "wire-close"`),
   *  since its own reply was dropped. `how` is one of "close" (its own
   *  loop), "wire-close", "rejected-open" or "post-failure". Rejects
   *  nothing, records failures instead. All convert/open calls accepted before
   *  disposal and their cleanups settle before plugin teardown; an unresolved
   *  plugin promise can delay graceful disposal indefinitely. Dropped call
   *  failures are retained in `dropped`; no cancellation or timeout is added. */
  dispose(reason?: string): Promise<{
    reason: string;
    released: { id: number; name: string; ok: boolean; error: string | null; how?: string }[];
    dropped: { id: number; name: string; type: string; error: string }[];
    plugins: { name: string; ok: boolean; returned?: unknown; error?: unknown }[];
  }>;
  formats(): FormatEntry[];
  readonly streamCount: number;
}

export declare function createConverterHost(options: {
  registry: FormatRegistry;
  postMessage: (message: any, transfer?: Transferable[]) => void;
  context?: Readonly<PluginContext>;
}): ConverterHost;

// The worker-side installer is declared in types/worker.d.ts (the
// `./plugin/worker` and plugin `./worker` entries): the runtime module
// src/worker.js exports only installPluginConverterWorker, and src/index.js
// exports none of it. Equally, the DocuWorks constants and adapter factory
// live in types/docuworks.d.ts with src/adapters/docuworks.js. Do not add
// exports here that src/index.js does not provide at runtime.

/** Copy the exact byte range of an ArrayBuffer body or typed-array view. */
export declare function toBytes(data: ArrayBuffer | ArrayBufferView): Uint8Array;
/** Copy the exact byte range a plugin reported, before transfer. */
export declare function outgoingBytes(plugin: { name: string }, value: Uint8Array, field: string): Uint8Array;

export declare const DOCUWORKS_FORMAT_NAME: "xdw";
export declare const DOCUWORKS_EXTENSIONS: readonly [".xdw", ".xbd"];
export declare const DOCUWORKS_DESCRIPTION: string;

export declare interface DocuWorksDelegate {
  /** Must be synchronous: the registry's detection loop cannot await. A
   *  promise-returning detector is rejected at call time with the
   *  `async-detect` PluginError instead of silently counting as false. */
  detect(bytes: Uint8Array): boolean;
  convert(
    bytes: Uint8Array,
    request: { includeHidden: boolean; name: string },
  ): PluginConvertResult | Promise<PluginConvertResult>;
}

/** Wrap a DocuWorks converter delegate in the plugin contract. */
export declare function docuworksPlugin(options: {
  delegate: DocuWorksDelegate;
  name?: string;
  description?: string;
  extensions?: readonly string[];
  version?: string;
  vendor?: string;
}): Readonly<FormatPlugin>;

/** The MoonBit `plugin/moonbit/docuworks_js` export module as a delegate. */
export declare interface DocuWorksMoonBitModule {
  bdf_xdw_detect(data: Uint8Array): boolean;
  bdf_xdw_convert(data: Uint8Array, includeHidden: boolean): string;
}

export declare function moonbitDocuWorks(module: DocuWorksMoonBitModule): DocuWorksDelegate;

/** Strict standard base64 decode: the length must be a multiple of four,
 *  characters outside the standard alphabet, misplaced `=` (anywhere but the
 *  trailing positions of the final quad) and padding that carries data bits
 *  (e.g. "AB==") are errors. */
export declare function base64Decode(text: string, what?: string): Uint8Array;

export declare class BindingError extends Error {
  constructor(message?: string, code?: string);
  name: "ConvertError";
  code: string;
}
