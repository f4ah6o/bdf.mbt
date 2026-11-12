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
extern "js" fn viewer_renderer_content(
  renderer : BrowserRenderClient,
  view : String,
  page : Int32,
) -> @js_async.Promise[RenderValue] =
  #|(renderer,view,page) => typeof renderer.content==='function' ? renderer.content(view,page) : Promise.resolve(null)

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
  let other = old_id != new_id
  if other {
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
  // the find bar goes on with its query in the view that came
  if other && viewer_bar_shown(self.dom) {
    let query = viewer_bar_query(self.dom)
    if query != "" {
      viewer_callback_ignore(
        @js_async.Promise::from_async(() => self.find_background(query)),
      )
    }
  }
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
  viewer_dom_observe(
    self.dom,
    (index, canvas) => {
      viewer_callback_ignore(
        @js_async.Promise::from_async(() => {
          self.render_page(view, index, canvas, generation)
        }),
      )
      viewer_callback_ignore(
        @js_async.Promise::from_async(() => self.mark_find_background()),
      )
    },
    (index, canvas) =>
      @js_async.Promise::from_async(() => {
        self.prepare_selection_page(view, index, canvas, generation)
      }),
  )
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
  let revision = viewer_canvas_revision(canvas)
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
    let current = generation == self.generation &&
      viewer_canvas_request_matches(canvas, request, revision)
    let valid = current && viewer_canvas_revision_current(canvas, revision)
    viewer_canvas_finish(canvas, bitmap, request, valid)
    if current && !valid {
      viewer_canvas_error(canvas)
    }
    if valid {
      let content = viewer_remember(
        self.dom,
        viewer_renderer_content(self.renderer, view.id, index),
      ).wait() catch {
        error => {
          viewer_forget_error(self.dom, error.to_string())
          render_null()
        }
      }
      let data = text_layer_from_content(content)
      if generation == self.generation &&
        viewer_canvas_request_matches(canvas, request, revision) {
        if !viewer_canvas_revision_current(canvas, revision) {
          viewer_canvas_error(canvas)
        } else if view.pages.get(index) is Some(page) {
          let zoom = self.viewer.zoom
          viewer_canvas_mount_text(canvas, data, viewer_content_ready(content), frame => {
            render_text_layer(
              frame,
              data,
              0.0,
              0.0,
              page.width * zoom,
              page.height * zoom,
              zoom,
            )
          })
        }
      }
    }
  } catch {
    error => {
      if generation == self.generation &&
        viewer_canvas_request_matches(canvas, request, revision) {
        viewer_canvas_error(canvas)
        if viewer_canvas_revision_current(canvas, revision) {
          viewer_dom_failure(self.dom, error.to_string())
        } else {
          viewer_forget_error(self.dom, error.to_string())
        }
      } else {
        viewer_forget_error(self.dom, error.to_string())
      }
    }
  }
}

///|
/// Mount only the selectable text layer of a page whose content is not yet
/// loaded, for copies that span pages outside the rendered region. A stale
/// generation discards the result.
async fn ViewerController::prepare_selection_page(
  self : ViewerController,
  view : @core.View,
  index : Int32,
  canvas : ViewerCanvas,
  generation : Int32,
) -> Unit {
  let revision = viewer_canvas_revision(canvas)
  let content = viewer_remember(
    self.dom,
    viewer_renderer_content(self.renderer, view.id, index),
  ).wait() catch {
    error => {
      viewer_forget_error(self.dom, error.to_string())
      raise error
    }
  }
  if generation != self.generation ||
    !viewer_canvas_revision_current(canvas, revision) {
    return
  }
  let data = text_layer_from_content(content)
  if view.pages.get(index) is Some(page) {
    let zoom = self.viewer.zoom
    viewer_canvas_mount_text(
      canvas,
      data,
      viewer_content_ready(content),
      frame => {
        render_text_layer(
          frame,
          data,
          0.0,
          0.0,
          page.width * zoom,
          page.height * zoom,
          zoom,
        )
      },
    )
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
