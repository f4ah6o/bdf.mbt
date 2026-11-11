// 記入済みのフォームを PDF にしたときの、文字と升目の検査。
//
// ブラウザも poppler も使わず、書き出した PDF のバイト列だけを読む:
//   - 内容ストリームの Tz / Tm から、升目の列の位置を出す
//   - ToUnicode の CMap から、Tj の文字を戻して日本語と罫線を確かめる
//   - 埋め込めないフォント・字形の無い文字は、警告になることを確かめる
//
// `npm run build:site` のあとに `node site/form/pdf.test.mjs` で動く。

import {readFile} from "node:fs/promises";
import {fileURLToPath} from "node:url";
import {dirname, resolve} from "node:path";
import {bdf_form_fill} from "../../_build/js/release/build/form_page/form_page.js";
import {bdf_wasm_export_pdf_font} from "../../_build/js/release/build/bridge/wasm/wasm.js";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const fonts = resolve(root, "site/form/fonts");
const samples = resolve(root, "site/form/samples");

const mono = await readFile(resolve(fonts, "MPLUS1Code-Regular.ttf"));
const proportional = await readFile(resolve(fonts, "MPLUS1p-Regular.ttf"));

let failed = 0;
let passed = 0;
function check(name, ok, detail) {
  if (ok) {
    passed++;
    console.log("PASS " + name);
  } else {
    failed++;
    console.log("FAIL " + name + (detail === undefined ? "" : " :: " + detail));
  }
}

function fill(template, data, open = "[]") {
  const result = JSON.parse(
    bdf_form_fill(
      typeof template === "string" ? new TextEncoder().encode(template) : template,
      JSON.stringify(data),
      open,
      false,
    ),
  );
  if (!result.ok) throw new Error(result.error);
  return Buffer.from(result.bdf, "base64");
}

function exportPdf(bdf, font) {
  const result = JSON.parse(
    bdf_wasm_export_pdf_font(
      bdf.toString("base64"),
      0,
      font === null ? "" : font.toString("base64"),
    ),
  );
  if (!result.ok) throw new Error(result.error);
  return {
    pdf: Buffer.from(result.pdf, "base64"),
    pages: result.pages,
    fonts: result.fonts,
    warnings: result.warnings,
  };
}

// PDF のオブジェクトを、/Length を見てストリームごと切り出す。
function parseObjects(buf) {
  const text = buf.toString("latin1");
  const objects = new Map();
  let at = 0;
  for (;;) {
    const match = /(\d+) 0 obj/.exec(text.slice(at));
    if (match === null) break;
    const start = at + match.index;
    const body = start + match[0].length;
    const stream = text.indexOf("stream", body);
    const end = text.indexOf("endobj", body);
    if (stream >= 0 && (end < 0 || stream < end)) {
      const head = text.slice(body, stream);
      const length = /\/Length\s+(\d+)/.exec(head);
      let data = stream + 6;
      if (text[data] === "\r") data++;
      if (text[data] === "\n") data++;
      const size = length === null ? 0 : Number(length[1]);
      objects.set(Number(match[1]), {
        dict: head,
        data: buf.subarray(data, data + size),
      });
      const after = text.indexOf("endobj", data + size);
      at = after < 0 ? text.length : after + 6;
    } else {
      objects.set(Number(match[1]), {
        dict: text.slice(body, end < 0 ? text.length : end),
        data: null,
      });
      at = end < 0 ? text.length : end + 6;
    }
  }
  return objects;
}

function hex(text) {
  return parseInt(text, 16);
}

// ToUnicode の CMap を、字形の番号から文字へ。
function parseCMap(data) {
  const text = data.toString("latin1");
  const map = new Map();
  for (const block of text.matchAll(/beginbfchar([\s\S]*?)endbfchar/g)) {
    for (const pair of block[1].matchAll(/<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>/g)) {
      const code = hex(pair[1]);
      const value = pair[2];
      let out = "";
      for (let i = 0; i + 4 <= value.length; i += 4) {
        out += String.fromCharCode(hex(value.slice(i, i + 4)));
      }
      map.set(code, out);
    }
  }
  for (const block of text.matchAll(/beginbfrange([\s\S]*?)endbfrange/g)) {
    for (const range of block[1].matchAll(
      /<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>\s*<([0-9a-fA-F]+)>/g,
    )) {
      const from = hex(range[1]);
      const to = hex(range[2]);
      const base = hex(range[3]);
      for (let code = from; code <= to; code++) {
        map.set(code, String.fromCharCode(base + code - from));
      }
    }
  }
  return map;
}

