// Shared type declarations for the diagram-to-BDF encoder used by the
// Excalidraw and Mermaid format plugins (plugin/src/diagram-bdf.js).

export interface DiagramColor {
  /** 0..255 */
  r: number;
  /** 0..255 */
  g: number;
  /** 0..255 */
  b: number;
  /** 0..255 */
  a: number;
}

export interface DiagramShapeStyle {
  fill?: DiagramColor | null;
  stroke?: DiagramColor | null;
  /** positive stroke width in pt, at most 10000; default 2 */
  strokeWidth?: number;
  /** dash segments in pt (each 0..100000); null/undefined means solid */
  dash?: number[] | null;
  /** 0..1; default 1 */
  opacity?: number;
  /** radians within +/-1e6, rotation about pivot (or the shape's own center); default 0 */
  angle?: number;
  /**
   * Rotation pivot [x, y]. When absent, shapes rotate about their own
   * center and text about its anchor (x, y). Decomposed elements
   * (an arrow shaft and its head, multi-line text) pass the ORIGINAL
   * element pivot so all parts stay attached under rotation.
   */
  pivot?: [number, number] | null;
}

export interface RectPrimitive extends DiagramShapeStyle {
  kind: "rect";
  x: number;
  y: number;
  w: number;
  h: number;
  /** corner radius; a rounded rect is emitted as a roundRect path */
  rounded?: number;
}

export interface EllipsePrimitive extends DiagramShapeStyle {
  kind: "ellipse";
  cx: number;
  cy: number;
  rx: number;
  ry: number;
}

export interface PolygonPrimitive extends DiagramShapeStyle {
  kind: "polygon";
  /** 3 or more [x, y] pairs; the ring is closed */
  points: Array<[number, number]>;
}

export interface PolylinePrimitive extends DiagramShapeStyle {
  kind: "polyline";
  /** 2 or more [x, y] pairs; the chain is open; fill is ignored */
  points: Array<[number, number]>;
}

export type TextAlign = "left" | "right" | "center" | "start" | "end";
export type TextBaseline = "alphabetic" | "top" | "middle" | "bottom" | "hanging" | "ideographic";
export type FontStyle = "normal" | "italic" | "oblique";

export interface TextPrimitive {
  kind: "text";
  x: number;
  y: number;
  text: string;
  /** positive size in pt */
  fontSize: number;
  /** system font family; default "Helvetica" */
  family?: string;
  /** 100..900; default 400 */
  weight?: number;
  style?: FontStyle;
  align?: TextAlign;
  baseline?: TextBaseline;
  fill?: DiagramColor | null;
  opacity?: number;
  /**
   * Explicit advance estimate in pt (0..1e7), overriding the default
   * 0.6em-per-codepoint estimate. Pass a CJK-aware estimate for labels
   * with wide characters; it drives the recorded op advance and the
   * text extent used for page fitting and the object bounding box.
   */
  advance?: number;
  /** radians around the pivot (default: the text anchor x, y); default 0 */
  angle?: number;
  /** rotation pivot; see DiagramShapeStyle.pivot */
  pivot?: [number, number] | null;
}

/**
 * A drawn rectangle of an embedded raster resource. `image` names an
 * entry of EncodeDiagramDocumentInput.images; fill/stroke/dash/strokeWidth
 * are not accepted (rejected, not ignored), and both w and h must be
 * positive (the underlying canvas image op does not mirror nonpositive
 * rectangles, so they are rejected instead of silently drawing nothing).
 */
export interface ImagePrimitive {
  kind: "image";
  /** the id of an images entry of the document input */
  image: string;
  x: number;
  y: number;
  /** positive width in pt */
  w: number;
  /** positive height in pt */
  h: number;
  /** 0..1 of the BDF alpha op */
  opacity?: number;
  /** radians around the pivot (default: the rectangle's center); default 0 */
  angle?: number;
  /** rotation pivot; see DiagramShapeStyle.pivot */
  pivot?: [number, number] | null;
}

/**
 * The vector primitives `encodeDiagram` accepts (its single-diagram API
 * predates image primitives and keeps rejecting them with
 * `unknown primitive kind "image"`).
 */
export type DiagramPrimitive =
  | RectPrimitive
  | EllipsePrimitive
  | PolygonPrimitive
  | PolylinePrimitive
  | TextPrimitive;

/** The primitives a page of {@link encodeDiagramDocument} accepts. */
export type DiagramDocumentPrimitive =
  | DiagramPrimitive
  | ImagePrimitive;

export interface EncodeDiagramInput {
  /** page width in pt, 0 < width <= 16777216 */
  width: number;
  /** page height in pt, 0 < height <= 16777216 */
  height: number;
  /** lowercase format identifier, becomes the manifest generator */
  source: string;
  /** view title; default "" */
  title?: string;
  /** z order: later entries draw on top; at most 20000 */
  primitives: DiagramPrimitive[];
}

