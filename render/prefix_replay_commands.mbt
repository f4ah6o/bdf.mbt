///|
fn PrefixReplay::emit(
  self : PrefixReplay,
  span : InstructionSpan,
) -> Unit raise {
  let target = self.target
  let f = fn(x : Double) { Float::from_double(x) }
  match span.command {
    Save => target.save()
    Restore => target.restore()
    Transform(a, b, c, d, e, g) =>
      target.transform(f(a), f(b), f(c), f(d), f(e), f(g))
    Translate(x, y) => target.translate(f(x), f(y))
    Scale(x, y) => target.scale(f(x), f(y))
    ClipPath(index, rule) => target.clip_path(self.path(index), rule.to_byte())
    ClipRect(x, y, w, h) => target.clip_rect(f(x), f(y), f(w), f(h))
    FillColor(color) => target.fill_color(color.reinterpret_as_uint())
    FillPaint(index) => target.fill_paint(self.paint(index))
    StrokeColor(color) => target.stroke_color(color.reinterpret_as_uint())
    StrokePaint(index) => target.stroke_paint(self.paint(index))
    Line(width, cap, join, miter) =>
      target.line(f(width), cap.to_byte(), join.to_byte(), f(miter))
    Dash(values, offset) => target.dash(values.map(f), f(offset))
    Alpha(value) => target.alpha(f(value))
    Blend(value) => target.blend(value.to_byte())
    Shadow(color, blur, x, y) =>
      target.shadow(color.reinterpret_as_uint(), f(blur), f(x), f(y))
    Filter(css) => target.filter(css)
    Font(index, size) => target.font(self.font(index), f(size))
    TextStyle(align, baseline, direction, spacing) =>
      target.text_style(
        align.to_byte(),
        baseline.to_byte(),
        direction.to_byte(),
        f(spacing),
      )
    FillRect(x, y, w, h) => target.fill_rect(f(x), f(y), f(w), f(h))
    StrokeRect(x, y, w, h) => target.stroke_rect(f(x), f(y), f(w), f(h))
    ClearRect(x, y, w, h) => target.clear_rect(f(x), f(y), f(w), f(h))
    FillPath(index, rule) => target.fill_path(self.path(index), rule.to_byte())
    StrokePath(index) => target.stroke_path(self.path(index))
    FillPathAt(index, rule, x, y) =>
      target.fill_path_at(self.path(index), rule.to_byte(), f(x), f(y))
    FillPathRun(rule, glyphs) => {
      let remapped : Array[@core.ObjectGlyph] = []
      for glyph in glyphs {
        remapped.push({
          path: self.path(glyph.path),
          x: f(glyph.x),
          y: f(glyph.y),
        })
      }
      target.fill_path_run(rule.to_byte(), remapped)
    }
    FillText(text, x, y, advance) =>
      target.fill_text(text, f(x), f(y), f(advance))
    StrokeText(text, x, y, advance) =>
      target.stroke_text(text, f(x), f(y), f(advance))
    Image(_, x, y, w, h) =>
      target.image(self.image(self.source_index(span)), f(x), f(y), f(w), f(h))
    ImageSub(_, sx, sy, sw, sh, x, y, w, h) =>
      target.image_sub(
        self.image(self.source_index(span)),
        f(sx),
        f(sy),
        f(sw),
        f(sh),
        f(x),
        f(y),
        f(w),
        f(h),
      )
    Smoothing(enabled, quality) => target.smoothing(enabled, quality.to_byte())
    Use(_) => target.use_object(self.child(self.source_index(span)))
    UseAt(_, x, y) =>
      target.use_object_at(self.child(self.source_index(span)), f(x), f(y))
    GroupBegin(alpha, blend, x, y, w, h) =>
      target.group_begin(f(alpha), blend.to_byte(), f(x), f(y), f(w), f(h))
    GroupEnd => target.group_end()
    MaskBegin(kind, backdrop, transfer) =>
      target.mask_begin(
        kind.to_byte(),
        backdrop.reinterpret_as_uint(),
        transfer,
      )
    MaskEnd => target.mask_end()
    Link(x, y, w, h, url) => target.link(f(x), f(y), f(w), f(h), url)
    Mark(kind, payload) => target.mark(kind.to_byte(), payload)
    Ext(payload) => target.ext(payload)
  }
}
