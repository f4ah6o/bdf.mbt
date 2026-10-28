///|
extern "js" fn fake_context() -> CanvasContext =
  #|() => ({
  #|  calls: [], filter: "none", letterSpacing: "0px",
  #|  setLineDash(a) { this.calls.push(["dash", [...a]]); },
  #|  measureText() { return { width: 10 }; },
  #|  save() { this.calls.push(["save"]); },
  #|  restore() { this.calls.push(["restore"]); },
  #|  translate(x,y) { this.calls.push(["translate",x,y]); },
  #|  scale(x,y) { this.calls.push(["scale",x,y]); },
  #|  fillText(t,x,y) { this.calls.push(["text",t,x,y]); },
  #|  getTransform() { return {a:2,b:0,c:0,d:2}; }
  #|})

///|
extern "js" fn browser_test_result(ctx : CanvasContext) -> Bool =
  #|(ctx) => JSON.stringify(ctx.calls) === JSON.stringify([["dash",[1,2]],["save"],["translate",5,6],["scale",2,1],["text","a",0,0],["restore"]]) && ctx.lineDashOffset === 3 && ctx.globalCompositeOperation === "multiply" && ctx.shadowBlur === 4 && ctx.shadowOffsetX === 6 && ctx.shadowOffsetY === 8 && ctx.letterSpacing === "1.5px" && ctx.filter === "blur(2px)"

///|
extern "js" fn filter_is_none(ctx : CanvasContext) -> Bool =
  #|(ctx) => ctx.filter === "none"

///|
test "canvas effects and text advance" {
  let ctx = fake_context()
  paint_commands(ctx, [
    @render.Dash([1.0, 2.0], 3.0),
    @render.Blend(1),
    @render.Shadow(0x11223344, 2.0, 3.0, 4.0),
    @render.TextStyle(0, 0, 0, 1.5),
    @render.Filter("blur(2px)"),
    @render.FillText("a", 5.0, 6.0, 20.0),
  ])
  assert_true(browser_test_result(ctx))
  paint_commands(ctx, [@render.Filter("url(https://example.com)")])
  assert_true(filter_is_none(ctx))
}

///|
extern "js" fn fake_path_context() -> CanvasContext =
  #|() => {
  #|  globalThis.Path2D = class { constructor() { this.ops = []; } moveTo(...v) { this.ops.push(["move", ...v]); } lineTo(...v) { this.ops.push(["line", ...v]); } };
  #|  return { calls: [], clip(p,r) { this.calls.push(["clip",p.ops,r]); }, fill(p,r) { this.calls.push(["fill",p.ops,r]); }, stroke(p) { this.calls.push(["stroke",p.ops]); }, save() { this.calls.push(["save"]); }, restore() { this.calls.push(["restore"]); }, translate(x,y) { this.calls.push(["translate",x,y]); } };
  #|}

///|
extern "js" fn path_test_result(ctx : CanvasContext) -> Bool =
  #|(ctx) => JSON.stringify(ctx.calls) === JSON.stringify([["clip",[["move",1,2],["line",3,4]],"evenodd"],["save"],["translate",5,6],["fill",[["move",1,2],["line",3,4]],"nonzero"],["restore"]])

