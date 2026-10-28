///|
#external
priv type RenderRequest

///|
#external
priv type RenderSourceInput

///|
#external
priv type RenderValue

///|
#external
priv type RenderOutcome

///|
extern "js" fn render_request_type(request : RenderRequest) -> String =
  #|(request) => String(request.type)

///|
extern "js" fn render_request_source(
  request : RenderRequest,
) -> RenderSourceInput =
  #|(request) => request.source

///|
extern "js" fn render_source_kind(source : RenderSourceInput) -> String =
  #|(source) => String(source.kind)

///|
extern "js" fn render_source_buffer(source : RenderSourceInput) -> Bytes =
  #|(source) => new Uint8Array(source.buffer)

///|
extern "js" fn render_source_url(source : RenderSourceInput) -> String =
  #|(source) => source.kind==='split'?(source.base.endsWith('/')?source.base:source.base+'/')+'manifest.json':source.url

///|
extern "js" fn render_source_part_loader(
  source : RenderSourceInput,
) -> SplitPartLoader =
  #|(source) => {const base=source.base.endsWith('/')?source.base:source.base+'/';return async(hash,limit)=>{const response=await fetch(base+'parts/'+hash);if(!response.ok)throw new Error(`bdf: part ${hash} fetch failed with ${response.status}`);return self[Symbol.for('f4ah6o.bdf.renderWorker')].read(response,limit,`part ${hash}`)}}

///|
extern "js" fn render_fetch_source(
  source : RenderSourceInput,
) -> @js_async.Promise[Bytes] =
  #|async source => {const split=source.kind==='split',base=split?(source.base.endsWith('/')?source.base:source.base+'/'):'';const response=await fetch(split?base+'manifest.json':source.url);if(!response.ok)throw new Error(split?`bdf: manifest fetch failed with ${response.status}`:`bdf: fetch failed with ${response.status}`);return self[Symbol.for('f4ah6o.bdf.renderWorker')].read(response,split?268435456:1073741824,split?'manifest':'single-file response')}

///|
extern "js" fn render_json_encrypted(bytes : Bytes) -> Bool =
  #|(bytes) => {try{return !!JSON.parse(new TextDecoder().decode(bytes)).encryption}catch{return false}}

///|
extern "js" fn render_request_has_password(request : RenderRequest) -> Bool =
  #|(request) => request.password!==undefined

///|
extern "js" fn render_request_password(
  request : RenderRequest,
) -> CryptoCredential =
  #|(request) => request.password

///|
extern "js" fn render_json_value(data : Bytes) -> RenderValue =
  #|(data) => JSON.parse(new TextDecoder().decode(data))

///|
extern "js" fn render_null() -> RenderValue =
  #|() => null

///|
extern "js" fn render_success(value : RenderValue) -> RenderOutcome =
  #|(result) => ({ok:true,result})

///|
extern "js" fn render_error(message : String, code : String) -> RenderOutcome =
  #|(error,code) => code?{ok:false,error,code}:{ok:false,error}

///|
fn render_manifest_bytes(data : Bytes) -> Bytes raise {
  let header = @core.parse_header(data)
  let reader = @core.Reader::new(data)
  reader.skip(header.manifest_offset)
  @core.decode_encoded(
    reader.take(header.manifest_length),
    if header.manifest_encoding == 1 {
      "deflate-raw"
    } else {
      "identity"
    },
    268435456,
  )
}

///|
priv struct RenderDocumentSource {
  manifest : @core.Manifest
  load : (String) -> Bytes raise
  ensure : (String) -> @js_async.Promise[Unit]
}

///|
priv struct RenderDocument {
  manifest : @core.Manifest
  sources : Array[RenderDocumentSource]
  raw : Bytes
}

///|
fn render_single_source(document : @core.Document) -> RenderDocumentSource {
  {
    manifest: document.manifest,
    load: hash => document.part(hash),
    ensure: _ => @js_async.Promise::from_async(() => ()),
  }
}

///|
fn render_split_source(
  manifest : Bytes,
  source_loader : SplitPartLoader,
) -> RenderDocumentSource raise {
  let cache : Map[String, Bytes] = {}
  let loader = shared_split_loader(source_loader)
  let split = @core.open_split(manifest, (hash, _) => {
    match cache.get(hash) {
      Some(data) => data
      None => raise BadFormat("split part not loaded")
    }
  })
  {
    manifest: split.manifest,
    load: hash => split.part(hash),
    ensure: hash => {
      @js_async.Promise::from_async(() => {
        prefetch_part(split, cache, loader, hash)
      })
    },
  }
}

