///|
#external
pub type BrowserFindResult

///|
#external
priv type FindMeasure

///|
extern "js" fn find_measure_context(host : BrowserHost) -> FindMeasure =
  #|(host) => { const ctx=host.ownerDocument.createElement('canvas').getContext('2d'); if(!ctx)throw new Error('Canvas 2D context unavailable'); return ctx; }

///|
extern "js" fn measure_find_text(
  context : FindMeasure,
  family : String,
  weight : Int32,
  style : Int32,
  size : Double,
  text : String,
) -> Double =
  #|(ctx,family,weight,style,size,text) => {ctx.font=`${['normal','italic','oblique'][style]??'normal'} ${weight||400} ${size}px ${family||'sans-serif'}`;return ctx.measureText(text).width}

///|
extern "js" fn find_result(
  query : String,
  index : Int32,
  total : Int32,
  more : Bool,
  detail : String,
) -> BrowserFindResult =
  #|(query,index,total,more,detail) => ({query,index,total,more,detail,rects:[]})

///|
extern "js" fn add_find_rect(
  result : BrowserFindResult,
  hit : Int32,
  page : Int32,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> Unit =
  #|(r,hit,page,x,y,w,h) => r.rects.push({hit,page,x,y,w,h})

///|
extern "js" fn find_nonblank(query : String) -> Bool =
  #|(query) => query.trim().length>0

///|
extern "js" fn find_scroll_top(host : BrowserHost) -> Double =
  #|(host) => host.scrollTop

///|
extern "js" fn throw_find_error(message : String) -> BrowserFindResult =
  #|(message) => { throw new Error(message); }

///|
fn find_font_family(font : @core.Font) -> String {
  match font.hash {
    Some(hash) =>
      if font.family == "" {
        "\"bdf-" + hash + "\""
      } else {
        "\"bdf-" + hash + "\", " + font.family
      }
    None => if font.family == "" { "sans-serif" } else { font.family }
  }
}

///|
fn install_document_find(
  host : BrowserHost,
  document : BrowserDocument,
  view : @core.View,
  placements : Array[@viewer.Placement],
  runs : Array[Array[Array[@render.TextRun]]],
  fallback : Array[@core.IndexRun],
  viewer : @viewer.Viewer,
) -> Unit {
  let measure = find_measure_context(host)
  let mut searchable : @core.TextSearch? = None
  let mut last_query = ""
  let mut hits : Array[@core.SearchHit] = []
  let mut selected = -1
  let mut more = false
  install_find_dom(
    host,
    (query, step) => {
      let zoom = viewer.zoom
      try {
        if !find_nonblank(query) {
          last_query = ""
          hits = []
          selected = -1
          more = false
          find_result(query, -1, 0, false, "")
        } else {
          if query != last_query {
            let search = match searchable {
              Some(index) => index
              None => {
                let index = match view.text_index {
                  Some(hash) => @core.decode_text_index(document.part(hash))
                  None => fallback
                }
                let value = @core.TextSearch::new(index)
                searchable = Some(value)
                value
              }
            }
            hits = search.search(query, limit=1001)
            more = hits.length() > 1000
            if more {
              ignore(hits.pop())
            }
            last_query = query
            let top = find_scroll_top(host)
            let mut page = 0
            for placement in placements {
              if placement.y + placement.height > top {
                page = placement.index
                break
              }
            }
            let mut start = 0
            for i, hit in hits {
              if hit.segments.length() > 0 && hit.segments[0].a >= page {
                start = i
                break
              }
            }
            selected = if hits.is_empty() {
              -1
            } else if step < 0 {
              (start + hits.length() - 1) % hits.length()
            } else {
              start
            }
          } else if !hits.is_empty() {
            let change = if step < 0 { -1 } else if step > 0 { 1 } else { 0 }
            selected = (selected + change + hits.length()) % hits.length()
          }
          let detail = if selected >= 0 {
            let hit = hits[selected]
            (if view.kind == "scroll" {
              ""
            } else {
              "page " + (hit.segments[0].a + 1).to_string() + ": "
            }) +
            hit.context.replace_all(old=" ⏎ ", new=" ")
          } else {
            ""
          }
          let result = find_result(query, selected, hits.length(), more, detail)
          for index, hit in hits {
            let rects = @render.locate_text_hit(
              hit,
              (a, b, ordinal) => {
                if a < 0 ||
                  a >= runs.length() ||
                  b < 0 ||
                  b >= runs[a].length() ||
                  ordinal < 0 ||
                  ordinal >= runs[a][b].length() {
                  None
                } else {
                  Some(runs[a][b][ordinal])
                }
              },
              (font, size, text) => {
                measure_find_text(
                  measure,
                  find_font_family(font),
                  font.weight,
                  font.style,
                  size,
                  text,
                )
              },
            )
            for rect in rects {
              if rect.a >= 0 && rect.a < placements.length() {
                let placement = placements[rect.a]
                add_find_rect(
                  result,
                  index,
                  rect.a,
                  placement.x + rect.x * zoom,
                  placement.y + rect.y * zoom,
                  rect.width * zoom,
                  rect.height * zoom,
                )
              }
            }
          }
          result
        }
      } catch {
        error => throw_find_error(error.to_string())
      }
    },
    (_, _) => {
      @js_async.Promise::from_async(() => find_result("", -1, 0, false, ""))
    },
    false,
  )
}

///|
// The browser owns the DOM and event lifecycle; the search and rectangles
// passed into this adapter are computed by MoonBit.
extern "js" fn install_find_dom(
  host : BrowserHost,
  search : (String, Int32) -> BrowserFindResult,
  search_async : (String, Int32) -> @js_async.Promise[BrowserFindResult],
  sheet : Bool,
) -> Unit =
  #|(host,search,searchAsync,sheet) => {
  #| const doc=host.ownerDocument,win=doc.defaultView,key=Symbol.for('f4ah6o.bdf.find');let bar,input,status,timer,last,layer,observer,disposed=false,turn=0,working=false,dirty=false,refreshFrame=0;
  #| const addedTab=!host.hasAttribute('tabindex');if(addedTab)host.tabIndex=-1;
  #| const barCSS='position:absolute;top:8px;right:24px;z-index:10;display:none;align-items:center;gap:4px;max-width:calc(100% - 48px);box-sizing:border-box;padding:4px 6px;border:1px solid #b8b8b8;border-radius:6px;background:#fff;color:#222;box-shadow:0 2px 10px rgba(0,0,0,.25);font:13px/1.4 system-ui,sans-serif;color-scheme:light;text-align:left;direction:ltr';
  #| const fieldCSS='flex:1 1 12em;width:12em;min-width:4em;box-sizing:border-box;margin:0;padding:3px 6px;border:1px solid #b8b8b8;border-radius:4px;background:#fff;color:#222;font:inherit',countCSS='flex:none;min-width:4.5em;text-align:center;color:#555;white-space:nowrap;font-variant-numeric:tabular-nums',buttonCSS='flex:none;width:26px;height:26px;margin:0;padding:0;border:0;border-radius:4px;background:transparent;color:#333;font:inherit;line-height:1;cursor:pointer';
  #| const mark=r=>{layer?.remove();layer=null;if(!r.rects.length)return;layer=doc.createElement('div');layer.dataset.bdfHits='';layer.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;forced-color-adjust:none';for(const box of r.rects){const el=doc.createElement('div');el.dataset.bdfHit=String(box.hit);el.style.cssText=`position:absolute;left:${box.x}px;top:${box.y}px;width:${box.w}px;height:${box.h}px;border-radius:2px;`+(box.hit===r.index?'background:rgba(255,120,0,.5);outline:1px solid #c04000':'background:rgba(255,210,0,.45);outline:1px solid rgba(200,140,0,.8)');layer.append(el)}host.insertBefore(layer,bar??null)};
  #| const report=r=>{if(!status)return;status.textContent=!r.query.trim()?'':!r.total?'No matches':`${r.index+1} / ${r.total}${r.more?'+':''}`;if(r.total&&r.detail){const d=doc.createElement('span');d.style.cssText='position:absolute;width:1px;height:1px;overflow:hidden;clip-path:inset(50%);white-space:nowrap';d.textContent=' '+r.detail;status.append(d)}};
  #| const apply=(r,reveal,notify=true)=>{last=r;mark(r);report(r);if(notify)host.dispatchEvent(new win.CustomEvent('findchange',{detail:{query:r.query,index:r.index,total:r.total,more:r.more}}));if(reveal&&r.index>=0){const box=r.rects.find(box=>box.hit===r.index);if(sheet&&box)host.scrollTo({left:Math.max(0,box.x-host.clientWidth/2),top:Math.max(0,box.y-host.clientHeight/2)});else layer?.querySelector(`[data-bdf-hit="${r.index}"]`)?.scrollIntoView({block:'nearest',inline:'nearest'})}return r};
  #| const find=(query,step=1,reveal=true)=>{if(disposed)throw new Error('BDF host is unmounted');if(sheet)throw new Error('Sheet search is asynchronous; use bdf_find_async');return apply(search(query,step),reveal)};
  #| const findAsync=async(query,step=1,reveal=true,notify=true)=>{if(disposed)throw new Error('BDF host is unmounted');if(!sheet)return find(query,step,reveal);const current=++turn;working=true;try{const r=await searchAsync(query,step);return !disposed&&current===turn?apply(r,reveal,notify):r}catch(error){if(disposed||current!==turn)return {query,index:-1,total:0,more:false,detail:'',rects:[]};throw error}finally{if(current===turn){working=false;if(dirty){dirty=false;position()}}}};
  #| const fail=error=>{if(disposed)return;if(status)status.textContent='Search failed';host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true}))};
  #| const safe=(query,step)=>{if(sheet){findAsync(query,step).catch(fail);return}try{find(query,step)}catch(error){fail(error)}};
  #| const step=d=>{win.clearTimeout(timer);safe(input.value,d)};
  #| const hide=()=>{win.clearTimeout(timer);if(bar)bar.style.display='none';if(status)status.textContent=''};
  #| const clear=reset=>{const had=!!last?.query;turn++;working=false;dirty=false;if(refreshFrame)win.cancelAnimationFrame(refreshFrame);refreshFrame=0;hide();if(reset&&input)input.value='';layer?.remove();layer=null;last=undefined;if(sheet)void searchAsync('',0).catch(fail);else search('',0);if(had)host.dispatchEvent(new win.CustomEvent('findchange',{detail:{query:'',index:-1,total:0,more:false}}))};
  #| const close=()=>{clear(false);host.focus({preventScroll:true})};
  #| const position=()=>{if(bar){bar.style.top=(host.scrollTop+8)+'px';bar.style.right=(24-host.scrollLeft)+'px'}if(sheet&&last?.query){if(working){dirty=true;return}if(!refreshFrame)refreshFrame=win.requestAnimationFrame(()=>{refreshFrame=0;if(last?.query)void findAsync(last.query,0,false,false).catch(fail)})}};
  #| const make=()=>{if(bar)return;bar=doc.createElement('div');bar.style.cssText=barCSS;bar.setAttribute('role','search');input=doc.createElement('input');input.type='search';input.placeholder='Find in document';input.setAttribute('aria-label','Find in document');input.autocomplete='off';input.spellcheck=false;input.style.cssText=fieldCSS;status=doc.createElement('span');status.style.cssText=countCSS;status.setAttribute('role','status');const button=(text,label,click)=>{const b=doc.createElement('button');b.type='button';b.textContent=text;b.title=label;b.setAttribute('aria-label',label);b.style.cssText=buttonCSS;b.onpointerenter=()=>{b.style.background='#e8e8e8'};b.onpointerleave=()=>{b.style.background='transparent'};b.onclick=click;return b};bar.append(input,status,button('▲','Previous match',()=>step(-1)),button('▼','Next match',()=>step(1)),button('✕','Close',close));const typed=()=>{win.clearTimeout(timer);if(!input.value){safe('',0);return}timer=win.setTimeout(()=>safe(input.value,0),150)};input.addEventListener('input',e=>{if(!e.isComposing)typed()});input.addEventListener('compositionend',typed);bar.addEventListener('keydown',e=>{if(e.isComposing||e.keyCode===229)return;if(e.key==='Escape'){e.preventDefault();e.stopPropagation();close()}else if(e.key==='Enter'&&e.target===input){e.preventDefault();step(e.shiftKey?-1:1)}});host.append(bar)};
  #| const open=()=>{make();position();bar.style.display='flex';input.focus({preventScroll:true});input.select();if(last)report(last);else if(input.value)safe(input.value,0)};
  #| const onkey=e=>{if(e.defaultPrevented||e.isComposing||e.altKey)return;const nav=win.navigator,apple=/mac|iphone|ipad|ipod/i.test(nav.userAgentData?.platform||nav.platform||nav.userAgent||'');let action='';if(e.key==='F3'&&!e.metaKey&&!e.ctrlKey)action=e.shiftKey?'previous':'next';else if(apple?e.metaKey&&!e.ctrlKey:e.ctrlKey&&!e.metaKey){const letter=/^[a-z]$/i.test(e.key)?e.key.toLowerCase():/^Key[A-Z]$/.test(e.code)&&!/^[\x20-\x7e]$/.test(e.key)?e.code[3].toLowerCase():'';if(letter==='f'&&!e.shiftKey)action='open';else if(letter==='g')action=e.shiftKey?'previous':'next'}if(action==='open'){if(bar?.style.display!=='none'&&doc.activeElement===input)return;e.preventDefault();open()}else if(action&&bar?.style.display!=='none'&&input?.value){e.preventDefault();step(action==='next'?1:-1)}};
  #| const focusCanvas=e=>{if(e.target?.tagName==='CANVAS')host.focus({preventScroll:true})};host.addEventListener('pointerdown',focusCanvas);host.addEventListener('keydown',onkey);host.addEventListener('scroll',position);host[key]={find,findAsync,open,refresh(){if(!disposed&&!sheet&&last?.query)apply(search(last.query,0),false,false)},clear:()=>clear(true),dispose(){disposed=true;turn++;if(refreshFrame)win.cancelAnimationFrame(refreshFrame);observer?.disconnect();win.clearTimeout(timer);host.removeEventListener('pointerdown',focusCanvas);host.removeEventListener('keydown',onkey);host.removeEventListener('scroll',position);layer?.remove();bar?.remove();if(addedTab)host.removeAttribute('tabindex')}};
  #| if(typeof MutationObserver==='function'){const watch=(weak,k,owner,connected)=>{const ob=new MutationObserver(()=>{const h=weak.deref();if(!h){ob.disconnect();return}if(h.isConnected)connected=true;else if(connected){h[k]?.dispose();delete h[k]}});ob.observe(owner,{childList:true,subtree:true});return ob};const weak=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host};observer=watch(weak,key,doc,host.isConnected)}
  #|}

///|
extern "js" fn browser_find(
  host : BrowserHost,
  query : String,
  step : Int32,
) -> BrowserFindResult =
  #|(host,query,step) => {const find=host[Symbol.for('f4ah6o.bdf.find')];if(!find)throw new Error('BDF host is not interactive');return find.find(query,step===undefined?1:step)}

///|
/// Search the mounted interactive view and reveal a match.
#export_name("bdf_find")
pub fn bdf_find(
  host : BrowserHost,
  query : String,
  step : Int32,
) -> BrowserFindResult {
  browser_find(host, query, step)
}

///|
/// Search an interactive page or sheet asynchronously and reveal a match.
#export_name("bdf_find_async")
pub fn bdf_find_async(
  host : BrowserHost,
  query : String,
  step : Int32,
) -> @js_async.Promise[BrowserFindResult] {
  browser_find_async(host, query, step)
}

///|
extern "js" fn browser_find_async(
  host : BrowserHost,
  query : String,
  step : Int32,
) -> @js_async.Promise[BrowserFindResult] =
  #|(host,query,step) => {const find=host[Symbol.for('f4ah6o.bdf.find')];if(!find)return Promise.reject(new Error('BDF host is not interactive'));return find.findAsync(query,step===undefined?1:step)}

///|
extern "js" fn browser_open_find(host : BrowserHost) -> Unit =
  #|(host) => host[Symbol.for('f4ah6o.bdf.find')]?.open()

///|
/// Open the search field for a mounted interactive view.
#export_name("bdf_open_find")
pub fn bdf_open_find(host : BrowserHost) -> Unit {
  browser_open_find(host)
}

///|
extern "js" fn browser_clear_find(host : BrowserHost) -> Unit =
  #|(host) => host[Symbol.for('f4ah6o.bdf.find')]?.clear()

///|
/// Close the search field and clear the search highlights.
#export_name("bdf_clear_find")
pub fn bdf_clear_find(host : BrowserHost) -> Unit {
  browser_clear_find(host)
}
