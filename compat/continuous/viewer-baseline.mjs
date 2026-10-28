import {BdfDocument,BufferSource} from '@bdfkit/core';
import {PageRenderer} from '@bdfkit/render';
import {Viewer} from '@bdfkit/viewer';
try{
  const bytes=new Uint8Array(await(await fetch('./scroll.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),pageRenderer=new PageRenderer(doc);
  const renderer={close:async()=>{},open:async()=>doc.manifest,page:async(_id,index,scale)=>{const page=doc.manifest.views[0].pages[index],canvas=document.createElement('canvas');canvas.width=Math.ceil(page.w*scale);canvas.height=Math.ceil(page.h*scale);await pageRenderer.renderPage(canvas.getContext('2d'),page,{scale});return createImageBitmap(canvas)}};
  const viewer=new Viewer(document.querySelector('#host'),{renderer,layout:'spread',find:false});await viewer.open({kind:'buffer',buffer:bytes.buffer});
  await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('viewer strips did not render')),5000);const check=()=>{if([...viewer.stage.querySelectorAll('canvas')].length===3&&[...viewer.stage.querySelectorAll('canvas')].every(c=>c.dataset.loaded==='ready')){clearTimeout(timer);resolve()}else requestAnimationFrame(check)};check()});
  window.viewer=viewer;window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
