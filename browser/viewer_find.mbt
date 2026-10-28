///|
#external
priv type ViewerHits

///|
#external
priv type ViewerHitSelection

///|
#external
priv type ViewerHitRects

///|
#external
priv type ViewerFindCache

///|
#external
priv type ViewerFindState

///|
extern "js" fn viewer_search(
  renderer : BrowserRenderClient,
  view : String,
  query : String,
) -> @js_async.Promise[ViewerHits] =
  #|(renderer,view,query) => query.trim()?renderer.search(view,query,{limit:1001}):Promise.resolve([])

///|
extern "js" fn viewer_hits_count(hits : ViewerHits) -> Int32 =
  #|(hits) => hits.length

///|
extern "js" fn viewer_hits_limit(hits : ViewerHits) -> ViewerHits =
  #|(hits) => hits.slice(0,1000)

///|
extern "js" fn viewer_hit_start(
  hits : ViewerHits,
  page : Int32,
  sheet : Bool,
) -> Int32 =
  #|(hits,page,sheet) => {if(sheet)return 0;const i=hits.findIndex(h=>h.segments[0].a>=page);return i<0?0:i}

///|
extern "js" fn viewer_same_hit(
  old : ViewerHits,
  index : Int32,
  next : ViewerHits,
) -> Int32 =
  #|(old,index,next) => {const s=old[index]?.segments[0];return s?next.findIndex(h=>{const t=h.segments[0];return t.a===s.a&&t.b===s.b&&t.ordinal===s.ordinal&&t.start===s.start}):-1}

///|
extern "js" fn viewer_reading(dom : ViewerDom) -> Int32 =
  #|(dom) => {const top=dom.stage.getBoundingClientRect().top;let index=Infinity;for(const frame of dom.near)if(frame.getBoundingClientRect().bottom>top)index=Math.min(index,Number(frame.dataset.bdfPage));return Number.isFinite(index)?index:0}

///|
extern "js" fn viewer_find_state(
  query : String,
  index : Int32,
  total : Int32,
  more : Bool,
) -> ViewerFindState =
  #|(query,index,total,more) => ({query,index,total,more})

///|
extern "js" fn viewer_find_report(
  dom : ViewerDom,
  state : ViewerFindState,
  hits : ViewerHits,
  index : Int32,
) -> Unit =
  #|(dom,state,hits,index) => {dom.findReport?.(state,hits[index],dom.view);dom.api.dispatchEvent(new CustomEvent('findchange',{detail:state}))}

///|
extern "js" fn viewer_find_clear_marks(dom : ViewerDom) -> Unit =
  #|(dom) => {for(const el of dom.stage.querySelectorAll('[data-bdf-hits]'))el.remove();dom.findReport?.()}

///|
extern "js" fn viewer_find_remove_marks(dom : ViewerDom) -> Unit =
  #|(dom) => {for(const el of dom.stage.querySelectorAll('[data-bdf-hits]'))el.remove()}

///|
extern "js" fn viewer_find_selection(
  dom : ViewerDom,
  hits : ViewerHits,
  index : Int32,
  sheet : Bool,
  tile : Double,
  zoom : Double,
) -> ViewerHitSelection =
  #|(dom,hits,index,sheet,tile,zoom) => {
  #| const stage=dom.stage,area=stage.getBoundingClientRect(),pages=new Set();
  #| if(!sheet)for(const frame of dom.near)pages.add(Number(frame.dataset.bdfPage));
  #| const x0=stage.scrollLeft/zoom,y0=stage.scrollTop/zoom,x1=x0+stage.clientWidth/zoom,y1=y0+stage.clientHeight/zoom;
  #| const indices=[];for(let i=0;i<hits.length;i++){const near=hits[i].segments.some(s=>sheet?s.a*tile<x1&&(s.a+1)*tile>x0&&s.b*tile<y1&&(s.b+1)*tile>y0:pages.has(s.a));if(near||i===index)indices.push(i)}
  #| return {indices,hits:indices.map(i=>hits[i])};
  #|}

///|
extern "js" fn viewer_find_cache() -> ViewerFindCache =
  #|() => ({rects:new Map(),pending:new Map()})

