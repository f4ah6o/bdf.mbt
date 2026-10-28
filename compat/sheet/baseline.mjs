import {BdfDocument,BufferSource} from '@bdfkit/core';
import {PageRenderer,tilesIn} from '@bdfkit/render';
try {
  const bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer());
  const doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],renderer=new PageRenderer(doc),host=document.querySelector('#host');
  window.renderRegion=async(x,y,w,h,scale)=>{
    host.replaceChildren();const canvas=document.createElement('canvas');canvas.width=Math.ceil(w*scale);canvas.height=Math.ceil(h*scale);Object.assign(canvas.style,{position:'absolute',left:'0px',top:'0px'});canvas.setAttribute('aria-label','BDF page');host.append(canvas);host.style.minWidth=Math.ceil(w*scale)+'px';host.style.minHeight=Math.ceil(h*scale)+'px';
    await renderer.renderSheet(canvas.getContext('2d'),view,{x,y,w,h},{scale});
    const tile=view.tile||2048;return tilesIn(view,[{tx0:Math.floor(x/tile),ty0:Math.floor(y/tile),tx1:Math.floor((x+w-1e-6)/tile),ty1:Math.floor((y+h-1e-6)/tile)}]).length;
  };
  await window.renderRegion(0,0,400,300,1);window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
