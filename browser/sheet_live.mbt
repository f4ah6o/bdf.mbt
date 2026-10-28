///|
// Draw offscreen and publish only the newest completed viewport. Resources
// stay alive until a detached or unmounted host has finished its pending draw.
extern "js" fn start_live_sheet(
  host : BrowserHost,
  sheet_width : Double,
  sheet_height : Double,
  draw : (CanvasContext, Double, Double, Double, Double, Double) -> @js_async.Promise[
    Unit,
  ],
  release : () -> Unit,
) -> @js_async.Promise[Int32] =
  #|(host,sheetWidth,sheetHeight,draw,release) => new Promise((resolve,reject) => {
  #| const doc=host.ownerDocument,win=doc.defaultView,key=Symbol.for('f4ah6o.bdf.sheet');let disposed=false,running=false,first=true,released=false,frame=0,revision=0,mutation,resize;
  #| const oldWidth=host.style.width,oldHeight=host.style.height;let defaultWidth=false,defaultHeight=false;
  #| const releaseOnce=()=>{if(!released){released=true;release()}};
  #| const restoreSize=()=>{if(defaultWidth&&host.style.width==='640px')host.style.width=oldWidth;if(defaultHeight&&host.style.height==='400px')host.style.height=oldHeight};
  #| try {
  #|  if(!host.clientWidth&&!host.style.width){host.style.width='640px';defaultWidth=true}if(!host.clientHeight&&!host.style.height){host.style.height='400px';defaultHeight=true}
  #|  const spacer=doc.createElement('div');spacer.style.cssText='position:relative';const canvas=doc.createElement('canvas');canvas.style.cssText='position:sticky;left:0;top:0;display:block';canvas.setAttribute('aria-label','BDF sheet');canvas.dataset.bdfSheet='';spacer.append(canvas);host.append(spacer);
  #|  const dimensions=()=>{const width=host.clientWidth||parseFloat(host.style.width)||640,height=host.clientHeight||parseFloat(host.style.height)||400;spacer.style.width=Math.max(width,sheetWidth)+'px';spacer.style.height=Math.max(height,sheetHeight)+'px';return{width,height}};
  #|  const onerror=error=>{if(first){first=false;record.dispose();if(host[key]===record)delete host[key];host.replaceChildren();reject(error)}else if(host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf sheet:',error)};
  #|  const schedule=()=>{if(disposed)return;revision++;if(!running&&!frame)frame=win.requestAnimationFrame(paint)};
  #|  const paint=async()=>{frame=0;if(disposed||running)return;running=true;const current=revision;try{const {width,height}=dimensions(),dpr=win.devicePixelRatio||1,w=Math.ceil(width*dpr),h=Math.ceil(height*dpr),x=host.scrollLeft,y=host.scrollTop;if(!Number.isFinite(w)||!Number.isFinite(h)||w<=0||h<=0||w>8192||h>8192||w*h>16777216)throw new RangeError('sheet bitmap exceeds browser limits');const scratch=doc.createElement('canvas');scratch.width=w;scratch.height=h;const ctx=scratch.getContext('2d');if(!ctx)throw new Error('Canvas 2D context unavailable');ctx.scale(dpr,dpr);await draw(ctx,x,y,width,height,dpr);if(!disposed&&current===revision){canvas.width=w;canvas.height=h;canvas.style.width=width+'px';canvas.style.height=height+'px';const target=canvas.getContext('2d');if(!target)throw new Error('Canvas 2D context unavailable');target.drawImage(scratch,0,0);canvas.dataset.bdfSheetViewport=JSON.stringify([x,y,width,height]);canvas.dataset.bdfSheetFrame=String(current);if(first){first=false;resolve(1)}}}catch(error){if(!disposed)onerror(error)}finally{running=false;if(disposed)releaseOnce();else if(current!==revision&&!frame)frame=win.requestAnimationFrame(paint)}};
  #|  const record=host[key]={dispose(){if(disposed)return;disposed=true;mutation?.disconnect();resize?.disconnect();host.removeEventListener('scroll',schedule);if(frame)win.cancelAnimationFrame(frame);frame=0;restoreSize();if(first){first=false;reject(new Error('sheet mount cancelled'))}if(!running)releaseOnce()}};
  #|  host.addEventListener('scroll',schedule);if(typeof ResizeObserver==='function'){resize=new ResizeObserver(schedule);resize.observe(host)}
  #|  if(typeof MutationObserver==='function'){const watch=(weak,k,owner,connected)=>{const ob=new MutationObserver(()=>{const h=weak.deref();if(!h){ob.disconnect();return}if(h.isConnected)connected=true;else if(connected){h[k]?.dispose();delete h[k]}});ob.observe(owner,{childList:true,subtree:true});return ob};const weak=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host};mutation=watch(weak,key,doc,host.isConnected)}
  #|  schedule();
  #| } catch(error){first=false;host[key]?.dispose();delete host[key];restoreSize();releaseOnce();reject(error)}
  #|})

///|
extern "js" fn sheet_initial_width(host : BrowserHost) -> Double =
  #|(host) => host.clientWidth||parseFloat(host.style.width)||640

///|
extern "js" fn sheet_initial_height(host : BrowserHost) -> Double =
  #|(host) => host.clientHeight||parseFloat(host.style.height)||400

///|
extern "js" fn sheet_initial_scale(host : BrowserHost) -> Double =
  #|(host) => host.ownerDocument.defaultView.devicePixelRatio||1

///|
async fn mount_live_sheet(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  tiles : Array[@core.Tile],
  resources : BrowserResources,
  prepare : (Array[@core.Tile]) -> @js_async.Promise[Unit],
) -> Int32 {
  let mut handed_off = false
  defer (if !handed_off { dispose_resources(resources) })
  let request = begin_sheet_request(host)
  defer end_sheet_request(host, request)
  // Prepare the first viewport before replacing an existing mounted document.
  let initial = sheet_viewport(
    0.0,
    0.0,
    sheet_initial_width(host),
    sheet_initial_height(host),
    sheet_initial_scale(host),
  )
  prepare(visible_sheet_tiles(view, tiles, initial)).wait()
  if !current_sheet_request(host, request) {
    raise BadFormat("sheet mount superseded")
  }
  clear_host(host)
  reset_host_size(host)
  let (width, height) = @render.sheet_size(view)
  let pending = start_live_sheet(
    host,
    width,
    height,
    (ctx, x, y, w, h, scale) => {
      @js_async.Promise::from_async(() => {
        let viewport = sheet_viewport(x, y, w, h, scale)
        let visible = visible_sheet_tiles(view, tiles, viewport)
        prepare(visible).wait()
        draw_sheet_region(
          ctx, document, view, visible, viewport, scale, resources,
        )
      })
    },
    () => dispose_resources(resources),
  )
  handed_off = true
  pending.wait()
}