///|
extern "js" fn viewer_locate(
  renderer : BrowserRenderClient,
  view : String,
  selection : ViewerHitSelection,
  cache : ViewerFindCache,
) -> @js_async.Promise[ViewerHitRects] =
  #|async (renderer,view,selection,cache) => {
  #| const waits=new Set(),todo=[];for(let n=0;n<selection.indices.length;n++){const i=selection.indices[n];if(cache.rects.has(i))continue;const pending=cache.pending.get(i);if(pending)waits.add(pending);else todo.push(n)}
  #| if(todo.length){const batch=renderer.locate(view,todo.map(n=>selection.hits[n])).then(rects=>{todo.forEach((n,k)=>cache.rects.set(selection.indices[n],rects[k]??[]))}).finally(()=>{for(const n of todo)cache.pending.delete(selection.indices[n])});for(const n of todo)cache.pending.set(selection.indices[n],batch);waits.add(batch)}
  #| await Promise.all(waits);return selection.indices.map(i=>cache.rects.get(i)??[])
  #|}

///|
extern "js" fn viewer_selection_length(selection : ViewerHitSelection) -> Int32 =
  #|(selection) => selection.indices.length

///|
extern "js" fn viewer_find_mark(
  dom : ViewerDom,
  selection : ViewerHitSelection,
  rects : ViewerHitRects,
  index : Int32,
  zoom : Double,
  sheet : Bool,
  reveal : Bool,
) -> Unit =
  #|(dom,selection,rects,index,zoom,sheet,reveal) => {
  #| for(const old of dom.stage.querySelectorAll('[data-bdf-hits]'))old.remove();const layers=new Map();let target;
  #| for(let n=0;n<selection.indices.length;n++)for(const rect of rects[n]??[]){const i=selection.indices[n];if(i===index&&!target)target=rect;const frame=sheet?dom.stage.firstElementChild:dom.stage.querySelector(`[data-bdf-page="${rect.a}"]`);if(!frame||(!sheet&&!dom.near.has(frame)))continue;let layer=layers.get(frame);if(!layer){layer=document.createElement('div');layer.dataset.bdfHits='';layer.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;forced-color-adjust:none';layers.set(frame,layer);frame.append(layer)}const box=document.createElement('div');box.style.cssText=`position:absolute;left:${rect.x*zoom}px;top:${rect.y*zoom}px;width:${rect.w*zoom}px;height:${rect.h*zoom}px;border-radius:2px;`+(i===index?'background:rgba(255,120,0,.5);outline:1px solid #c04000':'background:rgba(255,210,0,.45);outline:1px solid rgba(200,140,0,.8)');layer.append(box)}
  #| if(!reveal||!target)return;const stage=dom.stage;if(sheet){stage.scrollTo({left:Math.max(0,target.x*zoom-stage.clientWidth/2),top:Math.max(0,target.y*zoom-stage.clientHeight/2)});return}const frame=stage.querySelector(`[data-bdf-page="${target.a}"]`);if(!frame)return;const area=stage.getBoundingClientRect(),at=frame.getBoundingClientRect(),x=at.left-area.left+target.x*zoom,y=at.top-area.top+target.y*zoom,aside=x<0||x+target.w*zoom>stage.clientWidth;stage.scrollTo({top:Math.max(0,stage.scrollTop+y-stage.clientHeight/3),left:aside?Math.max(0,stage.scrollLeft+x-stage.clientWidth/2):stage.scrollLeft})
  #|}

///|
fn ViewerController::drop_find(self : ViewerController) -> Unit {
  let searched = self.find_hits is Some(_) && self.find_query != ""
  self.find_turn += 1
  self.find_hits = None
  self.find_cache = None
  self.find_query = ""
  self.find_index = -1
  self.find_stale = false
  viewer_find_clear_marks(self.dom)
  if searched {
    viewer_find_report(
      self.dom,
      viewer_find_state("", -1, 0, false),
      viewer_empty_hits(),
      -1,
    )
  }
}

///|
extern "js" fn viewer_empty_hits() -> ViewerHits =
  #|() => []

///|
async fn ViewerController::find(
  self : ViewerController,
  query : String,
  step : Int32,
) -> ViewerFindState {
  self.run_find(query, step, true)
}

