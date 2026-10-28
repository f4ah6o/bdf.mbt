///|
pub suberror BrowserError {
  Unsupported(String)
  BadFormat(String)
}

///|
/// The DOM and Canvas are deliberately limited to a JS-only host adapter.
/// BDF parsing, display-list validation, and page placement stay in MoonBit.
#external
type BrowserHost

///|
#external
priv type CanvasContext

///|
extern "js" fn clear_host(host : BrowserHost) -> Unit =
  #|(host) => {
  #|  if (!host || typeof host.replaceChildren !== "function") {
  #|    throw new TypeError("host must be an HTMLElement");
  #|  }
  #|  host.replaceChildren();
  #|  host.style.position = "relative";
  #|  host.style.overflow = "auto";
  #|}

///|
extern "js" fn make_canvas(
  host : BrowserHost,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  z : Double,
) -> CanvasContext =
  #|(host, x, y, width, height, z) => {
  #|  const canvas = document.createElement("canvas");
  #|  const w = Math.ceil(width), h = Math.ceil(height);
  #|  if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0 ||
  #|      w > 8192 || h > 8192 || w * h > 16777216) {
  #|    throw new RangeError("page bitmap exceeds browser limits");
  #|  }
  #|  canvas.width = w;
  #|  canvas.height = h;
  #|  canvas.style.position = "absolute";
  #|  canvas.style.left = x + "px";
  #|  canvas.style.top = y + "px";
  #|  canvas.setAttribute("aria-label", "BDF page");
  #|  host.appendChild(canvas);
  #|  const ctx = canvas.getContext("2d");
  #|  if (!ctx) throw new Error("Canvas 2D context unavailable");
  #|  ctx.scale(z, z);
  #|  return ctx;
  #|}

///|
extern "js" fn resize_host(
  host : BrowserHost,
  width : Double,
  height : Double,
) -> Unit =
  #|(host, w, h) => {
  #|  host.style.minWidth = Math.ceil(w) + "px";
  #|  host.style.minHeight = Math.ceil(h) + "px";
  #|}

///|
extern "js" fn save(ctx : CanvasContext) -> Unit =
  #|(ctx) => ctx.save()

///|
extern "js" fn restore(ctx : CanvasContext) -> Unit =
  #|(ctx) => ctx.restore()