// ページの内容と、そのとき使うフォントの CMap。
function readPage(pdf) {
  const objects = parseObjects(pdf);
  const cmaps = new Map();
  for (const [number, object] of objects) {
    const toUnicode = /\/ToUnicode\s+(\d+) 0 R/.exec(object.dict);
    if (toUnicode === null) continue;
    const cmap = objects.get(Number(toUnicode[1]));
    if (cmap === undefined || cmap.data === null) continue;
    cmaps.set(number, parseCMap(cmap.data));
  }
  const names = new Map();
  for (const object of objects.values()) {
    const font = /\/Font\s*<<([\s\S]*?)>>/.exec(object.dict);
    if (font === null) continue;
    for (const entry of font[1].matchAll(/\/(F\d+)\s+(\d+) 0 R/g)) {
      names.set(entry[1], Number(entry[2]));
    }
  }
  let content = "";
  for (const object of objects.values()) {
    const contents = /\/Contents\s+(\d+) 0 R/.exec(object.dict);
    if (contents === null) continue;
    const stream = objects.get(Number(contents[1]));
    if (stream !== undefined && stream.data !== null) {
      content += stream.data.toString("latin1") + "\n";
    }
  }
  return {content, cmaps, names};
}

// 内容ストリームの Tj を、フォントの CMap で文字に戻す。
function decodeText(page) {
  const lines = [];
  let cmap = new Map();
  for (const line of page.content.split("\n")) {
    const font = /^\/(F\d+) [\d.]+ Tf$/.exec(line);
    if (font !== null) {
      cmap = page.cmaps.get(page.names.get(font[1])) ?? new Map();
      continue;
    }
    const show = /^<([0-9a-fA-F]+)> Tj$/.exec(line);
    if (show === null) continue;
    let out = "";
    for (let i = 0; i + 4 <= show[1].length; i += 4) {
      const code = hex(show[1].slice(i, i + 4));
      out += cmap.get(code) ?? "\uFFFD";
    }
    lines.push(out);
  }
  return lines;
}

// 文字を置いた位置と、そのときの横の倍率。
function placements(page) {
  const rows = [];
  let tz = 100;
  for (const line of page.content.split("\n")) {
    const scale = /^([\d.]+) Tz$/.exec(line);
    if (scale !== null) {
      tz = Number(scale[1]);
      continue;
    }
    const at = /^1 0 0 -1 ([\d.-]+) ([\d.-]+) Tm$/.exec(line);
    if (at !== null) rows.push({x: Number(at[1]), y: Number(at[2]), tz});
  }
  return rows;
}

// 埋め込んだフォントの /W から、字形の幅 (1000 分の 1 em) を読む。
// 幅は CIDFont の辞書にある (Type0 の辞書ではない)。
function readWidths(pdf) {
  const widths = new Map();
  for (const object of parseObjects(pdf).values()) {
    const at = object.dict.indexOf("/W");
    if (at < 0) continue;
    const open = object.dict.indexOf("[", at);
    if (open < 0) continue;
    // the array holds arrays, so count the brackets
    let depth = 0;
    let end = open;
    for (; end < object.dict.length; end++) {
      if (object.dict[end] === "[") depth++;
      else if (object.dict[end] === "]") {
        depth--;
        if (depth === 0) break;
      }
    }
    const array = object.dict.slice(open + 1, end);
    for (const entry of array.matchAll(/(\d+)\s*\[(\d+)\]/g)) {
      widths.set(Number(entry[1]), Number(entry[2]));
    }
  }
  return widths;
}

// 内容ストリームの Tj を、Tm の位置と /W の幅から 1 文字ずつ置き直す。
// 返すのは、PDF が実際に置く位置 (pt) と、その文字。
function glyphPositions(pdf) {
  const page = readPage(pdf);
  const widths = readWidths(pdf);
  const out = [];
  let size = 0;
  let tz = 100;
  let x = 0;
  let y = 0;
  let cmap = new Map();
  for (const line of page.content.split("\n")) {
    let match = /^\/(F\d+) ([\d.]+) Tf$/.exec(line);
    if (match !== null) {
      size = Number(match[2]);
      cmap = page.cmaps.get(page.names.get(match[1])) ?? new Map();
      continue;
    }
    match = /^([\d.]+) Tz$/.exec(line);
    if (match !== null) {
      tz = Number(match[1]);
      continue;
    }
    match = /^1 0 0 -1 ([\d.-]+) ([\d.-]+) Tm$/.exec(line);
    if (match !== null) {
      x = Number(match[1]);
      y = Number(match[2]);
      continue;
    }
    match = /^<([0-9a-fA-F]+)> Tj$/.exec(line);
    if (match === null) continue;
    let at = x;
    for (let i = 0; i + 4 <= match[1].length; i += 4) {
      const cid = parseInt(match[1].slice(i, i + 4), 16);
      const width = widths.get(cid) ?? 1000;
      out.push({char: cmap.get(cid) ?? "\uFFFD", x: at, y, tz});
      at += (width / 1000) * size * (tz / 100);
    }
  }
  return out;
}