///|
async fn ViewerController::run_find(
  self : ViewerController,
  query : String,
  step : Int32,
  reveal : Bool,
) -> ViewerFindState {
  guard self.current is Some(view) else {
    return viewer_find_state(query, -1, 0, false)
  }
  if self.music_mode == "piano-roll" &&
    view.play is Some(play) &&
    play.seq is Some(_) &&
    viewer_has_music(self.options) {
    return viewer_find_state(query, -1, 0, false)
  }
  self.find_turn += 1
  let turn = self.find_turn
  let old = self.find_hits
  if old is None || query != self.find_query || self.find_stale || self.partial {
    self.find_stale = false
    let all = viewer_remember(
      self.dom,
      viewer_search(self.renderer, view.id, query),
    ).wait()
    let more = viewer_hits_count(all) > 1000
    let hits = viewer_hits_limit(all)
    let count = viewer_hits_count(hits)
    if turn != self.find_turn {
      return viewer_find_state(query, -1, count, more)
    }
    let same = if old is Some(previous) && query == self.find_query {
      viewer_same_hit(previous, self.find_index, hits)
    } else {
      -1
    }
    let start = viewer_hit_start(
      hits,
      viewer_reading(self.dom),
      view.kind == "sheet",
    )
    self.find_index = if count == 0 {
      -1
    } else if same >= 0 {
      (same + step + count) % count
    } else if step < 0 {
      (start - 1 + count) % count
    } else {
      start
    }
    self.find_query = query
    self.find_hits = Some(hits)
    self.find_cache = Some(viewer_find_cache())
    self.find_more = more
  } else if old is Some(hits) && viewer_hits_count(hits) > 0 {
    let count = viewer_hits_count(hits)
    self.find_index = (self.find_index + step + count) % count
  }
  guard self.find_hits is Some(hits) else {
    return viewer_find_state(query, -1, 0, false)
  }
  let state = viewer_find_state(
    query,
    self.find_index,
    viewer_hits_count(hits),
    self.find_more,
  )
  viewer_find_report(self.dom, state, hits, self.find_index)
  self.mark_find(reveal)
  state
}

///|
async fn ViewerController::mark_find(
  self : ViewerController,
  reveal : Bool,
) -> Unit {
  guard self.current is Some(view) &&
    self.find_hits is Some(hits) &&
    self.find_cache is Some(cache) else {
    return
  }
  let turn = self.find_turn
  let selection = viewer_find_selection(
    self.dom,
    hits,
    self.find_index,
    view.kind == "sheet",
    view.tile_size,
    self.viewer.zoom,
  )
  if viewer_selection_length(selection) == 0 {
    viewer_find_remove_marks(self.dom)
    return
  }
  let rects = viewer_remember(
    self.dom,
    viewer_locate(self.renderer, view.id, selection, cache),
  ).wait()
  if turn == self.find_turn {
    viewer_find_mark(
      self.dom,
      selection,
      rects,
      self.find_index,
      self.viewer.zoom,
      view.kind == "sheet",
      reveal,
    )
  }
}

///|
fn ViewerController::open_find(self : ViewerController) -> Unit {
  guard self.current is Some(view) else { return }
  if self.music_mode == "piano-roll" &&
    view.play is Some(play) &&
    play.seq is Some(_) &&
    viewer_has_music(self.options) {
    return
  }
  viewer_bar_open(self.dom)
  let query = viewer_bar_query(self.dom)
  if query != "" && self.find_hits is None {
    viewer_callback_ignore(
      @js_async.Promise::from_async(() => self.find_background(query)),
    )
  }
}

///|
async fn ViewerController::mark_find_background(
  self : ViewerController,
) -> Unit {
  self.mark_find(false) catch {
    error => viewer_dom_failure(self.dom, error.to_string())
  }
}

///|
async fn ViewerController::find_background(
  self : ViewerController,
  query : String,
) -> Unit {
  ignore(self.find(query, 0)) catch {
    error => viewer_dom_failure(self.dom, error.to_string())
  }
}

///|
async fn ViewerController::research_background(
  self : ViewerController,
  query : String,
) -> Unit {
  ignore(self.run_find(query, 0, false)) catch {
    error => viewer_dom_failure(self.dom, error.to_string())
  }
}
