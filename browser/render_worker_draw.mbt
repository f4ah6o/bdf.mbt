///|
#external
priv type RenderCanvas

///|
extern "js" fn render_request_view(request : RenderRequest) -> String =
  #|(request) => String(request.view)

///|
extern "js" fn render_request_page(request : RenderRequest) -> Int32 =
  #|(request) => request.page

///|
extern "js" fn render_request_scale(request : RenderRequest) -> Double =
  #|(request) => request.scale

///|
extern "js" fn render_request_rect(
  request : RenderRequest,
  field : String,
) -> Double =
  #|(request,field) => request.viewport[field]

///|
extern "js" fn render_request_role(
  request : RenderRequest,
  role : String,
) -> Bool =
  #|(request,role) => request.roles==null||request.roles.includes(role)

///|
extern "js" fn render_request_page_buffer(request : RenderRequest) -> Bytes =
  #|(request) => new Uint8Array(request.buffer)

///|
extern "js" fn render_canvas(width : Double, height : Double) -> RenderCanvas =
  #|(width,height) => {const w=Math.max(1,Math.ceil(width)),h=Math.max(1,Math.ceil(height));if(!(w<=32767&&h<=32767&&w*h<=268435456))throw new Error(`bdf: a canvas of ${w} by ${h} pixels is too large`);return new OffscreenCanvas(w,h)}

///|
extern "js" fn render_canvas_context(
  canvas : RenderCanvas,
  scale : Double,
) -> CanvasContext =
  #|(canvas,scale) => {const ctx=canvas.getContext('2d');if(!ctx)throw new Error('Canvas 2D context unavailable');ctx.setTransform(scale,0,0,scale,0,0);return ctx}

///|
extern "js" fn render_canvas_clear(canvas : RenderCanvas) -> Unit =
  #|(canvas) => {const ctx=canvas.getContext('2d');ctx.save();ctx.setTransform(1,0,0,1,0,0);ctx.clearRect(0,0,canvas.width,canvas.height);ctx.restore()}

///|
extern "js" fn render_canvas_bitmap(canvas : RenderCanvas) -> RenderValue =
  #|(canvas) => canvas.transferToImageBitmap()

///|
extern "js" fn render_play_value(
  data : Bytes,
  cues : BrowserAudioCues,
) -> RenderValue =
  #|(data,cues) => ({seq:data.slice().buffer,cues})

///|
extern "js" fn render_audio_value(
  data : Bytes,
  media_type : String,
  cues : BrowserAudioCues,
) -> RenderValue =
  #|(data,type,cues) => ({blob:new Blob([data],{type}),cues})

///|
async fn RenderDocument::prepare_object_parts(
  self : RenderDocument,
  hash : String,
  seen : Map[String, Bool],
  depth : Int32,
) -> Unit {
  if depth > 64 {
    raise BadFormat("objects draw objects too deep")
  }
  if seen.contains(hash) {
    return
  }
  seen[hash] = true
  self.ensure(hash)
  let object = @core.decode_object_resources(self.part(hash))
  for path in object.paths {
    if path is @core.External(path_hash, _) {
      self.ensure(path_hash)
    }
  }
  for command in @render.compile_object(object.object) {
    match command {
      @render.Image(image, _, _, _, _)
      | @render.ImageSub(image, _, _, _, _, _, _, _, _) => self.ensure(image)
      @render.FillPaint(index) | @render.StrokePaint(index) => {
        if index < 0 || index >= object.paints.length() {
          raise BadFormat("paint reference out of range")
        }
        if object.paints[index] is @core.Pattern(image, _, _) {
          if image < 0 || image >= object.object.images.length() {
            raise BadFormat("pattern image reference out of range")
          }
          self.ensure(object.object.images[image])
        }
      }
      @render.Font(index, _) => {
        if index < 0 || index >= object.fonts.length() {
          raise BadFormat("font reference out of range")
        }
        if object.fonts[index].hash is Some(font) {
          self.ensure(font)
        }
      }
      @render.Use(child) | @render.UseAt(child, _, _) =>
        self.prepare_object_parts(child, seen, depth + 1)
      _ => ()
    }
  }
}

///|
async fn render_prepare_layers(
  doc : RenderDocument,
  resources : BrowserResources,
  layers : Array[@core.Layer],
) -> Unit {
  let fetched : Map[String, Bool] = {}
  let prepared : Map[String, Bool] = {}
  let browser = doc.browser_document()
  for layer in layers {
    doc.prepare_object_parts(layer.object, fetched, 0)
  }
  for layer in layers {
    prepare_object(browser, resources, layer.object, prepared, 0)
  }
}

