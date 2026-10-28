///|
/// A browser viewer following the BDF viewer control API.
#external
pub type BrowserViewer

///|
/// JavaScript viewer options, including an optional renderer and music callback.
#external
pub type BrowserViewerOptions

///|
#external
priv type ViewerDom

///|
#external
priv type ViewerRow

///|
#external
priv type ViewerCanvas

///|
#external
priv type ViewerBitmap

///|
extern "js" fn viewer_new_renderer(
  options : BrowserViewerOptions,
) -> BrowserRenderClient =
  #|(options) => options?.renderer??null

///|
extern "js" fn viewer_options_renderer(options : BrowserViewerOptions) -> Bool =
  #|(options) => !!options?.renderer

///|
extern "js" fn viewer_worker_url(options : BrowserViewerOptions) -> String =
  #|(options) => {if(options?.workerUrl)return options.workerUrl;const entries=globalThis.performance?.getEntriesByType('resource')??[],module=[...entries].reverse().find(e=>/\/browser\/browser\.js(?:[?#]|$)/.test(e.name))?.name;return module?new URL('../render_worker/render_worker.js',module).href:new URL('./render_worker.js',document.baseURI).href}

///|
extern "js" fn viewer_option_string(
  options : BrowserViewerOptions,
  key : String,
  fallback : String,
) -> String =
  #|(options,key,fallback) => options?.[key]??fallback

///|
extern "js" fn viewer_option_zoom(options : BrowserViewerOptions) -> Double =
  #|(options) => options?.zoom??1

///|
extern "js" fn viewer_has_music(options : BrowserViewerOptions) -> Bool =
  #|(options) => typeof options?.music==='function'

///|
extern "js" fn viewer_dom_new(
  host : BrowserHost,
  options : BrowserViewerOptions,
  renderer : BrowserRenderClient,
  owned : Bool,
) -> ViewerDom =
  #|(host,options,renderer,owned) => {
  #| const mode=options?.mode??'embedded',surface=document.createElement('div'),stage=document.createElement('div'),box=document.createElement('div');
  #| surface.style.cssText=mode==='lightbox'?'position:fixed;inset:0;z-index:2147483647;background:#000b;display:none;padding:3vmin;box-sizing:border-box':'width:100%;height:100%;min-height:0;box-sizing:border-box';
  #| stage.style.cssText='width:100%;height:100%;overflow:auto;box-sizing:border-box;overscroll-behavior:contain';stage.setAttribute('role','region');stage.setAttribute('aria-label','Document pages');stage.tabIndex=0;
  #| box.style.cssText='position:relative;width:100%;height:100%;min-height:0';box.append(stage);surface.append(box);host.append(surface);
  #| return {host,options:options??{},renderer,owned,mode,surface,stage,box,observer:null,resize:null,frame:0,near:new Set(),errors:new Map(),errorSerial:0,manifest:undefined,view:undefined,layout:options?.layout??'single'};
  #|}

///|
extern "js" fn viewer_dom_manifest(
  dom : ViewerDom,
  value : RenderValue,
) -> Unit =
  #|(dom,value) => {dom.manifest=value}

///|
extern "js" fn viewer_dom_set_view(dom : ViewerDom, id : String) -> Unit =
  #|(dom,id) => {dom.view=dom.manifest?.views.find(v=>v.id===id)}

///|
extern "js" fn viewer_dom_event(
  dom : ViewerDom,
  name : String,
  value : RenderValue,
) -> Unit =
  #|(dom,name,value) => {dom.api.dispatchEvent(new CustomEvent(name,{detail:value}))}

///|
extern "js" fn viewer_dom_view_event(dom : ViewerDom) -> Unit =
  #|(dom) => {dom.api.dispatchEvent(new CustomEvent('viewchange',{detail:dom.view}))}

///|
extern "js" fn viewer_dom_failure(dom : ViewerDom, message : String) -> Unit =
  #|(dom,message) => {const error=dom.errors.get(message)??new Error(message);dom.errors.delete(message);if(dom.api.dispatchEvent(new CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf viewer:',error)}

///|
extern "js" fn viewer_forget_error(dom : ViewerDom, message : String) -> Unit =
  #|(dom,message) => {dom.errors.delete(message)}

///|
// Preserve the original JavaScript rejection across MoonBit's async boundary.
extern "js" fn viewer_remember_js(
  dom : ViewerDom,
  promise : ViewerPromise,
) -> ViewerPromise =
  #|(dom,promise) => Promise.resolve(promise).catch(error=>{const key='bdf-viewer-error:'+ ++dom.errorSerial;dom.errors.set(key,error);throw key})

