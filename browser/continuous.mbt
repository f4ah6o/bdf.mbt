///|
fn continuous_view(document : BrowserDocument) -> @core.View raise {
  if document.manifest.views.is_empty() ||
    document.manifest.views[0].kind == "sheet" {
    raise Unsupported("document has no continuous page view")
  }
  document.manifest.views[0]
}

///|
fn draw_continuous_region(
  ctx : CanvasContext,
  document : BrowserDocument,
  view : @core.View,
  bands : Array[@render.ContinuousBand],
  viewport : @render.TextRect,
  resources : BrowserResources,
) -> Unit raise {
  let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
  for band in bands {
    let body = band.body
    save(ctx)
    translate(ctx, -viewport.x, band.offset - viewport.y)
    clip_rect(ctx, 0.0, 0.0, body.width, body.height)
    set_color(ctx, -1, false)
    fill_rect(ctx, 0.0, 0.0, body.width, body.height)
    translate(ctx, -body.x, -body.y)
    for layer in view.pages[band.index].layers {
      if layer.role != "body" && layer.role != "annotation" {
        continue
      }
      let object = @core.decode_object_resources(document.part(layer.object))
      paint_root_object(ctx, document, object, Some(resources), limits)
    }
    restore(ctx)
  }
}

///|
async fn render_continuous_single(
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
  ignore(sheet_viewport(x, y, width, height, scale))
  let viewport : @render.TextRect = { x, y, width, height, }
  let document = single_document(@core.open_single(data))
  let view = continuous_view(document)
  let bands = @render.continuous_bands(view, viewport)
  let resources = new_resources()
  defer dispose_resources(resources)
  let seen : Map[String, Bool] = Map([])
  for band in bands {
    for layer in view.pages[band.index].layers {
      prepare_object(document, resources, layer.object, seen, 0)
    }
  }
  let result = invoke_render(() => {
    try {
      if !current_sheet_request(host, request) {
        raise BadFormat("continuous render superseded")
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
      draw_continuous_region(ctx, document, view, bands, viewport, resources)
      resize_host(host, width * scale, height * scale)
      Ok(bands.length())
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
/// Draw a viewport of the first view's continuous page bodies.
#export_name("render_bdf_continuous_region_async")
pub fn render_bdf_continuous_region_async(
  host : BrowserHost,
  data : Bytes,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    render_continuous_single(host, data, x, y, width, height, scale)
  })
}

///|
async fn render_continuous_split(
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
  ignore(sheet_viewport(x, y, width, height, scale))
  let viewport : @render.TextRect = { x, y, width, height, }
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
  let view = continuous_view(document)
  let bands = @render.continuous_bands(view, viewport)
  let fetched : Map[String, Bool] = Map([])
  for band in bands {
    for layer in view.pages[band.index].layers {
      prefetch_split_object(split, cache, loader, layer.object, fetched, 0)
    }
  }
  let resources = new_resources()
  defer dispose_resources(resources)
  let seen : Map[String, Bool] = Map([])
  for band in bands {
    for layer in view.pages[band.index].layers {
      prepare_object(document, resources, layer.object, seen, 0)
    }
  }
  let result = invoke_render(() => {
    try {
      if !current_sheet_request(host, request) {
        raise BadFormat("continuous render superseded")
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
      draw_continuous_region(ctx, document, view, bands, viewport, resources)
      resize_host(host, width * scale, height * scale)
      Ok(bands.length())
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
/// Draw a continuous viewport from a split BDF with an asynchronous part loader.
#export_name("render_bdf_continuous_region_split_async")
pub fn render_bdf_continuous_region_split_async(
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
    render_continuous_split(host, manifest, loader, x, y, width, height, scale)
  })
}

///|
async fn render_continuous_encrypted(
  host : BrowserHost,
  metadata : @core.EncryptedManifest,
  loader : SplitPartLoader,
  credential : CryptoCredential,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> Int32 {
  let request = begin_sheet_request(host)
  defer end_sheet_request(host, request)
  ignore(sheet_viewport(x, y, width, height, scale))
  let (manifest, inner_loader) = encrypted_document_parts(
    metadata, loader, credential,
  )
  if !current_sheet_request(host, request) {
    raise BadFormat("continuous render superseded")
  }
  render_continuous_split(
    host, manifest, inner_loader, x, y, width, height, scale,
  )
}

///|
/// Draw a continuous viewport from a password- or P-256-encrypted single file.
#export_name("render_bdf_continuous_region_encrypted_async")
pub fn render_bdf_continuous_region_encrypted_async(
  host : BrowserHost,
  data : Bytes,
  credential : CryptoCredential,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    let single = @core.open_encrypted_single(data)
    let loader = make_split_loader((hash, _) => {
      @js_async.Promise::from_async(() => single.stored_part(hash))
    })
    render_continuous_encrypted(
      host,
      single.metadata,
      loader,
      credential,
      x,
      y,
      width,
      height,
      scale,
    )
  })
}

///|
/// Draw a continuous viewport from an encrypted split BDF.
#export_name("render_bdf_continuous_region_encrypted_split_async")
pub fn render_bdf_continuous_region_encrypted_split_async(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  credential : CryptoCredential,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    if manifest.length() > 268435456 {
      raise BadFormat("manifest exceeds 256 MiB")
    }
    let text = @utf8.decode(manifest) catch {
      _ => raise BadFormat("invalid UTF-8 manifest")
    }
    render_continuous_encrypted(
      host,
      @core.parse_encrypted_manifest(text),
      loader,
      credential,
      x,
      y,
      width,
      height,
      scale,
    )
  })
}
