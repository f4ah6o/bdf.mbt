import {BdfDocument,BufferSource} from '@bdfkit/core';
import {PageRenderer} from '@bdfkit/render';
import {Viewer} from '@bdfkit/viewer';
try{
  const bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),pageRenderer=new PageRenderer(doc);
  window.sheetCalls=0;
  const renderer={close:async()=>{},open:async()=>doc.manifest,sheet:async(_id,viewport,scale)=>{const canvas=document.createElement('canvas');canvas.width=Math.ceil(viewport.w*scale);canvas.height=Math.ceil(viewport.h*scale);await pageRenderer.renderSheet(canvas.getContext('2d'),doc.manifest.views[0],viewport,{scale});window.sheetCalls++;return createImageBitmap(canvas)}};
  const viewer=new Viewer(document.querySelector('#host'),{renderer,zoom:1.5,find:false});await viewer.open({kind:'buffer',buffer:bytes.buffer});window.viewer=viewer;
  await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('sheet did not render')),5000);const check=()=>{const canvas=viewer.stage.querySelector('canvas');if(window.sheetCalls>0&&canvas?.width===Math.ceil(viewer.stage.clientWidth*devicePixelRatio)&&canvas?.height===Math.ceil(viewer.stage.clientHeight*devicePixelRatio)){clearTimeout(timer);resolve()}else requestAnimationFrame(check)};check()});window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
