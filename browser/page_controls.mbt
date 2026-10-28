///|
// Prepare a replacement set of page bitmaps before changing the mounted DOM.
extern "js" fn page_scratch_surface(host : BrowserHost) -> BrowserHost =
  #|(host) => (host.ownerDocument ?? document).createElement('div')

///|
extern "js" fn replace_page_canvases(
  surface : BrowserHost,
  scratch : BrowserHost,
) -> Unit =
  #|(surface,scratch) => {
  #|  const old=[...surface.querySelectorAll('canvas[data-bdf-page-index]')],next=[...scratch.querySelectorAll('canvas[data-bdf-page-index]')];
  #|  if(old.length!==next.length)throw new Error('page canvas count changed');
  #|  for(let i=0;i<old.length;i++)old[i].replaceWith(next[i]);
  #|}

///|
extern "js" fn scale_page_text(
  surface : BrowserHost,
  index : Int32,
  scale : Double,
) -> Unit =
  #|(surface,index,scale) => {const el=surface.querySelector(`[data-bdf-layer][data-bdf-page-index="${index}"]`);if(el){el.style.transformOrigin='0 0';el.style.transform=`scale(${scale})`}}

///|
// Each upstream row has a bottom margin, including the final row.
fn page_surface_height(
  view : @core.View,
  viewer : @viewer.Viewer,
  bottom : Double,
) -> Double {
  if !view.pages.is_empty() &&
    view.kind != "scroll" &&
    viewer.layout != @viewer.Continuous {
    bottom + 16.0
  } else {
    bottom
  }
}

///|
fn update_page_layout(
  host : BrowserHost,
  surface : BrowserHost,
  view : @core.View,
  viewer : @viewer.Viewer,
  placements : Array[@viewer.Placement],
  width : Double,
) -> Unit {
  let next = viewer.placements_in(view, width)
  let mut right = width
  let mut bottom = 0.0
  for i, p in next {
    placements[i] = p
    move_page_children(surface, p.index, p.x, p.y)
    resize_page_canvas(surface, p.index, p.width, p.height)
    scale_page_text(surface, p.index, viewer.zoom)
    if p.x + p.width > right {
      right = p.x + p.width
    }
    if p.y + p.height > bottom {
      bottom = p.y + p.height
    }
  }
  resize_page_surface(surface, right, page_surface_height(view, viewer, bottom))
  refresh_page_find(host)
}

///|
fn redraw_page_zoom(
  host : BrowserHost,
  surface : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  viewer : @viewer.Viewer,
  placements : Array[@viewer.Placement],
  resources : BrowserResources?,
  zoom : Double,
) -> Unit raise {
  for page in view.pages {
    validate_page_bitmap(host, page.width * zoom, page.height * zoom)
  }
  let scratch = page_scratch_surface(host)
  for index, page in view.pages {
    let ctx = make_page_canvas(
      scratch,
      0.0,
      0.0,
      page.width * zoom,
      page.height * zoom,
      zoom,
    )
    tag_page_child(scratch, index)
    set_color(ctx, -1, false)
    fill_rect(ctx, 0.0, 0.0, page.width, page.height)
    let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
    for layer in page.layers {
      let object = @core.decode_object_resources(document.part(layer.object))
      paint_root_object(ctx, document, object, resources, limits)
    }
  }
  replace_page_canvases(surface, scratch)
  viewer.zoom = zoom
  update_page_layout(
    host,
    surface,
    view,
    viewer,
    placements,
    page_viewport_width(host),
  )
}

///|
extern "js" fn throw_page_control_error(message : String) -> Unit =
  #|(message) => { throw new Error(message); }

///|
extern "js" fn set_page_zoom(host : BrowserHost, zoom : Double) -> Unit =
  #|(host,zoom) => {if(!Number.isFinite(zoom)||zoom<=0||zoom>8)throw new RangeError('zoom must be in (0, 8]');const page=host[Symbol.for('f4ah6o.bdf.pageLayout')],sheet=host[Symbol.for('f4ah6o.bdf.sheet')];if(page)page.zoom(zoom);else if(sheet)sheet.setZoom(zoom);else throw new Error('BDF view is not mounted')}

///|
/// Set a mounted page or sheet view's zoom in the range (0, 8].
#export_name("bdf_set_zoom")
pub fn bdf_set_zoom(host : BrowserHost, zoom : Double) -> Unit {
  set_page_zoom(host, zoom)
}

///|
extern "js" fn set_page_layout(host : BrowserHost, layout : String) -> Unit =
  #|(host,layout) => {const page=host[Symbol.for('f4ah6o.bdf.pageLayout')],sheet=host[Symbol.for('f4ah6o.bdf.sheet')];if(page)page.layout(layout);else if(sheet)sheet.setLayout();else throw new Error('BDF view is not mounted')}

///|
/// Change the mounted page layout to single, spread, or continuous.
#export_name("bdf_set_layout")
pub fn bdf_set_layout(host : BrowserHost, layout : String) -> Unit {
  set_page_layout(host, layout)
}

///|
extern "js" fn scroll_page_into_view(host : BrowserHost, index : Int32) -> Unit =
  #|(host,index) => {if(!Number.isInteger(index))return;host.querySelector(`canvas[data-bdf-page-index="${index}"]`)?.scrollIntoView({block:'start'})}

///|
/// Scroll to a zero-based page index; indices outside the view are ignored.
#export_name("bdf_scroll_to_page")
pub fn bdf_scroll_to_page(host : BrowserHost, index : Int32) -> Unit {
  scroll_page_into_view(host, index)
}