///|
#external
priv type ViewerPromise

///|
fn[X] viewer_promise_wrap(promise : @js_async.Promise[X]) -> ViewerPromise = "%identity"

///|
fn[X] viewer_promise_unwrap(promise : ViewerPromise) -> @js_async.Promise[X] = "%identity"

///|
fn[X] viewer_remember(
  dom : ViewerDom,
  promise : @js_async.Promise[X],
) -> @js_async.Promise[X] {
  viewer_promise_unwrap(viewer_remember_js(dom, viewer_promise_wrap(promise)))
}

///|
extern "js" fn viewer_dom_clear(dom : ViewerDom) -> Unit =
  #|(dom) => {dom.observer?.disconnect();dom.observer=null;dom.near.clear();cancelAnimationFrame(dom.frame);dom.frame=0;dom.sheetDraw=undefined;dom.schedule=undefined;dom.stage.onscroll=null;dom.stage.replaceChildren()}

///|
extern "js" fn viewer_dom_background(dom : ViewerDom, sheet : Bool) -> Unit =
  #|(dom,sheet) => {dom.stage.style.background=sheet?'white':'#e8e8e8'}

///|
extern "js" fn viewer_dom_row(
  dom : ViewerDom,
  gap : Int32,
  rtl : Bool,
) -> ViewerRow =
  #|(dom,gap,rtl) => {const row=document.createElement('div');row.style.cssText=`display:flex;justify-content:center;align-items:flex-start;gap:${gap}px;margin-bottom:${gap}px;width:max-content;min-width:100%;`;if(rtl)row.style.flexDirection='row-reverse';dom.stage.append(row);return row}

///|
extern "js" fn viewer_dom_page(
  dom : ViewerDom,
  row : ViewerRow,
  index : Int32,
  width : Double,
  height : Double,
) -> Unit =
  #|(dom,row,index,width,height) => {const frame=document.createElement('div');frame.dataset.bdfPage=String(index);frame.style.cssText=`position:relative;flex:none;width:${width}px;height:${height}px;background:white;`;const canvas=document.createElement('canvas');canvas.style.cssText='display:block;width:100%;height:100%';frame.append(canvas);row.append(frame);dom.observer.observe(frame)}

///|
extern "js" fn viewer_dom_observe(
  dom : ViewerDom,
  visible : (Int32, ViewerCanvas) -> Unit,
) -> Unit =
  #|(dom,visible) => {dom.observer=new IntersectionObserver(entries=>{for(const entry of entries){const frame=entry.target,canvas=frame.querySelector('canvas'),index=Number(frame.dataset.bdfPage);if(entry.isIntersecting){dom.near.add(frame);visible(index,canvas)}else{dom.near.delete(frame);if(canvas.width){canvas.width=canvas.height=0;canvas.dataset.loaded=''}frame.querySelector('[data-bdf-hits]')?.remove()}}},{root:dom.stage,rootMargin:'600px'})}

///|
extern "js" fn viewer_canvas_start(canvas : ViewerCanvas) -> Int32 =
  #|(canvas) => {if(canvas.dataset.loaded)return -1;canvas.dataset.loaded='loading';const request=Number(canvas.dataset.renderRequest??'0')+1;canvas.dataset.renderRequest=String(request);return request}

///|
extern "js" fn viewer_canvas_finish(
  canvas : ViewerCanvas,
  bitmap : ViewerBitmap,
  request : Int32,
  valid : Bool,
) -> Unit =
  #|(canvas,bitmap,request,valid) => {if(valid&&canvas.isConnected&&Number(canvas.dataset.renderRequest)===request){canvas.width=bitmap.width;canvas.height=bitmap.height;canvas.getContext('2d').drawImage(bitmap,0,0);canvas.dataset.loaded='ready'}bitmap.close()}

///|
extern "js" fn viewer_canvas_error(canvas : ViewerCanvas) -> Unit =
  #|(canvas) => {canvas.dataset.loaded=''}

///|
extern "js" fn viewer_pixel_ratio() -> Double =
  #|() => globalThis.devicePixelRatio??1

///|
extern "js" fn viewer_dom_destroy(dom : ViewerDom) -> Unit =
  #|(dom) => {dom.resize?.disconnect();dom.findDispose?.();dom.surface.remove();if(dom.owned)dom.renderer.terminate()}

///|
extern "js" fn viewer_raw_string(value : RenderValue) -> String =
  #|(value) => JSON.stringify(value)

///|
extern "js" fn viewer_raw_first_view(value : RenderValue) -> String =
  #|(value) => value.views?.[0]?.id??''
