// Mermaid flowchart adapter (bounded static subset).
//
// This adapter converts plain-text Mermaid flowcharts into BDF pages. It is a
// hand-written bounded line scanner: NO Mermaid engine, NO regex
// backtracking hazards (the two expressions used are linear character-class
// scans), NO recursion, NO eval/new Function, NO DOM, NO network. It is safe
// to load in a worker.
//
// SUPPORTED SUBSET (nothing more is claimed; everything else is rejected with
// an error that names WHAT was rejected and WHY — this adapter never
// partially parses and then guesses):
//   * Strict UTF-8 text, at most 1 MiB (Error with .code "too-large" beyond).
//     An optional fence of exactly two lines — a ```mermaid first line and a
//     ``` last line wrapping the whole content — is stripped; any other fence
//     or HTML is rejected.
//   * First meaningful line: "flowchart" or "graph" — the keywords are
//     lowercase-only, exactly like Mermaid ("Flowchart"/"GRAPH" reject; also
//     detect() only claims lowercase headers) — optionally followed by a
//     direction td|tb|lr|rl (case-insensitive, default td). "flowchart"
//     without a direction is fine.
//   * Nodes: id; id[label]; id(label); id([label]); id{label}; id{{label}}
//     (rect, rounded, stadium, rhombus, hexagon). Ids are built from letters
//     (any script), digits (any script), "_" and "-"; the first codepoint is
//     a letter or "_", at most 64 codepoints; ids are scanned, validated and
//     counted per Unicode CODE POINT, so supplementary-plane ids (e.g. the
//     bare id 𠮷) work while lone unpaired surrogates still reject. A bare id
//     (ASCII, Japanese, any script) doubles as the node label, exactly like
//     Mermaid. Labels may be quoted (id["plain text"]); among other plain
//     text, a quoted label may contain the shape's own delimiter characters
//     (id["items[index]"] works, because the label runs to ITS closing
//     quote and the shape closer must immediately follow it). Unquoted
//     labels may not contain quotes; both are plain Unicode text of at most 256 UTF-8
//     BYTES (byte caps are measured on UTF-8, never on UTF-16 units), with
//     control characters (C0/C1), lone surrogates, bidi overrides, "<", ">",
//     "&" and "`" (HTML of any kind, including <br/> and entities) and
//     javascript:/data: URLs rejected. The last declaration carrying a shape
//     sets shape and label; a bare id reference changes nothing.
//   * Edges and chains A --> B --> C. Arrows: -->, ---, -.->, ==> and the
//     labeled forms "A -- text --> B", "A -. text .-> B", "A == text ==> B"
//     and the pipe form "A -->|text| B" (labels: the same Unicode rules as
//     node labels). "--" runs inside labels are rejected, and --- carries no
//     label (---|...| is rejected).
//   * Full-line comments ("%% ...") are skipped; CR, CRLF and blank lines are
//     accepted.
//
// REJECTED (invalid-input): other diagram kinds (sequenceDiagram,
//   classDiagram, stateDiagram/stateDiagram-v2, erDiagram, gantt, pie,
//   journey, gitGraph, mindmap, timeline, quadrantChart, requirementDiagram,
//   sankey..., block..., C4...), "subgraph", "end", "classDef", "class ",
//   "click", callbacks, "call ", "init", "require", "linkStyle", "style ",
//   inline "direction", any %%{...}%% directive, unsupported node shapes
//   (cylinder id[(...)], subroutine id[[...]], circles id((...)), asymmetric
//   id>...], anything not in the supported list), HTML labels and entities,
//   javascript:/data: URLs, unusual arrows (at least --o, --x, o--, x--,
//   ---|...|), mid-line comments, empty "./-run" ids, ids violating the id
//   rule or longer than 64 codepoints, labels longer than 256 UTF-8 bytes,
//   empty labels in the "-- text -->" form, unterminated shapes, quotes,
//   pipes and labeled edges, invalid UTF-8.
//
// BOUNDS (Error with .code "too-large" beyond): input 1 MiB, 4096 lines
//   (a trailing newline counts one trailing empty line), 512 nodes, 2048
//   edges (chain arrows count per segment), 8 tokens per line, 100000 total
//   label characters (the shared encoder caps totals as well). All limits
//   are numbered BEFORE any array is allocated from input data. Coordinates
//   are pre-bounded to |v| <= 1e6 and every emitted stroke is 2 or 3 pt, so
//   no emitted value can overflow its float32 conversion.
//
// DETERMINISTIC LAYOUT (documented exactly): layered layout. depth(node) is
//   1 + max(depth(parents)), roots at depth 0, computed by iterative
//   relaxation capped at node-count iterations. Cycles never crash the
//   relaxation: cycle members grow one layer per iteration and, when the cap
//   hits, keep their deepest settled depth — the layout simply freezes at
//   the cap, and convert() returns a warning saying so. Within a layer,
//   nodes keep first-appearance order. The layout box is 160x48 pt:
//     td/tb:  x = 40 + layerIndex*(160+40), y = 40 + depth*120
//     lr:     x = 40 + depth*(160+40),      y = 40 + layerIndex*(48+40)
//     rl:     mirrored lr: x = 40 + (maxDepth-depth)*(160+40)
//   A rhombus draws as a 192x96 diamond on the same 160x48 layout box; a
//   hexagon uses a 192x96 outline too.
//
// RENDER (fixed palette, documented): edges draw FIRST, nodes after them, so
//   edge lines and arrowheads are never hidden beneath node shapes; edge
//   labels draw last, on top. Edge segments clip at the target/source
//   boundary: rhombus and hexagon nodes clip against their drawn convex
//   polygon outline, every other shape against its 160x48 box (plain slab
//   math). Edges are straight polylines, stroke #4b5563, width 2 (3 for
//   ==>), dash [4,4] for -.->, with a filled arrowhead triangle at the
//   target end for -->, -.-> and ==> (none for ---). Nodes: rect and
//   rounded/stadium shapes fill #f9fafb stroke #1f2937 width 2; a rhombus
//   polygon fills #fef9c3; a hexagon polygon fills #e0f2fe; each node then
//   draws 16 pt Helvetica #111827 text, align center, baseline middle, at
//   the shape center. An edge label draws a small white rect behind a 12 pt
//   #374151 text (center/middle) at the segment midpoint, above the line.
//   Self-edges draw a fixed loop anchored ON the node's ACTUAL drawn
//   outline (top edge for rect/rounded/stadium, upper edges at dx = +/-24
//   for a rhombus, flat top edge for a hexagon): both loop endpoints sit on
//   the outline, the route stays strictly outside it and the arrowhead tip
//   sits on the outline with its body outside, so node fills drawn afterward
//   can never hide the head. Warned about.
//   Text advance uses a CJK-aware estimate (estimate is documented below);
//   it is passed to the encoder as an `advance` override so text bounds are
//   real: wide East Asian codepoints count 1.0 em, everything else 0.6 em.
//   Page fitting uses TRUE extents: everything emitted (shapes, text bands
//   from the advance estimate, edge labels and their
//   white backings, self-loops) is measured, with the stroke side of every
//   stroked chain or ring computed by the shared miter-aware helper
//   (strokedPolylineExtent: pads + miter protrusions, exactly matching the
//   encoder's bbox math); when the minimum coordinate
//   falls below the 40 pt margin (a wide label, a rhombus tip, a loop), ALL
//   primitives are translated so the minimum is exactly the margin, and the
//   page covers the extents plus the margins on the right and bottom
//   (integer size). No primitive is ever rotated, so no transform ops occur.
//
// convert() returns { bdf, format: "mermaid",
//   summary: "1 page, N node(s), M edge(s)", warnings: [...] } (warnings
//   only for the documented approximations above). All rejects are thrown
//   ConvertErrors with .code "invalid-input" or "too-large". The BDF source
//   identifier is "mermaid" (the format id), and detect() is synchronous,
//   checks the byte cap BEFORE decoding and never throws.