///|
extern "js" fn transform(
  ctx : CanvasContext,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> Unit =
  #|(ctx,a,b,c,d,e,f) => ctx.transform(a,b,c,d,e,f)

///|
extern "js" fn translate(ctx : CanvasContext, x : Double, y : Double) -> Unit =
  #|(ctx,x,y) => ctx.translate(x,y)

///|
extern "js" fn scale(ctx : CanvasContext, x : Double, y : Double) -> Unit =
  #|(ctx,x,y) => ctx.scale(x,y)

///|
extern "js" fn clip_rect(
  ctx : CanvasContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(ctx,x,y,w,h) => { ctx.beginPath(); ctx.rect(x,y,w,h); ctx.clip(); }

///|
extern "js" fn set_color(
  ctx : CanvasContext,
  rgba : Int32,
  stroke : Bool,
) -> Unit =
  #|(ctx,rgba,stroke) => {
  #|  const n = rgba >>> 0;
  #|  const r = (n >>> 24) & 255, g = (n >>> 16) & 255, b = (n >>> 8) & 255;
  #|  const css = "rgba(" + r + "," + g + "," + b + "," + ((n & 255)/255) + ")";
  #|  if (stroke) ctx.strokeStyle = css;
  #|  else ctx.fillStyle = css;
  #|}

///|
extern "js" fn set_line(
  ctx : CanvasContext,
  width : Double,
  cap : Int32,
  join : Int32,
  miter : Double,
) -> Unit =
  #|(ctx,w,cap,join,miter) => {
  #|  ctx.lineWidth = w;
  #|  ctx.lineCap = ["butt","round","square"][cap] ?? "butt";
  #|  ctx.lineJoin = ["miter","round","bevel"][join] ?? "miter";
  #|  ctx.miterLimit = miter;
  #|}

///|
extern "js" fn set_dash(
  ctx : CanvasContext,
  segments : FixedArray[Double],
  offset : Double,
) -> Unit =
  #|(ctx, segments, offset) => { ctx.setLineDash(segments); ctx.lineDashOffset = offset; }

///|
extern "js" fn set_blend(ctx : CanvasContext, mode : Int32) -> Unit =
  #|(ctx, mode) => {
  #|  const names = ["source-over", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity", "destination-over", "destination-in", "destination-out", "source-in", "source-out", "source-atop", "destination-atop", "xor", "copy", "lighter"];
  #|  ctx.globalCompositeOperation = names[mode] ?? "source-over";
  #|}

///|
extern "js" fn set_shadow(
  ctx : CanvasContext,
  rgba : Int32,
  blur : Double,
  dx : Double,
  dy : Double,
) -> Unit =
  #|(ctx, rgba, blur, dx, dy) => {
  #|  const n = rgba >>> 0, m = ctx.getTransform();
  #|  const scale = Math.sqrt(Math.abs(m.a * m.d - m.b * m.c)) || 1;
  #|  ctx.shadowColor = `rgba(${n >>> 24},${(n >>> 16) & 255},${(n >>> 8) & 255},${(n & 255) / 255})`;
  #|  ctx.shadowBlur = blur * scale;
  #|  ctx.shadowOffsetX = dx * scale;
  #|  ctx.shadowOffsetY = dy * scale;
  #|}

///|
extern "js" fn set_filter(ctx : CanvasContext, css : String) -> Unit =
  #|(ctx, css) => {
  #|  const allowed = new Set(["blur", "brightness", "contrast", "drop-shadow", "grayscale", "hue-rotate", "invert", "opacity", "saturate", "sepia", "rgb", "rgba", "hsl", "hsla", "hwb", "lab", "lch", "oklab", "oklch", "color"]);
  #|  if (!/^[a-zA-Z0-9\s.,%#()+\/-]*$/.test(css) || [...css.matchAll(/([a-zA-Z-]*)\(/g)].some(m => !allowed.has(m[1].toLowerCase()))) css = "none";
  #|  if ("filter" in ctx) ctx.filter = css;
  #|}

///|
extern "js" fn set_alpha(ctx : CanvasContext, alpha : Double) -> Unit =
  #|(ctx,a) => { ctx.globalAlpha = a; }

///|
extern "js" fn set_font(
  ctx : CanvasContext,
  size : Double,
  family : String,
  weight : Int32,
  style : Int32,
) -> Unit =
  #|(ctx,size,family,weight,style) => {
  #|  ctx.font = `${["normal", "italic", "oblique"][style] ?? "normal"} ${weight || 400} ${size}px ${family || "sans-serif"}`;
  #|}

///|
extern "js" fn set_text_style(
  ctx : CanvasContext,
  align : Int32,
  baseline : Int32,
  direction : Int32,
  spacing : Double,
) -> Unit =
  #|(ctx,a,b,d,spacing) => {
  #|  ctx.textAlign = ["left","right","center","start","end"][a] ?? "left";
  #|  ctx.textBaseline = ["alphabetic","top","middle","bottom","hanging","ideographic"][b] ?? "alphabetic";
  #|  ctx.direction = ["inherit","ltr","rtl"][d] ?? "inherit";
  #|  if ("letterSpacing" in ctx) ctx.letterSpacing = spacing + "px";
  #|}

///|
extern "js" fn fill_rect(
  ctx : CanvasContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(ctx,x,y,w,h) => ctx.fillRect(x,y,w,h)

///|
extern "js" fn stroke_rect(
  ctx : CanvasContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(ctx,x,y,w,h) => ctx.strokeRect(x,y,w,h)

///|
extern "js" fn clear_rect(
  ctx : CanvasContext,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(ctx,x,y,w,h) => ctx.clearRect(x,y,w,h)

///|
extern "js" fn draw_text(
  ctx : CanvasContext,
  text : String,
  x : Double,
  y : Double,
  advance : Double,
  stroke : Bool,
) -> Unit =
  #|(ctx,t,x,y,w,stroke) => {
  #|  const measured = w > 0 ? ctx.measureText(t).width : 0;
  #|  if (measured > 0 && Math.abs(measured - w) / w > 0.005) {
  #|    ctx.save(); ctx.translate(x, y); ctx.scale(w / measured, 1);
  #|    if (stroke) ctx.strokeText(t, 0, 0); else ctx.fillText(t, 0, 0);
  #|    ctx.restore();
  #|  } else if (stroke) ctx.strokeText(t, x, y); else ctx.fillText(t, x, y);
  #|}

///|
extern "js" fn set_smoothing(
  ctx : CanvasContext,
  enabled : Bool,
  quality : Int32,
) -> Unit =
  #|(ctx,on,q) => {
  #|  ctx.imageSmoothingEnabled = on;
  #|  ctx.imageSmoothingQuality = ["low","medium","high"][q] ?? "low";
  #|}

///|
extern "js" fn draw_path(
  ctx : CanvasContext,
  verbs : Bytes,
  coordinates : FixedArray[Double],
  operation : Int32,
  rule : Int32,
  x : Double,
  y : Double,
) -> Unit =
  #|(ctx, verbs, coordinates, operation, rule, x, y) => {
  #|  const path = new Path2D(); let i = 0;
  #|  for (const v of verbs) {
  #|    switch (v) {
  #|      case 0: path.moveTo(coordinates[i++], coordinates[i++]); break;
  #|      case 1: path.lineTo(coordinates[i++], coordinates[i++]); break;
  #|      case 2: path.quadraticCurveTo(...coordinates.slice(i, i += 4)); break;
  #|      case 3: path.bezierCurveTo(...coordinates.slice(i, i += 6)); break;
  #|      case 4: path.closePath(); break;
  #|      case 5: path.rect(...coordinates.slice(i, i += 4)); break;
  #|      case 6: path.ellipse(...coordinates.slice(i, i + 7), coordinates[i + 7] !== 0); i += 8; break;
  #|      case 7: path.arcTo(...coordinates.slice(i, i += 5)); break;
  #|      case 8: path.roundRect(...coordinates.slice(i, i += 5)); break;
  #|    }
  #|  }
  #|  const fillRule = rule === 1 ? "evenodd" : "nonzero";
  #|  if (operation === 0) ctx.clip(path, fillRule);
  #|  else if (operation === 1) ctx.fill(path, fillRule);
  #|  else if (operation === 2) ctx.stroke(path);
  #|  else { ctx.save(); ctx.translate(x, y); ctx.fill(path, fillRule); ctx.restore(); }
  #|}

///|
fn path_at(paths : Array[@core.Path], index : Int32) -> @core.Path raise {
  if index < 0 || index >= paths.length() {
    raise BadFormat("path reference out of range")
  }
  paths[index]
}

///|
fn paint_path(
  ctx : CanvasContext,
  paths : Array[@core.Path],
  index : Int32,
  operation : Int32,
  rule : Int32,
  x : Double,
  y : Double,
) -> Unit raise {
  let path = path_at(paths, index)
  draw_path(
    ctx,
    path.verbs,
    FixedArray::from_array(path.coordinates),
    operation,
    rule,
    x,
    y,
  )
}

///|
fn resolve_paths(
  doc : @core.Document,
  entries : Array[@core.PathEntry],
) -> Array[@core.Path] raise {
  let paths = []
  for entry in entries {
    match entry {
      @core.Inline(path) => paths.push(path)
      @core.External(hash, index) => {
        let collection = @core.decode_path_collection(doc.part(hash))
        paths.push(path_at(collection, index))
      }
    }
  }
  paths
}

///|
priv struct UseLimits {
  seen : Map[String, Bool]
  mut reused : Int32
  maximum : Int32
}

///|
fn paint_child(
  ctx : CanvasContext,
  document : @core.Document,
  hash : String,
  x : Double,
  y : Double,
  depth : Int32,
  repeated : Bool,
  limits : UseLimits,
  resources : BrowserResources?,
) -> Unit raise {
  if depth >= 64 {
    raise BadFormat("objects draw objects too deep")
  }
  let again = limits.seen.contains(hash)
  limits.seen[hash] = true
  let child = @core.decode_object_resources(document.part(hash))
  let paths = resolve_paths(document, child.paths)
  let commands = @render.compile_object(child.object)
  save(ctx)
  if x != 0.0 || y != 0.0 {
    translate(ctx, x, y)
  }
  paint_commands(
    ctx,
    commands,
    paths~,
    paints=child.paints,
    fonts=child.fonts,
    images=child.object.images,
    resources?,
    document~,
    depth=depth + 1,
    repeated=repeated || again,
    limits~,
  ) catch {
    error => {
      restore(ctx)
      raise error
    }
  }
  restore(ctx)
}

///|
fn paint_commands(
  ctx : CanvasContext,
  commands : Array[@render.Command],
  paths~ : Array[@core.Path] = [],
  paints~ : Array[@core.Paint] = [],
  fonts~ : Array[@core.Font] = [],
  images~ : Array[String] = [],
  resources? : BrowserResources,
  document? : @core.Document,
  depth~ : Int32 = 0,
  repeated~ : Bool = false,
  limits? : UseLimits,
) -> Unit raise {
  let state = limits.unwrap_or({ seen: {}, reused: 0, maximum: 134217728, })
  for cmd in commands {
    if repeated {
      if state.reused >= state.maximum {
        raise BadFormat("objects are drawn too many times")
      }
      state.reused += 1
    }
    match cmd {
      @render.Save => save(ctx)
      @render.Restore => restore(ctx)
      @render.Transform(a, b, c, d, e, f) => transform(ctx, a, b, c, d, e, f)
      @render.Translate(x, y) => translate(ctx, x, y)
      @render.Scale(x, y) => scale(ctx, x, y)
      @render.ClipPath(index, rule) =>
        paint_path(ctx, paths, index, 0, rule, 0.0, 0.0)
      @render.ClipRect(x, y, w, h) => clip_rect(ctx, x, y, w, h)
      @render.FillColor(color) => set_color(ctx, color, false)
      @render.FillPaint(index) =>
        paint_style(ctx, paints, index, false, images, resources)
      @render.StrokeColor(color) => set_color(ctx, color, true)
      @render.StrokePaint(index) =>
        paint_style(ctx, paints, index, true, images, resources)
      @render.Line(width, cap, join, miter) =>
        set_line(ctx, width, cap, join, miter)
      @render.Dash(segments, offset) =>
        set_dash(ctx, FixedArray::from_array(segments), offset)
      @render.Alpha(value) => set_alpha(ctx, value)
      @render.Blend(mode) => set_blend(ctx, mode)
      @render.Shadow(color, blur, dx, dy) =>
        set_shadow(ctx, color, blur, dx, dy)
      @render.Filter(css) => set_filter(ctx, css)
      @render.Font(index, size) =>
        apply_font(ctx, fonts, index, size, resources)
      @render.TextStyle(a, b, d, spacing) =>
        set_text_style(ctx, a, b, d, spacing)
      @render.FillRect(x, y, w, h) => fill_rect(ctx, x, y, w, h)
      @render.StrokeRect(x, y, w, h) => stroke_rect(ctx, x, y, w, h)
      @render.FillPath(index, rule) =>
        paint_path(ctx, paths, index, 1, rule, 0.0, 0.0)
      @render.StrokePath(index) => paint_path(ctx, paths, index, 2, 0, 0.0, 0.0)
      @render.FillPathAt(index, rule, x, y) =>
        paint_path(ctx, paths, index, 3, rule, x, y)
      @render.FillPathRun(rule, glyphs) =>
        for glyph in glyphs {
          paint_path(ctx, paths, glyph.path, 3, rule, glyph.x, glyph.y)
        }
      @render.ClearRect(x, y, w, h) => clear_rect(ctx, x, y, w, h)
      @render.FillText(text, x, y, advance) =>
        draw_text(ctx, text, x, y, advance, false)
      @render.StrokeText(text, x, y, advance) =>
        draw_text(ctx, text, x, y, advance, true)
      @render.Smoothing(enabled, quality) =>
        set_smoothing(ctx, enabled, quality)
      @render.Use(hash) =>
        match document {
          Some(doc) =>
            paint_child(
              ctx, doc, hash, 0.0, 0.0, depth, repeated, state, resources,
            )
          None => raise Unsupported("child object requires a document")
        }
      @render.UseAt(hash, x, y) =>
        match document {
          Some(doc) =>
            paint_child(ctx, doc, hash, x, y, depth, repeated, state, resources)
          None => raise Unsupported("child object requires a document")
        }
      @render.Ext(_) | @render.Link(_, _, _, _, _) | @render.Mark(_, _) => ()
      @render.Image(hash, x, y, w, h) =>
        match resources {
          Some(r) => {
            if !has_image(r, hash) {
              raise BadFormat("image resource not prepared")
            }
            render_image(ctx, r, hash, 0.0, 0.0, 0.0, 0.0, x, y, w, h, false)
          }
          None => raise Unsupported("images require asynchronous loading")
        }
      @render.ImageSub(hash, sx, sy, sw, sh, dx, dy, dw, dh) =>
        match resources {
          Some(r) => {
            if !has_image(r, hash) {
              raise BadFormat("image resource not prepared")
            }
            render_image(ctx, r, hash, sx, sy, sw, sh, dx, dy, dw, dh, true)
          }
          None => raise Unsupported("images require asynchronous loading")
        }
    }
  }
}

///|
/// Mount an unencrypted, identity-encoded BDF fixed/flow view into an HTML
/// element using MoonBit's parsed objects and display lists. Returns pages.
/// Images, compressed parts, sheets, and unsupported ops fail explicitly.
pub fn mount_bdf(
  host : BrowserHost,
  data : Bytes,
  layout : String,
) -> Int32 raise {
  mount_document(host, @core.open_single(data), layout)
}

///|
extern "js" fn throw_browser_error(message : String) -> Int32 =
  #|(message) => { throw new Error(message); }

///|
/// JavaScript entry point: return the page count or throw on failure.
#export_name("mount_bdf")
pub fn mount_bdf_js(host : BrowserHost, data : Bytes, layout : String) -> Int32 {
  mount_bdf(host, data, layout) catch {
    error => throw_browser_error(error.to_string())
  }
}

///|
fn mount_document(
  host : BrowserHost,
  doc : @core.Document,
  layout : String,
  resources? : BrowserResources,
) -> Int32 raise {
  if doc.manifest.views.length() == 0 {
    raise BadFormat("document has no view")
  }
  let view = doc.manifest.views[0]
  if view.kind != "fixed" && view.kind != "flow" {
    raise Unsupported("browser MVP supports fixed/flow pages only")
  }
  if view.pages.length() > 256 {
    raise Unsupported("more than 256 pages")
  }
  let viewer = @viewer.Viewer::new()
  if layout == "spread" {
    viewer.set_layout(@viewer.Spread)
  } else if layout == "continuous" {
    viewer.set_layout(@viewer.Continuous)
  }
  let placements = viewer.placements(view)
  clear_host(host)
  let mut max_x = 0.0
  let mut max_y = 0.0
  for p in placements {
    let ctx = make_canvas(host, p.x, p.y, p.width, p.height, viewer.zoom)
    if p.x + p.width > max_x {
      max_x = p.x + p.width
    }
    if p.y + p.height > max_y {
      max_y = p.y + p.height
    }
    let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
    for layer in view.pages[p.index].layers {
      let object = @core.decode_object_resources(doc.part(layer.object))
      let paths = resolve_paths(doc, object.paths)
      paint_commands(
        ctx,
        @render.compile_object(object.object),
        paths~,
        paints=object.paints,
        fonts=object.fonts,
        images=object.object.images,
        resources?,
        document=doc,
        limits~,
      )
    }
  }
  resize_host(host, max_x, max_y)
  placements.length()
}
