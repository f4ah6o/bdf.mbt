///|
#external
priv type TextLayerData

///|
extern "js" fn new_text_layer_data() -> TextLayerData =
  #|() => ({nodes:[],runs:[],links:[]})

///|
extern "js" fn add_text_node(
  data : TextLayerData,
  kind : String,
  parent : Int32,
  level : Int32,
  row : Int32,
  col : Int32,
  rows : Int32,
  cols : Int32,
  scope : String,
  alt : String,
  has_bounds : Bool,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Unit =
  #|(d,kind,parent,level,row,col,rows,cols,scope,alt,hasBounds,x,y,w,h) => d.nodes.push({kind,parent,level,row,col,rows,cols,scope,alt,bounds:hasBounds?{x,y,w,h}:null})

///|
extern "js" fn add_text_run(
  data : TextLayerData,
  text : String,
  x : Double,
  y : Double,
  advance : Double,
  size : Double,
  align : Int32,
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  separator : Int32,
  ordinal : Int32,
  alt : Bool,
  lang : String,
  node : Int32,
  has_font : Bool,
  family : String,
  weight : Int32,
  style : Int32,
) -> Unit =
  #|(out,text,x,y,advance,size,align,a,b,c,d,sep,ordinal,alt,lang,node,hasFont,family,weight,style) => out.runs.push({text,x,y,advance,size,align,a,b,c,d,sep,ordinal,alt,lang,node,hasFont,family,weight,style})

///|
extern "js" fn add_text_link(
  data : TextLayerData,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  url : String,
  after : Int32,
  node : Int32,
) -> Unit =
  #|(d,x,y,w,h,url,after,node) => d.links.push({x,y,w,h,url,after,node})

///|
fn append_text_content(
  data : TextLayerData,
  content : @render.TextContent,
  node_base : Int32,
  run_base : Int32,
) -> Unit {
  for node in content.nodes {
    let (has_bounds, x, y, w, h) = match node.bounds {
      Some(b) => (true, b.x, b.y, b.width, b.height)
      None => (false, 0.0, 0.0, 0.0, 0.0)
    }
    add_text_node(
      data,
      node.kind,
      if node.parent < 0 {
        -1
      } else {
        node.parent + node_base
      },
      node.level.unwrap_or(0),
      node.row.unwrap_or(-1),
      node.col.unwrap_or(-1),
      node.rows.unwrap_or(1),
      node.cols.unwrap_or(1),
      node.scope.unwrap_or(""),
      node.alt.unwrap_or(""),
      has_bounds,
      x,
      y,
      w,
      h,
    )
  }
  for run in content.runs {
    let (has_font, family, weight, style) = match run.font {
      None => (false, "sans-serif", 400, 0)
      Some(font) => {
        let family = match font.hash {
          Some(hash) =>
            if font.family == "" {
              "\"bdf-" + hash + "\""
            } else {
              "\"bdf-" + hash + "\", " + font.family
            }
          None => if font.family == "" { "sans-serif" } else { font.family }
        }
        (true, family, font.weight, font.style)
      }
    }
    let (a, b, c, d, _, _) = run.matrix
    add_text_run(
      data,
      run.text,
      run.x,
      run.y,
      run.advance,
      run.size,
      run.align,
      a,
      b,
      c,
      d,
      run.separator,
      run.ordinal,
      run.alt_text,
      run.lang,
      if run.node < 0 {
        -1
      } else {
        run.node + node_base
      },
      has_font,
      family,
      weight,
      style,
    )
  }
  for link in content.links {
    add_text_link(
      data,
      link.x,
      link.y,
      link.width,
      link.height,
      link.url,
      link.after + run_base,
      if link.node < 0 {
        -1
      } else {
        link.node + node_base
      },
    )
  }
}

///|
// DOM operations stay at the JS boundary; extraction and document structure
// are computed by MoonBit on both supported targets.
extern "js" fn render_text_layer(
  host : BrowserHost,
  data : TextLayerData,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  scale : Double,
) -> Unit =
  #|(host,data,x,y,width,height,scale) => {
  #| const layer=document.createElement('div'); layer.className='bdfTextLayer'; layer.setAttribute('data-bdf-layer','');
  #| Object.assign(layer.style,{position:'absolute',left:x+'px',top:y+'px',width:width+'px',height:height+'px',overflow:'hidden',lineHeight:'1',forcedColorAdjust:'none'});
  #| const doc=host.ownerDocument,styleKey=Symbol.for('f4ah6o.bdf.textStyle');if(!doc[styleKey]){const style=doc.createElement('style'); style.textContent='.bdfTextLayer span{position:absolute;z-index:1;color:transparent;white-space:pre;transform-origin:0 0;cursor:text}.bdfTextLayer span::selection{background:rgba(0,120,255,.35)}.bdfTextLayer a,.bdfTextLayer [role=img]{position:absolute}.bdfTextLayer [role=img]{pointer-events:none}.bdfTextLayer [role=img] span{pointer-events:auto}.bdfTextLayer a,.bdfTextLayer a span{cursor:pointer}.bdfTextLayer a:focus-visible{outline:2px solid #1a73e8;outline-offset:1px}.bdfTextLayer [data-bdf-end]{display:none;position:fixed;inset:0;z-index:0;cursor:text;user-select:none;-webkit-user-select:none}.bdfTextLayer [data-bdf-end][data-bdf-selecting]{display:block}.bdfTextLayer[data-bdf-selecting] a{pointer-events:none}.bdfTextLayer[data-bdf-selecting] a span{pointer-events:auto}';doc.head.appendChild(style);doc[styleKey]=style;}
  #| const placed=new Map(), rows=new Map(), root={el:layer,ox:0,oy:0}, roles={paragraph:'paragraph',heading:'heading',caption:'caption',list:'list',item:'listitem',table:'table'};
  #| const div=(parent,role)=>{const el=document.createElement('div'); if(role)el.setAttribute('role',role); parent.appendChild(el); return el};
  #| const position=(el,parent,b)=>{Object.assign(el.style,{left:(b.x*scale-parent.ox)+'px',top:(b.y*scale-parent.oy)+'px',width:(b.w*scale)+'px',height:(b.h*scale)+'px'}); return {el,ox:b.x*scale,oy:b.y*scale}};
  #| function node(i){if(i<0||i>=data.nodes.length)return root;if(placed.has(i))return placed.get(i);const n=data.nodes[i],parent=node(n.parent),p=data.nodes[n.parent];let result;
  #|  if(n.kind==='cell'&&p?.kind==='table'){let r=rows.get(parent.el);if(!r||r.row!==(n.row<0?0:n.row)){const el=div(parent.el,'row');el.setAttribute('aria-rowindex',String((n.row<0?0:n.row)+1));r={row:n.row<0?0:n.row,el};rows.set(parent.el,r)} const el=div(r.el,n.scope==='col'?'columnheader':n.scope==='row'?'rowheader':'cell');el.setAttribute('aria-colindex',String((n.col<0?0:n.col)+1));if(n.rows>1)el.setAttribute('aria-rowspan',String(n.rows));if(n.cols>1)el.setAttribute('aria-colspan',String(n.cols));result={...parent,el};}
  #|  else if(n.kind==='figure'&&n.alt&&n.bounds){const el=div(parent.el,'img');el.setAttribute('aria-label',n.alt);result=position(el,parent,n.bounds)}
  #|  else {const el=div(parent.el,n.kind==='cell'?'paragraph':roles[n.kind]);if(n.kind==='heading'&&n.level)el.setAttribute('aria-level',String(n.level));if(n.kind==='table'){let nr=0,nc=0;for(const z of data.nodes)if(z.parent===i&&z.kind==='cell'){nr=Math.max(nr,(z.row<0?0:z.row)+z.rows);nc=Math.max(nc,(z.col<0?0:z.col)+z.cols)}if(nr)el.setAttribute('aria-rowcount',String(nr));if(nc)el.setAttribute('aria-colcount',String(nc))}result={...parent,el};}
  #|  placed.set(i,result);return result;
  #| }
  #| function internal(url){let m=/^#page=(\d{1,7})$/.exec(url);if(m)return +m[1]>=1?{page:+m[1]}:null;m=/^#view=([^&#]+)(?:&page=(\d{1,7}))?$/.exec(url);if(!m||m[2]!==undefined&&+m[2]<1)return null;try{return {view:decodeURIComponent(m[1].replace(/\+/g,' ')),page:m[2]===undefined?undefined:+m[2]}}catch{return null}}
  #| function safe(url){if(url.startsWith('#'))return internal(url)?url:null;try{const u=new URL(url);return ['http:','https:','mailto:'].includes(u.protocol)?u.href:null}catch{return null}}
  #| const hrefs=data.links.map(l=>safe(l.url));
  #| const covering=r=>{const w=r.advance>0?r.advance:r.size*r.text.length*.5,cx=r.align===1?-w/2:r.align===2?0:w/2,cy=-r.size*.3,px=r.a*cx+r.c*cy+r.x,py=r.b*cx+r.d*cy+r.y;let best=-1;data.links.forEach((l,i)=>{if(!hrefs[i]||px<l.x||py<l.y||px>l.x+l.w||py>l.y+l.h)return;if(best<0||l.w*l.h<data.links[best].w*data.links[best].h)best=i});return best};
  #| const linkOf=data.runs.map(r=>r.text?covering(r):-1),textLinks=new Set(linkOf.filter(i=>i>=0));
  #| function anchor(i,parent){const l=data.links[i],a=document.createElement('a'),href=hrefs[i];a.href=href;a.draggable=false;const within=internal(href);if(within){if(within.view!==undefined)a.setAttribute('data-bdf-view',within.view);if(within.page!==undefined)a.setAttribute('data-bdf-page',String(within.page))}else{a.target='_blank';a.rel='noopener noreferrer'}parent.el.appendChild(a);return position(a,parent,l)}
  #| const measure=document.createElement('canvas').getContext('2d');let lastAnchor=null,nextNode=0,nextLink=0;
  #| function standalone(upTo){while(nextLink<data.links.length&&data.links[nextLink].after<upTo){const i=nextLink++,l=data.links[i];if(textLinks.has(i)||!hrefs[i])continue;const p=anchor(i,node(l.node)),within=internal(l.url);p.el.setAttribute('aria-label',within?.view!==undefined?'view '+within.view:within?.page!==undefined?'page '+within.page:l.url)}}
  #| for(let i=0;i<data.runs.length;i++){const r=data.runs[i];for(;nextNode<=r.node&&nextNode<data.nodes.length;nextNode++)if(data.nodes[nextNode].kind==='figure'&&data.nodes[nextNode].alt)node(nextNode);standalone(i);if(!r.text)continue;let target=node(r.node),li=linkOf[i];if(li>=0){if(lastAnchor&&lastAnchor.parent===target.el&&lastAnchor.link===li&&lastAnchor.placed.el===target.el.lastElementChild)target=lastAnchor.placed;else{const parent=target.el;target=anchor(li,target);lastAnchor={parent,link:li,placed:target}}}
  #|  const span=document.createElement('span');span.textContent=r.text;span.setAttribute('data-bdf-ordinal',String(r.ordinal));span.setAttribute('data-bdf-sep',String(r.sep));if(r.lang)span.lang=r.lang;
  #|  if(r.hasFont&&(!r.alt||r.advance>0)){const font=`${['normal','italic','oblique'][r.style]??'normal'} ${r.weight||400} ${r.size}px ${r.family}`;span.style.font=font;measure.font=font;const measured=measure.measureText(r.text).width,sx=r.advance>0&&measured>0?r.advance/measured:1,w=r.advance>0?r.advance:measured,offset=r.align===1?-w:r.align===2?-w/2:0;span.style.transform=`matrix(${r.a*scale},${r.b*scale},${r.c*scale},${r.d*scale},${r.x*scale-target.ox},${r.y*scale-target.oy}) translate(${offset}px,${-r.size*.8}px) scaleX(${sx})`;}
  #|  else{const size=(r.size>0?r.size:10)*scale,angle=Math.atan2(r.b,r.a);span.style.font=`${size}px sans-serif`;span.style.transform=`translate(${r.x*scale-target.ox}px,${r.y*scale-target.oy}px) rotate(${angle}rad) translate(0,${-size*.8}px)`}span.style.lineHeight='1';target.el.appendChild(span);
  #| }
  #| for(;nextNode<data.nodes.length;nextNode++)if(data.nodes[nextNode].kind==='figure'&&data.nodes[nextNode].alt)node(nextNode);standalone(Infinity);
  #| const end=document.createElement('div');end.setAttribute('data-bdf-end','');end.setAttribute('aria-hidden','true');layer.appendChild(end);
  #| host.appendChild(layer);
  #|}

///|
extern "js" fn install_copy_handler(host : BrowserHost) -> Unit =
  #|(host) => {
  #|  const key=Symbol.for('f4ah6o.bdf.copy');if(host[key])return;
  #|  const selected=()=>{const sel=host.ownerDocument.getSelection();if(!sel||sel.isCollapsed)return '';let output='';for(let i=0;i<sel.rangeCount;i++){const range=sel.getRangeAt(i);let text='',prev=null;for(const span of host.querySelectorAll('[data-bdf-ordinal]')){const child=span.firstChild;if(!child||!range.intersectsNode(span))continue;const value=child.textContent??'';let start=0,end=value.length;if(range.comparePoint(child,0)<0&&range.startContainer===child)start=range.startOffset;if(range.comparePoint(child,value.length)>0&&range.endContainer===child)end=range.endOffset;if(end<=start)continue;const page=span.closest('[data-bdf-layer]'),sep=Number(span.getAttribute('data-bdf-sep'));if(prev!==null)text+=prev!==page?'\n\n':sep===2?'\n':sep===1?' ':'';text+=value.slice(start,end);prev=page}if(text)output+=(output?'\n':'')+text}return output};
  #|  const doc=host.ownerDocument,win=doc.defaultView;let down=false,end=null;
  #|  const uncover=()=>{if(!end)return;const previous=end;end=null;previous.removeAttribute('data-bdf-selecting');previous.style.cssText='';const layer=previous.closest('[data-bdf-layer]');if(layer){layer.removeAttribute('data-bdf-selecting');if(layer.lastChild!==previous)layer.appendChild(previous)}};
  #|  const scrollArea=layer=>{for(let el=layer.parentElement;el&&el!==doc.documentElement&&el!==doc.body;el=el.parentElement){const s=win.getComputedStyle(el);if(!/auto|scroll|overlay/.test(`${s.overflowX} ${s.overflowY}`))continue;const r=el.getBoundingClientRect();return {x:r.left+el.clientLeft,y:r.top+el.clientTop,w:el.clientWidth,h:el.clientHeight}}return {x:0,y:0,w:doc.documentElement.clientWidth,h:doc.documentElement.clientHeight}};
  #|  const cover=(layer,run,before)=>{const next=layer.querySelector('[data-bdf-end]');if(!next)return;if(end!==next){uncover();end=next;const r=scrollArea(layer);end.style.cssText=`left:${r.x}px;top:${r.y}px;width:${r.w}px;height:${r.h}px`;end.setAttribute('data-bdf-selecting','');layer.setAttribute('data-bdf-selecting','')}const gecko=typeof CSS!=='undefined'&&CSS.supports('-moz-user-select','none');if(!gecko&&(before?run.previousSibling:run.nextSibling)!==end)run.parentNode.insertBefore(end,before?run:run.nextSibling)};
  #|  const follow=()=>{if(!down)return;const sel=doc.getSelection();if(!sel?.rangeCount)return;const range=sel.getRangeAt(0);if(range.collapsed&&!end)return;const back=!range.collapsed&&sel.focusNode===range.startContainer&&sel.focusOffset===range.startOffset;const n=back?range.startContainer:range.endContainer,offset=back?range.startOffset:range.endOffset;const layer=(n.nodeType===1?n:n.parentElement)?.closest('[data-bdf-layer]');if(!layer||!host.contains(layer))return;const runs=[...layer.querySelectorAll('[data-bdf-ordinal]')],at=doc.createRange();at.setStart(n,offset);let lo=0,hi=runs.length;while(lo<hi){const mid=(lo+hi)>>1,t=runs[mid].firstChild;const past=back?at.comparePoint(t,t.textContent.length)>0:at.comparePoint(t,0)>=0;if(past)hi=mid;else lo=mid+1}const run=back?runs[lo]:runs[lo-1];if(run)cover(layer,run,back)};
  #|  const stop=()=>{if(!down)return;down=false;uncover();doc.removeEventListener('pointerup',stop,true);doc.removeEventListener('pointercancel',stop,true);doc.removeEventListener('selectionchange',follow);win.removeEventListener('blur',stop)};
  #|  const start=e=>{if(e.pointerType==='touch'||e.button!==0)return;stop();down=true;doc.addEventListener('pointerup',stop,true);doc.addEventListener('pointercancel',stop,true);doc.addEventListener('selectionchange',follow);win.addEventListener('blur',stop);const run=e.target instanceof Element?e.target.closest('[data-bdf-ordinal]'):null,layer=run?.closest('[data-bdf-layer]');if(run&&layer&&host.contains(layer))cover(layer,run,false)};
  #|  const oncopy=e=>{if(!e.clipboardData)return;const text=selected();if(text){e.clipboardData.setData('text/plain',text);e.preventDefault()}};let observer,active=false;
  #|  const record={selected,activate(){if(!active){doc.addEventListener('pointerdown',start,true);active=true}},dispose(){stop();observer?.disconnect();host.removeEventListener('copy',oncopy);host.removeEventListener('cut',oncopy);if(active)doc.removeEventListener('pointerdown',start,true);active=false}};
  #|  host.addEventListener('copy',oncopy);host.addEventListener('cut',oncopy);host[key]=record;
  #|  if(host.isConnected||typeof MutationObserver!=='function')record.activate();
  #|  if(typeof MutationObserver==='function'){const watch=(weak,k,owner,connected)=>{const ob=new MutationObserver(()=>{const h=weak.deref();if(!h){ob.disconnect();return}if(h.isConnected){connected=true;h[k]?.activate()}else if(connected){h[k]?.dispose();delete h[k]}});ob.observe(owner,{childList:true,subtree:true});return ob};const weak=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host};observer=watch(weak,key,doc,host.isConnected)}
  #|}

///|
extern "js" fn get_selection_text(host : BrowserHost) -> String =
  #|(host) => host[Symbol.for('f4ah6o.bdf.copy')]?.selected() ?? ''

///|
/// The selected text inside this mounted host, with BDF separators.
#export_name("bdf_selection_text")
pub fn bdf_selection_text(host : BrowserHost) -> String {
  get_selection_text(host)
}

///|
// Interactive spans need embedded fonts after painting. The host owns those
// faces until it is remounted, unmounted, or removed from the document.
extern "js" fn retain_host_fonts(
  host : BrowserHost,
  resources : BrowserResources,
) -> Unit =
  #|(host,r) => {
  #| const faces=[...r.fonts.values()];r.fonts.clear();if(!faces.length)return;
  #| const doc=host.ownerDocument,ref=typeof WeakRef==='function'?new WeakRef(host):{deref:()=>host},key=Symbol.for('f4ah6o.bdf.fonts');
  #| const register=(weak,owner,k,held,connected)=>{let observer;const record={release(){observer?.disconnect();for(const face of held)owner.fonts.delete(face);held.length=0}};if(typeof MutationObserver==='function'){observer=new MutationObserver(()=>{const h=weak.deref();if(!h){record.release();return}if(h.isConnected)connected=true;else if(connected){record.release();if(h[k]===record)delete h[k]}});observer.observe(owner,{childList:true,subtree:true})}return record};
  #| host[key]=register(ref,doc,key,faces,host.isConnected);
  #|}

///|
/// Remove a mounted document and release its retained browser resources.
#export_name("unmount_bdf")
pub fn unmount_bdf(host : BrowserHost) -> Unit {
  clear_host(host)
  reset_host_size(host)
}

///|
extern "js" fn reset_host_size(host : BrowserHost) -> Unit =
  #|(host) => { host.style.minWidth='';host.style.minHeight=''; }
