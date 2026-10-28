///|
/// Compatibility alias for `view_text_index`.
pub fn page_text_index(
  view : @core.View,
  read_part : (String) -> Bytes raise,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  view_text_index(view, read_part, resolve)
}

///|
/// Load a view's BTXT part when present, otherwise rebuild its index.
pub fn view_text_index(
  view : @core.View,
  read_part : (String) -> Bytes raise,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  match view.text_index {
    Some(hash) => @core.decode_text_index(read_part(hash))
    None =>
      if view.kind == "sheet" {
        let tiles = if view.tiles.length() > 0 {
          view.tiles
        } else {
          match view.tiles_ref {
            Some(hash) => @core.decode_tile_index(read_part(hash))
            None => []
          }
        }
        build_sheet_text_index(tiles, view.tile_size, resolve)
      } else {
        build_page_text_index(view, resolve)
      }
  }
}

///|
/// Rebuild an index from sheet tiles, excluding runs anchored outside the tile.
pub fn build_sheet_text_index(
  tiles : Array[@core.Tile],
  tile_size : Double,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  let size = if tile_size > 0.0 { tile_size } else { 2048.0 }
  let sorted = [ for tile in tiles => tile ]
  sorted.sort_by((a, b) => {
    if a.y == b.y {
      a.x.compare(b.x)
    } else {
      a.y.compare(b.y)
    }
  })
  let index : Array[@core.IndexRun] = []
  for tile in sorted {
    let object = match resolve(tile.object) {
      Some(object) => object
      None => raise InvalidOperands("text index object missing")
    }
    let content = extract_text(object, resolve)
    let mut count = 0
    for run in content.runs {
      if !(run.x >= 0.0 && run.x < size && run.y >= 0.0 && run.y < size) {
        continue
      }
      index.push({
        a: tile.x,
        b: tile.y,
        ordinal: run.ordinal,
        separator: if count == 0 {
          2
        } else {
          run.separator
        },
        text: run.text,
      })
      count += 1
    }
  }
  index
}

///|
/// Extract an index from a paginated view when the document has no BTXT part.
/// Each layer starts a new paragraph, as in the upstream BDF reader.
pub fn build_page_text_index(
  view : @core.View,
  resolve : (String) -> @core.ObjectResources? raise,
) -> Array[@core.IndexRun] raise {
  if view.kind == "sheet" {
    raise InvalidOperands("sheet text index requires tiles")
  }
  let index : Array[@core.IndexRun] = []
  for a, page in view.pages {
    for b, layer in page.layers {
      let object = match resolve(layer.object) {
        Some(object) => object
        None => raise InvalidOperands("text index object missing")
      }
      let content = extract_text(object, resolve)
      for i, run in content.runs {
        index.push({
          a,
          b,
          ordinal: run.ordinal,
          separator: if i == 0 {
            2
          } else {
            run.separator
          },
          text: run.text,
        })
      }
    }
  }
  index
}