///|
test "canvas draws path commands and rejects bad references" {
  let ctx = fake_path_context()
  let paths : Array[@core.Path] = [
    { verbs: b"\x00\x01", coordinates: [1.0, 2.0, 3.0, 4.0], },
  ]
  paint_commands(
    ctx,
    [@render.ClipPath(0, 1), @render.FillPathAt(0, 0, 5.0, 6.0)],
    paths~,
  )
  assert_true(path_test_result(ctx))
  let rejected = try {
    paint_commands(ctx, [@render.FillPath(1, 0)], paths~)
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
extern "js" fn fake_paint_context() -> CanvasContext =
  #|() => {
  #|  const gradient = (kind, args) => ({kind, args, stops: [], addColorStop(offset, color) { this.stops.push([offset, color]); }});
  #|  return {
  #|    createLinearGradient(...args) { return gradient("linear",args); },
  #|    createRadialGradient(...args) { return gradient("radial",args); },
  #|    createConicGradient(...args) { return gradient("conic",args); }
  #|  };
  #|}

///|
extern "js" fn paint_test_result(ctx : CanvasContext) -> Bool =
  #|(ctx) => ctx.fillStyle.kind === "linear" && JSON.stringify(ctx.fillStyle.args) === "[1,2,3,4]" && JSON.stringify(ctx.fillStyle.stops) === '[[0,"rgba(17,34,51,0.26666666666666666)"],[1,"rgba(0,0,0,1)"]]' && ctx.strokeStyle.kind === "radial" && JSON.stringify(ctx.strokeStyle.args) === "[1,2,3,4,5,6]" && ctx.font === "italic 700 12px serif"

///|
test "canvas gradient paints and system fonts" {
  let ctx = fake_paint_context()
  let paints : Array[@core.Paint] = [
    Gradient(0, [1.0, 2.0, 3.0, 4.0], [
      { offset: -1.0, color: 0x11223344, },
      { offset: 2.0, color: 255, },
    ]),
    Gradient(1, [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], []),
    Pattern(0, 1, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0]),
  ]
  let fonts : Array[@core.Font] = [
    { hash: None, family: "serif", weight: 700, style: 1, },
    {
      hash: Some("00000000000000000000000000000000"),
      family: "",
      weight: 400,
      style: 0,
    },
  ]
  paint_commands(
    ctx,
    [@render.FillPaint(0), @render.StrokePaint(1), @render.Font(0, 12.0)],
    paints~,
    fonts~,
  )
  assert_true(paint_test_result(ctx))
  let bad_paint = try {
    paint_commands(ctx, [@render.FillPaint(3)], paints~)
    false
  } catch {
    _ => true
  }
  let pattern = try {
    paint_commands(ctx, [@render.FillPaint(2)], paints~)
    false
  } catch {
    _ => true
  }
  let embedded = try {
    paint_commands(ctx, [@render.Font(1, 12.0)], fonts~)
    false
  } catch {
    _ => true
  }
  assert_true(bad_paint && pattern && embedded)
}

///|
extern "js" fn is_conic(ctx : CanvasContext) -> Bool =
  #|(ctx) => ctx.fillStyle.kind === "conic" && JSON.stringify(ctx.fillStyle.args) === "[1,2,3]"

///|
test "canvas conic gradient" {
  let ctx = fake_paint_context()
  let paints : Array[@core.Paint] = [Gradient(2, [1.0, 2.0, 3.0], [])]
  paint_commands(ctx, [@render.FillPaint(0)], paints~)
  assert_true(is_conic(ctx))
}

///|
extern "js" fn fixture_host() -> BrowserHost =
  #|() => {
  #|  const g = (kind, args) => ({kind, args, stops: [], addColorStop(o,c) { this.stops.push([o,c]); }});
  #|  const ctx = {
  #|    scale(x,y) { this.scaled = [x,y]; },
  #|    createLinearGradient(...args) { return g("linear",args); },
  #|    createRadialGradient(...args) { return g("radial",args); },
  #|    createConicGradient(...args) { return g("conic",args); },
  #|    fillRect(...args) { this.rect = args; }
  #|  };
  #|  const canvas = {style: {}, setAttribute() {}, getContext() { return ctx; }};
  #|  globalThis.document = {createElement() { return canvas; }};
  #|  return {style: {}, ctx, replaceChildren() { this.children = []; }, appendChild(child) { this.children.push(child); }};
  #|}

///|
extern "js" fn fixture_rendered(host : BrowserHost) -> Bool =
  #|(host) => host.children.length === 1 && host.ctx.fillStyle.kind === "conic" && host.ctx.strokeStyle.kind === "radial" && host.ctx.font === "italic 700 12px serif" && JSON.stringify(host.ctx.rect) === "[1,2,3,4]"

///|
// Generated by shibukawa/bdf 4f9af52 with Document.WriteSingle and
// MinCompress = 1 << 30; the object has three gradients and a system font.
test "mount renders an upstream encoded object with gradients and a system font" {
  let host = fixture_host()
  let pages = mount_bdf(
    host, b"\x62\x64\x66\x00\x01\x00\x00\x00\x20\x00\x00\x00\x00\x00\x00\x00\x2e\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x7b\x22\x62\x64\x66\x22\x3a\x31\x2c\x22\x6f\x70\x73\x65\x74\x22\x3a\x31\x2c\x22\x75\x6e\x69\x74\x22\x3a\x22\x70\x74\x22\x2c\x22\x6d\x65\x74\x61\x22\x3a\x7b\x22\x67\x65\x6e\x65\x72\x61\x74\x6f\x72\x22\x3a\x22\x62\x64\x66\x2d\x67\x6f\x2f\x30\x2e\x31\x22\x7d\x2c\x22\x76\x69\x65\x77\x73\x22\x3a\x5b\x7b\x22\x69\x64\x22\x3a\x22\x70\x22\x2c\x22\x6b\x69\x6e\x64\x22\x3a\x22\x66\x69\x78\x65\x64\x22\x2c\x22\x70\x61\x67\x65\x73\x22\x3a\x5b\x7b\x22\x77\x22\x3a\x32\x30\x2c\x22\x68\x22\x3a\x32\x30\x2c\x22\x6c\x61\x79\x65\x72\x73\x22\x3a\x5b\x7b\x22\x72\x6f\x6c\x65\x22\x3a\x22\x62\x6f\x64\x79\x22\x2c\x22\x6f\x62\x6a\x22\x3a\x22\x66\x30\x62\x66\x36\x63\x39\x38\x32\x32\x33\x63\x33\x65\x33\x32\x66\x38\x31\x66\x36\x64\x64\x38\x37\x61\x66\x33\x33\x33\x38\x64\x22\x7d\x5d\x7d\x5d\x7d\x5d\x2c\x22\x70\x61\x72\x74\x73\x22\x3a\x5b\x7b\x22\x68\x22\x3a\x22\x66\x30\x62\x66\x36\x63\x39\x38\x32\x32\x33\x63\x33\x65\x33\x32\x66\x38\x31\x66\x36\x64\x64\x38\x37\x61\x66\x33\x33\x33\x38\x64\x22\x2c\x22\x74\x22\x3a\x22\x6f\x62\x6a\x22\x2c\x22\x65\x6e\x63\x22\x3a\x22\x69\x64\x65\x6e\x74\x69\x74\x79\x22\x2c\x22\x6c\x65\x6e\x22\x3a\x31\x34\x34\x2c\x22\x73\x69\x7a\x65\x22\x3a\x31\x34\x34\x2c\x22\x6f\x66\x66\x22\x3a\x30\x7d\x5d\x7d\x42\x4f\x42\x4a\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xa0\x41\x00\x00\xa0\x41\x00\x00\x03\x00\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x02\x00\x00\x80\xbf\x44\x33\x22\x11\x00\x00\x00\x40\xdd\xcc\xbb\xaa\x01\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40\x00\x00\xa0\x40\x00\x00\xc0\x40\x00\x02\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x01\x01\x05\x73\x65\x72\x69\x66\xbc\x02\x01\x00\x00\x1d\x11\x00\x13\x01\x11\x02\x1a\x00\x00\x00\x40\x41\x20\x00\x00\x80\x3f\x00\x00\x00\x40\x00\x00\x40\x40\x00\x00\x80\x40",
    "single",
  )
  assert_eq(pages, 1)
  assert_true(fixture_rendered(host))
}
