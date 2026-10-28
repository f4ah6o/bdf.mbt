///|
extern "js" fn sheet_tile_is_visible(
  host : BrowserHost,
  x : Int32,
  y : Int32,
  size : Double,
) -> Bool =
  #|(host,x,y,size) => x*size < host.scrollLeft+host.clientWidth && (x+1)*size > host.scrollLeft && y*size < host.scrollTop+host.clientHeight && (y+1)*size > host.scrollTop

///|
fn sheet_tile_key(x : Int32, y : Int32) -> String {
  x.to_string() + "," + y.to_string()
}

///|
fn install_sheet_find(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  tiles : Array[@core.Tile],
  load_text : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  load_index : () -> @js_async.Promise[Unit],
  prepare : (Array[@core.Tile]) -> @js_async.Promise[Unit],
  alive : () -> Bool,
  begin : () -> Unit,
  end : () -> Unit,
) -> Unit {
  let measure = find_measure_context(host)
  let by_place : Map[String, @core.Tile] = Map([])
  for tile in tiles {
    by_place[sheet_tile_key(tile.x, tile.y)] = tile
  }
  let runs : Map[String, Array[@render.TextRun]] = Map([])
  let mut searchable : @core.TextSearch? = None
  let mut last_query = ""
  let mut hits : Array[@core.SearchHit] = []
  let mut selected = -1
  let mut more = false
  let mut turn = 0
  install_find_dom(
    host,
    (_, _) => {
      throw_find_error("Sheet search is asynchronous; use bdf_find_async")
    },
    (query, step) => {
      @js_async.Promise::from_async(() => {
        begin()
        defer end()
        turn += 1
        let current = turn
        if !find_nonblank(query) {
          last_query = ""
          hits = []
          selected = -1
          more = false
          return find_result(query, -1, 0, false, "")
        }
        if query != last_query {
          let search = match searchable {
            Some(index) => index
            None => {
              let index = match view.text_index {
                Some(hash) => {
                  load_index().wait()
                  @core.decode_text_index(document.part(hash))
                }
                None => {
                  load_text(tiles).wait()
                  @render.build_sheet_text_index(tiles, view.tile_size, hash => {
                    Some(@core.decode_object_resources(document.part(hash)))
                  })
                }
              }
              let value = @core.TextSearch::new(index)
              searchable = Some(value)
              value
            }
          }
          if current != turn || !alive() {
            return find_result(query, -1, 0, false, "")
          }
          hits = search.search(query, limit=1001)
          more = hits.length() > 1000
          if more {
            ignore(hits.pop())
          }
          last_query = query
          selected = if hits.is_empty() {
            -1
          } else if step < 0 {
            hits.length() - 1
          } else {
            0
          }
        } else if !hits.is_empty() {
          let change = if step < 0 { -1 } else if step > 0 { 1 } else { 0 }
          selected = (selected + change + hits.length()) % hits.length()
        }
        let needed : Array[@core.Tile] = []
        let seen : Map[String, Bool] = Map([])
        for i, hit in hits {
          let mut locate = i == selected
          for segment in hit.segments {
            if sheet_tile_is_visible(host, segment.a, segment.b, view.tile_size) {
              locate = true
            }
          }
          if locate {
            for segment in hit.segments {
              let key = sheet_tile_key(segment.a, segment.b)
              if !seen.contains(key) && by_place.get(key) is Some(tile) {
                needed.push(tile)
                seen[key] = true
              }
            }
          }
        }
        if !alive() {
          return find_result(query, -1, 0, false, "")
        }
        prepare(needed).wait()
        if current != turn || !alive() {
          return find_result(query, -1, 0, false, "")
        }
        for tile in needed {
          let key = sheet_tile_key(tile.x, tile.y)
          if !runs.contains(key) {
            let object = @core.decode_object_resources(
              document.part(tile.object),
            )
            let content = @render.extract_text(object, hash => {
              Some(@core.decode_object_resources(document.part(hash)))
            })
            runs[key] = content.runs
          }
        }
        let detail = if selected >= 0 {
          hits[selected].context.replace_all(old=" ⏎ ", new=" ")
        } else {
          ""
        }
        let result = find_result(query, selected, hits.length(), more, detail)
        for i, hit in hits {
          let rects = @render.locate_text_hit(
            hit,
            (a, b, ordinal) => {
              match runs.get(sheet_tile_key(a, b)) {
                Some(array) if ordinal >= 0 && ordinal < array.length() =>
                  Some(array[ordinal])
                _ => None
              }
            },
            (font, size, text) => {
              measure_find_text(
                measure,
                find_font_family(font),
                font.weight,
                font.style,
                size,
                text,
              )
            },
            tile_size=view.tile_size,
          )
          for rect in rects {
            add_find_rect(
              result,
              i,
              rect.a,
              rect.x,
              rect.y,
              rect.width,
              rect.height,
            )
          }
        }
        result
      })
    },
    true,
  )
}
