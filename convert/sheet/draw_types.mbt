///|
/// A drawing tile produced for a sheet view.
pub(all) struct GridTile {
  x : Int32
  y : Int32
  object : Bytes
  drawn : Bool
}

///|
/// The sheet's dimensions and independently encoded BDF drawing tiles.
pub(all) struct DrawnGrid {
  geometry : GridGeometry
  tiles : Array[GridTile]
}

///|
priv struct DrawLine {
  text : String
  x : Double
  baseline : Double
  width : Double
  cjk_wrap : Bool
  explicit : Bool
}

///|
priv struct DrawCell {
  x0 : Double
  x1 : Double
  y0 : Double
  y1 : Double
  clip : Bool
  lang : String
  lang_known : Bool
  lines : Array[DrawLine]
}

///|
priv struct DrawTile {
  x : Int32
  y : Int32
  object : @core.ObjectBuilder
  fonts : Map[String, Int32]
  mut has_font : Bool
  mut current_font : Int32
  mut current_size : Double
  mut has_color : Bool
  mut current_color : UInt32
  mut lang : String
  document_language : String
  mut drawn : Bool
}

///|
priv struct GridDrawContext {
  tiles : Array[DrawTile]
  indexes : Map[String, Int32]
  width : Double
  height : Double
  document_language : String
}

///|
fn GridDrawContext::tile(
  self : GridDrawContext,
  x : Int32,
  y : Int32,
) -> DrawTile {
  let key = "\{x},\{y}"
  let index = match self.indexes.get(key) {
    Some(index) => index
    None => {
      let index = self.tiles.length()
      self.tiles.push(DrawTile::new(x, y, self.document_language))
      self.indexes[key] = index
      index
    }
  }
  self.tiles[index]
}

///|
fn GridDrawContext::in_bounds(
  self : GridDrawContext,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Array[DrawTile] {
  let x0 = Double::max(x0, 0.0)
  let y0 = Double::max(y0, 0.0)
  let x1 = Double::min(x1, self.width)
  let y1 = Double::min(y1, self.height)
  let result : Array[DrawTile] = []
  if x0 < x1 && y0 < y1 {
    for y in (y0 / 2048.0).to_int()..<(y1 / 2048.0).ceil().to_int() {
      for x in (x0 / 2048.0).to_int()..<(x1 / 2048.0).ceil().to_int() {
        result.push(self.tile(x, y))
      }
    }
  }
  result
}

///|
fn DrawTile::new(x : Int32, y : Int32, document_language : String) -> DrawTile {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 2048.0F, 2048.0F)
  {
    x,
    y,
    object,
    fonts: Map([]),
    has_font: false,
    current_font: 0,
    current_size: 0.0,
    has_color: false,
    current_color: 0U,
    lang: "",
    document_language,
    drawn: false,
  }
}