import { ConvertError, defineFormatPlugin } from "../contract.js";
import { acceptedParams, noPassword } from "../adapter-options.js";
import { encodeDiagram, strokedPolylineExtent } from "../diagram-bdf.js";

export const MERMAID_FORMAT_NAME = "mermaid";
export const MERMAID_EXTENSIONS = [".mmd", ".mermaid"];
export const MERMAID_DESCRIPTION =
  "Mermaid flowchart (bounded static flowchart subset: nodes, edges and labels with a fixed deterministic layered layout; no scripting, no HTML, no other diagram kinds)";

const MAX_INPUT_BYTES = 1024 * 1024;
const MAX_LINES = 4096;
const MAX_NODES = 512;
const MAX_EDGES = 2048;
const MAX_TOKENS_PER_LINE = 8;
const MAX_ID_CODEPOINTS = 64;
const MAX_LABEL_BYTES = 256;
const MAX_TOTAL_LABEL_CHARS = 100000;
const MAX_PRIMITIVES = 20000;
const MAX_COORD = 1_000_000;

const BOX_W = 160;
const BOX_H = 48;
const PITCH_X = BOX_W + 40; // 200
const PITCH_Y = 120;
const PITCH_Y_LR = BOX_H + 40; // 88
const MARGIN = 40;
const NODE_STROKE_WIDTH = 2;

// Linear scans only: every unit is a character class, so there is no
// unbounded backtracking in either expression.
const ID_RE = /^[\p{L}_][\p{L}\p{Nd}_-]*$/u;
const DIRECTIONS = new Set(["td", "tb", "lr", "rl"]);
const RESERVED_KINDS = new Set([
  "sequencediagram", "classdiagram", "statediagram", "statediagram-v2",
  "erdiagram", "gantt", "pie", "journey", "gitgraph", "mindmap", "timeline",
  "quadrantchart", "requirementdiagram", "sankey", "block", "c4context",
  "c4container", "c4dynamic", "c4deployment", "c4",
]);
// Reserved as node ids or statement starters anywhere in the body.
const RESERVED_IDS = new Set([
  "subgraph", "end", "classdef", "class", "click", "call", "init", "require",
  "linkstyle", "style", "direction", "flowchart", "graph",
]);

const COLOR = {
  nodeFill: { r: 249, g: 250, b: 251, a: 255 }, // #f9fafb
  nodeStroke: { r: 31, g: 41, b: 55, a: 255 }, // #1f2937
  rhombusFill: { r: 254, g: 249, b: 195, a: 255 }, // #fef9c3
  hexagonFill: { r: 224, g: 242, b: 254, a: 255 }, // #e0f2fe
  nodeText: { r: 17, g: 24, b: 39, a: 255 }, // #111827
  edge: { r: 75, g: 85, b: 99, a: 255 }, // #4b5563
  labelBg: { r: 255, g: 255, b: 255, a: 255 }, // #ffffff
  labelText: { r: 55, g: 65, b: 81, a: 255 }, // #374151
};

const DECODER = new TextDecoder("utf-8", { fatal: true });
const UTF8 = new TextEncoder();

function reject(code, message) {
  return new ConvertError(`mermaid: ${message}`, code);
}

///|
// Error messages quote a short excerpt of the offending text so a rejection
// names WHAT it rejected without echoing control characters.
function excerpt(value, limit = 40) {
  let out = "";
  for (const ch of String(value ?? "")) {
    const code = ch.codePointAt(0);
    out += code < 0x20 || code > 0x7e ? "?" : ch;
    if (out.length >= limit) {
      return `${out}...`;
    }
  }
  return out;
}

function decodeUtf8Strict(bytes) {
  try {
    return DECODER.decode(bytes);
  } catch (error) {
    throw reject(
      "invalid-input",
      "input is not valid UTF-8: no other encoding is accepted",
    );
  }
}

///|
// Plain Unicode label text: printable, no markup, no control characters.
function isControlOrBanned(code) {
  return code < 0x20 // C0
    || (code >= 0x7f && code <= 0x9f) // DEL and C1
    || (code >= 0xd800 && code <= 0xdfff) // (lone) surrogates
    || code === 0x200e || code === 0x200f // LRM / RLM
    || (code >= 0x202a && code <= 0x202e) // bidi embedding / overrides
    || (code >= 0x2066 && code <= 0x2069); // isolated bidi
}

