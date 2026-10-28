///|
/// A JavaScript function accepting a hash and maximum size and returning a
/// Promise of Uint8Array. The host should enforce the limit while reading.
#external
pub type SplitPartLoader

///|
extern "js" fn fetch_split_part(
  loader : SplitPartLoader,
  hash : String,
  maximum : Int32,
) -> @js_async.Promise[Bytes] =
  #|(loader, hash, maximum) => Promise.resolve().then(() => loader(hash, maximum)).then(bytes => {
  #|  if (!(bytes instanceof Uint8Array) || bytes.byteLength > maximum) throw new TypeError("invalid split part bytes");
  #|  return bytes;
  #|})

///|
async fn prefetch_part(
  split : @core.SplitDocument,
  cache : Map[String, Bytes],
  loader : SplitPartLoader,
  hash : String,
) -> Unit {
  if cache.contains(hash) {
    return
  }
  for part in split.manifest.parts {
    if part.hash == hash {
      let bytes = fetch_split_part(loader, hash, part.length).wait()
      if bytes.length() != part.length {
        raise BadFormat("stored part size does not match manifest")
      }
      cache[hash] = bytes
      return
    }
  }
  raise BadFormat("unknown part")
}

///|
async fn prefetch_split_object(
  split : @core.SplitDocument,
  cache : Map[String, Bytes],
  loader : SplitPartLoader,
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
  prefetch_part(split, cache, loader, hash)
  let object = @core.decode_object_resources(split.part(hash))
  for path in object.paths {
    if path is @core.External(path_hash, _) {
      prefetch_part(split, cache, loader, path_hash)
    }
  }
  for command in @render.compile_object(object.object) {
    match command {
      @render.Image(image, _, _, _, _)
      | @render.ImageSub(image, _, _, _, _, _, _, _, _) =>
        prefetch_part(split, cache, loader, image)
      @render.FillPaint(index) | @render.StrokePaint(index) => {
        if index < 0 || index >= object.paints.length() {
          raise BadFormat("paint reference out of range")
        }
        if object.paints[index] is @core.Pattern(image, _, _) {
          if image < 0 || image >= object.object.images.length() {
            raise BadFormat("pattern image reference out of range")
          }
          prefetch_part(split, cache, loader, object.object.images[image])
        }
      }
      @render.Font(index, _) => {
        if index < 0 || index >= object.fonts.length() {
          raise BadFormat("font reference out of range")
        }
        if object.fonts[index].hash is Some(font) {
          prefetch_part(split, cache, loader, font)
        }
      }
      @render.Use(child) | @render.UseAt(child, _, _) =>
        prefetch_split_object(split, cache, loader, child, seen, depth + 1)
      _ => ()
    }
  }
}

///|
/// Mount an unencrypted split document, loading only referenced parts through
/// an asynchronous JavaScript loader. Resolves to the number of pages.
#export_name("mount_bdf_split_async")
pub fn mount_bdf_split_async(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    mount_split(host, manifest, loader, layout, false)
  })
}

///|
/// Mount a split document with selectable, accessible text and links.
#export_name("mount_bdf_interactive_split_async")
pub fn mount_bdf_interactive_split_async(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  layout : String,
) -> @js_async.Promise[Int32] {
  @js_async.Promise::from_async(() => {
    mount_split(host, manifest, loader, layout, true)
  })
}

///|
async fn mount_split(
  host : BrowserHost,
  manifest : Bytes,
  loader : SplitPartLoader,
  layout : String,
  interactive : Bool,
) -> Int32 {
  let cache : Map[String, Bytes] = Map([])
  let split = @core.open_split(manifest, fn(hash, _) {
    match cache.get(hash) {
      Some(data) => data
      None => raise BadFormat("split part not loaded")
    }
  })
  if split.manifest.views.length() == 0 {
    raise BadFormat("document has no view")
  }
  let view = split.manifest.views[0]
  if view.kind != "fixed" && view.kind != "flow" {
    raise Unsupported("browser supports fixed/flow pages only")
  }
  if view.pages.length() > 256 {
    raise Unsupported("more than 256 pages")
  }
  let seen : Map[String, Bool] = Map([])
  if interactive && view.text_index is Some(hash) {
    // Search is optional: an unavailable index must not prevent rendering.
    // The attempted lookup is reported if a search is subsequently requested.
    prefetch_part(split, cache, loader, hash) catch {
      _ => ()
    }
  }
  for page in view.pages {
    for layer in page.layers {
      prefetch_split_object(split, cache, loader, layer.object, seen, 0)
    }
  }
  let doc : BrowserDocument = {
    manifest: split.manifest,
    load: fn(hash) { split.part(hash) },
  }
  let resources = new_resources()
  defer dispose_resources(resources)
  let prepared : Map[String, Bool] = Map([])
  for page in view.pages {
    for layer in page.layers {
      prepare_object(doc, resources, layer.object, prepared, 0)
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
