///|
extern "js" fn viewer_renderer_open(
  renderer : BrowserRenderClient,
  source : RenderSourceInput,
  password : CryptoCredential,
) -> @js_async.Promise[RenderValue] =
  #|(renderer,source,password) => renderer.open(source,password)

///|
extern "js" fn viewer_renderer_close(
  renderer : BrowserRenderClient,
) -> @js_async.Promise[Unit] =
  #|(renderer) => renderer.close()

///|
extern "js" fn viewer_renderer_page(
  renderer : BrowserRenderClient,
  view : String,
  page : Int32,
  scale : Double,
) -> @js_async.Promise[ViewerBitmap] =
  #|(renderer,view,page,scale) => renderer.page(view,page,scale)

///|
extern "js" fn viewer_dom_set_layout(dom : ViewerDom, layout : String) -> Unit =
  #|(dom,layout) => {dom.layout=layout}

///|
extern "js" fn viewer_callback_ignore(
  promise : @js_async.Promise[Unit],
) -> Unit =
  #|(promise) => {promise.catch(()=>{})}

///|
priv struct ViewerController {
  dom : ViewerDom
  renderer : BrowserRenderClient
  options : BrowserViewerOptions
  viewer : @viewer.Viewer
  mut manifest : @core.Manifest?
  mut current : @core.View?
  mut generation : Int32
  mut sheet_request : Int32
  mut music_mode : String
  mut document_serial : Int32
  mut active_stream : ViewerStream?
  mut find_hits : ViewerHits?
  mut find_cache : ViewerFindCache?
  mut find_query : String
  mut find_index : Int32
  mut find_more : Bool
  mut find_turn : Int32
  mut find_stale : Bool
  mut partial : Bool
}

///|
async fn ViewerController::open(
  self : ViewerController,
  source : RenderSourceInput,
  password : CryptoCredential,
) -> RenderValue {
  self.document_serial += 1
  self.cancel_stream()
  self.generation += 1
  let generation = self.generation
  viewer_dom_clear(self.dom)
  self.drop_find()
  viewer_bar_reset(self.dom)
  self.partial = render_source_kind(source) == "segments"
  viewer_remember(self.dom, viewer_renderer_close(self.renderer)).wait()
  let value = viewer_remember(
    self.dom,
    viewer_renderer_open(self.renderer, source, password),
  ).wait()
  if generation != self.generation {
    return value
  }
  self.manifest = Some(@core.parse_manifest(viewer_raw_string(value)))
  viewer_dom_manifest(self.dom, value)
  self.set_view(viewer_raw_first_view(value))
  viewer_dom_event(self.dom, "documentchange", value)
  value
}

///|
fn ViewerController::set_view(self : ViewerController, id : String) -> Unit {
  let mut selected : @core.View? = None
  if self.manifest is Some(manifest) {
    for view in manifest.views {
      if view.id == id {
        selected = Some(view)
        break
      }
    }
  }
  let old_id = match self.current {
    Some(view) => view.id
    None => ""
  }
  let new_id = match selected {
    Some(view) => view.id
    None => ""
  }
  if old_id != new_id {
    self.drop_find()
  }
  self.current = selected
  viewer_dom_set_view(self.dom, id)
  if selected is None {
    viewer_dom_clear(self.dom)
    return
  }
  self.draw()
  viewer_dom_view_event(self.dom)
}

///|
fn ViewerController::set_layout(
  self : ViewerController,
  layout : String,
) -> Unit {
  self.viewer.layout = match layout {
    "spread" => @viewer.Spread
    "continuous" => @viewer.Continuous
    _ => @viewer.Single
  }
  viewer_dom_set_layout(self.dom, layout)
  self.draw()
}

///|
fn ViewerController::set_zoom(self : ViewerController, zoom : Double) -> Unit {
  self.viewer.zoom = zoom
  self.draw()
}

///|
fn ViewerController::set_music(self : ViewerController, mode : String) -> Unit {
  self.music_mode = mode
  if mode == "piano-roll" &&
    self.current is Some(view) &&
    view.play is Some(play) &&
    play.seq is Some(_) &&
    viewer_has_music(self.options) {
    self.drop_find()
    viewer_bar_reset(self.dom)
  }
  self.draw()
}

///|
fn ViewerController::draw(self : ViewerController) -> Unit {
  viewer_dom_clear(self.dom)
  guard self.current is Some(view) else { return }
  self.generation += 1
  let generation = self.generation
  let piano = self.music_mode == "piano-roll" &&
    view.play is Some(play) &&
    play.seq is Some(_) &&
    viewer_has_music(self.options)
  viewer_dom_searchable(self.dom, !piano)
  if view.kind == "sheet" {
    self.draw_sheet(view, generation)
    return
  }
  if piano {
    viewer_callback_ignore(
      @js_async.Promise::from_async(() => self.draw_music(view, generation)),
    )
    return
  }
  viewer_dom_background(self.dom, false)
  viewer_dom_observe(self.dom, (index, canvas) => {
    viewer_callback_ignore(
      @js_async.Promise::from_async(() => {
        self.render_page(view, index, canvas, generation)
      }),
    )
    viewer_callback_ignore(
      @js_async.Promise::from_async(() => self.mark_find_background()),
    )
  })
  let spread = self.viewer.layout == @viewer.Spread && view.kind != "scroll"
  let gap = if self.viewer.layout == @viewer.Continuous || view.kind == "scroll" {
    0
  } else {
    16
  }
  let mut row : ViewerRow? = None
  for index, page in view.pages {
    if !spread || index % 2 == 0 {
      row = Some(
        viewer_dom_row(self.dom, gap, spread && view.direction == "rtl"),
      )
    }
    if row is Some(row) {
      viewer_dom_page(
        self.dom,
        row,
        index,
        page.width * self.viewer.zoom,
        page.height * self.viewer.zoom,
      )
    }
  }
}

///|
async fn ViewerController::render_page(
  self : ViewerController,
  view : @core.View,
  index : Int32,
  canvas : ViewerCanvas,
  generation : Int32,
) -> Unit {
  let request = viewer_canvas_start(canvas)
  if request < 0 {
    return
  }
  try {
    let bitmap = viewer_remember(
      self.dom,
      viewer_renderer_page(
        self.renderer,
        view.id,
        index,
        self.viewer.zoom * viewer_pixel_ratio(),
      ),
    ).wait()
    viewer_canvas_finish(canvas, bitmap, request, generation == self.generation)
  } catch {
    error => {
      viewer_canvas_error(canvas)
      viewer_dom_failure(self.dom, error.to_string())
    }
  }
}

///|
fn ViewerController::destroy(self : ViewerController) -> Unit {
  self.document_serial += 1
  self.cancel_stream()
  self.generation += 1
  viewer_dom_clear(self.dom)
  viewer_dom_destroy(self.dom)
}
