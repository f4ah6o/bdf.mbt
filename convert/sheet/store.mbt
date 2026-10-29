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
    "gridlines": Json::boolean(true),
  }
  if title != "" {
    view["title"] = Json::string(title)
  }
  if grid.geometry.frozen_rows > 0 {
    view["freeze"] = Json::object({
      "rows": Json::number(grid.geometry.frozen_rows.to_double()),
    })
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