function validateLabel(raw, lineNo, what) {
  let text = raw;
  if (text.length >= 2 && text.startsWith('"') && text.endsWith('"')) {
    const inner = text.slice(1, -1);
    if (inner.includes('"')) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: a quoted ${what} may not contain another quote character`,
      );
    }
    text = inner;
  } else if (text.startsWith('"') || text.endsWith('"')) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: unterminated quote in ${what}: quotes must wrap the whole label`,
    );
  }
  for (const ch of text) {
    const code = ch.codePointAt(0);
    if (isControlOrBanned(code)) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: control, surrogate or bidi-override character in ${what}: labels are plain Unicode text`,
      );
    }
    if (ch === '"' || ch === "`") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: quotes and backticks are not allowed inside ${what}`,
      );
    }
    if (ch === "<" || ch === ">" || ch === "&") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: HTML markup (${JSON.stringify(ch)}) in ${what} is rejected: labels are plain text`,
      );
    }
  }
  const byteLength = UTF8.encode(text).length;
  if (byteLength > MAX_LABEL_BYTES) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: ${what} longer than ${MAX_LABEL_BYTES} UTF-8 bytes (${byteLength})`,
    );
  }
  const lower = text.toLowerCase();
  if (lower.includes("javascript:") || lower.includes("data:")) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: javascript:/data: URLs are rejected`,
    );
  }
  return text;
}

///|
// CJK-aware advance estimate (documented in the module header): wide East
// Asian codepoints render about 1.0 em wide, everything else about 0.6 em.
function isWide(code) {
  return (code >= 0x1100 && code <= 0x115f) // Hangul Jamo
    || (code >= 0x2e80 && code <= 0x303e) // CJK radicals and kana
    || (code >= 0x3041 && code <= 0x33ff)
    || (code >= 0x3400 && code <= 0x4dbf) // CJK extension A
    || (code >= 0x4e00 && code <= 0x9fff) // CJK unified ideographs
    || (code >= 0x20000 && code <= 0x3fffd) // CJK extensions B+ (supplementary plane)
    || (code >= 0xa000 && code <= 0xa4cf)
    || (code >= 0xac00 && code <= 0xd7a3) // Hangul syllables
    || (code >= 0xf900 && code <= 0xfaff) // CJK compatibility ideographs
    || (code >= 0xfe30 && code <= 0xfe4f)
    || (code >= 0xff00 && code <= 0xff60) // fullwidth forms
    || (code >= 0xffe0 && code <= 0xffe6);
}

function textAdvance(text, fontSize) {
  let units = 0;
  for (const ch of text) {
    units += isWide(ch.codePointAt(0)) ? 1.0 : 0.6;
  }
  return units * fontSize;
}

///|
// Bounded line tokenizer. Emits node tokens (id + shape + validated label),
// arrow tokens (-->, ---, -.->, ==>), arrow opener fragments (--, -., ==),
// the dotted closer (.->), pipe labels and plain words (Unicode text runs).
// Rejects every character or construct outside the supported subset.
// Tokens per line are capped before anything downstream may look at them.
function tokenizeLine(line, lineNo) {
  const tokens = [];
  const len = line.length;
  let i = 0;
  const at = (s) => line.startsWith(s, i);
  const push = (token) => {
    tokens.push(token);
    if (tokens.length > MAX_TOKENS_PER_LINE) {
      throw reject(
        "too-large",
        `line ${lineNo}: ${tokens.length} tokens on one line (max ${MAX_TOKENS_PER_LINE})`,
      );
    }
  };
  while (i < len) {
    const c = line[i];
    if (c === " " || c === "\t") {
      i += 1;
      continue;
    }
    const code = line.codePointAt(i);
    if (isControlOrBanned(code)) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: control, unpaired surrogate or bidi-override character (U+${code.toString(16)}): text must be plain, no markup and no overrides`,
      );
    }
    if (c === "|") {
      const close = line.indexOf("|", i + 1);
      if (close === -1) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: "|" with no closing "|"`,
        );
      }
      push({
        type: "pipe",
        value: validateLabel(line.slice(i + 1, close), lineNo, "pipe label"),
      });
      i = close + 1;
      continue;
    }
    // Arrows and arrow fragments, longest first.
    if (at("-.->")) {
      push({ type: "arrow", value: "-.->" });
      i += 4;
      continue;
    }
    if (at("-->")) {
      push({ type: "arrow", value: "-->" });
      i += 3;
      continue;
    }
    if (at("---")) {
      push({ type: "arrow", value: "---" });
      i += 3;
      continue;
    }
    if (at("==>")) {
      push({ type: "arrow", value: "==>" });
      i += 3;
      continue;
    }
    if (at("--o")) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported arrow "--o": this subset only supports -->, ---, -.-> and ==>`,
      );
    }
    if (at("--x")) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported arrow "--x": this subset only supports -->, ---, -.-> and ==>`,
      );
    }
    if (at("-.")) {
      push({ type: "arrowOpen", value: "-." });
      i += 2;
      continue;
    }
    if (at("--")) {
      push({ type: "arrowOpen", value: "--" });
      i += 2;
      continue;
    }
    if (at("==")) {
      push({ type: "arrowOpen", value: "==" });
      i += 2;
      continue;
    }
    if (at(".->")) {
      push({ type: "arrowClose", value: ".->" });
      i += 3;
      continue;
    }
    if (at("o--") || at("x--")) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported arrow "${at("o--") ? "o--" : "x--"}": this subset only supports -->, ---, -.-> and ==>`,
      );
    }
    if (c === "<") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: "<" is rejected: HTML labels (including <br/> and entities) are not supported`,
      );
    }
    if (c === "&") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: "&" is rejected: HTML entities are not supported in labels`,
      );
    }
    if (c === ">") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unexpected ">": arrows are written without inner spaces (--)`,
      );
    }
    if (c === "`") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: backticks and code fences are rejected inside the diagram body`,
      );
    }
    if (c === '"') {
      throw reject(
        "invalid-input",
        `line ${lineNo}: quotes are only allowed around a whole node label, as in id["label"]`,
      );
    }
    if (c === "[" || c === "]" || c === "(" || c === ")" || c === "{" || c === "}") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unexpected "${c}": shapes are attached to a node id (id[label], id(label), id([label]), id{label}, id{{label}})`,
      );
    }
    // A word: a run of plain text. Words are node ids, label pieces or
    // directions depending on context; the parser decides. Unicode runs pass
    // through CODE POINT by code point (supplementary-plane characters are
    // consumed as one unit, never as split surrogates); lone unpaired
    // surrogates still reject, and control/bidi characters already did above.
    const start = i;
    // Step by Unicode code point: a supplementary-plane character (a
    // surrogate pair) is one unit, never two split halves.
    i += line.codePointAt(i) > 0xffff ? 2 : 1;
    while (i < len) {
      const ch = line[i];
      const chCode = line.codePointAt(i);
      if (
        ch === " " || ch === "\t" || ch === "|" || ch === "`" || ch === "<"
        || ch === ">" || ch === "&" || ch === "[" || ch === "]" || ch === "("
        || ch === ")" || ch === "{" || ch === "}" || ch === '"'
      ) {
        break;
      }
      if (isControlOrBanned(chCode)) {
        break;
      }
      // An arrow fragment mid-word ends the word.
      if (line.startsWith("--", i) || line.startsWith("-.", i)
        || line.startsWith("==", i) || line.startsWith(".->", i)) {
        break;
      }
      i += chCode > 0xffff ? 2 : 1;
    }
    const value = line.slice(start, i);
    const lower = value.toLowerCase();
    if (lower.includes("javascript:") || lower.includes("data:")) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: javascript:/data: URLs are rejected`,
      );
    }
    if (i < len && (line[i] === "[" || line[i] === "(" || line[i] === "{")) {
      const node = scanShape(line, i, value, lineNo);
      i = node.next;
      push({ type: "node", id: node.id, shape: node.shape, label: node.label });
      continue;
    }
    push({ type: "word", value });
  }
  return tokens;
}

///|
// Node shapes directly attached to an id. The only supported shapes are
// [label], (label), ([label]), {label} and {{label}}; anything else
// (cylinder [(...)], subroutine [[...]], circles ((...)), >...], ...) is
// rejected by name. A label wrapped in quotes ("id[\"plain text\"]") is
// plain text to its closing quote, so the shape's delimiter characters may
// appear inside it; the closer must sit immediately after the closing quote.
// Unquoted labels keep the original first-occurrence close scan.
function quotedShapeClose(line, content, closer, lineNo, id, what) {
  const endQuote = line.indexOf('"', content + 1);
  if (endQuote === -1) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: ${what} node ${excerpt(`${id}...`)} has an unterminated quoted label`,
    );
  }
  if (!line.startsWith(closer, endQuote + 1)) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: ${what} node ${excerpt(`${id}...`)} is not closed: the shape closer "${closer}" must immediately follow the quoted label`,
    );
  }
  // `close` is an exclusive slice end one past the closing quote, so the
  // caller's raw includes the whole quoted label; the shape closer begins
  // at that same index.
  return { close: endQuote + 1, next: endQuote + 1 + closer.length };
}

function scanShape(line, i, id, lineNo) {
  const open = line[i];
  let shape;
  let raw;
  let next;
  if (open === "(") {
    const after = line[i + 1];
    if (after === "(") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported node shape "id((...))" (double circle): supported shapes are [label], (label), ([label]), {label} and {{label}}`,
      );
    }
    if (after === "[") {
      // "([label])" is a stadium; "[(label)]" is a cylinder (rejected).
      if (line[i + 2] === '"') {
        // quoted stadium: the content is plain text, so ")]" or "])" inside
        // the quotes is label content, not a shape delimiter
        const quoted = quotedShapeClose(line, i + 2, "])", lineNo, id, "stadium");
        shape = "stadium";
        raw = line.slice(i + 2, quoted.close);
        next = quoted.next;
      } else {
        const stadiumClose = line.indexOf("])", i + 2);
        const cylinderClose = line.indexOf(")]", i + 2);
        if (cylinderClose !== -1 && (stadiumClose === -1 || cylinderClose < stadiumClose)) {
          throw reject(
            "invalid-input",
            `line ${lineNo}: unsupported node shape "id[(...)]" (cylinder/database): supported shapes are [label], (label), ([label]), {label} and {{label}}`,
          );
        }
        if (stadiumClose === -1) {
          throw reject(
            "invalid-input",
            `line ${lineNo}: stadium node ${excerpt(`${id}([...])`)} is not closed (missing "]")`,
          );
        }
        shape = "stadium";
        raw = line.slice(i + 2, stadiumClose);
        next = stadiumClose + 2;
      }
    } else if (line[i + 1] === '"') {
      const quoted = quotedShapeClose(line, i + 1, ")", lineNo, id, "rounded");
      shape = "rounded";
      raw = line.slice(i + 1, quoted.close);
      next = quoted.next;
    } else {
      const close = line.indexOf(")", i + 1);
      if (close === -1) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: rounded node ${excerpt(`${id}(...)`)} is not closed`,
        );
      }
      shape = "rounded";
      raw = line.slice(i + 1, close);
      next = close + 1;
    }
  } else if (open === "[") {
    if (line[i + 1] === "[") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported node shape "id[[...]]" (subroutine): supported shapes are [label], (label), ([label]), {label} and {{label}}`,
      );
    }
    if (line[i + 1] === "(") {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported node shape "id[(...)]" (cylinder/database): supported shapes are [label], (label), ([label]), {label} and {{label}}`,
      );
    }
    if (line[i + 1] === '"') {
      const quoted = quotedShapeClose(line, i + 1, "]", lineNo, id, "rect");
      shape = "rect";
      raw = line.slice(i + 1, quoted.close);
      next = quoted.next;
    } else {
      const close = line.indexOf("]", i + 1);
      if (close === -1) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: rect node ${excerpt(`${id}[...]`)} is not closed`,
        );
      }
      shape = "rect";
      raw = line.slice(i + 1, close);
      next = close + 1;
    }
  } else {
    // "{"
    if (line[i + 1] === "{") {
      if (line[i + 2] === '"') {
        const quoted = quotedShapeClose(line, i + 2, "}}", lineNo, id, "hexagon");
        shape = "hexagon";
        raw = line.slice(i + 2, quoted.close);
        next = quoted.next;
      } else {
        const close = line.indexOf("}}", i + 2);
        if (close === -1) {
          throw reject(
            "invalid-input",
            `line ${lineNo}: hexagon node ${excerpt(`${id}{{...}}`)} is not closed`,
          );
        }
        shape = "hexagon";
        raw = line.slice(i + 2, close);
        next = close + 2;
      }
    } else if (line[i + 1] === '"') {
      const quoted = quotedShapeClose(line, i + 1, "}", lineNo, id, "rhombus");
      shape = "rhombus";
      raw = line.slice(i + 1, quoted.close);
      next = quoted.next;
    } else {
      const close = line.indexOf("}", i + 1);
      if (close === -1) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: rhombus node ${excerpt(`${id}{...}`)} is not closed`,
        );
      }
      shape = "rhombus";
      raw = line.slice(i + 1, close);
      next = close + 1;
    }
  }
  return { id, shape, label: validateLabel(raw, lineNo, `${shape} label`), next };
}

function describeToken(token) {
  if (token.type === "pipe") {
    return `a pipe label "|${excerpt(token.value, 20)}|"`;
  }
  return `"${excerpt(token.value, 24)}"`;
}

///|
// The full parse. Bounded, iterative, no regex with unbounded backtracking.
function parseDiagram(text) {
  let lines = text.split(/\r\n|\r|\n/);
  if (lines.length > MAX_LINES) {
    throw reject(
      "too-large",
      `the input has ${lines.length} lines (max ${MAX_LINES})`,
    );
  }
  // Optional fence of exactly two lines wrapping the whole content.
  let end = lines.length;
  while (end > 0 && lines[end - 1].trim() === "") {
    end -= 1;
  }
  const first = end > 0 ? lines[0] : "";
  if (first.startsWith("```")) {
    if (!/^```mermaid[ \t]*$/.test(first)) {
      throw reject(
        "invalid-input",
        "unsupported fence: the only accepted wrapper is a first line ```mermaid and a last line ```",
      );
    }
    if (end < 2 || !/^```[ \t]*$/.test(lines[end - 1])) {
      throw reject(
        "invalid-input",
        "a ```mermaid-wrapped diagram must end with a line that is exactly ```",
      );
    }
    lines = lines.slice(1, end - 1);
    if (lines.length > MAX_LINES) {
      throw reject(
        "too-large",
        `the diagram body has ${lines.length} lines (max ${MAX_LINES})`,
      );
    }
  }
  const doc = { direction: "td", nodes: [], byId: new Map(), edges: [] };
  let headerSeen = false;
  for (let index = 0; index < lines.length; index += 1) {
    const raw = lines[index];
    const lineNo = index + 1;
    const trimmed = raw.trim();
    if (trimmed === "") {
      continue;
    }
    if (raw.includes("%%{")) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: %%{...}%% directives are rejected`,
      );
    }
    if (trimmed.startsWith("%%")) {
      continue;
    }
    const tokens = tokenizeLine(raw, lineNo);
    if (tokens.length === 0) {
      continue;
    }
    if (!headerSeen) {
      parseHeader(tokens, lineNo, doc);
      headerSeen = true;
      continue;
    }
    parseStatement(tokens, lineNo, doc);
  }
  if (!headerSeen) {
    throw reject(
      "invalid-input",
      'no diagram header found: the first meaningful line must be "flowchart" or "graph"',
    );
  }
  if (doc.nodes.length === 0) {
    throw reject(
      "invalid-input",
      "the diagram declares no nodes: there is nothing to draw",
    );
  }
  return doc;
}

function parseHeader(tokens, lineNo, doc) {
  const head = tokens[0];
  if (head.type !== "word") {
    throw reject(
      "invalid-input",
      `line ${lineNo}: the diagram must open with the plain word "flowchart" or "graph"`,
    );
  }
  const lower = head.value.toLowerCase();
  if (head.value !== "flowchart" && head.value !== "graph") {
    if (RESERVED_KINDS.has(lower)) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported diagram kind "${excerpt(head.value)}": this adapter only accepts the bounded flowchart subset`,
      );
    }
    throw reject(
      "invalid-input",
      `line ${lineNo}: expected "flowchart" or "graph" (lowercase only), found ${describeToken(head)}`,
    );
  }
  if (tokens.length >= 2) {
    const dir = tokens[1];
    if (dir.type !== "word" || !DIRECTIONS.has(dir.value.toLowerCase())) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: unsupported direction ${describeToken(dir)}: only td, tb, lr and rl are accepted`,
      );
    }
    doc.direction = dir.value.toLowerCase();
  }
  if (tokens.length > 2) {
    throw reject(
      "invalid-input",
      `line ${lineNo}: unexpected tokens after the direction (${describeToken(tokens[2])})`,
    );
  }
}

function parseStatement(tokens, lineNo, doc) {
  let cursor = 0;

  const parseNodeRef = () => {
    const token = tokens[cursor];
    if (token === undefined) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: expected a node id after the arrow (a statement may not end on an arrow)`,
      );
    }
    cursor += 1;
    let shape = null;
    let label = null;
    let id;
    if (token.type === "node") {
      id = token.id;
      shape = token.shape;
      label = token.label;
    } else if (token.type === "word") {
      id = token.value;
    } else {
      throw reject(
        "invalid-input",
        `line ${lineNo}: expected a node id, found ${describeToken(token)}`,
      );
    }
    const lower = (id || "").toLowerCase();
    if (RESERVED_IDS.has(lower)) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: "${id}" is a reserved word and cannot be used as a node id`,
      );
    }
    const codepoints = [...id].length;
    if (codepoints > MAX_ID_CODEPOINTS) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: node id "${excerpt(id, MAX_ID_CODEPOINTS + 2)}" is longer than ${MAX_ID_CODEPOINTS} codepoints`,
      );
    }
    if (!ID_RE.test(id)) {
      throw reject(
        "invalid-input",
        `line ${lineNo}: invalid node id "${excerpt(id)}": ids are letters (any script), digits (any script), "_" and "-", starting with a letter or "_"`,
      );
    }
    let index = doc.byId.get(id);
    if (index === undefined) {
      if (doc.nodes.length >= MAX_NODES) {
        throw reject(
          "too-large",
          `more than ${MAX_NODES} nodes: "${excerpt(id)}" is one too many`,
        );
      }
      index = doc.nodes.length;
      doc.nodes.push({ id, shape: null, label: id });
      doc.byId.set(id, index);
    }
    if (shape !== null) {
      // The last declaration carrying a shape wins.
      const node = doc.nodes[index];
      node.shape = shape;
      node.label = label;
    }
    return index;
  };

  const parseSeparator = () => {
    const token = tokens[cursor];
    if (token.type === "arrow") {
      cursor += 1;
      if (cursor < tokens.length && tokens[cursor].type === "pipe") {
        if (token.value === "---") {
          throw reject(
            "invalid-input",
            `line ${lineNo}: unsupported arrow "---|": plain links cannot carry labels`,
          );
        }
        const label = tokens[cursor].value;
        cursor += 1;
        return { kind: kindOf(token.value), label };
      }
      return { kind: kindOf(token.value), label: null };
    }
    if (token.type === "arrowOpen") {
      cursor += 1;
      const closer = token.value === "--" ? "-->"
        : token.value === "-." ? ".->"
          : "==>";
      const kind = kindOf(closer);
      const words = [];
      while (cursor < tokens.length && tokens[cursor].type === "word") {
        words.push(tokens[cursor].value);
        cursor += 1;
      }
      const close = tokens[cursor];
      if (cursor >= tokens.length
        || ((close.type !== "arrow" && close.type !== "arrowClose") || close.value !== closer)) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: a labeled edge opened with "${token.value}" must be closed with "${closer}"`,
        );
      }
      cursor += 1;
      if (words.length === 0) {
        throw reject(
          "invalid-input",
          `line ${lineNo}: empty edge label: write ${closer} without a label instead`,
        );
      }
      return { kind, label: validateLabel(words.join(" "), lineNo, "edge label") };
    }
    throw reject(
      "invalid-input",
      `line ${lineNo}: expected an arrow after a node, found ${describeToken(token)}`,
    );
  };

  let node = parseNodeRef();
  while (cursor < tokens.length) {
    const separator = parseSeparator();
    const target = parseNodeRef();
    if (doc.edges.length >= MAX_EDGES) {
      throw reject(
        "too-large",
        `more than ${MAX_EDGES} edges: edge ${doc.edges.length + 1} is one too many`,
      );
    }
    doc.edges.push({
      from: node,
      to: target,
      kind: separator.kind,
      label: separator.label,
    });
    node = target;
  }
}

function kindOf(arrow) {
  if (arrow === "-->" || arrow === "--") {
    return "arrow";
  }
  if (arrow === "-.->" || arrow === "-." || arrow === ".->") {
    return "dotted";
  }
  if (arrow === "==>" || arrow === "==" || arrow === "=>") {
    return "thick";
  }
  return "plain"; // ---
}

///|
// DETERMINISTIC LAYOUT (documented in the module header). Iterative
// relaxation capped at node-count iterations; cycles keep their deepest
// settled depth when the cap hits, and `capped` reports it.
function layoutDiagram(doc) {
  const n = doc.nodes.length;
  const parents = new Array(n);
  const seenParents = new Array(n);
  for (let i = 0; i < n; i += 1) {
    parents[i] = [];
    seenParents[i] = new Set();
  }
  for (const edge of doc.edges) {
    if (!seenParents[edge.to].has(edge.from)) {
      seenParents[edge.to].add(edge.from);
      parents[edge.to].push(edge.from);
    }
  }
  let depth = new Array(n).fill(0);
  let capped = false;
  for (let iter = 0; iter < n; iter += 1) {
    let changed = false;
    const next = depth.slice();
    for (let j = 0; j < n; j += 1) {
      let best = 0;
      const list = parents[j];
      for (let k = 0; k < list.length; k += 1) {
        const candidate = depth[list[k]] + 1;
        if (candidate > best) {
          best = candidate;
        }
      }
      if (best > next[j]) {
        next[j] = best;
        changed = true;
      }
    }
    depth = next;
    if (!changed) {
      break;
    }
    if (iter === n - 1) {
      capped = true;
    }
  }
  let maxDepth = 0;
  for (let i = 0; i < n; i += 1) {
    if (depth[i] > maxDepth) {
      maxDepth = depth[i];
    }
  }
  // Within a layer, nodes keep first-appearance order.
  const counts = new Array(maxDepth + 1).fill(0);
  const layerIndex = new Array(n);
  for (let i = 0; i < n; i += 1) {
    layerIndex[i] = counts[depth[i]];
    counts[depth[i]] += 1;
  }
  const x = new Float64Array(n);
  const y = new Float64Array(n);
  const vertical = doc.direction === "td" || doc.direction === "tb";
  for (let i = 0; i < n; i += 1) {
    if (vertical) {
      x[i] = MARGIN + layerIndex[i] * PITCH_X;
      y[i] = MARGIN + depth[i] * PITCH_Y;
    } else if (doc.direction === "lr") {
      x[i] = MARGIN + depth[i] * PITCH_X;
      y[i] = MARGIN + layerIndex[i] * PITCH_Y_LR;
    } else {
      // rl: mirrored lr, the flow moves leftward.
      x[i] = MARGIN + (maxDepth - depth[i]) * PITCH_X;
      y[i] = MARGIN + layerIndex[i] * PITCH_Y_LR;
    }
  }
  return { depth, maxDepth, x, y, capped };
}

///|
// Node geometry: the drawn outline for rhombus/hexagon nodes (edges clip
// against it), the 160x48 box for everything else, plus the shape center.
function nodeGeometry(doc, i, x, y) {
  const nx = x[i];
  const ny = y[i];
  const cx = nx + BOX_W / 2;
  const cy = ny + BOX_H / 2;
  let outline = null;
  if (doc.nodes[i].shape === "rhombus") {
    outline = [[cx, cy - 48], [cx + 96, cy], [cx, cy + 48], [cx - 96, cy]];
  } else if (doc.nodes[i].shape === "hexagon") {
    outline = [
      [cx - 96, cy], [cx - 72, cy - 48], [cx + 72, cy - 48],
      [cx + 96, cy], [cx + 72, cy + 48], [cx - 72, cy + 48],
    ];
  }
  return { nx, ny, cx, cy, outline };
}

///|
// Exit point of a box along the (dx,dy) direction from its center: plain
// slab clipping against the 160x48 layout box.
function exitBox(cx, cy, dx, dy, bx, by) {
  let t = Infinity;
  if (dx > 0) {
    t = Math.min(t, (bx + BOX_W - cx) / dx);
  } else if (dx < 0) {
    t = Math.min(t, (bx - cx) / dx);
  }
  if (dy > 0) {
    t = Math.min(t, (by + BOX_H - cy) / dy);
  } else if (dy < 0) {
    t = Math.min(t, (by - cy) / dy);
  }
  if (!Number.isFinite(t) || t < 0 || t > 1) {
    t = 0;
  }
  return [cx + dx * t, cy + dy * t];
}

///|
// Exit point of a convex polygon along the (dx,dy) direction from its
// center: the nearest edge crossing on the ray (the center is inside the
// polygon, so exactly one edge crossing is closest). c + t*d = a + s*e.
function exitPolygon(cx, cy, dx, dy, polygon) {
  let bestT = Infinity;
  let px = cx;
  let py = cy;
  const count = polygon.length;
  for (let i = 0; i < count; i += 1) {
    const a = polygon[i];
    const b = polygon[(i + 1) % count];
    const ex = b[0] - a[0];
    const ey = b[1] - a[1];
    const denom = dx * ey - dy * ex;
    if (denom === 0) {
      continue;
    }
    const wx = a[0] - cx;
    const wy = a[1] - cy;
    const t = (wx * ey - wy * ex) / denom;
    const s = (wx * dy - wy * dx) / denom;
    if (t > 0 && s >= 0 && s <= 1 && t < bestT) {
      bestT = t;
      px = cx + dx * t;
      py = cy + dy * t;
    }
  }
  return [px, py];
}

///|
// Edge geometry: the clipped segment between the two nodes' actual
// boundaries. Rhombus/hexagon boundaries are their drawn outlines; every
// other shape clips at its box. Self-edges draw a fixed loop anchored ON the
// node's actual drawn outline (box top edge for rect/rounded/stadium, upper
// edges for a rhombus, flat top edge for a hexagon), and the route stays
// strictly outside the outline so the head is never hidden by the node fill.
function edgeGeometry(doc, edge, layout) {
  const { x, y } = layout;
  if (edge.from === edge.to) {
    const node = doc.nodes[edge.from];
    const geom = nodeGeometry(doc, edge.from, x, y);
    let anchorY;
    let routeTop;
    if (geom.outline === null) {
      // rect/rounded/stadium: the top edge carries the anchors (24pt either
      // side of the center stays on the straight part of a rounded top).
      anchorY = geom.ny;
      routeTop = geom.ny - 28;
    } else if (node.shape === "rhombus") {
      // The diamond edge at dx = +/-24 sits at cy - 36; its top tip is
      // cy - 48, so a route 28pt above the tip clears the whole outline.
      anchorY = geom.cy - 36;
      routeTop = geom.cy - 48 - 28;
    } else {
      // Hexagon: flat top edge at cy - 48 (|dx| <= 72 covers +/-24).
      anchorY = geom.cy - 48;
      routeTop = geom.cy - 48 - 28;
    }
    const left = [geom.cx - 24, anchorY];
    const right = [geom.cx + 24, anchorY];
    return {
      points: [[left[0], left[1]], [left[0], routeTop], [right[0], routeTop], [right[0], right[1]]],
      ps: [left[0], left[1]],
      pe: [right[0], right[1]],
      tip: [0, 1],
      labelAnchor: [geom.cx, routeTop],
    };
  }
  const source = nodeGeometry(doc, edge.from, x, y);
  const target = nodeGeometry(doc, edge.to, x, y);
  const dx = target.cx - source.cx;
  const dy = target.cy - source.cy;
  const ps = source.outline === null
    ? exitBox(source.cx, source.cy, dx, dy, source.nx, source.ny)
    : exitPolygon(source.cx, source.cy, dx, dy, source.outline);
  const pe = target.outline === null
    ? exitBox(target.cx, target.cy, -dx, -dy, target.nx, target.ny)
    : exitPolygon(target.cx, target.cy, -dx, -dy, target.outline);
  return {
    points: [ps, pe],
    ps,
    pe,
    tip: [pe[0] - ps[0], pe[1] - ps[1]],
    labelAnchor: [(ps[0] + pe[0]) / 2, (ps[1] + pe[1]) / 2],
  };
}

function assertRenderable(primitives) {
  if (primitives.length > MAX_PRIMITIVES) {
    throw reject(
      "too-large",
      `rendering produced ${primitives.length} primitives (max ${MAX_PRIMITIVES})`,
    );
  }
  const check = (value, what) => {
    if (value === undefined || value === null) {
      return; // fields the primitive kind does not carry are simply absent
    }
    if (typeof value !== "number" || !Number.isFinite(value) || Math.abs(value) > MAX_COORD) {
      throw reject(
        "invalid-input",
        `internal render invariant violated ${what}: coordinates must be finite and bounded`,
      );
    }
  };
  for (const prim of primitives) {
    if (prim.kind === undefined || typeof prim.kind !== "string") {
      throw reject("invalid-input", "internal render invariant violated (missing kind)");
    }
    check(prim.x, `(${prim.kind}.x)`);
    check(prim.y, `(${prim.kind}.y)`);
    check(prim.cx, `(${prim.kind}.cx)`);
    check(prim.cy, `(${prim.kind}.cy)`);
    check(prim.w, `(${prim.kind}.w)`);
    check(prim.h, `(${prim.kind}.h)`);
    check(prim.strokeWidth, `(${prim.kind}.strokeWidth)`);
    check(prim.advance, `(${prim.kind}.advance)`);
    for (const point of prim.points ?? []) {
      check(point[0], `(${prim.kind}.point.x)`);
      check(point[1], `(${prim.kind}.point.y)`);
    }
    for (const seg of prim.dash ?? []) {
      if (typeof seg !== "number" || !Number.isFinite(seg) || seg <= 0 || seg > 100000) {
        throw reject(
          "invalid-input",
          "internal render invariant violated (dash segment): dash values must be finite, positive and bounded",
        );
      }
    }
  }
}

///|
// RENDER (documented in the module header). Builds primitives in z order
// (edges, nodes, edge labels), computes TRUE extents including stroke
// padding and real text bands (advance estimate), translates everything so
// the minimum coordinate is >= the margin, and returns page size,
// primitives and approximation warnings.
function renderDiagram(doc, layout) {
  const prims = [];
  const warnings = [
    "layout uses a fixed deterministic layered approximation, not the Mermaid rendering engine",
  ];
  const { x, y } = layout;
  const n = doc.nodes.length;
  let minX = Infinity;
  let minY = Infinity;
  let maxX = -Infinity;
  let maxY = -Infinity;
  // Track the fill/border geometry for the minimum (translating by strokes
  // is unnecessary) and the stroke-padded geometry for the maximum.
  const trackMin = (px, py) => {
    if (px < minX) minX = px;
    if (py < minY) minY = py;
  };
  const trackMax = (px, py) => {
    if (px > maxX) maxX = px;
    if (py > maxY) maxY = py;
  };
  let longLabels = 0;
  let selfLoops = 0;
  let totalTextChars = 0;

  // 1. Edges (under the nodes, so arrowheads on borders are never hidden).
  for (const edge of doc.edges) {
    const geometry = edgeGeometry(doc, edge, layout);
    if (edge.from === edge.to) {
      selfLoops += 1;
    }
    const strokeWidth = edge.kind === "thick" ? 3 : 2;
    const linePoints = geometry.points.map((p) => [p[0], p[1]]);
    prims.push({
      kind: "polyline",
      points: linePoints,
      stroke: COLOR.edge,
      strokeWidth,
      dash: edge.kind === "dotted" ? [4, 4] : null,
    });
    // Page fitting: the unpadded skeleton decides the minimum (translation);
    // the stroke side uses the shared miter-aware extent (pads + protrusions).
    for (const point of linePoints) {
      trackMin(point[0], point[1]);
    }
    const lineExtent = strokedPolylineExtent(linePoints, strokeWidth, false);
    trackMax(lineExtent.x + lineExtent.w, lineExtent.y + lineExtent.h);
    if (edge.kind !== "plain") {
      // Filled arrowhead triangle at the target end.
      let [dx, dy] = geometry.tip;
      const len = Math.hypot(dx, dy) || 1;
      dx /= len;
      dy /= len;
      const nxv = -dy;
      const nyv = dx;
      const [ex, ey] = geometry.pe;
      const base1x = ex - dx * 12 + nxv * 5;
      const base1y = ey - dy * 12 + nyv * 5;
      const base2x = ex - dx * 12 - nxv * 5;
      const base2y = ey - dy * 12 - nyv * 5;
      const points = [[ex, ey], [base1x, base1y], [base2x, base2y]];
      prims.push({
        kind: "polygon",
        points,
        fill: COLOR.edge,
        stroke: null,
      });
      for (const point of points) {
        trackMin(point[0], point[1]);
        trackMax(point[0], point[1]);
      }
    }
    if (edge.label) {
      totalTextChars += edge.label.length;
    }
  }

  // 2. Nodes: shape, then its text.
  for (let i = 0; i < n; i += 1) {
    const node = doc.nodes[i];
    const geom = nodeGeometry(doc, i, x, y);
    if (node.shape === "rhombus") {
      // 192x96 diamond on the 160x48 layout box.
      const points = geom.outline.map((p) => [p[0], p[1]]);
      prims.push({
        kind: "polygon",
        points,
        fill: COLOR.rhombusFill,
        stroke: COLOR.nodeStroke,
        strokeWidth: NODE_STROKE_WIDTH,
      });
      for (const point of points) {
        trackMin(point[0], point[1]);
      }
      const ext = strokedPolylineExtent(points, NODE_STROKE_WIDTH, true);
      trackMax(ext.x + ext.w, ext.y + ext.h);
    } else if (node.shape === "hexagon") {
      const points = geom.outline.map((p) => [p[0], p[1]]);
      prims.push({
        kind: "polygon",
        points,
        fill: COLOR.hexagonFill,
        stroke: COLOR.nodeStroke,
        strokeWidth: NODE_STROKE_WIDTH,
      });
      for (const point of points) {
        trackMin(point[0], point[1]);
      }
      const ext = strokedPolylineExtent(points, NODE_STROKE_WIDTH, true);
      trackMax(ext.x + ext.w, ext.y + ext.h);
    } else {
      const rounded = node.shape === "rounded" || node.shape === "stadium" ? 24 : 0;
      prims.push({
        kind: "rect",
        x: geom.nx,
        y: geom.ny,
        w: BOX_W,
        h: BOX_H,
        rounded,
        fill: COLOR.nodeFill,
        stroke: COLOR.nodeStroke,
        strokeWidth: NODE_STROKE_WIDTH,
      });
      trackMin(geom.nx, geom.ny);
      const ext = strokedPolylineExtent(
        [[geom.nx, geom.ny], [geom.nx + BOX_W, geom.ny], [geom.nx + BOX_W, geom.ny + BOX_H], [geom.nx, geom.ny + BOX_H]],
        NODE_STROKE_WIDTH,
        true,
      );
      trackMax(ext.x + ext.w, ext.y + ext.h);
    }
    const label = node.label || "";
    if (label !== "") {
      totalTextChars += label.length;
      const advance = textAdvance(label, 16);
      // 16pt Helvetica averages ~9.7pt advance for ASCII; warn when the
      // label cannot fit the 160pt box (the text still draws, unclipped).
      if (advance > BOX_W - 16) {
        longLabels += 1;
      }
      prims.push({
        kind: "text",
        x: geom.cx,
        y: geom.cy,
        text: label,
        fontSize: 16,
        family: "Helvetica",
        weight: 400,
        style: "normal",
        align: "center",
        baseline: "middle",
        advance,
        fill: COLOR.nodeText,
      });
      trackMin(geom.cx - advance / 2, geom.cy - 16 * 0.6);
      trackMax(geom.cx + advance / 2, geom.cy + 16 * 0.6);
    }
  }

  // 3. Edge labels, on top: a white rect behind a 12pt text anchored at the
  // segment midpoint for normal edges (respecting the actual outline clip)
  // and above the loop for self-edges.
  for (const edge of doc.edges) {
    if (!edge.label) {
      continue;
    }
    const geometry = edgeGeometry(doc, edge, layout);
    const mx = geometry.labelAnchor[0];
    const my = geometry.labelAnchor[1];
    const advance = textAdvance(edge.label, 12);
    const bcy = my - 16;
    const w = Math.max(24, advance + 10);
    const h = 20;
    prims.push({
      kind: "rect",
      x: mx - w / 2,
      y: bcy - h / 2,
      w,
      h,
      rounded: 0,
      fill: COLOR.labelBg,
      stroke: null,
    });
    prims.push({
      kind: "text",
      x: mx,
      y: bcy,
      text: edge.label,
      fontSize: 12,
      family: "Helvetica",
      weight: 400,
      style: "normal",
      align: "center",
      baseline: "middle",
      advance,
      fill: COLOR.labelText,
    });
    trackMin(mx - w / 2, bcy - h / 2);
    trackMax(mx + w / 2, bcy + h / 2);
    trackMin(mx - advance / 2, bcy - 12 * 0.6);
    trackMax(mx + advance / 2, bcy + 12 * 0.6);
  }

  if (totalTextChars > MAX_TOTAL_LABEL_CHARS) {
    throw reject(
      "too-large",
      `total label text is ${totalTextChars} characters (max ${MAX_TOTAL_LABEL_CHARS})`,
    );
  }
  if (selfLoops > 0) {
    warnings.push(`${selfLoops} self-edge(s) drawn as a fixed small loop above the node`);
  }
  if (longLabels > 0) {
    warnings.push(`${longLabels} node label(s) wider than the 160pt box; text may overflow the shape`);
  }
  if (layout.capped) {
    warnings.push(
      "a cycle kept the layer relaxation running to its node-count cap; the cycle's nodes keep their deepest settled layer",
    );
  }
  if (prims.length > MAX_PRIMITIVES) {
    throw reject(
      "too-large",
      `rendering produced ${prims.length} primitives (max ${MAX_PRIMITIVES})`,
    );
  }

  // Page fitting: when anything (a wide label, a polygon tip, a loop) falls
  // below the margin, translate EVERY primitive so the minimum sits exactly
  // at the margin; the page then covers extents + margins.
  const tx = MARGIN - Math.min(minX, MARGIN);
  const ty = MARGIN - Math.min(minY, MARGIN);
  if (tx !== 0 || ty !== 0) {
    for (const prim of prims) {
      if (prim.kind === "rect" || prim.kind === "text") {
        if (prim.x !== undefined) {
          prim.x += tx;
        }
        if (prim.y !== undefined) {
          prim.y += ty;
        }
      }
      for (const point of prim.points ?? []) {
        point[0] += tx;
        point[1] += ty;
      }
    }
  }
  const width = Math.ceil(maxX + tx + MARGIN);
  const height = Math.ceil(maxY + ty + MARGIN);
  if (!(width > 0 && height > 0) || width > 16777216 || height > 16777216) {
    throw reject(
      "invalid-input",
      "rendered page size fell outside the page bounds",
    );
  }
  return { width, height, primitives: prims, warnings };
}

async function convertBytes(bytes, options) {
  acceptedParams(options, [], MERMAID_FORMAT_NAME);
  noPassword(options, MERMAID_FORMAT_NAME);
  if (!(bytes instanceof Uint8Array)) {
    throw reject("invalid-input", "convert expects a Uint8Array of the file's bytes");
  }
  if (bytes.length > MAX_INPUT_BYTES) {
    throw reject(
      "too-large",
      `input is ${bytes.length} bytes; the cap is ${MAX_INPUT_BYTES} bytes (1 MiB)`,
    );
  }
  const text = decodeUtf8Strict(bytes);
  const doc = parseDiagram(text);
  const layout = layoutDiagram(doc);
  const render = renderDiagram(doc, layout);
  assertRenderable(render.primitives);
  let bdf;
  try {
    bdf = await encodeDiagram({
      width: render.width,
      height: render.height,
      source: MERMAID_FORMAT_NAME,
      title: "flowchart",
      primitives: render.primitives,
    });
  } catch (error) {
    throw reject(
      error?.code === "too-large" ? "too-large" : "invalid-input",
      `encoding failed: ${error?.message ?? String(error)}`,
    );
  }
  return {
    bdf,
    format: MERMAID_FORMAT_NAME,
    summary: `1 page, ${doc.nodes.length} node(s), ${doc.edges.length} edge(s)`,
    warnings: render.warnings,
  };
}

///|
// Synchronous content detection: the byte cap is enforced BEFORE any
// decoding or scanning, and the verdict never throws.
function detectMermaid(bytes) {
  try {
    if (!(bytes instanceof Uint8Array) || bytes.length === 0) {
      return false;
    }
    if (bytes.length > MAX_INPUT_BYTES) {
      return false;
    }
    parseDiagram(decodeUtf8Strict(bytes));
    return true;
  } catch (error) {
    return false;
  }
}

///|
// The bounded Mermaid flowchart adapter as a versioned plugin descriptor.
export function mermaidPlugin() {
  const plugin = {
    apiVersion: 1,
    name: MERMAID_FORMAT_NAME,
    description: MERMAID_DESCRIPTION,
    extensions: [...MERMAID_EXTENSIONS],
    version: "1.0.0",
    vendor: "f4ah6o",
    detect: detectMermaid,
    convert: convertBytes,
  };
  return defineFormatPlugin(plugin);
}
