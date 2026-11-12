// The public PDF export entry of the library package, shipped as
// `dist/pdf/index.js` and exposed as `bdf.mbt/pdf`. It wraps the compiled
// MoonBit bridge `bdf_pdf_export` (staged beside it as `dist/pdf/pdf_js.js`)
// with the typed promise contract: BDF bytes and an explicit fallback font
// in, PDF bytes, the page count, the count of embedded fonts and the
// writer's warnings out. Saving the result — a browser Blob download or a
// Node file write — is the caller's job.
//
// The conversion itself runs synchronously in the calling thread (the
// MoonBit bridge is synchronous); the promise around it resolves right
// after the call returns. Rejections distinguish a wrong argument type
// from a document failure: check `error.message`. This file is a packaging
// input, not source-tree importable: its import resolves inside the staged
// `dist/` tree.

import { bdf_pdf_export } from "./pdf_js.js";

const EMPTY_BYTES = new Uint8Array(0);

/**
 * Options of `exportPdf`, the JavaScript shapes of the writer's options.
 * Every field is optional; the defaults are the writer's own.
 *
 * @typedef {object} PdfExportOptions
 * @property {string[]} [views] The ids of the document views to write; an
 *   empty or absent list writes every view. A view the document does not
 *   have rejects.
 * @property {boolean} [tagged] Ask for a tagged PDF structure; the writer
 *   does not write one yet, and the result warns about it.
 * @property {boolean} [compress] Ask for compressed content streams; the
 *   current writer writes them uncompressed, and the option is reserved.
 * @property {Uint8Array} [fallbackFont] The TrueType or OpenType program
 *   whose subset the writer embeds for the text that the document carries
 *   no font of, such as the text of a form fill. Japanese needs one.
 */

/**
 * The result of `exportPdf`.
 *
 * @typedef {object} PdfExportResult
 * @property {Uint8Array} bytes The written PDF.
 * @property {number} pages The count of PDF pages.
 * @property {number} fonts The count of embedded fonts.
 * @property {string[]} warnings What the writer could not reproduce:
 *   omitted images, shadows and filters, approximated gradients, an
 *   unreadable or missing-glyph fallback font, an unimplemented tagged
 *   structure. A result with warnings is not a faithful reproduction.
 */

/** @type {(input: Uint8Array, optionType: string) => void} */
function expectUint8Array(input, optionType) {
  if (!(input instanceof Uint8Array)) {
    throw new TypeError(
      `exportPdf expects ${optionType === "input" ? "a Uint8Array of BDF bytes" : `a Uint8Array as ${optionType}`}, got ${
        input === null ? "null" : typeof input
      }`,
    );
  }
}

/**
 * Write BDF bytes as PDF.
 *
 * @param {Uint8Array} input The single-file BDF document. It is only read:
 *   the buffer is never modified or detached.
 * @param {PdfExportOptions} [options] The writer's options; see
 *   `PdfExportOptions`.
 * @returns {Promise<PdfExportResult>} The PDF bytes and the report. Rejects
 *   when the input or an option has the wrong type, when the BDF cannot be
 *   read, when a requested view does not exist, or when the selected views
 *   hold no page — never with an empty PDF as a success.
 */
export async function exportPdf(input, options = {}) {
  expectUint8Array(input, "input");
  if (options === null || typeof options !== "object" || Array.isArray(options)) {
    throw new TypeError("exportPdf expects an options object");
  }
  let views = [];
  if (options.views !== undefined) {
    if (!Array.isArray(options.views)) {
      throw new TypeError("the views option is an array of view ids");
    }
    for (const view of options.views) {
      if (typeof view !== "string") {
        throw new TypeError("the views option is an array of view ids");
      }
      views.push(view);
    }
  }
  for (const flag of ["tagged", "compress"]) {
    if (options[flag] !== undefined && typeof options[flag] !== "boolean") {
      throw new TypeError(`the ${flag} option is a boolean`);
    }
  }
  const fallbackFont = options.fallbackFont ?? EMPTY_BYTES;
  if (fallbackFont.length > 0) {
    expectUint8Array(fallbackFont, "fallbackFont");
  }
  const bridgeOptions = JSON.stringify({
    views,
    tagged: options.tagged === true,
    compress: options.compress === true,
  });
  let report;
  try {
    report = bdf_pdf_export(input, bridgeOptions, fallbackFont);
  } catch (error) {
    throw new Error(`the PDF export failed: ${error.message ?? error}`);
  }
  if (!report || typeof report !== "object") {
    throw new Error("the PDF export failed: the bridge returned no report");
  }
  if (report.ok !== true) {
    throw new Error(report.error || "the PDF export failed");
  }
  if (typeof report.pages !== "number" || report.pages < 1) {
    throw new Error("the PDF export failed: the selected views hold no page");
  }
  if (!(report.pdf instanceof Uint8Array)) {
    throw new Error("the PDF export failed: no PDF bytes were returned");
  }
  return {
    bytes: report.pdf,
    pages: report.pages,
    fonts: report.fonts,
    warnings: [...report.warnings],
  };
}

