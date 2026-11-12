// Shared test helpers: a deterministic PRNG, a transport that records posted
// replies, plugin/delegate factories, and a small synthetic DocuWorks file
// built the way `convert/xdw/kind7_browser_test.mjs` builds its fixture (same
// project, same license).

import assert from "node:assert/strict";

///|
// A tiny deterministic PRNG (mulberry32). Property tests must not depend on
// platform entropy.
export function mulberry32(seed) {
  let state = seed >>> 0;
  const next = () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  const integer = (bound) => Math.floor(next() * bound);
  const pick = (list) => list[integer(list.length)];
  const shuffle = (list) => {
    const out = [...list];
    for (let i = out.length - 1; i > 0; i -= 1) {
      const j = integer(i + 1);
      [out[i], out[j]] = [out[j], out[i]];
    }
    return out;
  };
  return { next, integer, pick, shuffle };
}

///|
// A in-process postMessage transport: every reply lands in `replies`, and a
// reply wait can be awaited by request id.
export class Transport {
  constructor() {
    this.replies = [];
    this.transfers = [];
    this.postMessage = (message, transfer = []) => {
      this.replies.push(message);
      this.transfers.push(transfer);
    };
  }

  async wait(predicate, what = "reply") {
    const deadline = Date.now() + 5000;
    while (Date.now() < deadline) {
      const found = this.replies.find(predicate);
      if (found) {
        return found;
      }
      await new Promise(resolve => setTimeout(resolve, 10));
    }
    throw new Error(`timed out waiting for ${what} in ${JSON.stringify(this.replies.map(reply => reply.id))}`);
  }

  reply(id) {
    const found = this.replies.find(reply => reply.id === id);
    assert.ok(found, `no reply with id ${id}`);
    return found;
  }
}

///|
// The reporting envelope a plugin's result answers with, the way the native
// converter worker answers.
export function wire(result) {
  return { bdf: result.bdf, format: result.format, summary: result.summary, warnings: result.warnings };
}

///|
// A minimal plugin factory for tests. `detectAccepts` is a set of byte-string
// keys the detector accepts; `null` makes the detector claim everything.
export function makePlugin({
  name,
  description = `${name} test format`,
  extensions = [],
  detectAccepts = new Set(),
  convertDelay = 0,
  convertImpl,
  open = false,
  cleaned = { streams: 0, disposed: 0, badResults: [] },
  version = "",
  vendor = "",
}) {
  const convert = convertImpl ?? (async (bytes) => {
    if (convertDelay > 0) {
      await new Promise(resolve => setTimeout(resolve, convertDelay));
    }
    return { bdf: bytes.slice(), summary: `${name} summary`, warnings: [] };
  });
  const plugin = {
    apiVersion: 1,
    name,
    description,
    extensions: [...extensions],
    ...(version === "" ? {} : { version }),
    ...(vendor === "" ? {} : { vendor }),
    detect: bytes =>
      detectAccepts === null || detectAccepts.has(new TextDecoder().decode(bytes.slice(0, 8))),
    convert,
  };
  if (open) {
    plugin.open = async bytes => ({
      bdf: bytes.slice(0, bytes.length),
      summary: `${name} opened`,
      warnings: [],
      pages: 2,
      stream: {
        closed: false,
        pages: [bytes.slice(0, 4), bytes.slice(0, 6)],
      },
    });
    plugin.page = async (stream, index) => {
      if (index >= stream.pages.length) {
        throw new Error(`${name}: page ${index} is out of range`);
      }
      return { bdf: stream.pages[index], warnings: [] };
    };
    plugin.finish = async stream => ({
      bdf: stream.pages[0],
      summary: `${name} finished`,
      warnings: [],
    });
    plugin.disposeStream = stream => {
      stream.closed = true;
      cleaned.streams += 1;
    };
  }
  plugin.dispose = () => {
    cleaned.disposed += 1;
  };
  return { plugin, cleaned };
}

export const XDW_SIGNATURE_BYTES = 24;

///|
// A byte string long enough to be a detectable DocuWorks header, without
// being a convertible document: detection only reads the first header tags.
export function docuworksLikeHeader() {
  const bytes = new Uint8Array(XDW_SIGNATURE_BYTES);
  bytes[0] = 0x60;
  bytes[1] = 0x03;
  bytes[2] = 0x80;
  return bytes;
}

export function text(value) {
  return new TextEncoder().encode(value);
}
