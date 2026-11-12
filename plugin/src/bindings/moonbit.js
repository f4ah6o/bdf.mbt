// The binding between the DocuWorks adapter and this repository's MoonBit
// `convert/xdw` JavaScript export (`plugin/moonbit/docuworks_js`).
//
// The exported MoonBit functions never raise across the FFI; conversion
// returns a JSON envelope, following the `form_page` export convention:
//   bdf_xdw_detect(data) -> boolean
//   bdf_xdw_convert(data, includeHidden) ->
//     {"ok":true,"bdf":"<base64>","pages":n,"summary":"...","warnings":[...]}
//     {"ok":false,"error":"..."}

export class BindingError extends Error {
  constructor(message, code = "binding-error") {
    super(message);
    this.name = "ConvertError";
    this.code = code;
  }
}

///|
// A strict standard-encoder decoder: canonical padding only. It rejects
// input whose length is not a multiple of four, characters outside the
// alphabet, misplaced `=` anywhere but the final quad, and padding that
// carries non-zero bits — the encodings a lenient consumer would silently
// re-serialize differently.
const BASE64_ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

const BASE64_INDEX = new Map(
  [...BASE64_ALPHABET].map((character, position) => [character, position]),
);

///|
export function base64Decode(text, what = "base64") {
  if (typeof text !== "string" || text.length % 4 !== 0) {
    throw new BindingError(`${what} payload is not well-formed base64`);
  }
  const quads = text.length / 4;
  const lastQuadPadding = text.endsWith("==") ? 2 : text.endsWith("=") ? 1 : 0;
  const size = quads * 3 - lastQuadPadding;
  const out = new Uint8Array(size);
  let at = 0;
  for (let quad = 0; quad < quads; quad += 1) {
    const offset = quad * 4;
    // Only the final quad may carry padding, and only as its trailing characters.
    const padding = quad === quads - 1 ? lastQuadPadding : 0;
    let group = 0;
    for (let position = 0; position < 4; position += 1) {
      const character = text[offset + position];
      if (character === "=") {
        if (padding === 0 || position < 4 - padding) {
          throw new BindingError(`${what} payload is not well-formed base64: misplaced "="`);
        }
        group <<= 6;
        continue;
      }
      const value = BASE64_INDEX.get(character);
      if (value === undefined) {
        throw new BindingError(`${what} payload is not well-formed base64`);
      }
      group = (group << 6) | value;
    }
    if (padding > 0) {
      // Padding replaces 6*padding character bits with 8*padding payload
      // bits; the low bits of the group beyond the payload must be zero in
      // a canonical encoding.
      const discarded = (1 << (8 * padding)) - 1;
      if ((group & discarded) !== 0) {
        throw new BindingError(`${what} payload is not canonical base64: padding carries data bits`);
      }
    }
    out[at] = (group >> 16) & 0xff;
    at += 1;
    if (padding < 2 && at < size) {
      out[at] = (group >> 8) & 0xff;
      at += 1;
    }
    if (padding < 1 && at < size) {
      out[at] = group & 0xff;
      at += 1;
    }
  }
  return out;
}

///|
// Adapt a MoonBit DocuWorks JS export module into the delegate the DocuWorks
// adapter takes: `{detect, convert}`. The module is imported (never fetched
// or evaluated from a string) by the worker script.
export function moonbitDocuWorks(module) {
  if (typeof module?.bdf_xdw_detect !== "function" || typeof module?.bdf_xdw_convert !== "function") {
    throw new BindingError(
      "the module is not the DocuWorks MoonBit export: bdf_xdw_detect/bdf_xdw_convert are missing",
    );
  }
  return {
    detect(bytes) {
      return module.bdf_xdw_detect(bytes) === true;
    },
    async convert(bytes, { includeHidden = false, name = "" } = {}) {
      const parsed = readEnvelope(module.bdf_xdw_convert(bytes, includeHidden === true));
      return {
        bdf: base64Decode(parsed.bdf, "bdf"),
        summary: parsed.summary,
        warnings: parseWarnings(parsed.warnings),
        ...(name === "" ? {} : { name }),
      };
    },
  };
}

function readEnvelope(text) {
  let envelope;
  try {
    envelope = JSON.parse(text);
  } catch {
    throw new BindingError("the DocuWorks MoonBit convert export did not return JSON");
  }
  if (envelope?.ok !== true) {
    const error = new BindingError(
      typeof envelope?.error === "string" ? envelope.error : "the DocuWorks conversion failed",
    );
    throw error;
  }
  if (typeof envelope.bdf !== "string" || typeof envelope.summary !== "string") {
    throw new BindingError("the DocuWorks MoonBit convert envelope is missing bdf or summary");
  }
  return envelope;
}

function parseWarnings(warnings) {
  if (warnings === undefined) {
    return [];
  }
  if (!Array.isArray(warnings)) {
    throw new BindingError("the DocuWorks MoonBit convert envelope warnings must be an array");
  }
  return warnings.map(String);
}
