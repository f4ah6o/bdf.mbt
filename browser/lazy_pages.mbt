///|
extern "js" fn supports_lazy_pages(host : BrowserHost) -> Bool =
  #|(host) => !!host?.ownerDocument?.defaultView?.IntersectionObserver

///|
extern "js" fn make_page_placeholder(
  host : BrowserHost,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit =
  #|(host,x,y,width,height) => {const c=host.ownerDocument.createElement('canvas');c.width=c.height=0;Object.assign(c.style,{position:'absolute',left:x+'px',top:y+'px',width:width+'px',height:height+'px'});c.setAttribute('aria-label','BDF page');host.append(c)}

///|
extern "js" fn resize_page_canvas(
  surface : BrowserHost,
  index : Int32,
  width : Double,
  height : Double,
) -> Unit =
  #|(surface,index,width,height) => {const c=surface.querySelector(`canvas[data-bdf-page-index="${index}"]`);if(c){c.style.width=width+'px';c.style.height=height+'px'}}

///|
extern "js" fn invalidate_lazy_pages(host : BrowserHost, zoom : Double) -> Unit =
  #|(host,zoom) => host[Symbol.for('f4ah6o.bdf.pageLayout')]?.lazy?.zoom(zoom)

///|
extern "js" fn validate_lazy_zoom(host : BrowserHost, zoom : Double) -> Unit =
  #|(host,zoom) => host[Symbol.for('f4ah6o.bdf.pageLayout')]?.lazy?.validate(zoom)

///|
// The observer owns the backing bitmaps and serializes preparation. Stale
// renders never publish, and resources are released after pending work ends.
extern "js" fn start_lazy_pages(
  host : BrowserHost,
  surface : BrowserHost,
  draw : (Int32, CanvasContext) -> @js_async.Promise[Unit],
) -> @js_async.Promise[Int32] =
  #|(host,surface,draw) => {
  #| const win=host.ownerDocument.defaultView,state=host[Symbol.for('f4ah6o.bdf.pageLayout')],canvases=[...surface.querySelectorAll('canvas[data-bdf-page-index]')],visible=new Set(),serial=new Map();
  #| let disposed=false,active=0,initial=true,observed=false,started=false,zoom=1,queue=Promise.resolve(),release,resolveReady,rejectReady;
  #| const ready=new Promise((resolve,reject)=>{resolveReady=resolve;rejectReady=reject});
  #| const finish=()=>{if(disposed&&active===0&&release){const done=release;release=undefined;done()}else if(initial&&observed&&active===0){initial=false;resolveReady(canvases.length)}};
  #| const fail=error=>{if(initial){initial=false;rejectReady(error)}else if(!disposed&&host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf page:',error)};
  #| const schedule=canvas=>{const id=Number(canvas.dataset.bdfPageIndex),token=(serial.get(canvas)??0)+1;serial.set(canvas,token);canvas.dataset.bdfPageLoaded='loading';active++;
  #|  const job=queue.then(async()=>{if(disposed||!visible.has(canvas)||serial.get(canvas)!==token)return;const dpr=win.devicePixelRatio||1,w=Math.ceil(parseFloat(canvas.style.width)*dpr),h=Math.ceil(parseFloat(canvas.style.height)*dpr);if(!Number.isFinite(w)||!Number.isFinite(h)||w<=0||h<=0||w>8192||h>8192||w*h>16777216)throw new RangeError('page bitmap exceeds browser limits');const scratch=host.ownerDocument.createElement('canvas');scratch.width=w;scratch.height=h;const ctx=scratch.getContext('2d');if(!ctx)throw new Error('Canvas 2D context unavailable');ctx.scale(zoom*dpr,zoom*dpr);await draw(id,ctx);if(disposed||!visible.has(canvas)||serial.get(canvas)!==token)return;canvas.width=w;canvas.height=h;const target=canvas.getContext('2d');if(!target)throw new Error('Canvas 2D context unavailable');target.drawImage(scratch,0,0);canvas.dataset.bdfPageLoaded='ready'});
  #|  queue=job.catch(error=>{if(!disposed&&visible.has(canvas)&&serial.get(canvas)===token){canvas.dataset.bdfPageLoaded='error';fail(error)}}).finally(()=>{active--;finish()});
  #| };
  #| const observer=new win.IntersectionObserver(entries=>{for(const entry of entries){const canvas=entry.target;if(entry.isIntersecting){if(!visible.has(canvas)){visible.add(canvas);schedule(canvas)}}else if(visible.delete(canvas)){serial.set(canvas,(serial.get(canvas)??0)+1);canvas.width=canvas.height=0;canvas.dataset.bdfPageLoaded=''}}observed=true;finish()},{root:host,rootMargin:'600px'});
  #| state.lazy={ready,start(){if(disposed||started)return;started=true;for(const canvas of canvases)observer.observe(canvas);if(!canvases.length){observed=true;finish()}},validate(value){const dpr=win.devicePixelRatio||1;for(const canvas of visible){const w=Math.ceil(parseFloat(canvas.style.width)*value/zoom*dpr),h=Math.ceil(parseFloat(canvas.style.height)*value/zoom*dpr);if(!Number.isFinite(w)||!Number.isFinite(h)||w<=0||h<=0||w>8192||h>8192||w*h>16777216)throw new RangeError('page bitmap exceeds browser limits')}},zoom(value){zoom=value;for(const canvas of visible){serial.set(canvas,(serial.get(canvas)??0)+1);canvas.width=canvas.height=0;schedule(canvas)}},dispose(done){disposed=true;observer.disconnect();if(initial){initial=false;rejectReady(new Error('page mount cancelled'))}release=done;finish()}};
  #| if(host.isConnected)state.lazy.start();else{observed=true;finish()}return ready;
  #|}

///|
extern "js" fn wait_lazy_pages(host : BrowserHost) -> @js_async.Promise[Int32] =
  #|(host) => host[Symbol.for('f4ah6o.bdf.pageLayout')].lazy.ready

///|
#external
priv type PageRecord

///|
extern "js" fn page_record(host : BrowserHost) -> PageRecord =
  #|(host) => host[Symbol.for('f4ah6o.bdf.pageLayout')]

///|
extern "js" fn current_page_record(
  host : BrowserHost,
  record : PageRecord,
) -> Bool =
  #|(host,record) => host[Symbol.for('f4ah6o.bdf.pageLayout')]===record

///|
fn paint_lazy_page(
  ctx : CanvasContext,
  document : BrowserDocument,
  view : @core.View,
  index : Int32,
  resources : BrowserResources?,
) -> Unit raise {
  let page = view.pages[index]
  set_color(ctx, -1, false)
  fill_rect(ctx, 0.0, 0.0, page.width, page.height)
  let limits : UseLimits = { seen: {}, reused: 0, maximum: 134217728, }
  for layer in page.layers {
    let object = @core.decode_object_resources(document.part(layer.object))
    paint_root_object(ctx, document, object, resources, limits)
  }
}
