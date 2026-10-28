///|
#external
priv type CanvasGradient

///|
extern "js" fn make_gradient(
  ctx : CanvasContext,
  kind : Int32,
  coordinates : FixedArray[Double],
) -> CanvasGradient =
  #|(ctx, kind, c) => kind === 0 ? ctx.createLinearGradient(...c) : kind === 1 ? ctx.createRadialGradient(...c) : ctx.createConicGradient(...c)

///|
extern "js" fn add_stop(
  gradient : CanvasGradient,
  offset : Double,
  color : Int32,
) -> Unit =
  #|(g, offset, color) => {
  #|  const n = color >>> 0;
  #|  g.addColorStop(Math.min(1, Math.max(0, offset)), `rgba(${n >>> 24},${(n >>> 16) & 255},${(n >>> 8) & 255},${(n & 255) / 255})`);
  #|}

///|
extern "js" fn apply_gradient(
  ctx : CanvasContext,
  gradient : CanvasGradient,
  stroke : Bool,
) -> Unit =
  #|(ctx, g, stroke) => { if (stroke) ctx.strokeStyle = g; else ctx.fillStyle = g; }

///|
fn paint_style(
  ctx : CanvasContext,
  paints : Array[@core.Paint],
  index : Int32,
  stroke : Bool,
  images : Array[String],
  resources : BrowserResources?,
) -> Unit raise {
  if index < 0 || index >= paints.length() {
    raise BadFormat("paint reference out of range")
  }
  match paints[index] {
    @core.Gradient(kind, coordinates, stops) => {
      let gradient = make_gradient(
        ctx,
        kind,
        FixedArray::from_array(coordinates),
      )
      for stop in stops {
        add_stop(gradient, stop.offset, stop.color)
      }
      apply_gradient(ctx, gradient, stroke)
    }
    @core.Pattern(image, repeat, matrix) => {
      if image < 0 || image >= images.length() {
        raise BadFormat("pattern image reference out of range")
      }
      let hash = images[image]
      match resources {
        Some(r) => {
          if !has_image(r, hash) {
            raise BadFormat("image resource not prepared")
          }
          render_pattern(
            ctx,
            r,
            hash,
            repeat,
            FixedArray::from_array(matrix),
            stroke,
          )
        }
        None => raise Unsupported("image patterns require asynchronous loading")
      }
    }
  }
}

///|
fn apply_font(
  ctx : CanvasContext,
  fonts : Array[@core.Font],
  index : Int32,
  size : Double,
  resources : BrowserResources?,
) -> Unit raise {
  if index < 0 || index >= fonts.length() {
    raise BadFormat("font reference out of range")
  }
  let font = fonts[index]
  let family = match font.hash {
    None => font.family
    Some(hash) =>
      match resources {
        Some(r) => {
          if !has_font(r, hash) {
            raise BadFormat("font resource not prepared")
          }
          let embedded = "\"bdf-" + hash + "\""
          if font.family == "" {
            embedded
          } else {
            embedded + ", " + font.family
          }
        }
        None => raise Unsupported("embedded fonts require asynchronous loading")
      }
  }
  set_font(ctx, size, family, font.weight, font.style)
}
