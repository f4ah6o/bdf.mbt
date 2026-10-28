///|
extern "js" fn render_measure_context() -> FindMeasure =
  #|() => new OffscreenCanvas(1,1).getContext('2d')

///|
fn render_measure(
  context : FindMeasure,
  font : @core.Font,
  size : Double,
  text : String,
) -> Double {
  measure_find_text(
    context,
    find_font_family(font),
    font.weight,
    font.style,
    size,
    text,
  )
}

///|
async fn RenderDocument::prepare_text_parts(
  self : RenderDocument,
  hash : String,
  seen : Map[String, Bool],
  depth : Int32,
  fonts~ : Bool = true,
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
  for command in @render.compile_object(object.object) {
    match command {
      @render.Font(index, _) => {
        if index < 0 || index >= object.fonts.length() {
          raise BadFormat("font reference out of range")
        }
        if fonts && object.fonts[index].hash is Some(font) {
          self.ensure(font)
        }
      }
      @render.Use(child) | @render.UseAt(child, _, _) =>
        self.prepare_text_parts(child, seen, depth + 1, fonts~)
      _ => ()
    }
  }
}

///|
async fn render_prepare_text(
  doc : RenderDocument,
  resources : BrowserResources,
  layers : Array[@core.Layer],
) -> Unit {
  let fetched : Map[String, Bool] = {}
  let prepared : Map[String, Bool] = {}
  let browser = doc.browser_document()
  for layer in layers {
    doc.prepare_text_parts(layer.object, fetched, 0)
  }
  for layer in layers {
    prepare_search_object(browser, resources, layer.object, prepared, 0)
  }
}

///|
fn render_empty_content() -> @render.TextContent {
  { runs: [], nodes: [], links: [], }
}

///|
fn render_append_content(
  output : @render.TextContent,
  content : @render.TextContent,
) -> Unit {
  let nodes = output.nodes.length()
  let runs = output.runs.length()
  for node in content.nodes {
    output.nodes.push({
      ..node,
      parent: if node.parent < 0 {
        node.parent
      } else {
        node.parent + nodes
      },
    })
  }
  for run in content.runs {
    output.runs.push({
      ..run,
      node: if run.node < 0 {
        run.node
      } else {
        run.node + nodes
      },
    })
  }
  for link in content.links {
    output.links.push({
      ..link,
      after: link.after + runs,
      node: if link.node < 0 {
        link.node
      } else {
        link.node + nodes
      },
    })
  }
}

///|
fn render_inside(
  rect : @render.TextRect,
  x : Double,
  y : Double,
  dx : Double,
  dy : Double,
) -> Bool {
  x - dx >= rect.x &&
  x - dx < rect.x + rect.width &&
  y - dy >= rect.y &&
  y - dy <= rect.y + rect.height
}

///|
fn render_within(
  content : @render.TextContent,
  rect : @render.TextRect,
  dx : Double,
  dy : Double,
) -> @render.TextContent {
  let runs : Array[@render.TextRun] = []
  let kept : Array[Int32] = []
  for run in content.runs {
    if render_inside(rect, run.x, run.y, dx, dy) {
      runs.push(run)
    }
    kept.push(runs.length() - 1)
  }
  let links : Array[@render.TextLink] = []
  for link in content.links {
    if render_inside(
        rect,
        link.x + link.width / 2.0,
        link.y + link.height / 2.0,
        dx,
        dy,
      ) {
      links.push({
        ..link,
        after: if link.after >= 0 {
          kept[link.after]
        } else {
          -1
        },
      })
    }
  }
  { runs, nodes: content.nodes, links, }
}

///|
fn render_extract_layers(
  doc : RenderDocument,
  layers : Array[@core.Layer],
  measure : FindMeasure,
  matrix : @render.Matrix,
  continuous : Bool,
  measure_advance~ : Bool = true,
) -> @render.TextContent raise {
  let output = render_empty_content()
  for layer in layers {
    if continuous && layer.role != "body" && layer.role != "annotation" {
      continue
    }
    let object = @core.decode_object_resources(doc.part(layer.object))
    let content = @render.extract_text(
      object,
      hash => Some(@core.decode_object_resources(doc.part(hash))),
      matrix~,
    )
    let runs : Array[@render.TextRun] = []
    for run in content.runs {
      if measure_advance &&
        run.advance == 0.0 &&
        run.font is Some(font) &&
        run.text != "" &&
        !run.alt_text {
        runs.push({
          ..run,
          advance: render_measure(measure, font, run.size, run.text),
        })
      } else {
        runs.push(run)
      }
    }
    render_append_content(output, { ..content, runs, })
  }
  output
}

