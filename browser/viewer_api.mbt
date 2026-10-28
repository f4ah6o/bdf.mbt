///|
extern "js" fn viewer_facade(
  dom : ViewerDom,
  open : (RenderSourceInput, CryptoCredential) -> @js_async.Promise[RenderValue],
  open_file : (ViewerConverter, ViewerFileData, ViewerFileOptions) -> @js_async.Promise[
    RenderValue,
  ],
  set_view : (String) -> Unit,
  set_layout : (String) -> Unit,
  set_zoom : (Double) -> Unit,
  set_music : (String) -> Unit,
  find : (String, Int32) -> @js_async.Promise[ViewerFindState],
  clear_find : () -> Unit,
  open_find : () -> Unit,
  destroy : () -> Unit,
) -> BrowserViewer =
  #|(dom,open,openFile,setView,setLayout,setZoom,setMusic,find,clearFind,openFind,destroy) => {
  #| const api=new EventTarget();dom.api=api;api.host=dom.host;api.stage=dom.stage;api.surface=dom.surface;api.renderer=dom.renderer;
  #| Object.defineProperties(api,{document:{get:()=>dom.manifest,configurable:true},view:{get:()=>dom.view,configurable:true},pageLayout:{get:()=>dom.layout,configurable:true}});
  #| const restore=promise=>promise.catch(value=>{if(dom.errors.has(value)){const error=dom.errors.get(value);dom.errors.delete(value);throw error}throw value instanceof Error?value:new Error(String(value))});
  #| api.open=(source,password)=>restore(open(source,password));api.openFile=(converter,data,options)=>restore(openFile(converter,data,options));api.setView=id=>setView(id??'');api.setLayout=layout=>setLayout(layout);
  #| api.setZoom=zoom=>{if(!Number.isFinite(zoom)||zoom<=0||zoom>8)throw new RangeError('zoom must be in (0, 8]');setZoom(zoom)};
  #| api.setMusicMode=mode=>{if(mode==='piano-roll'&&typeof dom.options.music!=='function')throw new Error('piano roll requires @bdfkit/viewer/music');setMusic(mode)};
  #| api.find=(query,step=1)=>restore(find(query,step));api.clearFind=clearFind;api.openFind=openFind;
  #| api.show=()=>{if(dom.mode==='lightbox')dom.surface.style.display='block'};api.hide=()=>{if(dom.mode==='lightbox')dom.surface.style.display='none'};
  #| api.scrollToPage=index=>dom.stage.querySelector(`[data-bdf-page="${index}"]`)?.scrollIntoView({block:'start'});api.destroy=destroy;return api;
  #|}

///|
extern "js" fn viewer_validate_options(options : BrowserViewerOptions) -> Unit =
  #|(options) => {if(options?.musicMode==='piano-roll'&&typeof options?.music!=='function')throw new Error('piano roll requires @bdfkit/viewer/music')}

///|
/// Create a Worker-backed browser viewer. `options.renderer` may supply an
/// existing client; otherwise `options.workerUrl` selects the Worker module.
#export_name("bdf_create_viewer")
pub fn bdf_create_viewer(
  host : BrowserHost,
  options : BrowserViewerOptions,
) -> BrowserViewer {
  viewer_validate_options(options)
  let owned = !viewer_options_renderer(options)
  let renderer = if owned {
    bdf_create_render_worker(viewer_worker_url(options))
  } else {
    viewer_new_renderer(options)
  }
  let dom = viewer_dom_new(host, options, renderer, owned)
  let state = @viewer.Viewer::new()
  state.zoom = viewer_option_zoom(options)
  let layout = viewer_option_string(options, "layout", "single")
  state.layout = match layout {
    "spread" => @viewer.Spread
    "continuous" => @viewer.Continuous
    _ => @viewer.Single
  }
  let controller : ViewerController = {
    dom,
    renderer,
    options,
    viewer: state,
    manifest: None,
    current: None,
    generation: 0,
    sheet_request: 0,
    music_mode: viewer_option_string(options, "musicMode", "score"),
    document_serial: 0,
    active_stream: None,
    find_hits: None,
    find_cache: None,
    find_query: "",
    find_index: -1,
    find_more: false,
    find_turn: 0,
    find_stale: false,
    partial: false,
  }
  let api = viewer_facade(
    dom,
    (source, password) => {
      @js_async.Promise::from_async(() => controller.open(source, password))
    },
    (converter, data, opts) => {
      @js_async.Promise::from_async(() => {
        controller.open_file(converter, data, opts)
      })
    },
    id => controller.set_view(id),
    layout => controller.set_layout(layout),
    zoom => controller.set_zoom(zoom),
    mode => controller.set_music(mode),
    (query, step) => {
      @js_async.Promise::from_async(() => controller.find(query, step))
    },
    () => {
      controller.drop_find()
      viewer_bar_reset(dom)
    },
    () => controller.open_find(),
    () => controller.destroy(),
  )
  viewer_find_bar(dom, () => controller.drop_find())
  viewer_resize_observer(dom)
  api
}

///|
extern "js" fn viewer_class_prototype(
  api : BrowserViewer,
  ctor : (BrowserHost, BrowserViewerOptions) -> BrowserViewer,
) -> Unit =
  #|(api,ctor) => {
  #| const key=Symbol.for('f4ah6o.bdf.viewer.methods'),methods=['open','openFile','setView','setLayout','setZoom','setMusicMode','find','clearFind','openFind','show','hide','scrollToPage','destroy'],getters=['document','view','pageLayout'];
  #| if(Object.getPrototypeOf(ctor.prototype)!==EventTarget.prototype)Object.setPrototypeOf(ctor.prototype,EventTarget.prototype);
  #| if(!Object.hasOwn(ctor.prototype,key)){
  #|   Object.defineProperty(ctor.prototype,key,{value:true});
  #|   for(const name of methods)Object.defineProperty(ctor.prototype,name,{value:function(...args){return this[key].methods[name](...args)},writable:true,configurable:true});
  #|   for(const name of getters)Object.defineProperty(ctor.prototype,name,{get:function(){return this[key].getters[name]()},configurable:true});
  #| }
  #| const saved={methods:{},getters:{}};for(const name of methods){saved.methods[name]=api[name];delete api[name]}for(const name of getters){saved.getters[name]=Object.getOwnPropertyDescriptor(api,name).get;delete api[name]}Object.defineProperty(api,key,{value:saved});Object.setPrototypeOf(api,ctor.prototype)
  #|}

///|
/// JavaScript-compatible `new Viewer(host, options)` constructor.
#export_name("Viewer")
pub fn viewer_class(
  host : BrowserHost,
  options : BrowserViewerOptions,
) -> BrowserViewer {
  let api = bdf_create_viewer(host, options)
  viewer_class_prototype(api, viewer_class)
  api
}
