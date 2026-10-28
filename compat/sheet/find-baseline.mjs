import {BdfDocument,BufferSource} from '@bdfkit/core';
import {DocumentSearch,FindBar,ResourceCache} from '@bdfkit/render';
await import('./live-baseline.mjs');
window.bdfStatus='loading';
try {
  const host=document.querySelector('#host'),bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer());
  const doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],resources=new ResourceCache(doc,document.fonts),hold=resources.hold(),ctx=document.createElement('canvas').getContext('2d');
  const search=new DocumentSearch(doc,(font,text)=>{ctx.font=font;return ctx.measureText(text).width},hash=>resources.prepareText(hash,hold));
  let layer;
  const bar=new FindBar({onFind:(query,step)=>void find(query,step),onClose:()=>clear()});host.append(bar.element);host.tabIndex=-1;
  let last='',hits=[],index=-1;
  async function find(query,step=1){
    if(!query.trim()){last='';hits=[];index=-1}else if(query!==last){last=query;hits=(await search.search(view,query,{limit:1001})).slice(0,1000);index=hits.length?(step<0?hits.length-1:0):-1}else if(hits.length)index=(index+step+hits.length)%hits.length;
    const rects=(await Promise.all(hits.map(hit=>search.locate(view,hit)))).flatMap((boxes,i)=>boxes.map(box=>({...box,hit:i})));
    layer?.remove();layer=null;if(rects.length){layer=document.createElement('div');layer.dataset.bdfHits='';layer.style.cssText='position:absolute;left:0;top:0;width:100%;height:100%;pointer-events:none;forced-color-adjust:none';for(const r of rects){const el=document.createElement('div');el.dataset.bdfHit=String(r.hit);el.style.cssText=`position:absolute;left:${r.x}px;top:${r.y}px;width:${r.w}px;height:${r.h}px;border-radius:2px;`+(r.hit===index?'background:rgba(255,120,0,.5);outline:1px solid #c04000':'background:rgba(255,210,0,.45);outline:1px solid rgba(200,140,0,.8)');layer.append(el)}host.insertBefore(layer,bar.element)}
    if(query.trim())bar.result({index,total:hits.length,more:false,detail:index<0?'':hits[index].context.replace(/ ⏎ /g,' ')});else bar.result();
  }
  function clear(){last='';hits=[];index=-1;layer?.remove();bar.reset()}
  bar.open();bar.input.value='Tile';await find('Tile',0);host.focus({preventScroll:true});window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
