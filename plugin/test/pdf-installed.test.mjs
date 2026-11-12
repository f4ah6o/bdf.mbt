// Tests the shipped public PDF export entry `bdf.mbt/pdf` (dist/pdf) of the
// tarball-installed copy of the main library package, exactly as a consumer
// imports it: the same BDF bytes the shipped `bdf.mbt/forms` entry produces,
// written to a PDF through the public `exportPdf(input, options)` contract.
// The fallback fonts read below are the repository's own OFL-licensed test
// fonts (site/form/fonts): a consumer is expected to pass a font they
// have the rights to use, and the package never fetches one.
//
// Enabled by pointing BDF_LIBRARY_INSTALLED at the installed package
// directory (see plugin/tools/library-smoke.mjs); without it the tests
// skip so the plain unit suite never depends on packing.

import assert from "node:assert/strict";
import { test } from "node:test";
import { spawnSync } from "node:child_process";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const installed = process.env.BDF_LIBRARY_INSTALLED;
const name = process.env.BDF_LIBRARY_STAGING_NAME ?? "bdf.mbt";

if (!installed) {
  test("installed PDF export entry smoke (skipped: no BDF_LIBRARY_INSTALLED)", { skip: true }, () => {});
} else {
  const { exportPdf } = await import(`${installed}/dist/pdf/index.js`);
  const form = await import(`${installed}/dist/form/form_page.js`);
  const proportional = new Uint8Array(
    await readFile(resolve(root, "site/form/fonts/MPLUS1p-Regular.ttf")),
  );
  const mono = new Uint8Array(
    await readFile(resolve(root, "site/form/fonts/MPLUS1Code-Regular.ttf")),
  );

  ///|
  async function fill(sample, data) {
    const template = new Uint8Array(
      await readFile(resolve(root, "site/form/samples", sample)),
    );
    const values = await readFile(resolve(root, "site/form/samples", data), "utf8");
    const filled = JSON.parse(form.bdf_form_fill(template, values, "[]", false));
    assert.equal(filled.ok, true, filled.error);
    return { template, values, bdf: Buffer.from(filled.bdf, "base64"), filled };
  }

  // The PDF objects, cut per /Length, the ToUnicode CMaps and the content
  // streams: enough of the PDF's own structure to read back what the
  // writer drew, without a PDF library.
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
        objects.set(Number(match[1]), { dict: head, data: buf.subarray(data, data + size) });
        const after = text.indexOf("endobj", data + size);
        at = after < 0 ? text.length : after + 6;
      } else {
        objects.set(Number(match[1]), { dict: text.slice(body, end < 0 ? text.length : end), data: null });
        at = end < 0 ? text.length : end + 6;
      }
    }
    return objects;
  }

  function parseCMap(data) {
    const text = data.toString("latin1");
    const map = new Map();
    const hex = value => parseInt(value, 16);
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
    return map;
  }

  function decodePages(buf) {
    const objects = parseObjects(buf);
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
      for (const entry of object.dict.matchAll(/\/(F\d+)\s+(\d+) 0 R/g)) {
        names.set(entry[1], Number(entry[2]));
      }
    }
    let out = "";
    for (const object of objects.values()) {
      const contents = /\/Contents\s+(\d+) 0 R/.exec(object.dict);
      if (contents === null) continue;
      const stream = objects.get(Number(contents[1]));
      if (stream === undefined || stream.data === null) continue;
      let cmap = new Map();
      for (const line of stream.data.toString("latin1").split("\n")) {
        const font = /^\/(F\d+) [\d.]+ Tf$/.exec(line);
        if (font !== null) {
          cmap = cmaps.get(names.get(font[1])) ?? new Map();
          continue;
        }
        const show = /^<([0-9a-fA-F]+)> Tj$/.exec(line);
        if (show === null) continue;
        for (let i = 0; i + 4 <= show[1].length; i += 4) {
          out += cmap.get(parseInt(show[1].slice(i, i + 4), 16)) ?? "";
        }
      }
    }
    return out;
  }

  test("the shipped PDF entry resolves through the export map and exports exportPdf", () => {
    // Run where the installed package lives, exactly as a consumer would:
    // the exports map is the resolution gate, `bdf.mbt/pdf` the public path.
    const consumerDir = resolve(installed, "..", "..");
    const probe = `
      const m = await import(${JSON.stringify(`${name}/pdf`)});
      if (typeof m.exportPdf !== "function") throw new Error("exportPdf is not a function");
      if (Object.keys(m).sort().join(",") !== "exportPdf") throw new Error("unexpected exports: " + Object.keys(m));
      console.log("ok");
    `;
    const run = spawnSync("node", ["--input-type=module", "-e", probe], {
      cwd: consumerDir,
      encoding: "utf8",
    });
    assert.equal(run.status, 0, `resolution probe failed:\n${run.stdout}\n${run.stderr}`);
    assert.match(run.stdout, /ok/);
    assert.equal(typeof exportPdf, "function");
  });

  test("exportPdf writes the multi-page office form with its Japanese and an embedded font", async () => {
    const { bdf, filled } = await fill("form-pages.docx", "form-pages.json");
    assert.ok(filled.pages >= 2, `expected the form-pages sample to hold pages, got ${filled.pages}`);
    const input = new Uint8Array(bdf);
    const inputSnapshot = Buffer.from(input);
    const fontSnapshot = Buffer.from(proportional);
    const result = await exportPdf(input, { fallbackFont: proportional });
    assert.ok(result.bytes instanceof Uint8Array);
    const pdf = Buffer.from(result.bytes);
    const latin = pdf.toString("latin1");
    assert.ok(latin.startsWith("%PDF-"), "expected a PDF header");
    assert.ok(latin.includes("%%EOF"), "expected an EOF marker");
    assert.equal(result.pages, filled.pages);
    assert.ok(result.fonts >= 2, "expected the standard font and the embedded fallback subset");
    assert.ok(latin.includes("/FontFile2"), "expected the fallback subset embedded as a font file");
    assert.ok(Array.isArray(result.warnings));
    for (const warning of result.warnings) {
      assert.ok(!/no glyph for/.test(warning), `unexpected glyph loss: ${warning}`);
    }
    // the expected Japanese survives in the extracted text of the pages
    const text = decodePages(pdf);
    for (const part of ["株式会社みなと商事", "ノート A5", "デスクトレー"]) {
      assert.ok(text.includes(part), `expected "${part}" in the extracted text`);
    }
    // the buffers actually handed to the export are unchanged by it
    assert.ok(Buffer.from(input).equals(inputSnapshot), "the input bytes were modified");
    assert.equal(input.byteLength, inputSnapshot.byteLength, "the input buffer was detached or resized");
    assert.ok(Buffer.from(proportional).equals(fontSnapshot), "the fallback font bytes were modified");
    assert.equal(proportional.byteLength, fontSnapshot.byteLength, "the fallback font buffer was detached or resized");
  });

  test("exportPdf writes the text grid form with its rules and without changing the input", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const input = new Uint8Array(bdf);
    const before = Buffer.from(input);          // the buffer actually handed over
    const fontBefore = Buffer.from(mono);
    const result = await exportPdf(input, { fallbackFont: mono });
    assert.equal(result.pages, 1);
    assert.ok(result.warnings.length === 0, JSON.stringify(result.warnings));
    const text = decodePages(Buffer.from(result.bytes));
    for (const part of ["サンプル珈琲店", "ブレンドコーヒー", "チーズケーキ"]) {
      assert.ok(text.includes(part), `expected "${part}" in the extracted text`);
    }
    assert.ok(Buffer.from(input).equals(before), "the input bytes were modified");
    assert.ok(Buffer.from(mono).equals(fontBefore), "the fallback font bytes were modified");
  });

  test("exportPdf is deterministic and returns fresh bytes per call", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const first = await exportPdf(new Uint8Array(bdf), { fallbackFont: mono });
    const second = await exportPdf(new Uint8Array(bdf), { fallbackFont: mono });
    assert.ok(Buffer.compare(Buffer.from(first.bytes), Buffer.from(second.bytes)) === 0);
    assert.deepEqual(second.warnings, first.warnings);
    assert.equal(second.pages, first.pages);
  });

  test("exportPdf warns about the characters a missing fallback font draws as ?", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const result = await exportPdf(new Uint8Array(bdf), {});
    assert.equal(result.pages, 1);
    const prefix = "text without a font of its own is drawn with the PDF standard font";
    const warned = result.warnings.find(warning => warning.startsWith(prefix));
    assert.ok(warned, JSON.stringify(result.warnings));
    assert.ok(
      warned.length > prefix.length && warned.includes("no glyph for: "),
      `expected the warned characters to be listed: ${warned}`,
    );
    assert.equal(result.fonts, 1, `expected only the standard font to embed, got ${result.fonts}`);
  });

  test("exportPdf warns about an unreadable fallback font instead of failing", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const result = await exportPdf(new Uint8Array(bdf), { fallbackFont: new Uint8Array(64) });
    assert.equal(result.pages, 1);
    assert.ok(result.warnings.some(warning => /the fallback font could not be read/.test(warning)),
      JSON.stringify(result.warnings));
  });

  test("exportPdf reports the tagged limitation as a warning", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const result = await exportPdf(new Uint8Array(bdf), { fallbackFont: mono, tagged: true });
    assert.ok(result.warnings.includes("tagged PDF structure is not written yet"),
      JSON.stringify(result.warnings));
  });

  test("exportPdf accepts the reserved compress option", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const result = await exportPdf(new Uint8Array(bdf), { fallbackFont: mono, compress: true });
    assert.equal(result.pages, 1);
    assert.ok(result.bytes instanceof Uint8Array);
  });

  test("exportPdf rejects wrong argument types", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    const input = new Uint8Array(bdf);
    await assert.rejects(exportPdf("not bytes"), /Uint8Array/);
    await assert.rejects(exportPdf(null), /Uint8Array/);
    await assert.rejects(exportPdf(input, "options"), /options object/);
    await assert.rejects(exportPdf(input, { views: "receipt" }), /array of view ids/);
    await assert.rejects(exportPdf(input, { views: [1] }), /array of view ids/);
    await assert.rejects(exportPdf(input, { tagged: 1 }), /tagged option is a boolean/);
    await assert.rejects(exportPdf(input, { compress: "yes" }), /compress option is a boolean/);
    await assert.rejects(exportPdf(input, { fallbackFont: "font" }), /Uint8Array/);
    // an empty string or an empty object is not "no font": only the absence
    // of the field is, so both must reject instead of silently passing
    await assert.rejects(exportPdf(input, { fallbackFont: "" }), /Uint8Array/);
    await assert.rejects(exportPdf(input, { fallbackFont: {} }), /Uint8Array/);
    await assert.rejects(exportPdf(input, { fallbackFont: 0 }), /Uint8Array/);
    // an explicit null is a supplied value too: it must reject, not default
    await assert.rejects(exportPdf(input, { fallbackFont: null }), /Uint8Array/);
    await assert.rejects(exportPdf(input, { fallbackFont: [] }), /Uint8Array/);
  });

  test("exportPdf rejects broken BDF bytes", async () => {
    await assert.rejects(
      exportPdf(new Uint8Array(64), {}),
      /the BDF document could not be read/,
    );
    await assert.rejects(exportPdf(new Uint8Array(0), {}), /the BDF document is empty/);
  });

  test("exportPdf rejects a view the document does not have", async () => {
    const { bdf } = await fill("text-receipt.txt", "text-receipt.data.json");
    await assert.rejects(
      exportPdf(new Uint8Array(bdf), { views: ["no-such-view"] }),
      /the document has no view named "no-such-view"/,
    );
  });

  test("exportPdf writes only the requested views of a multi-view document", async () => {
    const { BdfDocument, BufferSource } = await import("@bdfkit/core");
    const { bdf } = await fill("form-pages.docx", "form-pages.json");
    const document = await BdfDocument.open(new BufferSource(bdf));
    const counts = document.manifest.views.map(view => {
      assert.equal(typeof view.id, "string");
      return { id: view.id, pages: view.pages?.length ?? 0 };
    });
    assert.ok(counts.length >= 2, `expected a multi-view sample, got ${JSON.stringify(counts)}`);
    const [first, second] = counts;
    const every = await exportPdf(new Uint8Array(bdf), { fallbackFont: proportional });
    assert.equal(every.pages, counts.reduce((sum, view) => sum + view.pages, 0));
    const onlyFirst = await exportPdf(new Uint8Array(bdf), {
      views: [first.id],
      fallbackFont: proportional,
    });
    assert.equal(onlyFirst.pages, first.pages, `expected only view ${first.id}`);
    assert.ok(Buffer.from(onlyFirst.bytes).toString("latin1").startsWith("%PDF-"));
    const onlySecond = await exportPdf(new Uint8Array(bdf), {
      views: [second.id, first.id],
      fallbackFont: proportional,
    });
    assert.equal(onlySecond.pages, second.pages + first.pages, "the view order must not matter");
  });

  test("exportPdf rejects a sheet-only document instead of an empty PDF", async () => {
    const { BdfDocument, BufferSource } = await import("@bdfkit/core");
    const { bdf, filled } = await fill("form-fixed.xlsx", "form-fixed.json");
    // the office form fill that produced it holds only a sheet view: no view
    // has a page, and the export must say so instead of writing an empty PDF
    const document = await BdfDocument.open(new BufferSource(bdf));
    assert.ok(document.manifest.views.length >= 1, "expected the fill to have a view");
    assert.equal(document.manifest.views.every(view => (view.pages?.length ?? 0) === 0), true,
      `expected a sheet-only sample, got ${JSON.stringify(document.manifest.views.map(view => view.id))}`);
    assert.equal(filled.views.length, 1);
    await assert.rejects(
      exportPdf(new Uint8Array(bdf), { fallbackFont: proportional }),
      /the selected views hold no page/,
    );
    await assert.rejects(
      exportPdf(new Uint8Array(bdf), { views: [document.manifest.views[0].id] }),
      /the selected views hold no page/,
    );
  });
}
