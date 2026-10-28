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