// 罫線の文字が置かれた x (pt)。
function rulePositions(pdf) {
  return glyphPositions(pdf)
    .filter((glyph) => glyph.char === "│")
    .map((glyph) => round(glyph.x));
}

const round = (value) => Math.round(value * 10) / 10;

// 1. 升目の既定: cpi 10、左余白 2 升。罫線は 2 升目と 5 升目の頭に来る。
{
  const template = `---\ncpi: 10\nmargin.left: 2\n---\nii│WW│\nWW│ii│\n日本│語 A│\n{{name}}\n`;
  const result = exportPdf(fill(template, {name: "x"}), mono);
  const page = readPage(result.pdf);
  const rows = placements(page);
  const text = decodeText(page);
  check("grid: one page", result.pages === 1, result.pages);
  check("grid: no warnings", result.warnings.length === 0, JSON.stringify(result.warnings));
  check(
    "grid: the text keeps its Japanese and its rules",
    text.includes("ii│WW│") && text.includes("日本│語 A│"),
    JSON.stringify(text),
  );
  check(
    "grid: every line starts on the left margin",
    rows.length === 4 && rows.every((row) => round(row.x) === 14.4),
    JSON.stringify(rows),
  );
  check(
    "grid: a monospace run takes one scale",
    rows.every((row) => Math.abs(row.tz - 120) < 0.01),
    JSON.stringify(rows.map((row) => row.tz)),
  );
  // 罫線の位置は、PDF が置いた字形の位置から出す (升目は 72/10 = 7.2 pt)。
  const rules = rulePositions(result.pdf);
  check(
    "grid: the rules of ii│WW│ and WW│ii│ land on 28.8 and 50.4",
    JSON.stringify(rules.slice(0, 4)) ===
      JSON.stringify([28.8, 50.4, 28.8, 50.4]),
    JSON.stringify(rules),
  );
  check(
    "grid: the rules of 日本│語 A│ land on 43.2 and 79.2",
    JSON.stringify(rules.slice(4)) === JSON.stringify([43.2, 79.2]),
    JSON.stringify(rules),
  );
}

// 2. ambiguous: wide では罫線が 2 升。文字ごとに升目が変わるので、走りは分かれる。
{
  const template = `---\ncpi: 10\nmargin.left: 2\nambiguous: wide\n---\nii│WW│\n`;
  const result = exportPdf(fill(template, {}), mono);
  const rows = placements(readPage(result.pdf));
  check(
    "grid: ambiguous wide puts each character on its own cells",
    JSON.stringify(rows.map((row) => round(row.x))) ===
      JSON.stringify([14.4, 28.8, 43.2, 57.6]),
    JSON.stringify(rows),
  );
  check(
    "grid: ambiguous wide scales the rules by two cells",
    JSON.stringify(rows.map((row) => Math.round(row.tz))) ===
      JSON.stringify([120, 240, 120, 240]),
    JSON.stringify(rows.map((row) => row.tz)),
  );
  check(
    "grid: ambiguous wide puts the rules on 28.8 and 57.6",
    JSON.stringify(rulePositions(result.pdf)) === JSON.stringify([28.8, 57.6]),
    JSON.stringify(rulePositions(result.pdf)),
  );
}

// 3. 高い行 (cpi 20 / lpi 6) の倍率は 0.5 を下回る。1 に戻してはいけない。
{
  const template = `---\ncpi: 20\nlpi: 6\nmargin.left: 2\n---\n{{#_tall}}ii│WW│{{/_tall}}\n`;
  const result = exportPdf(fill(template, {}), mono);
  const rows = placements(readPage(result.pdf));
  check(
    "grid: a tall line at cpi 20 keeps its 0.3 scale",
    rows.length > 0 && Math.abs(rows[0].tz - 30) < 0.5,
    JSON.stringify(rows),
  );
  check(
    "grid: a tall line at cpi 20 puts the rules on 14.4 and 25.2",
    JSON.stringify(rulePositions(result.pdf)) === JSON.stringify([14.4, 25.2]),
    JSON.stringify(rulePositions(result.pdf)),
  );
}

// 4. 本文と preprinted、空白、大きい行。
{
  const template = `---\ncpi: 10\nmargin.left: 2\n---\nA B C\n{{#_big}}ii│WW│{{/_big}}\n{{#preprinted}}PAPER│X{{/preprinted}}\n`;
  const result = exportPdf(fill(template, {}), mono);
  const page = readPage(result.pdf);
  const text = decodeText(page);
  check(
    "grid: body, big and preprinted lines all keep their text",
    text.includes("A B C") && text.includes("ii│WW│") && text.includes("PAPER│X"),
    JSON.stringify(text),
  );
  check("grid: the spaces of a run stay in the string", text.includes("A B C"));
}

