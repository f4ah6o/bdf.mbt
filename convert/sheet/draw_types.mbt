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
  fonts : Map[Int32, Int32]
  mut has_font : Bool
  mut current_font : Int32
  mut has_color : Bool
  mut current_color : UInt32
  mut lang : String
  mut drawn : Bool
}

///|
fn DrawTile::new(x : Int32, y : Int32) -> DrawTile {
  let object = @core.ObjectBuilder::new()
  object.set_bbox(0.0F, 0.0F, 2048.0F, 2048.0F)
  {
    x,
    y,
    object,
    fonts: Map([]),
    has_font: false,
    current_font: 0,
    has_color: false,
    current_color: 0U,
    lang: "",
    drawn: false,
  }
}
