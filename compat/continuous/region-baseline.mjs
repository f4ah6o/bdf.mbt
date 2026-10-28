import {BdfDocument,BufferSource} from '@bdfkit/core';
import {PageRenderer} from '@bdfkit/render';
try{
  const bytes=new Uint8Array(await(await fetch('./flow.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],renderer=new PageRenderer(doc),host=document.querySelector('#host');
  window.referenceLayout=renderer.continuousLayout(view);window.setGap=gap=>{view.continuous={gap}};
  window.renderRegion=async(x,y,w,h,scale)=>{const layout=renderer.continuousLayout(view);host.replaceChildren();const canvas=document.createElement('canvas');canvas.width=Math.ceil(w*scale);canvas.height=Math.ceil(h*scale);canvas.style.cssText='position:absolute;left:0;top:0';canvas.setAttribute('aria-label','BDF page');host.append(canvas);host.style.minWidth=Math.ceil(w*scale)+'px';host.style.minHeight=Math.ceil(h*scale)+'px';await renderer.renderContinuous(canvas.getContext('2d'),view,{x,y,w,h},{scale});return view.pages.filter((p,i)=>layout.offsets[i]<y+h&&layout.offsets[i]+(p.body?.h??p.h)>y).length};
  await window.renderRegion(0,0,200,200,1);window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