// 5. 字形の無い文字は、黙って別の字にせず警告にする。
{
  const template = `---\ncpi: 10\n---\n☃\n`;
  const result = exportPdf(fill(template, {}), mono);
  const warned = result.warnings.some((warning) =>
    warning.includes("no glyph for"),
  );
  check(
    "font: a character the fallback font lacks is a warning",
    warned,
    JSON.stringify(result.warnings),
  );
}

// 6. 埋め込みを許さないフォントは埋め込まず、警告を残す。
{
  const restricted = await readFile(resolve(root, "compat/font/fixtures/restricted.ttf"));
  const template = `---\ncpi: 10\n---\nii│WW│\n`;
  const result = exportPdf(fill(template, {}), restricted);
  const warned = result.warnings.some((warning) =>
    warning.includes("does not allow embedding"),
  );
  check(
    "font: a font whose license forbids embedding is not embedded",
    warned,
    JSON.stringify(result.warnings),
  );
  check(
    "font: the PDF carries no program of that font",
    !result.pdf.toString("latin1").includes("/FontFile2"),
  );
}

// 7. Office のテンプレート (字幅が自由な文) も日本語を保つ。
{
  const template = await readFile(resolve(samples, "form-fixed.docx"));
  const data = JSON.parse(await readFile(resolve(samples, "form-fixed.json"), "utf8"));
  const result = exportPdf(fill(template, data), proportional);
  const text = decodeText(readPage(result.pdf)).join("\n");
  check(
    "office: the Japanese of a document survives",
    text.includes("明細書") && text.includes("宛先"),
    JSON.stringify(text.slice(0, 200)),
  );
  check(
    "office: the numbers and the Latin text survive",
    text.includes("No. 1024") && text.includes("BDF STUDIO"),
    JSON.stringify(text.slice(0, 200)),
  );
}

// 8. テキストの見本 (text-slip) も、罫線と日本語を保つ。
{
  const template = await readFile(resolve(samples, "text-slip.txt"), "utf8");
  const data = JSON.parse(
    await readFile(resolve(samples, "text-slip.data.json"), "utf8"),
  );
  const result = exportPdf(fill(template, data), mono);
  const text = decodeText(readPage(result.pdf)).join("\n");
  check(
    "text: the slip keeps its title and its rules",
    text.includes("納品書") && text.includes("┌") && text.includes("│"),
    JSON.stringify(text.slice(0, 200)),
  );
  check(
    "text: the slip keeps the names of the customer",
    text.includes("株式会社サンプル商事"),
    JSON.stringify(text.slice(0, 200)),
  );
}

// 9. 補助面の文字 (UTF-16 で 2 単位) があっても、升目のままに置く。
{
  const template = `---\ncpi: 10\nmargin.left: 2\n---\nA\u{20BB7}B\n`;
  const result = exportPdf(fill(template, {}), mono);
  const page = readPage(result.pdf);
  const rows = placements(page);
  const text = decodeText(page);
  check(
    "grid: a supplementary character keeps the cells of the run",
    rows.length === 1 && round(rows[0].x) === 14.4,
    JSON.stringify(rows),
  );
  check(
    "grid: a supplementary character does not turn the cells off",
    rows.length === 1 && Math.abs(rows[0].tz - 120) < 0.01,
    JSON.stringify(rows.map((row) => row.tz)),
  );
  check(
    "grid: the supplementary character is drawn",
    text.join("") === "A\u{20BB7}B",
    JSON.stringify(text),
  );
  check(
    "grid: the supplementary character needs no warning",
    result.warnings.length === 0,
    JSON.stringify(result.warnings),
  );
}

// 10. 字形の無い文字のあとの文字は、前の字の送りに引きずられない。
{
  const template = `---\ncpi: 10\nmargin.left: 2\n---\nA\u2603B\n`;
  const result = exportPdf(fill(template, {}), mono);
  const page = readPage(result.pdf);
  const rows = placements(page);
  const text = decodeText(page);
  check(
    "grid: a missing glyph does not shift the characters after it",
    rows.length === 2 &&
      round(rows[0].x) === 14.4 &&
      round(rows[1].x) === 28.8,
    JSON.stringify(rows),
  );
  check(
    "grid: the characters after a missing glyph keep their scale",
    rows.length === 2 && rows.every((row) => Math.abs(row.tz - 120) < 0.01),
    JSON.stringify(rows.map((row) => row.tz)),
  );
  check(
    "grid: the missing glyph is left out, not drawn as another",
    text.join("") === "AB",
    JSON.stringify(text),
  );
}

console.log(
  (failed === 0 ? "ALL PASS" : failed + " FAILED") +
    " (" +
    passed +
    " passed, " +
    failed +
    " failed)",
);
process.exit(failed === 0 ? 0 : 1);
