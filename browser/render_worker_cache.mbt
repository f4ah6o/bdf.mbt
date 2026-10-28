///|
#external
priv type WorkerResourceOptions

///|
#external
priv type WorkerResourceCache

///|
extern "js" fn worker_default_options() -> WorkerResourceOptions =
  #|() => ({})

///|
extern "js" fn worker_request_options(
  request : RenderRequest,
) -> WorkerResourceOptions =
  #|(request) => request.options ?? {}

///|
extern "js" fn worker_cache_new(
  options : WorkerResourceOptions,
) -> WorkerResourceCache =
  #|(options) => ({
  #|  budget:options.imageBudget??268435456,maxPixels:options.maxImagePixels??268435456,holdLimit:options.holdLimit??4294967296,
  #|  images:new Map(),decoding:new Map(),refused:new Set(),vectors:new Map(),fonts:new Map(),fontLoading:new Map(),holds:new Set(),bytes:0,refs:0,retired:false,disposed:false,
  #|  trim(){const budget=this.disposed?0:this.budget;if(this.bytes<=budget)return;const held=new Set();for(const h of this.holds)for(const hash of h.images)held.add(hash);for(const [hash,bmp] of this.images){if(this.bytes<=budget)break;if(held.has(hash))continue;this.images.delete(hash);this.bytes-=bmp.width*bmp.height*4;bmp.close()}},
  #|  dispose(){if(this.disposed)return;this.disposed=true;this.trim();for(const v of this.vectors.values()){v.disposed=true;for(const r of v.rasters)r.canvas.close();v.rasters.length=0}this.vectors.clear();for(const face of this.fonts.values())(globalThis.document?.fonts??globalThis.fonts)?.delete(face);this.fonts.clear()},
  #|  collect(){if(this.retired&&this.refs===0)this.dispose()}
  #|})

///|
extern "js" fn worker_cache_enter(cache : WorkerResourceCache) -> Unit =
  #|(cache) => {cache.refs++}

///|
extern "js" fn worker_cache_leave(cache : WorkerResourceCache) -> Unit =
  #|(cache) => {cache.refs--;cache.collect()}

///|
extern "js" fn worker_cache_retire(cache : WorkerResourceCache) -> Unit =
  #|(cache) => {cache.retired=true;cache.collect()}

///|
extern "js" fn worker_cache_attach(
  resources : BrowserResources,
  cache : WorkerResourceCache,
) -> Unit =
  #|(r,cache) => {r.worker=cache;r.hold={images:new Set(),bytes:0};cache.holds.add(r.hold);r.fonts=cache.fonts}

///|
fn RenderDocument::resources(self : RenderDocument) -> BrowserResources {
  let resources = new_resources()
  if self.cache is Some(cache) {
    worker_cache_attach(resources, cache)
  }
  resources
}

///|
fn RenderWorkerState::install(
  self : RenderWorkerState,
  doc : RenderDocument,
) -> Unit {
  if self.open is Some(old) && old.cache is Some(cache) {
    worker_cache_retire(cache)
  }
  doc.cache = Some(worker_cache_new(self.settings))
  self.open = Some(doc)
}