///|
fn RenderDocument::source(
  self : RenderDocument,
  hash : String,
) -> RenderDocumentSource? {
  for source in self.sources {
    for part in source.manifest.parts {
      if part.hash == hash {
        return Some(source)
      }
    }
  }
  None
}

///|
async fn RenderDocument::ensure(self : RenderDocument, hash : String) -> Unit {
  match self.source(hash) {
    Some(source) => (source.ensure)(hash).wait()
    None => raise BadFormat("unknown part")
  }
}

///|
fn RenderDocument::part(self : RenderDocument, hash : String) -> Bytes raise {
  match self.source(hash) {
    Some(source) => (source.load)(hash)
    None => raise BadFormat("unknown part")
  }
}

///|
fn RenderDocument::browser_document(self : RenderDocument) -> BrowserDocument {
  { manifest: self.manifest, load: hash => self.part(hash), }
}

///|
fn RenderDocument::view(self : RenderDocument, id : String) -> @core.View raise {
  for view in self.manifest.views {
    if view.id == id {
      return view
    }
  }
  raise BadFormat("bdf: unknown view " + id)
}

///|
fn new_render_single(data : Bytes) -> RenderDocument raise {
  let doc = @core.open_single(data)
  {
    manifest: doc.manifest,
    sources: [render_single_source(doc)],
    raw: render_manifest_bytes(data),
  }
}

///|
fn new_render_split(
  manifest : Bytes,
  loader : SplitPartLoader,
) -> RenderDocument raise {
  let source = render_split_source(manifest, loader)
  { manifest: source.manifest, sources: [source], raw: manifest, }
}

///|
priv struct RenderLocked {
  metadata : @core.EncryptedManifest
  loader : SplitPartLoader
}

///|
priv struct RenderWorkerState {
  mut open : RenderDocument?
  mut locked : RenderLocked?
}

///|
async fn RenderWorkerState::unlock(
  self : RenderWorkerState,
  request : RenderRequest,
) -> RenderOutcome {
  guard self.locked is Some(locked) else {
    return render_error("bdf: no document to unlock", "")
  }
  if !render_request_has_password(request) {
    return render_error(
      "bdf: the document is encrypted and needs a password", "password-required",
    )
  }
  let (manifest, loader) = encrypted_document_parts(
    locked.metadata,
    locked.loader,
    render_request_password(request),
  ) catch {
    WrongPassword =>
      return render_error("bdf: wrong password", "wrong-password")
    error => return render_error(error.to_string(), "")
  }
  let document = new_render_split(manifest, loader) catch {
    error => return render_error(error.to_string(), "")
  }
  self.locked = None
  self.open = Some(document)
  render_success(render_json_value(document.raw))
}

///|
async fn RenderWorkerState::open_source(
  self : RenderWorkerState,
  request : RenderRequest,
  replace : Bool,
) -> RenderOutcome {
  let source = render_request_source(request)
  let kind = render_source_kind(source)
  if !replace {
    self.open = None
    self.locked = None
  }
  if kind != "buffer" && kind != "single" && kind != "split" {
    return render_error("bdf: unsupported source " + kind, "")
  }
  let bytes = if kind == "buffer" {
    render_source_buffer(source)
  } else {
    render_fetch_source(source).wait()
  }
  if kind == "split" {
    let loader = render_source_part_loader(source)
    if render_json_encrypted(bytes) {
      if replace {
        return render_error(
          "bdf: the document is encrypted and needs a password", "password-required",
        )
      }
      let text = @utf8.decode(bytes) catch {
        _ => return render_error("invalid UTF-8 manifest", "")
      }
      let metadata = @core.parse_encrypted_manifest(text) catch {
        error => return render_error(error.to_string(), "")
      }
      self.locked = Some({ metadata, loader, })
      return self.unlock(request)
    }
    let doc = new_render_split(bytes, loader) catch {
      error => return render_error(error.to_string(), "")
    }
    self.open = Some(doc)
    return render_success(render_json_value(doc.raw))
  }
  let header = @core.parse_header(bytes) catch {
    error => return render_error(error.to_string(), "")
  }
  if header.flags == 1 {
    if replace {
      return render_error(
        "bdf: the document is encrypted and needs a password", "password-required",
      )
    }
    let sealed = @core.open_encrypted_single(bytes) catch {
      error => return render_error(error.to_string(), "")
    }
    let loader = make_split_loader((hash, _) => {
      @js_async.Promise::from_async(() => sealed.stored_part(hash))
    })
    self.locked = Some({ metadata: sealed.metadata, loader, })
    return self.unlock(request)
  }
  let doc = new_render_single(bytes) catch {
    error => return render_error(error.to_string(), "")
  }
  self.open = Some(doc)
  render_success(render_json_value(doc.raw))
}
