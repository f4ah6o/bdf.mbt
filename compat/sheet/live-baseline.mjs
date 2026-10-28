import {BdfDocument,BufferSource} from '@bdfkit/core';
import {PageRenderer} from '@bdfkit/render';
try{
  const bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0],renderer=new PageRenderer(doc),host=document.querySelector('#host');
  const extent=runs=>(runs??[]).reduce((n,[count,size])=>n+count*size,0);
  const spacer=document.createElement('div');spacer.style.cssText=`position:relative;width:${Math.max(host.clientWidth,extent(view.cols))}px;height:${Math.max(host.clientHeight,extent(view.rows))}px`;
  const canvas=document.createElement('canvas');canvas.style.cssText='position:sticky;left:0;top:0;display:block';canvas.setAttribute('aria-label','BDF sheet');spacer.append(canvas);host.append(spacer);
  let seq=0;
  const draw=async()=>{const current=++seq,w=host.clientWidth,h=host.clientHeight,x=host.scrollLeft,y=host.scrollTop,dpr=devicePixelRatio||1,scratch=document.createElement('canvas');scratch.width=Math.ceil(w*dpr);scratch.height=Math.ceil(h*dpr);await renderer.renderSheet(scratch.getContext('2d'),view,{x,y,w,h},{scale:dpr});if(current!==seq)return;canvas.width=scratch.width;canvas.height=scratch.height;canvas.style.width=w+'px';canvas.style.height=h+'px';canvas.getContext('2d').drawImage(scratch,0,0);canvas.dataset.bdfSheetViewport=JSON.stringify([x,y,w,h]);canvas.dataset.bdfSheetFrame=String(current)};
  let frame=0;const schedule=()=>{if(!frame)frame=requestAnimationFrame(()=>{frame=0;void draw()})};host.addEventListener('scroll',schedule);new ResizeObserver(schedule).observe(host);
  await draw();window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