/** Complete single-file BDF bytes: header, manifest, one object part. */
export type BdfBytes = Uint8Array;

export function encodeDiagram(input: EncodeDiagramInput): Promise<BdfBytes>;

/**
 * An embedded raster resource of a multi-page document: actual PNG or JPEG
 * bytes, structurally complete inside the supplied bytes (PNG chunk table
 * with IHDR/IDAT/IEND all in range; JPEG segments with a frame header, a
 * start of scan, entropy data and a closing EOI; GIFs, BMPs, WebP, SVG,
 * URLs, paths and strings are rejected, never fetched or read), keyed by
 * a short id that image primitives reference.
 */
export interface DiagramImageResource {
  /** 1..128 characters; unique within the document */
  id: string;
  /** PNG or JPEG bytes; at most 4 MiB (16384 px per side, 2^24 pixels) */
  data: Uint8Array | ArrayBuffer;
}

/** One page of a multi-page diagram document. */
export interface DiagramDocumentPage {
  /** page width in pt, 0 < width <= 16777216 */
  width: number;
  /** page height in pt, 0 < height <= 16777216 */
  height: number;
  /**
   * z order within the page: later entries draw on top.
   * At most 20000 per page, 100000 document-wide.
   */
  primitives: DiagramDocumentPrimitive[];
}

export interface EncodeDiagramDocumentInput {
  /** lowercase format identifier, becomes the manifest generator */
  source: string;
  /** view title; default "" */
  title?: string;
  /** 1..256 pages, each with its own size; at most 100000 primitives document-wide */
  pages: DiagramDocumentPage[];
  /**
   * Optional embedded raster resources. Every resource must be referenced
   * by at least one page and every image primitive reference must resolve:
   * reference integrity holds both ways, and identical bytes are stored once.
   * At most 256 resources and 32 MiB of unique image bytes per document.
   */
  images?: DiagramImageResource[];
}

/**
 * Complete single-file BDF bytes of a multi-page diagram document: header,
 * identity JSON manifest (one fixed view, one page per input page), one obj
 * part per page and one img part per unique embedded image, parts stored
 * after the manifest with offsets relative to its end. Deterministic, and
 * the input is treated as read-only.
 */
export function encodeDiagramDocument(input: EncodeDiagramDocumentInput): Promise<BdfBytes>;

/** "invalid-input" for malformed value shapes, "too-large" past the limits. */
export type DiagramErrorCode = "invalid-input" | "too-large";

export class DiagramEncodeError extends Error {
  constructor(message?: string, code?: DiagramErrorCode);
  code: DiagramErrorCode;
}

/**
 * The miter limit every emitted line() op carries (10): joins that exceed
 * it render beveled, so miter extent bounds clamp at strokeJoinProtrusion.
 */
export const MITER_LIMIT: number;

/** Miter protrusion of a join at vertex `at` between `prev` and `next`. */
export function strokeJoinProtrusion(prev: [number, number], at: [number, number], next: [number, number], strokeWidth: number): number;

/** The reader-side page-size cap of the BDF manifest (1 << 24 units). */
export const BDF_MAX_PAGE_UNITS: number;
/** The per-document primitive cap encoded by {@link encodeDiagram}. */
export const MAX_PRIMITIVES: number;
/** The page cap of {@link encodeDiagramDocument}. */
export const MAX_PAGES: number;
/** The document-wide primitive cap of {@link encodeDiagramDocument}. */
export const MAX_DOCUMENT_PRIMITIVES: number;
/** The embedded-image resource count cap of {@link encodeDiagramDocument}. */
export const MAX_IMAGE_RESOURCES: number;
/** The per-image byte cap of {@link encodeDiagramDocument} (4 MiB). */
export const MAX_IMAGE_BYTES: number;
/** The cap on unique embedded-image bytes of {@link encodeDiagramDocument} (32 MiB). */
export const MAX_TOTAL_IMAGE_BYTES: number;
/** The per-side raster pixel cap of embedded images. */
export const MAX_IMAGE_SIDE: number;
/** The raster pixel product cap of embedded images (1 << 24 pixels). */
export const MAX_IMAGE_PIXELS: number;

/**
 * Page-space extent {x, y, w, h} of a stroked polyline or closed polygon
 * ring: point cloud grown by half the stroke width plus the per-vertex
 * miter protrusions (clamped by the miter limit). Adapters use it for page
 * fitting so thick acute joins cannot leave the page.
 */
export function strokedPolylineExtent(points: Array<[number, number]>, strokeWidth: number, closed?: boolean): { x: number; y: number; w: number; h: number };
