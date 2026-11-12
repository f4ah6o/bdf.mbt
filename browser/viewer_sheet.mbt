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
/// The sheetContent Worker request returns runs, links and figure bounds in
/// whole-sheet coordinates; a tile text layer is positioned at the tile
/// origin, so shift the extracted content back into tile-local coordinates.
extern "js" fn text_layer_tile_origin(
  data : TextLayerData,
  x : Double,
  y : Double,
  tile : Double,
) -> TextLayerData =
  #|(data,x,y,tile) => {const dx=x*tile,dy=y*tile;for(const r of data.runs){r.x-=dx;r.y-=dy}for(const l of data.links){l.x-=dx;l.y-=dy}for(const n of data.nodes)if(n.bounds){n.bounds.x-=dx;n.bounds.y-=dy}return data}

///|
/// Mount the sheet selection text layer for a Worker-backed renderer: the
/// installed spacer fetches tile text content for visited tiles, tracks the
/// selected cell rectangle, and resolves the rectangle's clipboard through
/// the renderer's sheetClipboard request. Tile content failures surface as
/// viewer `error` events, while clipboard failures stay with the copy
/// handler's `clipboarderror` events.
extern "js" fn viewer_sheet_text_setup(
  dom : ViewerDom,
  renderer : BrowserRenderClient,
  view : String,
  tile_size : Double,
  zoom : Double,
  mount : (BrowserHost, RenderValue, Double, Double) -> Unit,
) -> Unit =
  #|(dom,renderer,view,tileSize,zoom,mount) => {
  #| const stage=dom.stage,spacer=stage.firstElementChild,doc=stage.ownerDocument,cellKey=Symbol.for('f4ah6o.bdf.cell'),tableKey=Symbol.for('f4ah6o.bdf.table'),sheetKey=Symbol.for('f4ah6o.bdf.sheetCells');
  #| if(!spacer||!Number.isFinite(tileSize)||tileSize<=0)return;let live=true,running=0,pending=null,cached=null,clipboardSerial=Promise.resolve();const queue=[],tiles=new Map();
  #| const current=()=>live&&stage.contains(spacer)&&dom.view?.id===view;
  #| const failure=error=>{if(!current())return;if(!dom.api?.dispatchEvent(new CustomEvent('error',{detail:error,cancelable:true})))return;console.error('bdf viewer:',error)};
  #| const cell=node=>{for(let el=node?.nodeType===1?node:node?.parentElement;el&&el!==spacer;el=el.parentElement)if(el[cellKey])return el[cellKey];return null};
  #| const range=()=>{const s=doc.getSelection();if(!s||s.isCollapsed||!spacer.contains(s.anchorNode)||!spacer.contains(s.focusNode))return null;const a=cell(s.anchorNode),b=cell(s.focusNode);if(!a||!b||a.row===b.row&&a.col===b.col)return null;const r={row0:Math.min(a.row,b.row),col0:Math.min(a.col,b.col),row1:Math.max(a.row+a.rows,b.row+b.rows)-1,col1:Math.max(a.col+a.cols,b.col+b.cols)-1};let changed=true;while(changed){changed=false;for(const c of info.cells){if(c.row>r.row1||c.row+c.rows-1<r.row0||c.col>r.col1||c.col+c.cols-1<r.col0)continue;const values=[Math.min(r.row0,c.row),Math.min(r.col0,c.col),Math.max(r.row1,c.row+c.rows-1),Math.max(r.col1,c.col+c.cols-1)];if(values[0]!==r.row0||values[1]!==r.col0||values[2]!==r.row1||values[3]!==r.col1){[r.row0,r.col0,r.row1,r.col1]=values;changed=true}}}return r};
  #| const key=r=>r&&`${r.row0},${r.col0},${r.row1},${r.col1}`;
  #| const info={sheet:true,anchor:spacer,layer:spacer,cells:[],size:0,rows:(dom.view.rows??[]).reduce((n,r)=>n+r[0],0),cols:(dom.view.cols??[]).reduce((n,r)=>n+r[0],0),headerRows:0,headerCols:0,sync(){},ready(){const k=key(range());return !!k&&cached?.key===k},clipboard(r0,c0,r1,c1){return cached?.key===key({row0:r0,col0:c0,row1:r1,col1:c1})?cached.value:{error:true}},prepare(){const r=range(),k=key(r);if(!r||cached?.key===k)return Promise.resolve();if(pending?.key===k)return pending.promise;const promise=clipboardSerial.then(()=>current()&&key(range())===k?renderer.sheetClipboard(view,r):null).then(value=>{if(value&&current()&&key(range())===k){cached={key:k,value};dom.host.dispatchEvent(new Event('clipboardready'));doc.dispatchEvent(new Event('selectionchange'))}}).finally(()=>{if(pending?.key===k)pending=null});clipboardSerial=promise.catch(()=>{});pending={key:k,promise};return promise}};
  #| spacer[sheetKey]=info;spacer[tableKey]=info;
  #| const evict=()=>{for(const [k,v] of tiles){if(tiles.size<=256)break;const sel=doc.getSelection();if(v.layer&&sel?.rangeCount&&!sel.isCollapsed&&sel.getRangeAt(0).intersectsNode(v.layer))continue;if(v.layer){info.cells=info.cells.filter(c=>c.owner!==v.layer);v.layer.remove()}tiles.delete(k)}};
  #| const pump=()=>{while(current()&&running<4&&queue.length){const item=queue.shift();running++;renderer.sheetContent(view,{x:item.x*tileSize,y:item.y*tileSize,w:1,h:1}).then(content=>{if(!current()||tiles.get(item.key)!==item)return;const before=info.cells.length;mount(spacer,content,item.x,item.y);const layer=spacer.lastElementChild;if(!layer?.classList.contains('bdfTextLayer'))return;layer.dataset.bdfSheetTile=item.key;item.layer=layer;for(const c of info.cells.slice(before))c.owner=layer;for(const other of spacer.querySelectorAll(':scope > [data-bdf-sheet-tile]')){if(other===layer)continue;const [x,y]=other.dataset.bdfSheetTile.split(',').map(Number);if(y>item.y||y===item.y&&x>item.x){spacer.insertBefore(layer,other);break}}evict()}).catch(error=>{tiles.delete(item.key);failure(error)}).finally(()=>{running--;pump()})}};
  #| const schedule=()=>{if(!current())return;const x0=Math.floor(stage.scrollLeft/zoom/tileSize),y0=Math.floor(stage.scrollTop/zoom/tileSize),x1=Math.floor((stage.scrollLeft+stage.clientWidth)/zoom/tileSize),y1=Math.floor((stage.scrollTop+stage.clientHeight)/zoom/tileSize),raw=dom.view.tiles,known=raw&&Object.keys(raw).length?raw:null;let added=0;for(let y=y0;y<=y1&&added<128;y++)for(let x=x0;x<=x1&&added<128;x++){const k=`${x},${y}`;if(tiles.has(k)||known&&!Object.hasOwn(known,k))continue;const item={key:k,x,y};tiles.set(k,item);queue.push(item);added++}pump()};
  #| const draw=dom.sheetDraw;dom.sheetDraw=()=>{draw?.();schedule()};dom.sheetTextDispose=()=>{live=false;queue.length=0;tiles.clear()};schedule();
  #|}

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
  let zoom = self.viewer.zoom
  let tile = view.tile_size
  viewer_sheet_text_setup(self.dom, self.renderer, view.id, tile, zoom, (container, content, x, y) => {
    let data = text_layer_sheet_root(
      text_layer_tile_origin(text_layer_from_content(content), x, y, tile),
    )
    render_text_layer(container, data, x * tile * zoom, y * tile * zoom, tile * zoom, tile * zoom, zoom)
  })
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
