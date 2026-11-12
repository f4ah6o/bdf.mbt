// Type declarations for the public PDF export entry `bdf.mbt/pdf`
// (plugin/library/pdf.mjs, shipped as dist/pdf/index.js).

/** The writer's options, as JavaScript values. */
export declare interface PdfExportOptions {
  /**
   * The ids of the document views to write. An absent or empty list writes
   * every view. A view the document does not have rejects the call.
   */
  views?: string[];
  /**
   * Ask for a tagged PDF structure. The writer does not write one yet, and
   * the result warns that it does not.
   */
  tagged?: boolean;
  /**
   * Ask for compressed content streams. The current writer writes
   * uncompressed streams; the option is reserved.
   */
  compress?: boolean;
  /**
   * The fallback font program (TrueType or OpenType, Uint8Array bytes)
   * whose subset the writer embeds for the text that the document carries
   * no font of — the text of a form fill, and any Japanese. Without one,
   * that text is drawn with the PDF standard font as "?" and the result
   * warns about exactly which characters were replaced.
   */
  fallbackFont?: Uint8Array;
}

/** The result of a successful export. */
export declare interface PdfExportResult {
  /** The written PDF. */
  bytes: Uint8Array;
  /** The count of PDF pages. */
  pages: number;
  /** The count of fonts used; the PDF standard font counts too, though no program of it is embedded. */
  fonts: number;
  /**
   * What the writer could not reproduce: omitted images, cropped images,
   * shadows, filters, approximated gradients, an unreadable or
   * missing-glyph fallback font, an unimplemented tagged structure,
   * page-less views. A result with warnings is not a faithful
   * reproduction — surface them to the user.
   */
  warnings: string[];
}

/**
 * Write BDF bytes as PDF. The input is only read: its buffer is never
 * modified or detached. Downloading or saving the bytes is the caller's
 * job.
 *
 * Rejects (never resolves with an empty PDF as a success) when the input or
 * an option has the wrong type, when the BDF document cannot be read, when
 * a requested view does not exist, or when the selected views hold no
 * page.
 *
 * The conversion runs synchronously in the calling thread; the returned
 * promise resolves right after the call returns.
 */
export declare function exportPdf(
  input: Uint8Array,
  options?: PdfExportOptions,
): Promise<PdfExportResult>;
