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
#external
pub type BrowserClipboard

///|
extern "js" fn clipboard_value(
  text : String,
  html : String,
) -> BrowserClipboard =
  #|(text,html) => ({text,html})

///|
extern "js" fn empty_clipboard() -> BrowserClipboard =
  #|() => ({error:true})

///|
extern "js" fn set_table_clipboard(
  data : TextLayerData,
  index : Int32,
  make : (Int32, Int32, Int32, Int32) -> BrowserClipboard,
) -> Unit =
  #|(data,index,make) => { data.nodes[index].clipboard=make; }

///|
fn append_text_content(
  data : TextLayerData,
  content : @render.TextContent,
  node_base : Int32,
  run_base : Int32,
  tile_size~ : Double = 0.0,
  sheet_root~ : Bool = false,
) -> Unit {
  for node_index, node in content.nodes {
    let (has_bounds, x, y, w, h) = match node.bounds {
      Some(b) => (true, b.x, b.y, b.width, b.height)
      None => (false, 0.0, 0.0, 0.0, 0.0)
    }
    add_text_node(
      data,
      node.kind,
      if node.parent < 0 {
        if sheet_root &&
          node.kind == "cell" &&
          node.row is Some(_) &&
          node.col is Some(_) {
          0
        } else {
          -1
        }
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
    if node.kind == "table" {
      set_table_clipboard(data, node_base + node_index, (r0, c0, r1, c1) => {
        try {
          let cells = @render.table_cells(content, table=node_index)
          let result = @render.cell_clipboard(cells, {
            row0: r0,
            col0: c0,
            row1: r1,
            col1: c1,
          })
          clipboard_value(result.text, result.html)
        } catch {
          _ => empty_clipboard()
        }
      })
    }
  }
  for run in content.runs {
    if tile_size > 0.0 &&
      !(run.x >= 0.0 && run.x < tile_size && run.y >= 0.0 && run.y < tile_size) {
      continue
    }
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
    let mut after = link.after
    if tile_size > 0.0 {
      after = -1
      for index, run in content.runs {
        if index > link.after {
          break
        }
        if run.x >= 0.0 &&
          run.x < tile_size &&
          run.y >= 0.0 &&
          run.y < tile_size {
          after += 1
        }
      }
    }
    add_text_link(
      data,
      link.x,
      link.y,
      link.width,
      link.height,
      link.url,
      after + run_base,
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
  #| const doc=host.ownerDocument,styleKey=Symbol.for('f4ah6o.bdf.textStyle');if(!doc[styleKey]){const style=doc.createElement('style'); style.textContent='.bdfTextLayer span{position:absolute;z-index:1;color:transparent;white-space:pre;transform-origin:0 0;cursor:text}.bdfTextLayer span::selection{background:rgba(0,120,255,.35)}.bdfTextLayer a,.bdfTextLayer [role=img]{position:absolute}.bdfTextLayer [role=img]{pointer-events:none}.bdfTextLayer [role=img] span{pointer-events:auto}.bdfTextLayer a,.bdfTextLayer a span{cursor:pointer}.bdfTextLayer a:focus-visible{outline:2px solid #1a73e8;outline-offset:1px}.bdfTextLayer [data-bdf-end]{display:none;position:fixed;inset:0;z-index:0;cursor:text;user-select:none;-webkit-user-select:none}.bdfTextLayer [data-bdf-end][data-bdf-selecting]{display:block}.bdfTextLayer[data-bdf-selecting] a{pointer-events:none}.bdfTextLayer[data-bdf-selecting] a span{pointer-events:auto}.bdfTextLayer [data-bdf-cells] span::selection{background:transparent}.bdfTextLayer [data-bdf-cellbox]{position:absolute;z-index:0;pointer-events:none;background:rgba(0,120,255,.18);outline:2px solid rgba(0,100,230,.8)}';doc.head.appendChild(style);doc[styleKey]=style;}
  #| const cellKey=Symbol.for('f4ah6o.bdf.cell'),tableKey=Symbol.for('f4ah6o.bdf.table');
  #| const sheet=host[Symbol.for('f4ah6o.bdf.sheetCells')],placed=new Map(), rows=new Map(), root={el:layer,ox:0,oy:0}, roles={paragraph:'paragraph',heading:'heading',caption:'caption',list:'list',item:'listitem',table:'table'};
  #| const div=(parent,role)=>{const el=document.createElement('div'); if(role)el.setAttribute('role',role); parent.appendChild(el); return el};
  #| const position=(el,parent,b)=>{Object.assign(el.style,{left:(b.x*scale-parent.ox)+'px',top:(b.y*scale-parent.oy)+'px',width:(b.w*scale)+'px',height:(b.h*scale)+'px'}); return {el,ox:b.x*scale,oy:b.y*scale}};
  #| function node(i){if(i<0||i>=data.nodes.length)return root;if(placed.has(i))return placed.get(i);const n=data.nodes[i],parent=node(n.parent),p=data.nodes[n.parent];let result;
  #|  if(n.kind==='cell'&&p?.kind==='table'){let r=rows.get(parent.el);if(!r||r.row!==(n.row<0?0:n.row)){const el=div(parent.el,'row');el.setAttribute('aria-rowindex',String((n.row<0?0:n.row)+1));r={row:n.row<0?0:n.row,el};rows.set(parent.el,r)} const info=parent.el[tableKey],scope=n.scope||(info?.sheet?(n.row<info.headerRows?'col':n.col<info.headerCols?'row':''):'');const el=div(r.el,scope==='col'?'columnheader':scope==='row'?'rowheader':'cell');el.setAttribute('aria-colindex',String((n.col<0?0:n.col)+1));if(n.rows>1)el.setAttribute('aria-rowspan',String(n.rows));if(n.cols>1)el.setAttribute('aria-colspan',String(n.cols));const cell={row:n.row<0?0:n.row,col:n.col<0?0:n.col,rows:n.rows,cols:n.cols,box:null};el[cellKey]=cell;info?.cells.push(cell);result={...parent,el};}
  #|  else if(n.kind==='figure'&&n.alt&&n.bounds){const el=div(parent.el,'img');el.setAttribute('aria-label',n.alt);result=position(el,parent,n.bounds)}
  #|  else {const el=div(parent.el,n.kind==='cell'?'paragraph':roles[n.kind]);if(n.kind==='heading'&&n.level)el.setAttribute('aria-level',String(n.level));if(n.kind==='table'){let nr=0,nc=0;for(const z of data.nodes)if(z.parent===i&&z.kind==='cell'){nr=Math.max(nr,(z.row<0?0:z.row)+z.rows);nc=Math.max(nc,(z.col<0?0:z.col)+z.cols)}const info=i===0&&sheet?sheet:null;if(info){nr=info.rows;nc=info.cols}if(nr)el.setAttribute('aria-rowcount',String(nr));if(nc)el.setAttribute('aria-colcount',String(nc));el[tableKey]=info??{layer,cells:[],size:0,clipboard:n.clipboard}}result={...parent,el};}
  #|  placed.set(i,result);return result;
  #| }
  #| function internal(url){let m=/^#page=(\d{1,7})$/.exec(url);if(m)return +m[1]>=1?{page:+m[1]}:null;m=/^#view=([^&#]+)(?:&page=(\d{1,7}))?$/.exec(url);if(!m||m[2]!==undefined&&+m[2]<1)return null;try{return {view:decodeURIComponent(m[1].replace(/\+/g,' ')),page:m[2]===undefined?undefined:+m[2]}}catch{return null}}
  #| function safe(url){if(url.startsWith('#'))return internal(url)?url:null;try{const u=new URL(url);return ['http:','https:','mailto:'].includes(u.protocol)?u.href:null}catch{return null}}
  #| const hrefs=data.links.map(l=>safe(l.url));
  #| const covering=r=>{const w=r.advance>0?r.advance:r.size*r.text.length*.5,cx=r.align===1?-w/2:r.align===2?0:w/2,cy=-r.size*.3,px=r.a*cx+r.c*cy+r.x,py=r.b*cx+r.d*cy+r.y;let best=-1;data.links.forEach((l,i)=>{if(!hrefs[i]||px<l.x||py<l.y||px>l.x+l.w||py>l.y+l.h)return;if(best<0||l.w*l.h<data.links[best].w*data.links[best].h)best=i});return best};
  #| const linkOf=data.runs.map(r=>r.text?covering(r):-1),textLinks=new Set(linkOf.filter(i=>i>=0));
  #| function anchor(i,parent){const l=data.links[i],a=document.createElement('a'),href=hrefs[i];a.href=href;a.draggable=false;const within=internal(href);if(within){if(within.view!==undefined)a.setAttribute('data-bdf-view',within.view);if(within.page!==undefined)a.setAttribute('data-bdf-page',String(within.page))}else{a.target='_blank';a.rel='noopener noreferrer'}parent.el.appendChild(a);return position(a,parent,l)}
  #| const measure=document.createElement('canvas').getContext('2d');let lastAnchor=null,nextNode=0,nextLink=0;
  #| function cellText(element,r,measured){let cell=null,info=null;for(let el=element;el&&el!==layer;el=el.parentElement){cell=el[cellKey]??cell;if(el[tableKey]){info=el[tableKey];break}}if(!cell||!info)return;const size=r.size>0?r.size:10,known=r.hasFont&&(!r.alt||r.advance>0);let a=r.a,b=r.b,c=r.c,d=r.d,x0=0,x1;if(known){const w=r.advance>0?r.advance:measured;x0=r.align===1?-w:r.align===2?-w/2:0;x1=x0+w}else{const angle=Math.atan2(b,a);a=Math.cos(angle);b=Math.sin(angle);c=-b;d=a;x1=size*r.text.length*.5}let left=Infinity,top=Infinity,right=-Infinity,bottom=-Infinity;for(const dx of [x0,x1])for(const dy of [-size*.8,size*.2]){const px=(a*dx+c*dy+r.x)*scale+(info.sheet?x:0),py=(b*dx+d*dy+r.y)*scale+(info.sheet?y:0);left=Math.min(left,px);top=Math.min(top,py);right=Math.max(right,px);bottom=Math.max(bottom,py)}const box=cell.box;if(box){const bx=Math.min(box.x,left),by=Math.min(box.y,top);cell.box={x:bx,y:by,w:Math.max(box.x+box.w,right)-bx,h:Math.max(box.y+box.h,bottom)-by}}else cell.box={x:left,y:top,w:right-left,h:bottom-top};if(!info.size)info.size=size*scale}
  #| function standalone(upTo){while(nextLink<data.links.length&&data.links[nextLink].after<upTo){const i=nextLink++,l=data.links[i];if(textLinks.has(i)||!hrefs[i])continue;const p=anchor(i,node(l.node)),within=internal(l.url);p.el.setAttribute('aria-label',within?.view!==undefined?'view '+within.view:within?.page!==undefined?'page '+within.page:l.url)}}
  #| for(let i=0;i<data.runs.length;i++){const r=data.runs[i];for(;nextNode<=r.node&&nextNode<data.nodes.length;nextNode++)if(data.nodes[nextNode].kind==='figure'&&data.nodes[nextNode].alt)node(nextNode);standalone(i);if(!r.text)continue;let target=node(r.node),li=linkOf[i];if(li>=0){if(lastAnchor&&lastAnchor.parent===target.el&&lastAnchor.link===li&&lastAnchor.placed.el===target.el.lastElementChild)target=lastAnchor.placed;else{const parent=target.el;target=anchor(li,target);lastAnchor={parent,link:li,placed:target}}}
  #|  const span=document.createElement('span');span.textContent=r.text;span.setAttribute('data-bdf-ordinal',String(r.ordinal));span.setAttribute('data-bdf-sep',String(r.sep));if(r.lang)span.lang=r.lang;
  #|  let measured=0; if(r.hasFont&&(!r.alt||r.advance>0)){const font=`${['normal','italic','oblique'][r.style]??'normal'} ${r.weight||400} ${r.size}px ${r.family}`;span.style.font=font;measure.font=font;measured=measure.measureText(r.text).width;const sx=r.advance>0&&measured>0?r.advance/measured:1,w=r.advance>0?r.advance:measured,offset=r.align===1?-w:r.align===2?-w/2:0;span.style.transform=`matrix(${r.a*scale},${r.b*scale},${r.c*scale},${r.d*scale},${r.x*scale-target.ox},${r.y*scale-target.oy}) translate(${offset}px,${-r.size*.8}px) scaleX(${sx})`;}
  #|  else{const size=(r.size>0?r.size:10)*scale,angle=Math.atan2(r.b,r.a);span.style.font=`${size}px sans-serif`;span.style.transform=`translate(${r.x*scale-target.ox}px,${r.y*scale-target.oy}px) rotate(${angle}rad) translate(0,${-size*.8}px)`}span.style.lineHeight='1';target.el.appendChild(span);cellText(target.el,r,measured);
  #| }
  #| for(;nextNode<data.nodes.length;nextNode++)if(data.nodes[nextNode].kind==='figure'&&data.nodes[nextNode].alt)node(nextNode);standalone(Infinity);
  #| const end=document.createElement('div');end.setAttribute('data-bdf-end','');end.setAttribute('aria-hidden','true');layer.appendChild(end);
  #| host.appendChild(layer);
  #|}

///|
extern "js" fn install_copy_handler(host : BrowserHost) -> Unit =
  #|(host) => {
  #|  const key=Symbol.for('f4ah6o.bdf.copy');if(host[key])return;
  #|  const selected=()=>{const sel=host.ownerDocument.getSelection();if(!sel||sel.isCollapsed)return '';let output='';for(let i=0;i<sel.rangeCount;i++){const range=sel.getRangeAt(i);let text='',prev=null;for(const span of host.querySelectorAll('[data-bdf-ordinal]')){const child=span.firstChild;if(!child||!range.intersectsNode(span))continue;const value=child.textContent??'';let start=0,end=value.length;if(range.comparePoint(child,0)<0&&range.startContainer===child)start=range.startOffset;if(range.comparePoint(child,value.length)>0&&range.endContainer===child)end=range.endOffset;if(end<=start)continue;const page=span.closest('[data-bdf-layer]'),sep=Number(span.getAttribute('data-bdf-sep'));if(prev!==null)text+=prev!==page?(prev.hasAttribute('data-bdf-sheet-tile')&&page.hasAttribute('data-bdf-sheet-tile')?'\n':'\n\n'):sep===2?'\n':sep===1?' ':'';text+=value.slice(start,end);prev=page}if(text)output+=(output?'\n':'')+text}return output};
  #|  const doc=host.ownerDocument,win=doc.defaultView;let down=false,end=null,cellSelection=null;
  #|  const cellKey=Symbol.for('f4ah6o.bdf.cell'),tableKey=Symbol.for('f4ah6o.bdf.table');
  #|  const around=n=>{const found=new Map();let cell;for(let el=n?.nodeType===1?n:n?.parentElement;el;el=el.parentElement){cell=el[cellKey]??cell;if(el[tableKey]){const info=el[tableKey];if(cell)found.set(info.sheet?info.anchor:el,cell);cell=undefined}if(el.hasAttribute('data-bdf-layer'))break}return found};
  #|  const selectedTable=()=>{const sel=doc.getSelection();if(!sel||sel.isCollapsed||!sel.rangeCount)return null;const from=around(sel.anchorNode);for(const [table,to] of around(sel.focusNode)){const a=from.get(table);if(!a)continue;const info=table[tableKey];if(a===to||info.sheet&&a.row===to.row&&a.col===to.col||!host.contains(table))return null;if(info.sheet)info.sync();const range={row0:Math.min(a.row,to.row),col0:Math.min(a.col,to.col),row1:Math.max(a.row+a.rows,to.row+to.rows)-1,col1:Math.max(a.col+a.cols,to.col+to.cols)-1};let grew=true;while(grew){grew=false;for(const c of info.cells){if(c.rows===1&&c.cols===1)continue;if(c.row>range.row1||c.row+c.rows-1<range.row0||c.col>range.col1||c.col+c.cols-1<range.col0)continue;const r0=Math.min(range.row0,c.row),c0=Math.min(range.col0,c.col),r1=Math.max(range.row1,c.row+c.rows-1),c1=Math.max(range.col1,c.col+c.cols-1);if(r0!==range.row0||c0!==range.col0||r1!==range.row1||c1!==range.col1){Object.assign(range,{row0:r0,col0:c0,row1:r1,col1:c1});grew=true}}}return {table,info,range,from:a,to}}return null};
  #|  const rangeBox=(info,r)=>{let x0=Infinity,y0=Infinity,x1=-Infinity,y1=-Infinity,next=Infinity,below=Infinity;for(const cell of info.cells){const b=cell.box;if(!b)continue;if(cell.col>=r.col0&&cell.col+cell.cols-1<=r.col1){x0=Math.min(x0,b.x);x1=Math.max(x1,b.x+b.w)}if(cell.row>=r.row0&&cell.row+cell.rows-1<=r.row1){y0=Math.min(y0,b.y);y1=Math.max(y1,b.y+b.h)}if(cell.col>r.col1)next=Math.min(next,b.x);if(cell.row>r.row1)below=Math.min(below,b.y)}if(x0>x1||y0>y1)return null;const m=info.size*.3;x1=next<Infinity?Math.max(x1+m,next-m):x1+m;y1=below<Infinity?Math.max(y1+m,below-m):y1+m;return {x:x0-m,y:y0-m,w:x1-x0+m,h:y1-y0+m}};
  #|  const clearCells=()=>{if(cellSelection){cellSelection.box.remove();cellSelection.table.removeAttribute('data-bdf-cells');cellSelection=null}};
  #|  const selectCells=()=>{const found=selectedTable(),old=cellSelection;if(old&&found&&!found.info.sheet&&old.table===found.table&&['row0','col0','row1','col1'].every(k=>old.range[k]===found.range[k]))return;clearCells();if(!found)return;const box=doc.createElement('div');box.setAttribute('data-bdf-cellbox','');box.setAttribute('aria-hidden','true');const b=rangeBox(found.info,found.range);if(b)box.style.cssText=`left:${b.x}px;top:${b.y}px;width:${b.w}px;height:${b.h}px`;if(found.info.sheet)box.style.cssText+=';position:absolute;z-index:1;pointer-events:none;background:rgba(0,120,255,.18);outline:2px solid rgba(0,100,230,.8)';found.info.layer.prepend(box);found.table.setAttribute('data-bdf-cells','');cellSelection={...found,box};if(found.info.sheet&&!found.info.ready())void found.info.prepare().catch(error=>{if(host.contains(found.table))host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true}))})};
  #|  const clipboardFor=found=>{if(!found||typeof found.info.clipboard!=='function')return null;const r=found.range;if([r.row0,r.col0,r.row1,r.col1].some(n=>!Number.isSafeInteger(n)||n < -2147483648||n>2147483647))return null;const value=found.info.clipboard(r.row0,r.col0,r.row1,r.col1);if(value?.error)throw new RangeError('bdf: too many cells to copy');return value};
  #|  const selectedCells=()=>{const found=selectedTable();if(found?.info.sheet&&!found.info.ready())throw new Error('bdf: sheet cells are still loading; use bdf_selection_cells_async');return clipboardFor(found)};
  #|  const selectedCellsAsync=async()=>{const found=selectedTable();if(!found)return null;if(found.info.sheet)await found.info.prepare();const now=selectedTable();if(!now||now.table!==found.table||now.from!==found.from||now.to!==found.to)return null;return clipboardFor(now)};
  #|  const uncover=()=>{if(!end)return;const previous=end;end=null;previous.removeAttribute('data-bdf-selecting');previous.style.cssText='';const layer=previous.closest('[data-bdf-layer]');if(layer){layer.removeAttribute('data-bdf-selecting');if(layer.lastChild!==previous)layer.appendChild(previous)}};
  #|  const scrollArea=layer=>{for(let el=layer.parentElement;el&&el!==doc.documentElement&&el!==doc.body;el=el.parentElement){const s=win.getComputedStyle(el);if(!/auto|scroll|overlay/.test(`${s.overflowX} ${s.overflowY}`))continue;const r=el.getBoundingClientRect();return {x:r.left+el.clientLeft,y:r.top+el.clientTop,w:el.clientWidth,h:el.clientHeight}}return {x:0,y:0,w:doc.documentElement.clientWidth,h:doc.documentElement.clientHeight}};
  #|  const cover=(layer,run,before)=>{const next=layer.querySelector('[data-bdf-end]');if(!next)return;if(end!==next){uncover();end=next;const r=scrollArea(layer);end.style.cssText=`left:${r.x}px;top:${r.y}px;width:${r.w}px;height:${r.h}px`;end.setAttribute('data-bdf-selecting','');layer.setAttribute('data-bdf-selecting','')}const gecko=typeof CSS!=='undefined'&&CSS.supports('-moz-user-select','none');if(!gecko&&(before?run.previousSibling:run.nextSibling)!==end)run.parentNode.insertBefore(end,before?run:run.nextSibling)};
  #|  const follow=()=>{if(!down)return;const sel=doc.getSelection();if(!sel?.rangeCount)return;const range=sel.getRangeAt(0);if(range.collapsed&&!end)return;const back=!range.collapsed&&sel.focusNode===range.startContainer&&sel.focusOffset===range.startOffset;const n=back?range.startContainer:range.endContainer,offset=back?range.startOffset:range.endOffset;const layer=(n.nodeType===1?n:n.parentElement)?.closest('[data-bdf-layer]');if(!layer||!host.contains(layer))return;const runs=[...layer.querySelectorAll('[data-bdf-ordinal]')],at=doc.createRange();at.setStart(n,offset);let lo=0,hi=runs.length;while(lo<hi){const mid=(lo+hi)>>1,t=runs[mid].firstChild;const past=back?at.comparePoint(t,t.textContent.length)>0:at.comparePoint(t,0)>=0;if(past)hi=mid;else lo=mid+1}const run=back?runs[lo]:runs[lo-1];if(run)cover(layer,run,back)};
  #|  const stop=()=>{if(!down)return;down=false;uncover();doc.removeEventListener('pointerup',stop,true);doc.removeEventListener('pointercancel',stop,true);doc.removeEventListener('selectionchange',follow);win.removeEventListener('blur',stop)};
  #|  const start=e=>{if(e.pointerType==='touch'||e.button!==0)return;stop();down=true;doc.addEventListener('pointerup',stop,true);doc.addEventListener('pointercancel',stop,true);doc.addEventListener('selectionchange',follow);win.addEventListener('blur',stop);const run=e.target instanceof Element?e.target.closest('[data-bdf-ordinal]'):null,layer=run?.closest('[data-bdf-layer]');if(run&&layer&&host.contains(layer))cover(layer,run,false)};
  #|  const oncopy=e=>{if(!e.clipboardData)return;const found=selectedTable();if(found?.info.sheet&&!found.info.ready()){e.preventDefault();const report=error=>{if(host.contains(found.table)&&host.dispatchEvent(new win.CustomEvent('error',{detail:error,cancelable:true})))console.error('bdf sheet clipboard:',error)};if(!win.ClipboardItem||!win.navigator.clipboard?.write){void found.info.prepare().catch(report);report(new Error('bdf: sheet cells are still loading; copy again when ready'));return}try{const value=selectedCellsAsync().then(v=>{if(!v)throw new Error('bdf: selection changed while loading cells');return v});const plain=value.then(v=>new Blob([v.text],{type:'text/plain'})),html=value.then(v=>new Blob([v.html],{type:'text/html'}));plain.catch(()=>{});html.catch(()=>{});const item=new win.ClipboardItem({'text/plain':plain,'text/html':html});win.navigator.clipboard.write([item]).catch(report)}catch(error){report(error)}return}let cells;try{cells=selectedCells()}catch{}if(cells){e.clipboardData.setData('text/plain',cells.text);e.clipboardData.setData('text/html',cells.html);e.preventDefault();return}const text=selected();if(text){e.clipboardData.setData('text/plain',text);e.preventDefault()}};let observer,active=false;
  #|  const record={selected,selectedCells,selectedCellsAsync,activate(){if(!active){doc.addEventListener('pointerdown',start,true);doc.addEventListener('selectionchange',selectCells);active=true;selectCells()}},dispose(){stop();clearCells();observer?.disconnect();host.removeEventListener('copy',oncopy);host.removeEventListener('cut',oncopy);if(active){doc.removeEventListener('pointerdown',start,true);doc.removeEventListener('selectionchange',selectCells)}active=false}};
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
extern "js" fn get_selection_cells(host : BrowserHost) -> BrowserClipboard? =
  #|(host) => host[Symbol.for('f4ah6o.bdf.copy')]?.selectedCells() ?? undefined

///|
/// Return the selected table cells in TSV and HTML form, or None for a text selection.
#export_name("bdf_selection_cells")
pub fn bdf_selection_cells(host : BrowserHost) -> BrowserClipboard? {
  get_selection_cells(host)
}

///|
/// Resolve a rectangular cell selection, fetching sheet text when necessary.
#export_name("bdf_selection_cells_async")
pub fn bdf_selection_cells_async(
  host : BrowserHost,
) -> @js_async.Promise[BrowserClipboard?] {
  get_selection_cells_async(host)
}

///|
extern "js" fn get_selection_cells_async(
  host : BrowserHost,
) -> @js_async.Promise[BrowserClipboard?] =
  #|(host) => Promise.resolve(host[Symbol.for('f4ah6o.bdf.copy')]?.selectedCellsAsync()).then(value=>value??undefined)

///|
/// The plain-text TSV representation of a table selection.
#export_name("bdf_clipboard_text")
pub fn bdf_clipboard_text(value : BrowserClipboard) -> String {
  clipboard_text_js(value)
}

///|
extern "js" fn clipboard_text_js(value : BrowserClipboard) -> String =
  #|(value) => value.text

///|
/// The HTML table representation of a table selection.
#export_name("bdf_clipboard_html")
pub fn bdf_clipboard_html(value : BrowserClipboard) -> String {
  clipboard_html_js(value)
}

///|
extern "js" fn clipboard_html_js(value : BrowserClipboard) -> String =
  #|(value) => value.html

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