///|
extern "js" fn render_content_new() -> RenderValue =
  #|() => ({runs:[],nodes:[],links:[]})

///|
extern "js" fn render_add_node(
  out : RenderValue,
  kind : String,
  parent : Int32,
) -> Int32 =
  #|(out,kind,parent) => out.nodes.push({kind,parent})-1

///|
extern "js" fn render_node_int(
  out : RenderValue,
  index : Int32,
  key : String,
  value : Int32,
) -> Unit =
  #|(out,index,key,value) => {out.nodes[index][key]=value}

///|
extern "js" fn render_node_string(
  out : RenderValue,
  index : Int32,
  key : String,
  value : String,
) -> Unit =
  #|(out,index,key,value) => {out.nodes[index][key]=value}

///|
extern "js" fn render_node_code(out : RenderValue, index : Int32) -> Unit =
  #|(out,index) => {out.nodes[index].code=true}

///|
extern "js" fn render_node_bounds(
  out : RenderValue,
  index : Int32,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(out,index,x,y,w,h) => {out.nodes[index].bounds={x,y,w,h}}

///|
extern "js" fn render_add_run(
  out : RenderValue,
  text : String,
  x : Double,
  y : Double,
  advance : Double,
  size : Double,
  align : Int32,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
  sep : Int32,
  ordinal : Int32,
  alt : Bool,
  lang : String,
  node : Int32,
  has_font : Bool,
  hash : String,
  family : String,
  weight : Int32,
  style : Int32,
) -> Unit =
  #|(out,text,x,y,advance,size,align,a,b,c,d,e,f,sep,ordinal,altText,lang,node,hasFont,hash,family,weight,style) => {const font=hasFont?{kind:hash?0:1,hash:hash||undefined,family,weight,style}:undefined,run={text,advance,size,font,align,matrix:[a,b,c,d,e,f],altText,x,y,sep,ordinal,node};if(lang)run.lang=lang;out.runs.push(run)}

///|
extern "js" fn render_add_link(
  out : RenderValue,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  url : String,
  after : Int32,
  node : Int32,
) -> Unit =
  #|(out,x,y,w,h,url,after,node) => out.links.push({x,y,w,h,url,after,node})

///|
extern "js" fn render_content_runs(out : RenderValue) -> RenderValue =
  #|(out) => out.runs

///|
fn render_content_value(
  content : @render.TextContent,
  runs_only : Bool,
) -> RenderValue {
  let out = render_content_new()
  for node in content.nodes {
    let i = render_add_node(out, node.kind, node.parent)
    if node.level is Some(v) {
      render_node_int(out, i, "level", v)
    }
    if node.row is Some(v) {
      render_node_int(out, i, "row", v)
    }
    if node.col is Some(v) {
      render_node_int(out, i, "col", v)
    }
    if node.rows is Some(v) {
      render_node_int(out, i, "rows", v)
    }
    if node.cols is Some(v) {
      render_node_int(out, i, "cols", v)
    }
    if node.scope is Some(v) {
      render_node_string(out, i, "scope", v)
    }
    if node.alt is Some(v) {
      render_node_string(out, i, "alt", v)
    }
    if node.data is Some(v) {
      render_node_string(out, i, "data", v)
    }
    if node.code {
      render_node_code(out, i)
    }
    if node.quote > 0 {
      render_node_int(out, i, "quote", node.quote)
    }
    if node.list is Some(v) {
      render_node_string(out, i, "list", v)
    }
    if node.bounds is Some(v) {
      render_node_bounds(out, i, v.x, v.y, v.width, v.height)
    }
  }
  for run in content.runs {
    let (a, b, c, d, e, f) = run.matrix
    let (has_font, hash, family, weight, style) = match run.font {
      Some(font) =>
        (true, font.hash.unwrap_or(""), font.family, font.weight, font.style)
      None => (false, "", "", 0, 0)
    }
    render_add_run(
      out,
      run.text,
      run.x,
      run.y,
      run.advance,
      run.size,
      run.align,
      a,
      b,
      c,
      d,
      e,
      f,
      run.separator,
      run.ordinal,
      run.alt_text,
      run.lang,
      run.node,
      has_font,
      hash,
      family,
      weight,
      style,
    )
  }
  for link in content.links {
    render_add_link(
      out,
      link.x,
      link.y,
      link.width,
      link.height,
      link.url,
      link.after,
      link.node,
    )
  }
  if runs_only {
    render_content_runs(out)
  } else {
    out
  }
}

///|
extern "js" fn render_viewport_count(request : RenderRequest) -> Int32 =
  #|(request) => Array.isArray(request.viewport)?request.viewport.length:1

///|
extern "js" fn render_viewport_field(
  request : RenderRequest,
  index : Int32,
  key : String,
) -> Double =
  #|(request,index,key) => (Array.isArray(request.viewport)?request.viewport[index]:request.viewport)[key]

///|
async fn render_page_content_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
  runs_only : Bool,
) -> RenderValue {
  let index = render_request_page(request)
  let page = match view.pages.get(index) {
    Some(page) => page
    None => raise BadFormat("bdf: no page " + index.to_string())
  }
  let resources = new_resources()
  defer dispose_resources(resources)
  render_prepare_text(doc, resources, page.layers)
  render_content_value(
    render_extract_layers(
      doc,
      page.layers,
      render_measure_context(),
      (1.0, 0.0, 0.0, 1.0, 0.0, 0.0),
      false,
    ),
    runs_only,
  )
}

