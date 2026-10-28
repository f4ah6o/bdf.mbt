///|
priv suberror SegmentHttpError {
  SegmentHttp(Int32)
}

///|
#external
priv type SegmentNetwork

///|
#external
priv type SegmentResponse

///|
extern "js" fn segment_network(source : RenderSourceInput) -> SegmentNetwork =
  #|(source) => ({url:source.url,controller:new AbortController(),held:[]})

///|
extern "js" fn segment_initial_view(source : RenderSourceInput) -> String =
  #|(source) => source.view ?? ''

///|
extern "js" fn segment_has_initial_view(source : RenderSourceInput) -> Bool =
  #|(source) => source.view !== undefined

///|
extern "js" fn segment_initial_page(source : RenderSourceInput) -> Int32 =
  #|(source) => source.page ?? 0

///|
extern "js" fn segment_abort(network : SegmentNetwork) -> Unit =
  #|(network) => network.controller.abort()

///|
extern "js" fn segment_add_held(
  network : SegmentNetwork,
  view : String,
  from : Int32,
  to : Int32,
) -> Unit =
  #|(network,view,from,to) => network.held.push({view,from,to})

///|
extern "js" fn segment_fetch(
  network : SegmentNetwork,
  view : String,
  has_view : Bool,
  page : Int32,
) -> @js_async.Promise[SegmentResponse] =
  #|async (network,view,hasView,page) => {
  #|  const pair=await crypto.subtle.generateKey({name:'ECDH',namedCurve:'P-256'},false,['deriveKey']);
  #|  const pub=new Uint8Array(await crypto.subtle.exportKey('raw',pair.publicKey));
  #|  const response=await fetch(network.url,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({key:btoa(String.fromCharCode(...pub)),view:hasView?view:undefined,page,have:network.held}),cache:'no-store',signal:network.controller.signal});
  #|  if(!response.ok)return {status:response.status,pair,bytes:null};
  #|  return {status:response.status,pair,bytes:await self[Symbol.for('f4ah6o.bdf.renderWorker')].read(response,1073741824,'segment response')};
  #|}

///|
extern "js" fn segment_response_status(response : SegmentResponse) -> Int32 =
  #|(response) => response.status

///|
extern "js" fn segment_response_bytes(response : SegmentResponse) -> Bytes =
  #|(response) => response.bytes

///|
extern "js" fn segment_response_key(
  response : SegmentResponse,
) -> CryptoCredential =
  #|(response) => response.pair

///|
extern "js" fn segment_ignore(promise : @js_async.Promise[Unit]) -> Unit =
  #|(promise) => {promise.catch(()=>{})}

///|
extern "js" fn segment_wait_all(
  promises : Array[@js_async.Promise[Int32]],
) -> @js_async.Promise[Array[Int32]] =
  #|(promises) => Promise.all(promises)

///|
extern "js" fn segment_same_promise(
  a : @js_async.Promise[Int32],
  b : @js_async.Promise[Int32],
) -> Bool =
  #|(a,b) => a === b

///|
priv struct SegmentFlight {
  view : String
  from : Int32
  to : Int32
  done : @js_async.Promise[Int32]
}

///|
priv struct RenderSegmentLoader {
  network : SegmentNetwork
  held : Array[@core.Segment]
  inflight : Array[SegmentFlight]
  mut size : Int32
}

///|
fn RenderSegmentLoader::has(
  self : RenderSegmentLoader,
  view : String,
  page : Int32,
) -> Bool {
  for s in self.held {
    if s.view == view && s.from <= page && page < s.to {
      return true
    }
  }
  false
}

///|
fn RenderSegmentLoader::took(
  self : RenderSegmentLoader,
  doc : RenderDocument,
  s : @core.Segment,
) -> Unit raise {
  if !self.has(s.view, s.from) || !self.has(s.view, s.to - 1) {
    self.held.push(s)
    segment_add_held(self.network, s.view, s.from, s.to)
  }
  let view = doc.view(s.view)
  if s.to < view.pages.length() {
    self.size = self.size.max(s.to - s.from)
  }
}

///|
async fn RenderSegmentLoader::fetch(
  self : RenderSegmentLoader,
  view : String,
  has_view : Bool,
  page : Int32,
) -> Result[(RenderDocument, @core.Segment), Int32] {
  let response = segment_fetch(self.network, view, has_view, page).wait()
  let status = segment_response_status(response)
  if status < 200 || status >= 300 {
    return Err(status)
  }
  let bytes = segment_response_bytes(response)
  let header = @core.parse_header(bytes)
  let doc = if header.flags == 1 {
    let sealed = @core.open_encrypted_single(bytes)
    let loader = make_split_loader((hash, _) => {
      @js_async.Promise::from_async(() => sealed.stored_part(hash))
    })
    let (manifest, inner) = encrypted_document_parts(
      sealed.metadata,
      loader,
      segment_response_key(response),
    )
    new_render_split(manifest, inner)
  } else {
    new_render_single(bytes)
  }
  let text = @utf8.decode(doc.raw) catch {
    _ => raise BadFormat("invalid UTF-8 manifest")
  }
  let s = match @core.parse_segment(text) {
    Some(s) => s
    None => raise BadFormat("the server sent another segment")
  }
  if (has_view && s.view != view) || s.from > page || page >= s.to {
    raise BadFormat("the server sent another segment")
  }
  Ok((doc, s))
}

