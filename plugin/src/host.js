// The converter host: the plugin registry speaking the existing converter
// Worker envelope.
//
// Messages in: `{type, id, data?, options?, stream?, index?}` with types
// `init`, `convert`, `open`, `page`, `finish`, `close`. Replies out:
// `{id, ok, formats|result|error, code?}` — byte results carry `result.bdf`
// as a fresh `Uint8Array` whose exact byte range is transferred. The stream
// objects themselves never leave the worker; the client only sees increasing
// stream IDs, exactly like `bdf_install_converter_worker`.
//
// Lifecycle. Every plugin stream handle is claimed as soon as it can be
// identified in an open result, and released exactly once on every path:
// a rejected open result (malformed output, invalid pages, zero pages),
// a posting failure after the lease was made, a late result after disposal,
// a wire close, and host disposal. Cleanup errors are appended to the
// reported failure, never swallowed. Stream operations are serialized per
// handle: a `close` marks the lease closed, waits for the in-flight call to
// answer, and only then releases the handle; operations arriving after close
// started are refused as stale with the existing `no conversion <id>` error.

import { ConvertError, PluginError, errorText, pluginContext } from "./contract.js";

const KNOWN_OPTIONS = ["format", "name", "password", "params", "pages"];
const STRING_OPTIONS = ["format", "name", "password", "pages"];

function isPlainObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function requireTransport(postMessage) {
  if (typeof postMessage !== "function") {
    throw new PluginError("createConverterHost requires a postMessage function");
  }
}

///|
// Input bytes: an ArrayBuffer body or a typed-array view. The byte range a
// view claims (byteOffset, byteLength) is copied exactly, never the whole
// backing buffer, so a plugin can never be handed bytes that were not sent.
export function toBytes(data) {
  if (data instanceof ArrayBuffer) {
    return new Uint8Array(data.slice(0));
  }
  if (ArrayBuffer.isView(data)) {
    if (!(data.buffer instanceof ArrayBuffer)) {
      throw new ConvertError("input data must not reference a shared buffer");
    }
    return new Uint8Array(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength));
  }
  throw new ConvertError("input data must be an ArrayBuffer or a typed array view");
}

///|
// Output bytes: a fresh intrinsic `Uint8Array` holding exactly the byte
// range the plugin reported. `value.slice()` is not enough here: a Node
// Buffer is a Uint8Array subclass whose slice shares its pooled backing
// buffer, and transferring that buffer would hand the caller far more than
// the plugin's bytes.
export function outgoingBytes(plugin, value, field) {
  if (!(value instanceof Uint8Array)) {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: ${field} must be a Uint8Array, not ${value === null ? "null" : typeof value}`,
    );
  }
  const out = new Uint8Array(value.length);
  out.set(value);
  return out;
}

function outgoingWarnings(plugin, value, field) {
  const warnings = value ?? [];
  if (!Array.isArray(warnings)) {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: ${field} must be an array of strings`,
    );
  }
  for (const warning of warnings) {
    if (typeof warning !== "string") {
      throw new PluginError(
        `plugin "${plugin.name}" returned malformed output: ${field} must only hold strings`,
      );
    }
  }
  return [...warnings];
}

function outgoingPages(plugin, value) {
  const pages = value ?? 0;
  if (typeof pages !== "number" || !Number.isInteger(pages) || pages < 0) {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: pages must be a non-negative integer`,
    );
  }
  return pages;
}

///|
// A stream handle the moment it can be identified in an open result — before
// the rest of that result is judged valid. The plugin already made the
// resource; rejecting the result does not undo that, so the handle is
// claimed here and released on every path that does not turn it into a lease.
function claimedHandle(opened) {
  if (!isPlainObject(opened)) {
    return null;
  }
  const candidate = opened.stream;
  if (candidate === undefined || candidate === null || typeof candidate !== "object") {
    return null;
  }
  return candidate;
}

function acceptSummary(plugin, value, kind) {
  if (typeof value.summary !== "string") {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: the ${kind} result's summary must be a string`,
    );
  }
  return value.summary;
}

