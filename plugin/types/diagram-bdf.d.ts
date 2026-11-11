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

export type DiagramPrimitive =
  | RectPrimitive
  | EllipsePrimitive
  | PolygonPrimitive
  | PolylinePrimitive
  | TextPrimitive;

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

/** "invalid-input" for malformed value shapes, "too-large" past the limits. */
export type DiagramErrorCode = "invalid-input" | "too-large";

export class DiagramEncodeError extends Error {
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

/**
 * Page-space extent {x, y, w, h} of a stroked polyline or closed polygon
 * ring: point cloud grown by half the stroke width plus the per-vertex
 * miter protrusions (clamped by the miter limit). Adapters use it for page
 * fitting so thick acute joins cannot leave the page.
 */
export function strokedPolylineExtent(points: Array<[number, number]>, strokeWidth: number, closed?: boolean): { x: number; y: number; w: number; h: number };
