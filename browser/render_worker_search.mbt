///|
extern "js" fn render_search_query(r : RenderRequest) -> String =
  #|(r) => r.query

///|
extern "js" fn render_search_option(
  r : RenderRequest,
  key : String,
  fallback : Int32,
) -> Int32 =
  #|(r,key,fallback) => r.options?.[key] ?? fallback

///|
extern "js" fn render_search_new() -> RenderValue =
  #|() => []

///|
extern "js" fn render_search_add(
  out : RenderValue,
  text : String,
  context : String,
) -> Int32 =
  #|(out,text,context) => out.push({segments:[],text,context})-1

///|
extern "js" fn render_search_segment(
  out : RenderValue,
  i : Int32,
  run : Int32,
  a : Int32,
  b : Int32,
  ordinal : Int32,
  start : Int32,
  end : Int32,
) -> Unit =
  #|(out,i,run,a,b,ordinal,start,end) => out[i].segments.push({run,a,b,ordinal,start,end})

///|
extern "js" fn render_hit_count(r : RenderRequest) -> Int32 =
  #|(r) => r.hits.length

///|
extern "js" fn render_segment_count(r : RenderRequest, i : Int32) -> Int32 =
  #|(r,i) => r.hits[i].segments.length

///|
extern "js" fn render_segment_field(
  r : RenderRequest,
  i : Int32,
  j : Int32,
  key : String,
) -> Int32 =
  #|(r,i,j,key) => r.hits[i].segments[j][key]

///|
extern "js" fn render_rects_add(out : RenderValue) -> Int32 =
  #|(out) => out.push([])-1

///|
extern "js" fn render_rect_add(
  out : RenderValue,
  i : Int32,
  a : Int32,
  b : Int32,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(out,i,a,b,x,y,w,h) => out[i].push({a,b,x,y,w,h})

///|
async fn render_search_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  match view.text_index {
    Some(hash) => doc.ensure(hash)
    None => {
      let seen : Map[String, Bool] = {}
      if view.kind == "sheet" {
        if view.tiles.is_empty() && view.tiles_ref is Some(hash) {
          doc.ensure(hash)
        }
        for tile in sheet_tile_table(doc.browser_document(), view) {
          doc.prepare_text_parts(tile.object, seen, 0, fonts=false)
        }
      } else {
        for page in view.pages {
          for layer in page.layers {
            doc.prepare_text_parts(layer.object, seen, 0, fonts=false)
          }
        }
      }
    }
  }
  let index = @render.view_text_index(view, hash => doc.part(hash), hash => {
    Some(@core.decode_object_resources(doc.part(hash)))
  })
  let search = @core.TextSearch::new(index)
  let hits = search.search(
    render_search_query(request),
    limit=render_search_option(request, "limit", 1000),
    context=render_search_option(request, "context", 40),
  )
  let out = render_search_new()
  for hit in hits {
    let i = render_search_add(out, hit.text, hit.context)
    for s in hit.segments {
      render_search_segment(out, i, s.run, s.a, s.b, s.ordinal, s.start, s.end)
    }
  }
  out
}

///|
async fn render_locate_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  if view.kind == "sheet" &&
    view.tiles.is_empty() &&
    view.tiles_ref is Some(hash) {
    doc.ensure(hash)
  }
  let tiles = if view.kind == "sheet" {
    sheet_tile_table(doc.browser_document(), view)
  } else {
    []
  }
  let resources = doc.resources()
  defer dispose_resources(resources)
  let runs : Map[String, Array[@render.TextRun]] = {}
  let measure = render_measure_context()
  let out = render_search_new()
  for i in 0..<render_hit_count(request) {
    let segments : Array[@core.HitSegment] = []
    for j in 0..<render_segment_count(request, i) {
      let a = render_segment_field(request, i, j, "a")
      let b = render_segment_field(request, i, j, "b")
      let hash = if view.kind == "sheet" {
        let mut found = ""
        for tile in tiles {
          if tile.x == a && tile.y == b {
            found = tile.object
            break
          }
        }
        found
      } else {
        match view.pages.get(a) {
          Some(page) =>
            match page.layers.get(b) {
              Some(layer) => layer.object
              None => ""
            }
          None => ""
        }
      }
      if hash != "" && !runs.contains(hash) {
        let layers : Array[@core.Layer] = [{ role: "body", object: hash, }]
        render_prepare_text(doc, resources, layers)
        runs[hash] = render_extract_layers(
            doc,
            layers,
            measure,
            (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
            false,
            measure_advance=false,
          ).runs
      }
      segments.push({
        run: render_segment_field(request, i, j, "run"),
        a,
        b,
        ordinal: render_segment_field(request, i, j, "ordinal"),
        start: render_segment_field(request, i, j, "start"),
        end: render_segment_field(request, i, j, "end"),
      })
    }
    let hit : @core.SearchHit = { segments, text: "", context: "", }
    let rects = @render.locate_text_hit(
      hit,
      (a, b, ordinal) => {
        let hash = if view.kind == "sheet" {
          let mut found = ""
          for tile in tiles {
            if tile.x == a && tile.y == b {
              found = tile.object
              break
            }
          }
          found
        } else {
          match view.pages.get(a) {
            Some(page) =>
              match page.layers.get(b) {
                Some(layer) => layer.object
                None => ""
              }
            None => ""
          }
        }
        match runs.get(hash) {
          Some(items) => {
            let mut found = None
            for run in items {
              if run.ordinal == ordinal {
                found = Some(run)
                break
              }
            }
            found
          }
          None => None
        }
      },
      (font, size, text) => render_measure(measure, font, size, text),
      tile_size=if view.kind == "sheet" { view.tile_size } else { 0.0 },
    )
    let n = render_rects_add(out)
    for rect in rects {
      render_rect_add(
        out,
        n,
        rect.a,
        rect.b,
        rect.x,
        rect.y,
        rect.width,
        rect.height,
      )
    }
  }
  out
}
