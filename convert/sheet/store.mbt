///|
/// Store a drawn grid's objects and add its sheet view to a BDF writer.
pub fn store_grid(
  writer : @core.DocumentWriter,
  grid : DrawnGrid,
  id~ : String = "sheet1",
  title~ : String = "Sheet1",
  text_index~ : Bool = true,
) -> Unit raise {
  let tiles : Map[String, Json] = Map([])
  for tile in grid.tiles {
    let hash = writer.add_part("obj", tile.object)
    if tile.drawn {
      tiles["\{tile.x},\{tile.y}"] = Json::string(hash)
    }
  }
  store_grid_view(writer, grid, tiles, id, title, text_index, true, 0)
}

///|
fn store_grid_view(
  writer : @core.DocumentWriter,
  grid : DrawnGrid,
  tiles : Map[String, Json],
  id : String,
  title : String,
  text_index : Bool,
  gridlines : Bool,
  frozen_columns : Int32,
) -> Unit raise {
  let as_json = (runs : Array[Run]) => {
    Json::array(
      runs.map(run => {
        Json::array([
          Json::number(run.count.to_double()),
          Json::number(run.size.to_double(), repr=run.size.to_string()),
        ])
      }),
    )
  }
  let view : Map[String, Json] = {
    "id": Json::string(id),
    "kind": Json::string("sheet"),
    "tile": Json::number(2048.0),
    "cols": as_json(grid.geometry.columns),
    "rows": as_json(grid.geometry.rows),
  }
  if gridlines {
    view["gridlines"] = Json::boolean(true)
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  if grid.geometry.frozen_rows > 0 || frozen_columns > 0 {
    let freeze : Map[String, Json] = Map([])
    if grid.geometry.frozen_rows != 0 {
      freeze["rows"] = Json::number(grid.geometry.frozen_rows.to_double())
    }
    if frozen_columns != 0 {
      freeze["cols"] = Json::number(frozen_columns.to_double())
    }
    view["freeze"] = Json::object(freeze)
  }
  if tiles.length() > 0 {
    view["tiles"] = Json::object(tiles)
  }
  if text_index {
    let runs : Array[@core.IndexRun] = []
    let ordered = grid.tiles.filter(tile => tile.drawn)
    ordered.sort_by((a, b) => {
      if a.y == b.y {
        a.x.compare(b.x)
      } else {
        a.y.compare(b.y)
      }
    })
    for tile in ordered {
      let object = @core.decode_object_resources(tile.object)
      let text = @render.extract_text(object, _ => None)
      let mut first = true
      for run in text.runs {
        if run.x >= 0.0 && run.x < 2048.0 && run.y >= 0.0 && run.y < 2048.0 {
          runs.push({
            a: tile.x,
            b: tile.y,
            ordinal: run.ordinal,
            separator: if first {
              2
            } else {
              run.separator
            },
            text: run.text,
          })
          first = false
        }
      }
    }
    let hash = writer.add_part("idx", @core.encode_text_index(runs))
    view["textIndex"] = Json::string(hash)
  }
  writer.add_view(Json::object(view))
}

///|
/// One named sheet view to be stored in a BDF document.
pub(all) struct NamedGrid {
  id : String
  title : String
  grid : DrawnGrid
  gridlines : Bool
  frozen_columns : Int32
}

///|
/// Store one grid's tile objects and their deferred picture children.
pub fn store_grid_parts(
  writer : @core.DocumentWriter,
  grid : DrawnGrid,
  children : Array[(Int32, Int32, Bytes)],
) -> Map[String, Json] raise {
  for (x, y, _) in children {
    if x < 0 {
      if y != -1 || -(x + 1) > grid.tiles.length() {
        raise InvalidArgument("sheet: invalid picture child tile")
      }
    } else if !grid.tiles.any(tile => tile.x == x && tile.y == y) {
      raise InvalidArgument("sheet: missing picture child tile")
    }
  }
  let tiles : Map[String, Json] = Map([])
  for index, tile in grid.tiles {
    for (x, y, child) in children {
      if (x < 0 && -(x + 1) == index) || (x == tile.x && y == tile.y) {
        ignore(writer.add_part("obj", child))
      }
    }
    let hash = writer.add_part("obj", tile.object)
    if tile.drawn {
      tiles["\{tile.x},\{tile.y}"] = Json::string(hash)
    }
  }
  for (x, _, child) in children {
    if x < 0 && -(x + 1) == grid.tiles.length() {
      ignore(writer.add_part("obj", child))
    }
  }
  tiles
}

///|
/// Store views and optional text indexes after their tile objects are stored.
pub fn store_grid_views(
  writer : @core.DocumentWriter,
  grids : Array[NamedGrid],
  tile_maps : Array[Map[String, Json]],
  text_index : Bool,
) -> Unit raise {
  if tile_maps.length() != grids.length() {
    raise InvalidArgument("sheet: tile maps do not match the grids")
  }
  for i in 0..<grids.length() {
    let named = grids[i]
    store_grid_view(
      writer,
      named.grid,
      tile_maps[i],
      named.id,
      named.title,
      text_index,
      named.gridlines,
      named.frozen_columns,
    )
  }
}

///|
/// Store all sheet objects before their text indexes, matching XLSX output order.
pub fn store_grids(
  writer : @core.DocumentWriter,
  grids : Array[NamedGrid],
  text_index : Bool,
  picture_children~ : Array[Array[(Int32, Int32, Bytes)]] = [],
) -> Unit raise {
  if !picture_children.is_empty() && picture_children.length() != grids.length() {
    raise InvalidArgument("sheet: picture children do not match the grids")
  }
  let tile_maps : Array[Map[String, Json]] = []
  for index, named in grids {
    tile_maps.push(
      store_grid_parts(
        writer,
        named.grid,
        picture_children.get(index).unwrap_or([]),
      ),
    )
  }
  store_grid_views(writer, grids, tile_maps, text_index)
}
