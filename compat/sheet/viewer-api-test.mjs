import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

export async function verifyViewerSheet(browser,visualBase){
 const page=await browser.newPage();try{
  await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
  const results=await page.evaluate(async()=>{
   const {Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js'),{BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js'),moon=await import('/_build/js/debug/build/browser/browser.js');
   const bytes=new Uint8Array(await(await fetch('/compat/sheet/cells.bdf')).arrayBuffer()),out=[];
   const wait=async fn=>{const start=performance.now();while(!fn()){if(performance.now()-start>7000)throw new Error('sheet timed out');await new Promise(r=>setTimeout(r,15))}};
   for(const kind of ['upstream','moon']){
    const host=document.createElement('div');host.style.cssText='width:320px;height:200px;position:relative';document.body.append(host);
    const worker=new Worker(kind==='upstream'?'/node_modules/@bdfkit/render/dist/worker.js':'/_build/js/debug/build/render_worker/render_worker.js',{type:'module'}),renderer=new BdfWorkerClient(worker),viewer=kind==='upstream'?new Viewer(host,{renderer,find:false}):moon.bdf_create_viewer(host,{renderer,find:false});
    try{
     const manifest=await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});await wait(()=>viewer.stage.querySelector('canvas')?.width===320*(devicePixelRatio||1)&&viewer.stage.querySelector('canvas')?.height===200*(devicePixelRatio||1));
     const snap=()=>({view:viewer.view.id,stageWidth:viewer.stage.clientWidth,stageHeight:viewer.stage.clientHeight,scrollWidth:viewer.stage.scrollWidth,scrollHeight:viewer.stage.scrollHeight,canvas:viewer.stage.querySelector('canvas').toDataURL()});
     const initial=snap();viewer.setZoom(1.5);await wait(()=>viewer.stage.querySelector('canvas')?.width===320*(devicePixelRatio||1)&&viewer.stage.querySelector('canvas')?.height===200*(devicePixelRatio||1));const zoom=snap();
     const found=await viewer.find('apple');await wait(()=>viewer.stage.querySelector('[data-bdf-hits] div'));
     const marks=[...viewer.stage.querySelectorAll('[data-bdf-hits] div')].map(el=>el.style.cssText);
     out.push({kind,manifest:manifest.views[0].id,initial,zoom,found,marks,scroll:[viewer.stage.scrollLeft,viewer.stage.scrollTop]});
    }finally{viewer.destroy();renderer.terminate();host.remove()}
   }
   return out;
  });
  const [a,b]=results;assert.deepEqual(b.found,a.found,'sheet find state');assert.equal(a.found.total,1);assert.deepEqual(b.marks,a.marks,'sheet search marks');assert.deepEqual(b.scroll,a.scroll,'sheet search position');
  for(const key of ['initial','zoom']){
   const {canvas:x,...ax}=a[key],{canvas:y,...by}=b[key];assert.deepEqual(by,ax,'sheet '+key+' geometry');
   const before=PNG.sync.read(Buffer.from(x.split(',')[1],'base64')),after=PNG.sync.read(Buffer.from(y.split(',')[1],'base64'));assert.deepEqual([before.width,before.height],[after.width,after.height]);
   let changed=0;for(let i=0;i<before.data.length;i+=4)if(before.data[i]!==after.data[i]||before.data[i+1]!==after.data[i+1]||before.data[i+2]!==after.data[i+2]||before.data[i+3]!==after.data[i+3])changed++;
   assert.ok(changed/(before.width*before.height)<=0.0005,'sheet '+key+': '+changed+' pixels differ');
  }
 }finally{await page.close()}
}
