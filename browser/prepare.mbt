///|
async fn prepare_image(
  doc : BrowserDocument,
  resources : BrowserResources,
  hash : String,
) -> Unit {
  if !has_image(resources, hash) {
    load_image(resources, hash, doc.part(hash)).wait()
  }
}

///|
async fn prepare_object(
  doc : BrowserDocument,
  resources : BrowserResources,
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
  let object = @core.decode_object_resources(doc.part(hash))
  let commands = @render.compile_object(object.object)
  for command in commands {
    match command {
      @render.Image(image, _, _, _, _)
      | @render.ImageSub(image, _, _, _, _, _, _, _, _) =>
        prepare_image(doc, resources, image)
      @render.FillPaint(index) | @render.StrokePaint(index) => {
        if index < 0 || index >= object.paints.length() {
          raise BadFormat("paint reference out of range")
        }
        match object.paints[index] {
          @core.Pattern(image, _, _) => {
            if image < 0 || image >= object.object.images.length() {
              raise BadFormat("pattern image reference out of range")
            }
            prepare_image(doc, resources, object.object.images[image])
          }
          @core.Gradient(_, _, _) => ()
        }
      }
      @render.Font(index, _) => {
        if index < 0 || index >= object.fonts.length() {
          raise BadFormat("font reference out of range")
        }
        if object.fonts[index].hash is Some(font) && !has_font(resources, font) {
          load_font(resources, font, doc.part(font)).wait()
        }
      }
      @render.Use(child) | @render.UseAt(child, _, _) =>
        prepare_object(doc, resources, child, seen, depth + 1)
      _ => ()
    }
  }
}

///|
async fn prepare_search_object(
  doc : BrowserDocument,
  resources : BrowserResources,
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
  let object = @core.decode_object_resources(doc.part(hash))
  for command in @render.compile_object(object.object) {
    match command {
      @render.Font(index, _) => {
        if index < 0 || index >= object.fonts.length() {
          raise BadFormat("font reference out of range")
        }
        if object.fonts[index].hash is Some(font) && !has_font(resources, font) {
          load_font(resources, font, doc.part(font)).wait()
        }
      }
      @render.Use(child) | @render.UseAt(child, _, _) =>
        prepare_search_object(doc, resources, child, seen, depth + 1)
      _ => ()
    }
  }
}

///|
// JS Canvas methods can throw independently of MoonBit checked errors.
// The promise boundary translates those exceptions into async errors so the
// resource cleanup defer runs for either kind of failure.
extern "js" fn invoke_render(
  action : () -> Result[Int32, Error],
) -> @js_async.Promise[Result[Int32, Error]] =
  #|(action) => Promise.resolve().then(action)

///|
/// Load image and embedded font resources, then render an unencrypted BDF.
/// The returned JavaScript promise resolves to the number of mounted pages.
#export_name("mount_bdf_async")
pub fn mount_bdf_async(
  host : BrowserHost,
  data : Bytes,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => mount_single(host, data, layout, false))
}

///|
/// Mount a single document with selectable, accessible text and links.
#export_name("mount_bdf_interactive_async")
pub fn mount_bdf_interactive_async(
  host : BrowserHost,
  data : Bytes,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => mount_single(host, data, layout, true))
}

///|
async fn mount_single(
  host : BrowserHost,
  data : Bytes,
  layout : String,
  interactive : Bool,
) -> Int32 {
  let doc = single_document(@core.open_single(data))
  if doc.manifest.views.length() == 0 {
    raise BadFormat("document has no view")
  }
  let view = doc.manifest.views[0]
  if view.kind == "sheet" {
    let tiles = sheet_tile_table(doc, view)
    let resources = new_resources()
    return mount_live_sheet(
      host,
      doc,
      view,
      tiles,
      resources,
      visible => {
        @js_async.Promise::from_async(() => {
          let seen : Map[String, Bool] = Map([])
          for tile in visible {
            prepare_object(doc, resources, tile.object, seen, 0)
          }
        })
      },
      _ => @js_async.Promise::from_async(() => ()),
      () => @js_async.Promise::from_async(() => ()),
      selected => {
        @js_async.Promise::from_async(() => {
          let seen : Map[String, Bool] = Map([])
          for tile in selected {
            prepare_search_object(doc, resources, tile.object, seen, 0)
          }
        })
      },
      interactive~,
    )
  }
  if view.kind != "fixed" && view.kind != "flow" {
    raise Unsupported("browser supports fixed/flow pages only")
  }
  if view.pages.length() > 256 {
    raise Unsupported("more than 256 pages")
  }
  let resources = new_resources()
  defer dispose_resources(resources)
  let seen : Map[String, Bool] = Map([])
  for page in view.pages {
    for layer in page.layers {
      prepare_object(doc, resources, layer.object, seen, 0)
    }
  }
  let result = invoke_render(() => {
    Ok(mount_document(host, doc, layout, resources~, interactive~)) catch {
      error => Err(error)
    }
  }).wait()
  match result {
    Ok(pages) => pages
    Err(error) => raise error
  }
}