///|
fn render_page_draw(
  context : CanvasContext,
  doc : BrowserDocument,
  page : @core.Page,
  resources : BrowserResources,
  request : RenderRequest,
) -> Unit raise {
  save(context)
  defer restore(context)
  clip_rect(context, 0.0, 0.0, page.width, page.height)
  set_color(context, -1, false)
  fill_rect(context, 0.0, 0.0, page.width, page.height)
  let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
  for layer in page.layers {
    if render_request_role(request, layer.role) {
      paint_root_object(
        context,
        doc,
        @core.decode_object_resources(doc.part(layer.object)),
        Some(resources),
        limits,
      )
    }
  }
}

///|
async fn render_page_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  let index = render_request_page(request)
  let page = match view.pages.get(index) {
    Some(page) => page
    None => raise BadFormat("bdf: no page " + index.to_string())
  }
  let resources = new_resources()
  worker_resource_rasterizer(resources)
  defer dispose_resources(resources)
  render_prepare_layers(doc, resources, page.layers)
  let scale = render_request_scale(request)
  let canvas = render_canvas(page.width * scale, page.height * scale)
  let context = render_canvas_context(canvas, scale)
  let browser = doc.browser_document()
  for _ in 0..<8 {
    render_canvas_clear(canvas)
    let result = invoke_render(() => {
      try {
        render_page_draw(context, browser, page, resources, request)
        Ok(0)
      } catch {
        error => Err(error)
      }
    }).wait()
    match result {
      Ok(_) => ()
      Err(error) => raise error
    }
    if !settle_worker_rasters(resources).wait() {
      break
    }
  }
  render_canvas_bitmap(canvas)
}

///|
async fn render_continuous_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  let viewport : @render.TextRect = {
    x: render_request_rect(request, "x"),
    y: render_request_rect(request, "y"),
    width: render_request_rect(request, "w"),
    height: render_request_rect(request, "h"),
  }
  let bands = @render.continuous_bands(view, viewport)
  let resources = new_resources()
  worker_resource_rasterizer(resources)
  defer dispose_resources(resources)
  for band in bands {
    render_prepare_layers(doc, resources, view.pages[band.index].layers)
  }
  let scale = render_request_scale(request)
  let canvas = render_canvas(viewport.width * scale, viewport.height * scale)
  let context = render_canvas_context(canvas, scale)
  let browser = doc.browser_document()
  for _ in 0..<8 {
    render_canvas_clear(canvas)
    let result = invoke_render(() => {
      try {
        draw_continuous_region(
          context, browser, view, bands, viewport, resources,
        )
        Ok(0)
      } catch {
        error => Err(error)
      }
    }).wait()
    match result {
      Ok(_) => ()
      Err(error) => raise error
    }
    if !settle_worker_rasters(resources).wait() {
      break
    }
  }
  render_canvas_bitmap(canvas)
}

///|
async fn render_sheet_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  if view.tiles.is_empty() && view.tiles_ref is Some(hash) {
    doc.ensure(hash)
  }
  let browser = doc.browser_document()
  let table = sheet_tile_table(browser, view)
  let viewport : @render.SheetViewport = {
    x: render_request_rect(request, "x"),
    y: render_request_rect(request, "y"),
    width: render_request_rect(request, "w"),
    height: render_request_rect(request, "h"),
  }
  let tiles = visible_sheet_tiles(view, table, viewport)
  let resources = new_resources()
  worker_resource_rasterizer(resources)
  defer dispose_resources(resources)
  for tile in tiles {
    render_prepare_layers(doc, resources, [
      { role: "body", object: tile.object, },
    ])
  }
  let scale = render_request_scale(request)
  let canvas = render_canvas(viewport.width * scale, viewport.height * scale)
  let context = render_canvas_context(canvas, scale)
  for _ in 0..<8 {
    render_canvas_clear(canvas)
    let result = invoke_render(() => {
      try {
        draw_sheet_region(
          context, browser, view, tiles, viewport, scale, resources,
        )
        Ok(0)
      } catch {
        error => Err(error)
      }
    }).wait()
    match result {
      Ok(_) => ()
      Err(error) => raise error
    }
    if !settle_worker_rasters(resources).wait() {
      break
    }
  }
  render_canvas_bitmap(canvas)
}

///|
async fn render_play_worker(
  doc : RenderDocument,
  view : @core.View,
  audio : Bool,
) -> RenderValue {
  guard view.play is Some(play) else { return render_null() }
  let hash = if audio { play.audio } else { play.seq }
  guard hash is Some(hash) else { return render_null() }
  doc.ensure(hash)
  let cues = match play.cues {
    Some(hash) => {
      doc.ensure(hash)
      Some(@core.decode_cues(doc.part(hash)))
    }
    None => None
  }
  let bytes = doc.part(hash)
  if audio {
    render_audio_value(
      bytes,
      @core.audio_media_type(play.media_type),
      audio_cues_from_core(cues),
    )
  } else {
    render_play_value(bytes, audio_cues_from_core(cues))
  }
}