///|
// Validate and normalize a plugin's convert/open/finish result. The plugin
// cannot pick the wire format: a result claiming a format other than the
// registered name is rejected, never passed through.
function acceptResult(plugin, value, { kind }) {
  if (!isPlainObject(value)) {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: the ${kind} result must be a plain object, not ${value === null ? "null" : typeof value}`,
    );
  }
  if (value.format !== undefined && value.format !== plugin.name) {
    throw new PluginError(
      `plugin "${plugin.name}" returned malformed output: a result claiming format "${String(value.format)}" cannot leave a plugin registered as "${plugin.name}"`,
    );
  }
  return {
    bdf: outgoingBytes(plugin, value.bdf, "bdf"),
    summary: acceptSummary(plugin, value, kind),
    warnings: outgoingWarnings(plugin, value.warnings, "warnings"),
  };
}

function parseOptions(raw) {
  if (raw === undefined || raw === null) {
    raw = {};
  }
  if (!isPlainObject(raw)) {
    throw new ConvertError("options must be a plain object");
  }
  for (const key of Object.keys(raw)) {
    if (!KNOWN_OPTIONS.includes(key)) {
      throw new ConvertError(`options: unknown key "${key}"`, "invalid-options");
    }
  }
  const options = { format: "", name: "", password: "", pages: "", params: {} };
  for (const key of STRING_OPTIONS) {
    const value = raw[key];
    if (value === undefined) {
      continue;
    }
    if (typeof value !== "string") {
      throw new ConvertError(`options.${key} must be a string`, "invalid-options");
    }
    options[key] = value;
  }
  if (options.pages !== "") {
    throw new ConvertError("options.pages: page selection is not part of the plugin contract yet", "invalid-options");
  }
  if (raw.params !== undefined) {
    if (!isPlainObject(raw.params)) {
      throw new ConvertError("options.params must be a plain object", "invalid-options");
    }
    for (const [key, value] of Object.entries(raw.params)) {
      if (!["string", "number", "boolean"].includes(typeof value)) {
        throw new ConvertError(`options.params.${key} must be a string, number or boolean`, "invalid-options");
      }
      options.params[key] = String(value);
    }
  }
  return options;
}

export function createConverterHost({
  registry,
  postMessage,
  context = pluginContext(),
}) {
  requireTransport(postMessage);
  const streams = new Map();
  let nextStream = 1;
  let initialized = false;
  let disposed = false;
  let disposalPromise = null;

  function post(message, transfer = []) {
    postMessage(message, transfer);
  }

  ///|
  // A release that has started but not settled yet. Removal of a lease from
  // `streams` happens before the plugin's (possibly async) disposeStream is
  // awaited, so a racing host disposal must track these promises or it will
  // proceed to the plugin's dispose — and answer — while a stream's cleanup
  // is still running. Every tracked release also contributes its settlement
  // result to the disposal report: a close whose disposer fails while the
  // disposal races it has no reply anymore (the host is disposing), so the
  // report is the only place its failure may exist.
  // Outcome records of tracked releases: a release is removed from the
  // pending map the moment it settles, but while a disposal is in flight its
  // settled record is KEPT in settledForDisposal until the disposal collects
  // it. A release that settles while the disposal drains another lease still
  // belongs to the report, and dropping it there is how a cleanup failure
  // vanished: the report array is the only place a release with no reply of
  // its own can be visible.
  const pendingReleases = new Map(); // report promise -> {id, name, kind}
  const settledForDisposal = [];

  function trackRelease(release, description) {
    const report = Promise.resolve(release).then(
      () => ({ ok: true, error: null }),
      error => ({ ok: false, error: errorText(error) }),
    );
    pendingReleases.set(report, description);
    // the description is captured in the closure before the settle, so a
    // record cannot be lost after the map entry is removed
    report.then(outcome => {
      pendingReleases.delete(report);
      if (disposalPromise !== null) {
        settledForDisposal.push({
          id: description.id,
          name: description.name,
          ok: outcome.ok,
          error: outcome.error,
          how: description.kind,
        });
      }
    });
    return release;
  }

  async function awaitReleases() {
    // New releases can appear while we wait (a rejected open resolving after
    // dispose claims nothing but may still clean up); drain until quiescent.
    const outcomes = [];
    while (pendingReleases.size > 0 || settledForDisposal.length > 0) {
      const reports = [...pendingReleases.keys()];
      if (reports.length > 0) {
        // settle handlers move the batch's records into settledForDisposal
        await Promise.all(reports);
      }
      // collect everything settled so far, including releases that settled
      // while an earlier batch was awaited
      while (settledForDisposal.length > 0) {
        outcomes.push(settledForDisposal.shift());
      }
    }
    return outcomes;
  }

  function failure(request, error) {
    const id = isPlainObject(request) && request.type === "init" ? 0 : Number(request?.id);
    const reply = { id, ok: false, error: errorText(error) };
    const code = error?.code;
    if (code !== undefined && code !== null && code !== "") {
      reply.code = code;
    }
    return reply;
  }

  function resultBytes(result) {
    return [result.bdf.buffer];
  }

  ///|
  // Release a claimed handle exactly once on a path that never made a lease:
  // a rejected open result. The tracked release REJECTS when the disposer
  // fails — a failure must settle as a failure, never as a fulfilled error
  // value — and the callers that need its message read it through the catch
  // path, so the primary rejection is never hidden behind the cleanup
  // failure. The release is tracked so a racing host disposal waits for it
  // and reports its outcome (the rejected open itself never gets a lease id).
  function releaseClaimedHandle(plugin, handle, reason) {
    const disposer = plugin.disposeStream;
    if (typeof disposer !== "function") {
      return Promise.resolve(null);
    }
    return trackRelease(Promise.resolve()
      .then(() => disposer(handle, context, reason))
      .then(() => null), {
      id: 0,
      name: plugin.name,
      kind: reason === "disposed" ? "post-dispose" : "rejected-open",
    });
  }

  ///|
  // Remove a lease from the map before doing anything else, then call the
  // plugin's disposer exactly once for that handle. Awaited by its callers;
  // a failing disposal is the caller's failure to answer with. Tracked so a
  // racing host disposal waits for it and reports its outcome, with the
  // settled record kept until the disposal collects it.
  function releaseLease(id, kind = "wire-close") {
    const lease = streams.get(id);
    if (!lease) {
      return Promise.resolve(false);
    }
    streams.delete(id);
    const { plugin, stream } = lease;
    const disposer = plugin.disposeStream;
    // The lease's serialized calls may have failed while the disposal was
    // taking their replies: those failures are consumed here (exactly once —
    // whoever releases the lease first gets them) and folded into the
    // tracked release outcome for the report, but never into the caller's
    // answer: a normally answered failure was already posted to its caller.
    const dropped = lease.takeDroppedFailures();
    const droppedText = dropped
      .map(failure => `the drained in-flight call failed: ${errorText(failure)}`)
      .join("; ");
    const run = typeof disposer === "function"
      ? Promise.resolve().then(() => disposer(stream, context, kind === "wire-close" ? "close" : kind))
      : Promise.resolve();
    const folded = run.then(
      () => {
        if (droppedText !== "") {
          throw new Error(droppedText);
        }
        return true;
      },
      error => {
        if (droppedText === "") {
          throw error;
        }
        // a failing disposer AND drained-call failures: neither overwrites
        const base = error instanceof Error ? error : new Error(errorText(error));
        base.message += `; additionally, ${droppedText}`;
        throw base;
      },
    );
    return trackRelease(folded, {
      id,
      name: plugin.name,
      kind,
    });
  }

  const ready = () => initialized && !disposed;

  // convert/open calls accepted (registered in dispatch) before a disposal
  // and not settled yet: teardown waits for them (no cancellation — see
  // dispose), because their failures and claimed-handle cleanups belong to
  // the disposal report
  const activeCalls = new Set();
  // failures of calls whose reply the disposal took: the report is the only
  // reader they have left
  const droppedCalls = [];

  async function dispatch(request) {
    if (!isPlainObject(request) || typeof request.type !== "string") {
      post({ id: 0, ok: false, error: "invalid converter request" });
      return;
    }
    if (request.type === "init") {
      if (disposed) {
        throw new ConvertError("converter is disposed", "disposed");
      }
      initialized = true;
      post({ id: 0, ok: true, formats: registry.formats() });
      return;
    }
    if (request.type === "register") {
      // Registration is a code-time operation. The envelope has no message
      // that carries plugin code: not functions, and not URLs to import.
      throw new ConvertError("registration is only available at worker startup", "registration-at-startup");
    }
    if (!ready()) {
      throw new ConvertError("converter is not ready", "not-ready");
    }
    if (request.type === "convert" || request.type === "open") {
      // Register the accepted work BEFORE any plugin code can run. The
      // deferred continuation starts runConvertOrOpen one microtask later,
      // after this registration: a detector, converter or opener invoked by
      // that work always sees a host that has committed to awaiting its
      // completion. Invoking runConvertOrOpen inline here would run plugin
      // code first and leave the tracking below a beat behind. Disposal
      // snapshots activeCalls when it starts, so an accepted call is never
      // absent from a disposal that shares this synchronous stretch.
      const completion = Promise.resolve()
        .then(() => runConvertOrOpen(request))
        .finally(() => {
          activeCalls.delete(completion);
        });
      activeCalls.add(completion);
      return await completion;
    }
    if (request.type === "page" || request.type === "finish" || request.type === "close") {
      return await runStream(request);
    }
    throw new ConvertError("unknown request " + request.type, "unknown-request");
  }

  async function runConvertOrOpen(request) {
    const bytes = toBytes(request.data);
    const options = parseOptions(request.options);
    const { plugin, via } = registry.detect(bytes, options.name, options.format);
    try {
      await convertOrOpen(request, { bytes, options, plugin, via });
    } catch (error) {
      if (disposed) {
        // the disposal has taken the reply channel: the report keeps the
        // call's failure, which would otherwise vanish with the dropped
        // reply — named, typed and numbered so two racing calls that both
        // fail stay distinguishable
        droppedCalls.push({
          name: plugin.name,
          type: request.type,
          id: Number(request.id),
          error: errorText(error),
        });
      }
      throw error;
    }
  }

  async function convertOrOpen(request, { bytes, options, plugin, via }) {
    const wireOptions = { ...options, format: plugin.name, detectedVia: via };
    let result;
    let pages = 0;
    let handle = null;
    let leasedHandle = false;
    if (request.type === "convert" || typeof plugin.open !== "function") {
      result = acceptResult(plugin, await plugin.convert(bytes, wireOptions, context), { kind: "convert" });
      pages = 0;
    } else {
      const opened = await plugin.open(bytes, wireOptions, context);
      // The plugin may already have made the stream resource behind this
      // result; claim it before judging the result itself, so a rejection
      // can still release it.
      handle = claimedHandle(opened);
      try {
        if (!isPlainObject(opened)) {
          throw new PluginError(
            `plugin "${plugin.name}" returned malformed output: the open result must be a plain object, not ${opened === null ? "null" : typeof opened}`,
          );
        }
        result = acceptResult(plugin, opened, { kind: "open" });
        pages = outgoingPages(plugin, opened.pages);
        if (pages > 0) {
          if (handle === null) {
            throw new PluginError(
              `plugin "${plugin.name}" returned malformed output: an open result with pages must carry a stream handle object`,
            );
          }
        } else if (handle !== null) {
          // Zero complete-document opens carry no handle; a handle without
          // pages would leak it, so it is a malformed result — and the
          // claimed handle is released below, not left to the plugin.
          throw new PluginError(
            `plugin "${plugin.name}" returned malformed output: an open result with a stream handle must report pages`,
          );
        }
      } catch (error) {
        if (handle !== null) {
          // the release settles as a failure now, so the cleanup message is
          // read through the catch path; the primary error still answers
          const cleanupError = await releaseClaimedHandle(plugin, handle, "rejected-open").catch(caught => caught);
          if (cleanupError !== null) {
            const wrapped = error instanceof Error ? error : new Error(errorText(error));
            wrapped.message += `; additionally, releasing the rejected open's stream handle failed: ${errorText(cleanupError)}`;
            throw wrapped;
          }
        }
        throw error;
      }
    }
    if (disposed) {
      // The host went away while the plugin was working: no reply, no lease,
      // and the late handle is released exactly once. The release failure,
      // if any, is a settled release record: a still-collecting disposal
      // report carries it, and a finished one no longer has a reader (the
      // host itself is gone), so it is caught, not left unhandled.
      if (handle !== null) {
        await releaseClaimedHandle(plugin, handle, "disposed").catch(() => undefined);
      }
      return;
    }
    const wire = {
      bdf: result.bdf,
      format: plugin.name,
      summary: result.summary,
      warnings: result.warnings,
      protected: false,
    };
    let leaseId = 0;
    if (request.type === "open") {
      wire.pages = pages;
      if (handle !== null) {
        leaseId = nextStream;
        nextStream += 1;
        wire.stream = leaseId;
        // The lease is only visible from this point; if posting it fails, it
        // is released again below.
        leasedHandle = true;
        streams.set(leaseId, newLease(plugin, handle));
      }
    }
    try {
      post({ id: Number(request.id), ok: true, result: wire }, resultBytes(wire));
    } catch (error) {
      if (leasedHandle) {
        await releaseLease(leaseId, "post-failure");
      }
      throw error;
    }
  }

  ///|
  // A lease: the plugin's stream handle plus the serialization state of the
  // calls that use it. `closed` flips when a close or the host disposal
  // begins: in-flight calls finish first, later calls are stale. The chain
  // swallows settled operation failures so the queue keeps running, but a
  // failure whose reply the disposal took (it has no reader left) is kept
  // on the lease for the disposal report — exactly once, because whoever
  // releases or disposes the lease first consumes the kept failures.
  function newLease(plugin, handle) {
    let chain = Promise.resolve();
    const dropped = [];
    return {
      plugin,
      stream: handle,
      closed: false,
      enqueue(operation) {
        const run = chain.then(operation, operation);
        chain = run.then(() => undefined, () => undefined);
        return run;
      },
      drain() {
        return chain;
      },
      recordDropped(error) {
        dropped.push(error);
      },
      takeDroppedFailures() {
        return dropped.splice(0);
      },
    };
  }

  async function runStream(request) {
    const id = Number(request.stream);
    const lease = streams.get(id);
    if (request.type === "close") {
      return await closeLease(request, id, lease);
    }
    if (lease === undefined) {
      throw new ConvertError("no conversion " + String(request.stream), "no-conversion");
    }
    if (lease.closed) {
      // the close (or the disposal) has already started on this stream:
      // the handle is on its way out, so this call is stale
      throw new ConvertError("no conversion " + String(request.stream), "no-conversion");
    }
    const { plugin, stream } = lease;
    // Acceptance is decided here, synchronously: no await can slip a close
    // between the check and the enqueue. An accepted call runs to completion
    // even if its close arrives right after; the close drains the chain.
    // A failure that settles under disposal is kept on the lease — its
    // reply has no reader left, so the disposal report is its only sink,
    // exactly once (guarding against the double report a normally answered
    // failure would otherwise produce).
    return lease.enqueue(() => runStreamOp(request, { plugin, stream }))
      .then(value => value, error => {
        if (disposed) {
          lease.recordDropped(error);
        }
        throw error;
      });
  }

  async function runStreamOp(request, { plugin, stream }) {
    if (request.type === "page") {
      const index = request.index === undefined ? 0 : Number(request.index);
      if (!Number.isInteger(index) || index < 0) {
        throw new ConvertError(`page: invalid index ${String(request.index)}`, "invalid-options");
      }
      const value = await Promise.resolve().then(() => plugin.page(stream, index, context));
      if (disposed) {
        return;
      }
      if (!isPlainObject(value)) {
        throw new PluginError(
          `plugin "${plugin.name}" returned malformed output: the page result must be a plain object, not ${value === null ? "null" : typeof value}`,
        );
      }
      const wire = {
        bdf: outgoingBytes(plugin, value.bdf, "bdf"),
        warnings: outgoingWarnings(plugin, value.warnings, "warnings"),
      };
      post({ id: Number(request.id), ok: true, result: wire }, resultBytes(wire));
      return;
    }
    // finish: the lease stays, like the existing converter workers.
    const value = await Promise.resolve().then(() => plugin.finish(stream, context));
    if (disposed) {
      return;
    }
    const result = acceptResult(plugin, value, { kind: "finish" });
    const wire = {
      bdf: result.bdf,
      format: plugin.name,
      summary: result.summary,
      warnings: result.warnings,
      protected: false,
    };
    post({ id: Number(request.id), ok: true, result: wire }, resultBytes(wire));
  }

  ///|
  // Wire close: the lease stops accepting calls immediately, the in-flight
  // call answers first, and only then is the handle released and the close
  // answered. Closing an unknown id stays a successful no-op.
  async function closeLease(request, id, lease) {
    if (lease === undefined) {
      if (!disposed) {
        post({ id: Number(request.id), ok: true, result: null });
      }
      return;
    }
    lease.closed = true;
    await lease.drain();
    await releaseLease(id);
    if (!disposed) {
      post({ id: Number(request.id), ok: true, result: null });
    }
  }

  async function handle(request) {
    return dispatch(request).catch(error => {
      if (disposed) {
        // A disposed host has nowhere to answer to and keeps its failures.
        return;
      }
      post(failure(request, error));
    });
  }

  ///|
  // Releasing every lease and calling every plugin's disposer exactly once,
  // across races and repeated calls. Convert/open calls accepted before
  // the disposal are awaited BEFORE any teardown — with no cancellation and
  // no timeout: an unresolved plugin promise delays the graceful dispose,
  // and a consumer that cannot wait terminates the worker abruptly. Their
  // failures (replies the disposal took) and their claimed-handle cleanups
  // land in this report, which is the only reader they have left. In-flight
  // stream calls finish before their lease is released. Releases that a wire
  // close (or a rejected open) started and are still running are awaited
  // before any plugin dispose runs, so the plugin's own teardown never
  // overlaps a stream cleanup it assumes to be finished. Concurrent or
  // repeated calls all get the same settled report.
  function dispose(reason = "host dispose") {
    if (disposalPromise === null) {
      disposalPromise = (async () => {
        disposed = true;
        // wait until every convert/open call accepted before the disposal
        // has fully settled (result posted or dropped, claimed handles
        // released), so the report is complete when it is assembled
        while (activeCalls.size > 0) {
          await Promise.allSettled([...activeCalls]);
        }
        const released = [];
        for (const [id, lease] of [...streams]) {
          lease.closed = true;
          // wait for the in-flight call on this handle before releasing; the
          // chain swallows its failure by design (the queue must keep
          // running), so a failure whose reply the disposal took is read
          // from the lease instead, consumed here exactly once
          await lease.drain();
          // a wire close may have released this lease while disposal waited:
          // its own release outcome carries the kept failures instead
          if (streams.get(id) !== lease) {
            continue;
          }
          streams.delete(id);
          const dropped = lease.takeDroppedFailures();
          let ok = true;
          let message = null;
          const disposer = lease.plugin.disposeStream;
          if (typeof disposer === "function") {
            try {
              await disposer(lease.stream, context, reason);
            } catch (caught) {
              ok = false;
              message = errorText(caught);
            }
          }
          if (dropped.length > 0) {
            const droppedText = dropped
              .map(failure => `the drained in-flight call failed: ${errorText(failure)}`)
              .join("; ");
            if (message === null) {
              ok = false;
              message = droppedText;
            } else {
              // the disposer failed AND a drained call failed: neither
              // failure overwrites the other
              message += `; additionally, ${droppedText}`;
            }
          }
          released.push({ id, name: lease.plugin.name, ok, error: message, how: "host-dispose" });
        }
        released.sort((a, b) => a.id - b.id);
        // a release a wire close (or a rejected open) started before disposal
        // begins — or while the loop drains another lease — settles before
        // any plugin dispose is called, and its outcome is part of the
        // report: a failing disposer racing the disposal has no reply of its
        // own anymore, and the settle handlers keep its record until this
        // collection, whenever it settled
        await awaitReleases().then(outcomes => {
          for (const outcome of outcomes) {
            released.push(outcome);
          }
        });
        released.sort((a, b) => a.id - b.id);
        const { outcomes: plugins } = await registry.dispose(reason);
        // failures of calls whose replies the disposal took, recorded while
        // the active calls above settled
        const dropped = droppedCalls.splice(0);
        return { reason, released, dropped, plugins };
      })();
    }
    return disposalPromise;
  }

  return {
    handle,
    dispose,
    formats: () => registry.formats(),
    get streamCount() {
      return streams.size;
    },
  };
}
