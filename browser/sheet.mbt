///|
extern "js" fn sheet_grid_begin(ctx : CanvasContext, scale : Double) -> Unit =
  #|(ctx,scale) => {ctx.save();ctx.strokeStyle='#d9d9d9';ctx.lineWidth=1/scale;ctx.beginPath()}

///|
extern "js" fn sheet_grid_line(
  ctx : CanvasContext,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit =
  #|(ctx,x0,y0,x1,y1) => {ctx.moveTo(x0,y0);ctx.lineTo(x1,y1)}

///|
extern "js" fn sheet_grid_end(ctx : CanvasContext) -> Unit =
  #|(ctx) => {ctx.stroke();ctx.restore()}

///|
#external
priv type SheetRequest

///|
extern "js" fn begin_sheet_request(host : BrowserHost) -> SheetRequest =
  #|(host) => {const value={};host[Symbol.for('f4ah6o.bdf.sheetPending')]=value;return value}

///|
extern "js" fn current_sheet_request(
  host : BrowserHost,
  request : SheetRequest,
) -> Bool =
  #|(host,request) => host[Symbol.for('f4ah6o.bdf.sheetPending')]===request

///|
extern "js" fn end_sheet_request(
  host : BrowserHost,
  request : SheetRequest,
) -> Unit =
  #|(host,request) => {const key=Symbol.for('f4ah6o.bdf.sheetPending');if(host[key]===request)delete host[key]}

///|
fn sheet_viewport(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @render.SheetViewport raise {
  if x.is_nan() ||
    y.is_nan() ||
    width.is_nan() ||
    height.is_nan() ||
    scale.is_nan() ||
    x.is_inf() ||
    y.is_inf() ||
    width.is_inf() ||
    height.is_inf() ||
    scale.is_inf() ||
    width <= 0.0 ||
    height <= 0.0 ||
    scale <= 0.0 ||
    width * scale > 8192.0 ||
    height * scale > 8192.0 ||
    width * height * scale * scale > 16777216.0 {
    raise BadFormat("invalid sheet viewport")
  }
  { x, y, width, height, }
}

///|
fn sheet_view(document : BrowserDocument) -> @core.View raise {
  if document.manifest.views.length() == 0 ||
    document.manifest.views[0].kind != "sheet" {
    raise Unsupported("document has no sheet view")
  }
  document.manifest.views[0]
}

///|
fn sheet_tile_table(
  document : BrowserDocument,
  view : @core.View,
) -> Array[@core.Tile] raise {
  if !view.tiles.is_empty() {
    return view.tiles
  }
  match view.tiles_ref {
    Some(hash) => @core.decode_tile_index(document.part(hash))
    None => []
  }
}

///|
fn visible_sheet_tiles(
  view : @core.View,
  tiles : Array[@core.Tile],
  viewport : @render.SheetViewport,
) -> Array[@core.Tile] {
  @render.sheet_tiles_in(tiles, [
    @render.sheet_tile_range(viewport, view.tile_size),
  ])
}

///|
fn draw_sheet_region(
  ctx : CanvasContext,
  document : BrowserDocument,
  view : @core.View,
  tiles : Array[@core.Tile],
  viewport : @render.SheetViewport,
  scale : Double,
  resources : BrowserResources,
) -> Unit raise {
  save(ctx)
  defer restore(ctx)
  translate(ctx, -viewport.x, -viewport.y)
  set_color(ctx, -1, false)
  fill_rect(ctx, viewport.x, viewport.y, viewport.width, viewport.height)
  if view.gridlines {
    sheet_grid_begin(ctx, scale)
    @render.sheet_grid_lines(view, viewport, scale, (x0, y0, x1, y1) => {
      sheet_grid_line(ctx, x0, y0, x1, y1)
    })
    sheet_grid_end(ctx)
  }
  let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
  for tile in tiles {
    let object = @core.decode_object_resources(document.part(tile.object))
    save(ctx)
    translate(
      ctx,
      tile.x.to_double() * view.tile_size,
      tile.y.to_double() * view.tile_size,
    )
    clip_rect(ctx, 0.0, 0.0, view.tile_size, view.tile_size)
    paint_root_object(ctx, document, object, Some(resources), limits)
    restore(ctx)
  }
}

///|
async fn render_sheet_single(
  host : BrowserHost,
  data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> Int32 {
  let request = begin_sheet_request(host)
  defer end_sheet_request(host, request)
  let viewport = sheet_viewport(x, y, width, height, scale)
  let document = single_document(@core.open_single(data))
  let view = sheet_view(document)
  let tiles = visible_sheet_tiles(
    view,
    sheet_tile_table(document, view),
    viewport,
  )
  let resources = new_resources()
  defer dispose_resources(resources)
  let seen : Map[String, Bool] = Map([])
  for tile in tiles {
    prepare_object(document, resources, tile.object, seen, 0)
  }
  let result = invoke_render(() => {
    try {
      if !current_sheet_request(host, request) {
        raise BadFormat("sheet render superseded")
      }
      clear_host(host)
      let ctx = make_canvas(
        host,
        0.0,
        0.0,
        width * scale,
        height * scale,
        scale,
      )
      draw_sheet_region(ctx, document, view, tiles, viewport, scale, resources)
      resize_host(host, width * scale, height * scale)
      Ok(tiles.length())
    } catch {
      error => Err(error)
    }
  }).wait()
  match result {
    Ok(n) => n
    Err(error) => raise error
  }
}

///|
/// Draw a viewport of the first sheet view in a single-file BDF.
#export_name("render_bdf_sheet_region_async")
pub fn render_bdf_sheet_region_async(
  host : BrowserHost,
  data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    render_sheet_single(host, data, x, y, width, height, scale)
  })
}

///|
async fn render_sheet_split(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> Int32 {
  let request = begin_sheet_request(host)
  defer end_sheet_request(host, request)
  let viewport = sheet_viewport(x, y, width, height, scale)
  let cache : Map[String, Bytes] = Map([])
  let split = @core.open_split(manifest, (hash, _) => {
    match cache.get(hash) {
      Some(data) => data
      None => raise BadFormat("split part not loaded")
    }
  })
  let document : BrowserDocument = {
    manifest: split.manifest,
    load: hash => split.part(hash),
  }
  let view = sheet_view(document)
  if view.tiles.is_empty() && view.tiles_ref is Some(hash) {
    prefetch_part(split, cache, loader, hash)
  }
  let tiles = visible_sheet_tiles(
    view,
    sheet_tile_table(document, view),
    viewport,
  )
  let fetched : Map[String, Bool] = Map([])
  for tile in tiles {
    prefetch_split_object(split, cache, loader, tile.object, fetched, 0)
  }
  let resources = new_resources()
  defer dispose_resources(resources)
  let seen : Map[String, Bool] = Map([])
  for tile in tiles {
    prepare_object(document, resources, tile.object, seen, 0)
  }
  let result = invoke_render(() => {
    try {
      if !current_sheet_request(host, request) {
        raise BadFormat("sheet render superseded")
      }
      clear_host(host)
      let ctx = make_canvas(
        host,
        0.0,
        0.0,
        width * scale,
        height * scale,
        scale,
      )
      draw_sheet_region(ctx, document, view, tiles, viewport, scale, resources)
      resize_host(host, width * scale, height * scale)
      Ok(tiles.length())
    } catch {
      error => Err(error)
    }
  }).wait()
  match result {
    Ok(n) => n
    Err(error) => raise error
  }
}

///|
/// Draw a sheet viewport from a split BDF, fetching only intersecting tiles.
#export_name("render_bdf_sheet_region_split_async")
pub fn render_bdf_sheet_region_split_async(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    render_sheet_split(host, manifest, loader, x, y, width, height, scale)
  })
}