///|
fn RenderSegmentLoader::merge(
  self : RenderSegmentLoader,
  doc : RenderDocument,
  from : RenderDocument,
  s : @core.Segment,
) -> Unit raise {
  if doc.manifest.views.length() != from.manifest.views.length() {
    raise BadFormat("the segment is of another document")
  }
  for i in 0..<doc.manifest.views.length() {
    let a = doc.manifest.views[i]
    let b = from.manifest.views[i]
    if a.id != b.id || a.pages.length() != b.pages.length() {
      raise BadFormat("the segment is of another document")
    }
  }
  let dst = doc.view(s.view)
  let src = from.view(s.view)
  if s.from < 0 || s.from >= s.to || s.to > dst.pages.length() {
    raise BadFormat("segment of pages out of range")
  }
  for source in from.sources {
    doc.sources.push(source)
  }
  for i in s.from..<s.to {
    dst.pages[i] = src.pages[i]
  }
  self.took(doc, s)
}

///|
async fn RenderSegmentLoader::load(
  self : RenderSegmentLoader,
  doc : RenderDocument,
  view : String,
  page : Int32,
) -> Unit {
  let n = doc.view(view).pages.length()
  if page < 0 || page >= n {
    raise BadFormat("bdf: no page " + page.to_string() + " in view " + view)
  }
  while !self.has(view, page) {
    let mut wait : @js_async.Promise[Int32]? = None
    for f in self.inflight {
      if f.view == view && f.from <= page && page < f.to {
        wait = Some(f.done)
        break
      }
    }
    if wait is Some(done) {
      let status = done.wait()
      if status != 0 {
        raise SegmentHttp(status)
      }
      continue
    }
    let from = if self.size > 0 { page - page % self.size } else { page }
    let to = if self.size > 0 {
      if self.size > n - from {
        n
      } else {
        from + self.size
      }
    } else {
      page + 1
    }
    let done = @js_async.Promise::from_async(() => {
      match self.fetch(view, true, page) {
        Ok((next, s)) => {
          self.merge(doc, next, s)
          0
        }
        Err(status) => status
      }
    })
    let f : SegmentFlight = { view, from, to, done, }
    self.inflight.push(f)
    let result = Ok(done.wait()) catch { error => Err(error) }
    for i in 0..<self.inflight.length() {
      if segment_same_promise(self.inflight[i].done, done) {
        ignore(self.inflight.remove(i))
        break
      }
    }
    match result {
      Ok(status) => if status != 0 { raise SegmentHttp(status) }
      Err(error) => raise error
    }
    if !self.has(view, page) {
      raise BadFormat("the segment of page does not hold it")
    }
  }
}

///|
async fn RenderSegmentLoader::ensure(
  self : RenderSegmentLoader,
  doc : RenderDocument,
  view : String,
  page : Int32,
) -> Unit {
  self.load(doc, view, page)
  let n = doc.view(view).pages.length()
  if page < n - 3 {
    let ahead = page + 3
    if !self.has(view, ahead) {
      segment_ignore(
        @js_async.Promise::from_async(() => self.load(doc, view, ahead)),
      )
    }
  }
}

///|
async fn RenderSegmentLoader::ensure_pages(
  self : RenderSegmentLoader,
  doc : RenderDocument,
  view : String,
  pages : Array[Int32],
) -> Unit {
  let promises : Array[@js_async.Promise[Int32]] = []
  for page in pages {
    promises.push(
      @js_async.Promise::from_async(() => {
        try {
          self.ensure(doc, view, page)
          0
        } catch {
          SegmentHttp(status) => status
          error => raise error
        }
      }),
    )
  }
  for status in segment_wait_all(promises).wait() {
    if status != 0 {
      raise SegmentHttp(status)
    }
  }
}

///|
async fn RenderWorkerState::open_segments(
  self : RenderWorkerState,
  source : RenderSourceInput,
) -> RenderOutcome {
  let loader : RenderSegmentLoader = {
    network: segment_network(source),
    held: [],
    inflight: [],
    size: 0,
  }
  let (doc, s) = match
    loader.fetch(
      segment_initial_view(source),
      segment_has_initial_view(source),
      segment_initial_page(source),
    ) {
    Ok(result) => result
    Err(status) => raise SegmentHttp(status)
  }
  let view = doc.view(s.view)
  if s.from < 0 || s.from >= s.to || s.to > view.pages.length() {
    raise BadFormat("segment of pages out of range")
  }
  loader.took(doc, s)
  doc.segments = Some(loader)
  self.install(doc)
  render_success(render_json_value(doc.raw))
}
