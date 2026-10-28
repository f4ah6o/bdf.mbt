///|
/// A BDF path stores its verbs separately from their float32 coordinates.
pub(all) struct Path {
  verbs : Bytes
  coordinates : Array[Double]
}

///|
/// An inline path or a reference to an index in a path collection part.
pub(all) enum PathEntry {
  Inline(Path)
  External(String, Int32)
}

///|
fn read_path(reader : Reader) -> Path raise {
  let count = reader.varuint()
  if count > reader.remaining() {
    raise BadFormat("path verb count out of range")
  }
  let verbs = reader.take(count)
  let sizes = [2, 2, 4, 6, 0, 4, 8, 5, 5]
  let mut count_coords = 0
  for byte in verbs {
    let verb = byte.to_int()
    if verb >= sizes.length() {
      raise BadFormat("unknown path verb")
    }
    if sizes[verb] > reader.remaining() / 4 - count_coords {
      raise BadFormat("path coordinates out of range")
    }
    count_coords += sizes[verb]
  }
  let coordinates = []
  for _ in 0..<count_coords {
    coordinates.push(reader.f32())
  }
  { verbs, coordinates, }
}

///|
/// Decode a BDF path collection part, rejecting truncated data.
pub fn decode_path_collection(data : Bytes) -> Array[Path] raise {
  let reader = Reader::new(data)
  let count = reader.varuint()
  if count > reader.remaining() {
    raise BadFormat("path count out of range")
  }
  let paths = []
  for _ in 0..<count {
    paths.push(read_path(reader))
  }
  paths
}
