///|
#external
priv type ViewerViewport

///|
extern "js" fn viewer_sheet_setup(
  dom : ViewerDom,
  width : Double,
  height : Double,
  callback : (ViewerCanvas) -> Unit,
) -> Unit =
  #|(dom,width,height,callback) => {
  #| const spacer=document.createElement('div');spacer.style.cssText=`position:relative;width:${Math.max(dom.stage.clientWidth,width)}px;height:${Math.max(dom.stage.clientHeight,height)}px;`;
  #| const canvas=document.createElement('canvas');canvas.style.cssText='position:sticky;left:0;top:0;display:block';spacer.append(canvas);dom.stage.append(spacer);
  #| dom.sheetDraw=()=>callback(canvas);dom.schedule=()=>{if(dom.frame||!dom.sheetDraw)return;dom.frame=requestAnimationFrame(()=>{dom.frame=0;dom.sheetDraw?.()})};dom.stage.onscroll=dom.schedule;dom.schedule();
  #|}

///|
extern "js" fn viewer_resize_observer(dom : ViewerDom) -> Unit =
  #|(dom) => {dom.resize=new ResizeObserver(()=>dom.schedule?.());dom.resize.observe(dom.stage)}

///|
extern "js" fn viewer_sheet_viewport(
  dom : ViewerDom,
  zoom : Double,
) -> ViewerViewport =
  #|(dom,zoom) => ({x:dom.stage.scrollLeft/zoom,y:dom.stage.scrollTop/zoom,w:dom.stage.clientWidth/zoom,h:dom.stage.clientHeight/zoom})

///|
extern "js" fn viewer_viewport_field(
  viewport : ViewerViewport,
  name : String,
) -> Double =
  #|(viewport,name) => viewport[name]

///|
extern "js" fn viewer_renderer_sheet(
  renderer : BrowserRenderClient,
  view : String,
  viewport : ViewerViewport,
  scale : Double,
) -> @js_async.Promise[ViewerBitmap] =
  #|(renderer,view,viewport,scale) => renderer.sheet(view,viewport,scale)

///|
extern "js" fn viewer_sheet_finish(
  canvas : ViewerCanvas,
  bitmap : ViewerBitmap,
  width : Double,
  height : Double,
  valid : Bool,
) -> Unit =
  #|(canvas,bitmap,width,height,valid) => {if(valid){canvas.width=bitmap.width;canvas.height=bitmap.height;canvas.style.width=`${width}px`;canvas.style.height=`${height}px`;canvas.getContext('2d').drawImage(bitmap,0,0)}bitmap.close()}

///|
fn ViewerController::draw_sheet(
  self : ViewerController,
  view : @core.View,
  generation : Int32,
) -> Unit {
  viewer_dom_background(self.dom, true)
  let mut width = 0.0
  let mut height = 0.0
  for run in view.cols {
    width += run.count.to_double() * run.size
  }
  for run in view.rows {
    height += run.count.to_double() * run.size
  }
  viewer_sheet_setup(
    self.dom,
    width * self.viewer.zoom,
    height * self.viewer.zoom,
    canvas => {
      viewer_callback_ignore(
        @js_async.Promise::from_async(() => {
          self.render_sheet(view, canvas, generation)
        }),
      )
    },
  )
}

///|
async fn ViewerController::render_sheet(
  self : ViewerController,
  view : @core.View,
  canvas : ViewerCanvas,
  generation : Int32,
) -> Unit {
  viewer_callback_ignore(
    @js_async.Promise::from_async(() => self.mark_find_background()),
  )
  self.sheet_request += 1
  let request = self.sheet_request
  let viewport = viewer_sheet_viewport(self.dom, self.viewer.zoom)
  let width = viewer_viewport_field(viewport, "w") * self.viewer.zoom
  let height = viewer_viewport_field(viewport, "h") * self.viewer.zoom
  if width <= 0.0 || height <= 0.0 {
    return
  }
  try {
    let bitmap = viewer_remember(
      self.dom,
      viewer_renderer_sheet(
        self.renderer,
        view.id,
        viewport,
        self.viewer.zoom * viewer_pixel_ratio(),
      ),
    ).wait()
    viewer_sheet_finish(
      canvas,
      bitmap,
      width,
      height,
      generation == self.generation && request == self.sheet_request,
    )
  } catch {
    error => viewer_dom_failure(self.dom, error.to_string())
  }
}

///|
extern "js" fn viewer_music_draw(
  options : BrowserViewerOptions,
  dom : ViewerDom,
  renderer : BrowserRenderClient,
  zoom : Double,
  valid : () -> Bool,
) -> @js_async.Promise[Unit] =
  #|(options,dom,renderer,zoom,valid) => Promise.resolve().then(()=>options.music({stage:dom.stage,renderer,view:dom.view,zoom,isCurrent:valid}))

///|
async fn ViewerController::draw_music(
  self : ViewerController,
  _view : @core.View,
  generation : Int32,
) -> Unit {
  viewer_remember(
    self.dom,
    viewer_music_draw(self.options, self.dom, self.renderer, self.viewer.zoom, () => {
      generation == self.generation
    }),
  ).wait() catch {
    error => viewer_dom_failure(self.dom, error.to_string())
  }
}
