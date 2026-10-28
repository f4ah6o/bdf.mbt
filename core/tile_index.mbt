///|
/// Decode the sheet tile index's fixed-width (x, y, hash) records.
/// Coordinates above Int32's maximum are not supported by this reader.
pub fn decode_tile_index(data : Bytes) -> Array[Tile] raise {
  if data.length() % 24 != 0 {
    raise BadFormat("invalid tile index length")
  }
  let reader = Reader::new(data)
  let tiles : Array[Tile] = []
  while reader.remaining() > 0 {
    let x = reader.u32()
    let y = reader.u32()
    if x < 0 || y < 0 {
      raise BadFormat("tile coordinate out of range")
    }
    let object = reader.hash()
    if tiles.length() > 0 {
      let previous = tiles[tiles.length() - 1]
      if y < previous.y || (y == previous.y && x <= previous.x) {
        raise BadFormat("unordered tile index")
      }
    }
    tiles.push({ x, y, object, })
  }
  tiles
}