///|
async fn render_continuous_content_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
  runs_only : Bool,
) -> RenderValue {
  let viewport : @render.TextRect = {
    x: render_request_rect(request, "x"),
    y: render_request_rect(request, "y"),
    width: render_request_rect(request, "w"),
    height: render_request_rect(request, "h"),
  }
  let bands = @render.continuous_bands(view, viewport)
  let resources = new_resources()
  defer dispose_resources(resources)
  let measure = render_measure_context()
  let output = render_empty_content()
  for band in bands {
    let page = view.pages[band.index]
    render_prepare_text(doc, resources, page.layers)
    let body = band.body
    let dx = -body.x - viewport.x
    let dy = band.offset - body.y - viewport.y
    let content = render_extract_layers(
      doc,
      page.layers,
      measure,
      (1.0, 0.0, 0.0, 1.0, dx, dy),
      true,
    )
    render_append_content(
      output,
      render_within(
        content,
        { x: body.x, y: body.y, width: body.width, height: body.height, },
        dx,
        dy,
      ),
    )
  }
  render_content_value(output, runs_only)
}

///|
async fn render_sheet_content_worker(
  doc : RenderDocument,
  view : @core.View,
  request : RenderRequest,
) -> RenderValue {
  if view.tiles.is_empty() && view.tiles_ref is Some(hash) {
    doc.ensure(hash)
  }
  let tiles = sheet_tile_table(doc.browser_document(), view)
  let ranges : Array[@render.TileRange] = []
  for i in 0..<render_viewport_count(request) {
    let viewport : @render.SheetViewport = {
      x: render_viewport_field(request, i, "x"),
      y: render_viewport_field(request, i, "y"),
      width: render_viewport_field(request, i, "w"),
      height: render_viewport_field(request, i, "h"),
    }
    if viewport.width > 0.0 && viewport.height > 0.0 {
      ranges.push(@render.sheet_tile_range(viewport, view.tile_size))
    }
  }
  let visible = @render.sheet_tiles_in(tiles, ranges)
  let resources = new_resources()
  defer dispose_resources(resources)
  let output = render_empty_content()
  let measure = render_measure_context()
  for tile in visible {
    let layers : Array[@core.Layer] = [{ role: "body", object: tile.object, }]
    render_prepare_text(doc, resources, layers)
    let dx = tile.x.to_double() * view.tile_size
    let dy = tile.y.to_double() * view.tile_size
    let content = render_extract_layers(
      doc,
      layers,
      measure,
      (1.0, 0.0, 0.0, 1.0, dx, dy),
      false,
      measure_advance=false,
    )
    render_append_content(
      output,
      render_within(
        content,
        {
          x: 0.0,
          y: 0.0,
          width: view.tile_size,
          height: view.tile_size - 0.000001,
        },
        dx,
        dy,
      ),
    )
  }
  render_content_value(output, false)
}
