///|
pub suberror BrowserError {
  Unsupported(String)
  BadFormat(String)
  WrongPassword
  WrongKey
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
  #|  delete host[Symbol.for('f4ah6o.bdf.sheetPending')];
  #|  const fonts=host[Symbol.for('f4ah6o.bdf.fonts')]; if(fonts){fonts.release();delete host[Symbol.for('f4ah6o.bdf.fonts')];}
  #|  const copy=host[Symbol.for('f4ah6o.bdf.copy')]; if(copy){copy.dispose();delete host[Symbol.for('f4ah6o.bdf.copy')];}
  #|  const find=host[Symbol.for('f4ah6o.bdf.find')]; if(find){find.dispose();delete host[Symbol.for('f4ah6o.bdf.find')];}
  #|  const layout=host[Symbol.for('f4ah6o.bdf.pageLayout')]; if(layout){layout.dispose();delete host[Symbol.for('f4ah6o.bdf.pageLayout')];}
  #|  const sheet=host[Symbol.for('f4ah6o.bdf.sheet')]; if(sheet){sheet.dispose();delete host[Symbol.for('f4ah6o.bdf.sheet')];}
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
// Viewer pages use device pixels for their backing store while their DOM
// geometry remains in CSS pixels. Explicit region renderers use make_canvas
// because their scale already specifies the requested output resolution.
extern "js" fn validate_page_bitmap(
  host : BrowserHost,
  width : Double,
  height : Double,
) -> Unit =
  #|(host,width,height) => {
  #|  const dpr = host.ownerDocument?.defaultView?.devicePixelRatio || 1;
  #|  const w = Math.ceil(width * dpr), h = Math.ceil(height * dpr);
  #|  if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0 ||
  #|      w > 8192 || h > 8192 || w * h > 16777216) {
  #|    throw new RangeError("page bitmap exceeds browser limits");
  #|  }
  #|}

///|
extern "js" fn make_page_canvas(
  host : BrowserHost,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  z : Double,
) -> CanvasContext =
  #|(host, x, y, width, height, z) => {
  #|  const doc = host.ownerDocument ?? document;
  #|  const dpr = doc.defaultView?.devicePixelRatio || 1;
  #|  const w = Math.ceil(width * dpr), h = Math.ceil(height * dpr);
  #|  if (!Number.isFinite(w) || !Number.isFinite(h) || w <= 0 || h <= 0 ||
  #|      w > 8192 || h > 8192 || w * h > 16777216) {
  #|    throw new RangeError("page bitmap exceeds browser limits");
  #|  }
  #|  const canvas = doc.createElement("canvas");
  #|  canvas.width = w; canvas.height = h;
  #|  Object.assign(canvas.style, {position:"absolute", left:x+"px", top:y+"px", width:width+"px", height:height+"px"});
  #|  canvas.setAttribute("aria-label", "BDF page");
  #|  host.appendChild(canvas);
  #|  const ctx = canvas.getContext("2d");
  #|  if (!ctx) throw new Error("Canvas 2D context unavailable");
  #|  ctx.scale(z * dpr, z * dpr);
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
// The content owns its extent; a caller-supplied host height remains a
// viewport instead of being enlarged to fit every page.
extern "js" fn make_page_surface(host : BrowserHost) -> BrowserHost =
  #|(host) => {const surface=(host.ownerDocument??document).createElement('div');surface.style.position='relative';surface.style.background='#e8e8e8';surface.dataset.bdfPages='';host.appendChild(surface);return surface}

///|
extern "js" fn resize_page_surface(
  surface : BrowserHost,
  width : Double,
  height : Double,
) -> Unit =
  #|(surface,w,h) => {surface.style.width=Math.ceil(w)+'px';surface.style.height=Math.ceil(h)+'px'}

///|
extern "js" fn page_viewport_width(host : BrowserHost) -> Double =
  #|(host) => host.clientWidth || 0

///|
extern "js" fn tag_page_child(surface : BrowserHost, index : Int32) -> Unit =
  #|(surface,index) => {if(surface.lastElementChild)surface.lastElementChild.dataset.bdfPageIndex=String(index)}

///|
extern "js" fn move_page_children(
  surface : BrowserHost,
  index : Int32,
  x : Double,
  y : Double,
) -> Unit =
  #|(surface,index,x,y) => {for(const el of surface.querySelectorAll(`[data-bdf-page-index="${index}"]`)){el.style.left=x+'px';el.style.top=y+'px'}}

///|
extern "js" fn refresh_page_find(host : BrowserHost) -> Unit =
  #|(host) => host[Symbol.for('f4ah6o.bdf.find')]?.refresh()

///|
extern "js" fn observe_page_width(
  host : BrowserHost,
  initial : Double,
  update : (Double) -> Unit,
  zoom : (Double) -> Unit,
  layout : (String) -> Unit,
  release : () -> Unit,
) -> Unit =
  #|(host,initial,update,zoom,layout,release) => {
  #|  const doc=host.ownerDocument,win=doc?.defaultView;
  #|  const key=Symbol.for('f4ah6o.bdf.pageLayout');let width=initial,removed=false,observer,mutation,released=false;
  #|  const releaseOnce=()=>{if(!released){released=true;release()}};
  #|  const state={zoom,layout,start(){if(removed)return;if(!observer&&win?.ResizeObserver){observer=new win.ResizeObserver(()=>{if(removed)return;const next=host.clientWidth||0;if(next!==width){width=next;update(next)}});observer.observe(host)}state.lazy?.start()},dispose(){if(removed)return;removed=true;observer?.disconnect();mutation?.disconnect();if(state.lazy)state.lazy.dispose(releaseOnce);else releaseOnce()}};
  #|  host[key]=state;
  #|  if(win?.MutationObserver){const watch=(weak,k,owner,connected,dispose)=>{const ob=new win.MutationObserver(()=>{const h=weak.deref();if(!h){ob.disconnect();dispose();return}if(h.isConnected){connected=true;h[k]?.start()}else if(connected){h[k]?.dispose();delete h[k]}});ob.observe(owner,{childList:true,subtree:true});return ob};const weak=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host};mutation=watch(weak,key,doc,host.isConnected,releaseOnce)}
  #|  if(host.isConnected||!mutation)state.start();
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
  doc : BrowserDocument,
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
// Each top-level object starts with the Canvas 2D defaults while preserving
// the page or viewport transform and clip established by the caller.
extern "js" fn reset_object_state(ctx : CanvasContext) -> Unit =
  #|(ctx) => {ctx.fillStyle='#000000';ctx.strokeStyle='#000000';ctx.lineWidth=1;ctx.lineCap='butt';ctx.lineJoin='miter';ctx.miterLimit=10;if(typeof ctx.setLineDash==='function')ctx.setLineDash([]);ctx.lineDashOffset=0;ctx.globalAlpha=1;ctx.globalCompositeOperation='source-over';ctx.shadowColor='rgba(0,0,0,0)';ctx.shadowBlur=0;ctx.shadowOffsetX=0;ctx.shadowOffsetY=0;ctx.font='10px sans-serif';ctx.textAlign='left';ctx.textBaseline='alphabetic';ctx.direction='inherit';if('letterSpacing'in ctx)ctx.letterSpacing='0px';if('filter'in ctx)ctx.filter='none';ctx.imageSmoothingEnabled=true}

///|
fn paint_root_object(
  ctx : CanvasContext,
  document : BrowserDocument,
  object : @core.ObjectResources,
  resources : BrowserResources?,
  limits : UseLimits,
) -> Unit raise {
  let paths = resolve_paths(document, object.paths)
  save(ctx)
  defer restore(ctx)
  reset_object_state(ctx)
  paint_commands(
    ctx,
    @render.compile_object(object.object),
    paths~,
    paints=object.paints,
    fonts=object.fonts,
    images=object.object.images,
    resources?,
    document~,
    limits~,
  )
}

///|
fn paint_child(
  ctx : CanvasContext,
  document : BrowserDocument,
  hash : String,
  x : Double,
  y : Double,
  depth : Int32,
  repeated : Bool,
  limits : UseLimits,
  resources : BrowserResources?,
  canvas_state? : CanvasState,
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
    canvas_state?,
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
  document? : BrowserDocument,
  depth~ : Int32 = 0,
  repeated~ : Bool = false,
  limits? : UseLimits,
  canvas_state? : CanvasState,
) -> Unit raise {
  let canvas = canvas_state.unwrap_or({ ctx, groups: [], masks: [], })
  defer (if canvas_state is None { canvas.finish() })
  let state = limits.unwrap_or({ seen: {}, reused: 0, maximum: 134217728, })
  for cmd in commands {
    let ctx = canvas.ctx
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
              ctx,
              doc,
              hash,
              0.0,
              0.0,
              depth,
              repeated,
              state,
              resources,
              canvas_state=canvas,
            )
          None => raise Unsupported("child object requires a document")
        }
      @render.UseAt(hash, x, y) =>
        match document {
          Some(doc) =>
            paint_child(
              ctx,
              doc,
              hash,
              x,
              y,
              depth,
              repeated,
              state,
              resources,
              canvas_state=canvas,
            )
          None => raise Unsupported("child object requires a document")
        }
      @render.GroupBegin(a, b, x, y, w, h) =>
        canvas.start_group(a, b, x, y, w, h)
      @render.GroupEnd => canvas.end_group()
      @render.MaskBegin(kind, backdrop, transfer) =>
        canvas.start_mask(kind, backdrop, transfer)
      @render.MaskEnd => canvas.end_mask()
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
/// Mount an unencrypted BDF fixed/flow view into an HTML element using
/// MoonBit's parsed objects and display lists. Returns the page count.
/// Images and embedded fonts require the asynchronous entry point.
pub fn mount_bdf(
  host : BrowserHost,
  data : Bytes,
  layout : String,
) -> Int32 raise {
  mount_document(host, single_document(@core.open_single(data)), layout)
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
  doc : BrowserDocument,
  layout : String,
  resources? : BrowserResources,
  interactive~ : Bool = false,
  page_loader? : (Int32) -> @js_async.Promise[Unit],
  music_loader? : () -> @js_async.Promise[Bytes],
  audio_loader? : (BrowserAudioElement) -> @js_async.Promise[BrowserAudioPlayer],
  midi_loader? : (BrowserMusicOptions) -> @js_async.Promise[BrowserMusicPlayer],
) -> Int32 raise {
  if doc.manifest.views.length() == 0 {
    raise BadFormat("document has no view")
  }
  let view = doc.manifest.views[0]
  if view.kind != "fixed" && view.kind != "flow" && view.kind != "scroll" {
    raise Unsupported("browser supports fixed/flow/scroll pages only")
  }
  if page_loader is None && view.pages.length() > 256 {
    raise Unsupported("more than 256 pages")
  }
  let viewer = @viewer.Viewer::new()
  if layout == "spread" {
    viewer.set_layout(@viewer.Spread)
  } else if layout == "continuous" {
    viewer.set_layout(@viewer.Continuous)
  }
  for p in viewer.placements(view) {
    if page_loader is None || p.index == 0 {
      validate_page_bitmap(host, p.width, p.height)
    }
  }
  clear_host(host)
  reset_host_size(host)
  let surface = make_page_surface(host)
  let viewport_width = page_viewport_width(host)
  let placements = viewer.placements_in(view, viewport_width)
  let search_runs : Array[Array[Array[@render.TextRun]]] = []
  let fallback_index : Array[@core.IndexRun] = []
  let mut max_x = 0.0
  let mut max_y = 0.0
  for p in placements {
    let ctx = if page_loader is Some(_) {
      make_page_placeholder(surface, p.x, p.y, p.width, p.height)
      None
    } else {
      Some(make_page_canvas(surface, p.x, p.y, p.width, p.height, viewer.zoom))
    }
    tag_page_child(surface, p.index)
    if ctx is Some(c) {
      set_color(c, -1, false)
      fill_rect(
        c,
        0.0,
        0.0,
        view.pages[p.index].width,
        view.pages[p.index].height,
      )
    }
    if p.x + p.width > max_x {
      max_x = p.x + p.width
    }
    if p.y + p.height > max_y {
      max_y = p.y + p.height
    }
    let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
    let data = if interactive { Some(new_text_layer_data()) } else { None }
    let mut node_base = 0
    let mut run_base = 0
    let page_runs : Array[Array[@render.TextRun]] = []
    for layer_index, layer in view.pages[p.index].layers {
      if data is Some(text_data) {
        let object = @core.decode_object_resources(doc.part(layer.object))
        let content = @render.extract_text(object, hash => {
          Some(@core.decode_object_resources(doc.part(hash)))
        })
        page_runs.push(content.runs)
        for ordinal, run in content.runs {
          fallback_index.push({
            a: p.index,
            b: layer_index,
            ordinal: run.ordinal,
            separator: if ordinal == 0 {
              2
            } else {
              run.separator
            },
            text: run.text,
          })
        }
        append_text_content(text_data, content, node_base, run_base)
        node_base += content.nodes.length()
        run_base += content.runs.length()
      }
      if ctx is Some(c) {
        let object = @core.decode_object_resources(doc.part(layer.object))
        paint_root_object(c, doc, object, resources, limits)
      }
    }
    if data is Some(text_data) {
      search_runs.push(page_runs)
      render_text_layer(
        surface,
        text_data,
        p.x,
        p.y,
        p.width,
        p.height,
        viewer.zoom,
      )
      tag_page_child(surface, p.index)
    }
  }
  if interactive {
    install_copy_handler(host)
    install_document_find(
      host, doc, view, placements, search_runs, fallback_index, viewer,
    )
  }
  resize_page_surface(
    surface,
    if max_x > viewport_width {
      max_x
    } else {
      viewport_width
    },
    page_surface_height(view, viewer, max_y),
  )
  observe_page_width(
    host,
    viewport_width,
    width => update_page_layout(host, surface, view, viewer, placements, width),
    zoom => {
      if page_loader is Some(_) {
        validate_lazy_zoom(host, zoom)
        viewer.zoom = zoom
        update_page_layout(
          host,
          surface,
          view,
          viewer,
          placements,
          page_viewport_width(host),
        )
        invalidate_lazy_pages(host, zoom)
      } else {
        redraw_page_zoom(
          host, surface, doc, view, viewer, placements, resources, zoom,
        ) catch {
          error => throw_page_control_error(error.to_string())
        }
      }
    },
    layout => {
      viewer.set_layout(
        if layout == "spread" {
          @viewer.Spread
        } else if layout == "continuous" {
          @viewer.Continuous
        } else {
          @viewer.Single
        },
      )
      update_page_layout(
        host,
        surface,
        view,
        viewer,
        placements,
        page_viewport_width(host),
      )
    },
    () => if resources is Some(r) { dispose_resources(r) },
  )
  if page_loader is Some(load) {
    ignore(
      start_lazy_pages(host, surface, (index, ctx) => {
        @js_async.Promise::from_async(() => {
          load(index).wait()
          let result = invoke_render(() => {
            try {
              paint_lazy_page(ctx, doc, view, index, resources)
              Ok(0)
            } catch {
              error => Err(error)
            }
          }).wait()
          match result {
            Ok(_) => ()
            Err(error) => raise error
          }
        })
      }),
    )
  }
  if view.play is Some(play) && play.seq is Some(hash) {
    let load = music_loader.unwrap_or(() => {
      @js_async.Promise::from_async(() => doc.part(hash))
    })
    install_music_mode(host, surface, load)
  }
  install_view_audio(host, doc, view, audio_loader?)
  install_view_midi(host, doc, view, midi_loader?)
  placements.length()
}
