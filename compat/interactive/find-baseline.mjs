import { BdfDocument, BufferSource } from '@bdfkit/core';
import { DocumentSearch, FindBar, ResourceCache, findKey } from '@bdfkit/render';
await import('./baseline.mjs');
window.bdfStatus='loading';
try {
  const host=document.querySelector('#host');
  const bytes=new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0];
  const resources=new ResourceCache(doc,document.fonts), hold=resources.hold();
  const ctx=document.createElement('canvas').getContext('2d');
  const search=new DocumentSearch(doc,(font,text)=>{ctx.font=font;return ctx.measureText(text).width},hash=>resources.prepareText(hash,hold));
  let query='',hits=[],index=-1,more=false,layer;
  const bar=new FindBar({onFind:(q,step)=>{void find(q,step)},onClose:()=>{clear(false);host.focus({preventScroll:true})}});
  host.tabIndex=0;
  host.append(bar.element);
  const pageTop=[0,416];
  async function find(q,step=1) {
    if(!q.trim()){query='';hits=[];index=-1;more=false;}
    else if(q!==query){query=q;hits=await search.search(view,q,{limit:1001});more=hits.length>1000;hits=hits.slice(0,1000);index=hits.length?(step<0?hits.length-1:0):-1;}
    else if(hits.length)index=(index+step+hits.length)%hits.length;
    const rects=(await Promise.all(hits.map(h=>search.locate(view,h)))).flatMap((rs,i)=>rs.map(r=>({hit:i,page:r.a,x:r.x,y:r.y+pageTop[r.a],w:r.w,h:r.h})));
    layer?.remove();layer=null;
    if(rects.length){layer=document.createElement('div');layer.dataset.bdfHits='';layer.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;forced-color-adjust:none';for(const r of rects){const el=document.createElement('div');el.dataset.bdfHit=String(r.hit);el.style.cssText=`position:absolute;left:${r.x}px;top:${r.y}px;width:${r.w}px;height:${r.h}px;border-radius:2px;`+(r.hit===index?'background:rgba(255,120,0,.5);outline:1px solid #c04000':'background:rgba(255,210,0,.45);outline:1px solid rgba(200,140,0,.8)');layer.append(el)}host.insertBefore(layer,bar.element);}
    const detail=index>=0?`page ${hits[index].segments[0].a+1}: ${hits[index].context.replace(/ ⏎ /g,' ')}`:'';
    if(q.trim())bar.result({index,total:hits.length,more,detail});else bar.result();
    const result={query:q,index,total:hits.length,more,detail,rects};
    host.dispatchEvent(new CustomEvent('findchange',{detail:{query:q,index,total:hits.length,more}}));
    if(index>=0)layer?.querySelector(`[data-bdf-hit="${index}"]`)?.scrollIntoView({block:'nearest',inline:'nearest'});
    return result;
  }
  function clear(reset=true){const had=!!query;query='';hits=[];index=-1;more=false;layer?.remove();layer=null;if(reset)bar.reset();else bar.result();if(had)host.dispatchEvent(new CustomEvent('findchange',{detail:{query:'',index:-1,total:0,more:false}}));}
  host.addEventListener('keydown',event=>{const key=findKey(event);if(!key||event.defaultPrevented)return;if(key==='open'){if(bar.shown&&bar.focused)return;event.preventDefault();bar.open();if(bar.query&&!query)void find(bar.query,0);}else if(bar.shown&&bar.query){event.preventDefault();void find(bar.query,key==='next'?1:-1)}});
  window.findAction=find;window.clearFind=()=>clear();window.openFind=()=>bar.open();
  bar.open();bar.input.value='page';await find('page',0);host.focus({preventScroll:true});
  window.bdfStatus='ready';
} catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error);}
