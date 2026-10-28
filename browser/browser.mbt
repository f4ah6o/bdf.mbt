///|
/// The DOM and Canvas are deliberately limited to a JS-only host adapter.
/// BDF parsing, display-list validation, and page placement stay in MoonBit.
#external
type BrowserHost

///|
#external
type CanvasContext

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
extern "js" fn resize_host(host : BrowserHost, width : Double, height : Double) -> Unit =
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
extern "js" fn transform(ctx : CanvasContext, a : Double, b : Double, c : Double, d : Double, e : Double, f : Double) -> Unit =
  #|(ctx,a,b,c,d,e,f) => ctx.transform(a,b,c,d,e,f)

///|
extern "js" fn translate(ctx : CanvasContext, x : Double, y : Double) -> Unit =
  #|(ctx,x,y) => ctx.translate(x,y)

///|
extern "js" fn scale(ctx : CanvasContext, x : Double, y : Double) -> Unit =
  #|(ctx,x,y) => ctx.scale(x,y)

///|
extern "js" fn clip_rect(ctx : CanvasContext, x : Double, y : Double, w : Double, h : Double) -> Unit =
  #|(ctx,x,y,w,h) => { ctx.beginPath(); ctx.rect(x,y,w,h); ctx.clip(); }

///|
extern "js" fn set_color(ctx : CanvasContext, rgba : Int, stroke : Bool) -> Unit =
  #|(ctx,rgba,stroke) => {
  #|  const n = rgba >>> 0;
  #|  const r = (n >>> 24) & 255, g = (n >>> 16) & 255, b = (n >>> 8) & 255;
  #|  const css = "rgba(" + r + "," + g + "," + b + "," + ((n & 255)/255) + ")";
  #|  if (stroke) ctx.strokeStyle = css;
  #|  else ctx.fillStyle = css;
  #|}

///|
extern "js" fn set_line(ctx : CanvasContext, width : Double, cap : Int, join : Int, miter : Double) -> Unit =
  #|(ctx,w,cap,join,miter) => {
  #|  ctx.lineWidth = w;
  #|  ctx.lineCap = ["butt","round","square"][cap] ?? "butt";
  #|  ctx.lineJoin = ["miter","round","bevel"][join] ?? "miter";
  #|  ctx.miterLimit = miter;
  #|}

///|
extern "js" fn set_alpha(ctx : CanvasContext, alpha : Double) -> Unit =
  #|(ctx,a) => { ctx.globalAlpha = a; }

///|
extern "js" fn set_font(ctx : CanvasContext, size : Double) -> Unit =
  #|(ctx,size) => { ctx.font = size + "px sans-serif"; }

///|
extern "js" fn set_text_style(ctx : CanvasContext, align : Int, baseline : Int, direction : Int) -> Unit =
  #|(ctx,a,b,d) => {
  #|  ctx.textAlign = ["left","right","center","start","end"][a] ?? "left";
  #|  ctx.textBaseline = ["alphabetic","top","middle","bottom","hanging","ideographic"][b] ?? "alphabetic";
  #|  ctx.direction = ["inherit","ltr","rtl"][d] ?? "inherit";
  #|}

///|
extern "js" fn fill_rect(ctx : CanvasContext, x : Double, y : Double, w : Double, h : Double) -> Unit =
  #|(ctx,x,y,w,h) => ctx.fillRect(x,y,w,h)

///|
extern "js" fn stroke_rect(ctx : CanvasContext, x : Double, y : Double, w : Double, h : Double) -> Unit =
  #|(ctx,x,y,w,h) => ctx.strokeRect(x,y,w,h)

///|
extern "js" fn clear_rect(ctx : CanvasContext, x : Double, y : Double, w : Double, h : Double) -> Unit =
  #|(ctx,x,y,w,h) => ctx.clearRect(x,y,w,h)

///|
extern "js" fn draw_text(ctx : CanvasContext, text : String, x : Double, y : Double, advance : Double, stroke : Bool) -> Unit =
  #|(ctx,t,x,y,w,stroke) => {
  #|  if (stroke) { if (w > 0) ctx.strokeText(t,x,y,w); else ctx.strokeText(t,x,y); }
  #|  else { if (w > 0) ctx.fillText(t,x,y,w); else ctx.fillText(t,x,y); }
  #|}

///|
extern "js" fn set_smoothing(ctx : CanvasContext, enabled : Bool, quality : Int) -> Unit =
  #|(ctx,on,q) => {
  #|  ctx.imageSmoothingEnabled = on;
  #|  ctx.imageSmoothingQuality = ["low","medium","high"][q] ?? "low";
  #|}

///|
fn paint_commands(ctx : CanvasContext, commands : Array[@render.Command]) -> Unit raise {
  for cmd in commands {
    match cmd {
      @render.Save => save(ctx)
      @render.Restore => restore(ctx)
      @render.Transform(a,b,c,d,e,f) => transform(ctx,a,b,c,d,e,f)
      @render.Translate(x,y) => translate(ctx,x,y)
      @render.Scale(x,y) => scale(ctx,x,y)
      @render.ClipRect(x,y,w,h) => clip_rect(ctx,x,y,w,h)
      @render.FillColor(color) => set_color(ctx,color,false)
      @render.StrokeColor(color) => set_color(ctx,color,true)
      @render.Line(width,cap,join,miter) => set_line(ctx,width,cap,join,miter)
      @render.Alpha(value) => set_alpha(ctx,value)
      @render.Font(_,size) => set_font(ctx,size)
      @render.TextStyle(a,b,d,_) => set_text_style(ctx,a,b,d)
      @render.FillRect(x,y,w,h) => fill_rect(ctx,x,y,w,h)
      @render.StrokeRect(x,y,w,h) => stroke_rect(ctx,x,y,w,h)
      @render.ClearRect(x,y,w,h) => clear_rect(ctx,x,y,w,h)
      @render.FillText(text,x,y,advance) => draw_text(ctx,text,x,y,advance,false)
      @render.StrokeText(text,x,y,advance) => draw_text(ctx,text,x,y,advance,true)
      @render.Smoothing(enabled,quality) => set_smoothing(ctx,enabled,quality)
      @render.Ext(_) => ()
      @render.Image(_,_,_,_,_) | @render.ImageSub(_,_,_,_,_,_,_,_,_) =>
        raise @core.Unsupported("image resources are not supported by browser MVP")
    }
  }
}

///|
/// Mount an unencrypted, identity-encoded BDF fixed/flow view into an HTML
/// element using MoonBit's parsed objects and display lists. Returns pages.
/// Images, compressed parts, sheets, and unsupported ops fail explicitly.
#export_name("mount_bdf")
pub fn mount_bdf(host : BrowserHost, data : Bytes, layout : String) -> Int raise {
  let doc = @core.open_single(data)
  if doc.manifest.views.length() == 0 {
    raise @core.BadFormat("document has no view")
  }
  let view = doc.manifest.views[0]
  if view.kind != "fixed" && view.kind != "flow" {
    raise @core.Unsupported("browser MVP supports fixed/flow pages only")
  }
  if view.pages.length() > 256 {
    raise @core.Unsupported("more than 256 pages")
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
    let ctx = make_canvas(host,p.x,p.y,p.width,p.height,viewer.zoom)
    if p.x + p.width > max_x { max_x = p.x + p.width }
    if p.y + p.height > max_y { max_y = p.y + p.height }
    for layer in view.pages[p.index].layers {
      let object = @core.decode_object(doc.part(layer.object))
      paint_commands(ctx, @render.compile_object(object))
    }
  }
  resize_host(host, max_x, max_y)
  placements.length()
}
