///|
/// Millimeters to PostScript points.
pub fn mm_to_pt(mm : Double) -> Double {
  mm * 72.0 / 25.4
}

///|
/// A page of a fixed view.
pub fn page(w : Double, h : Double, layers : Array[Json]) -> Json {
  Json::object({
    "w": Json::number(w, repr=w.to_string()),
    "h": Json::number(h, repr=h.to_string()),
    "layers": Json::array(layers),
  })
}

///|
/// A page layer.
pub fn layer(role : String, hash : String) -> Json {
  Json::object({
    "role": Json::string(role),
    "obj": Json::string(hash),
  })
}

///|
/// A fixed view of pages.
pub fn fixed_view(pages : Array[Json], title~ : String = "") -> Json {
  let view : Map[String, Json] = {
    "id": Json::string("pages"),
    "kind": Json::string("fixed"),
    "pages": Json::array(pages),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  Json::object(view)
}

///|
/// Document metadata for a converter source.
pub fn document_meta(source : String, title~ : String = "") -> Map[String, Json] {
  let meta : Map[String, Json] = {
    "source": Json::string(source),
    "generator": Json::string("bdf-go/0.1"),
  }
  if title != "" {
    meta["dc"] = Json::object({ "title": Json::string(title) })
  }
  meta
}

///|
/// A background layer filled with one color, or None.
pub fn background_layer(
  canvas : @canvas.Canvas,
  width : Double,
  height : Double,
  color : UInt32,
  writer : @core.DocumentWriter,
  fonts : @canvas.Fonts,
  warnings : Array[String],
) -> String raise {
  canvas.object().fill_color(color)
  canvas.object().fill_rect(
    0.0F,
    0.0F,
    @canvas.f32(width),
    @canvas.f32(height),
  )
  canvas.set_drawn()
  canvas.encode(writer, fonts, warnings)
}

///|
/// A page's width and height rounded for a summary.
pub fn rounded_size(width : Double, height : Double) -> (Int, Int) {
  (width.round().to_int(), height.round().to_int())
}
