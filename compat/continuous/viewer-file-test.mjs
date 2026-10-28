import assert from 'node:assert/strict';

export async function verifyViewerFile(browser,visualBase){
 const page=await browser.newPage();try{
  await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
  const outcomes=await page.evaluate(async()=>{
   const {BdfDocument,BufferSource}=await import('/node_modules/@bdfkit/core/dist/index.js'),{Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js'),moon=await import('/_build/js/debug/build/browser/browser.js');
   const bytes=new Uint8Array(await(await fetch('/compat/continuous/scroll.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),out=[];
   const wait=async fn=>{const start=performance.now();while(!fn()){if(performance.now()-start>7000)throw new Error('conversion timed out');await new Promise(r=>setTimeout(r,10))}};
   for(const kind of ['upstream','moon'])for(const mode of ['stream','fallback','cancel']){
    const host=document.createElement('div');host.style.cssText='width:200px;height:200px';document.body.append(host);
    const calls=[],events=[];let done=false,release;
    const renderer={close:async()=>{},open:async()=>structuredClone(doc.manifest),page:async(_id,index,scale)=>{const p=doc.manifest.views[0].pages[index],c=document.createElement('canvas');c.width=Math.ceil(p.w*scale);c.height=Math.ceil(p.h*scale);return createImageBitmap(c)},addPage:async(_id,index,b)=>calls.push('add:'+index+':'+new Uint8Array(b)[0]),replace:async()=>{calls.push('replace');return structuredClone(doc.manifest)},terminate:()=>calls.push('terminate')};
    const converter={convert:async()=>{calls.push('convert');return {bdf:new Uint8Array([9])}}};
    if(mode!=='fallback')Object.assign(converter,{open:async()=>{calls.push('open');return {bdf:new Uint8Array([9]),pages:3,stream:7}},page:async(_id,index)=>{calls.push('page:'+index);if(mode==='cancel'&&index===0)await new Promise(r=>release=r);return {bdf:new Uint8Array([index])}},finish:async()=>{calls.push('finish');return {bdf:new Uint8Array([8])}},close:async()=>{calls.push('close')}});
    const options={renderer,find:false},viewer=kind==='upstream'?new Viewer(host,options):moon.bdf_create_viewer(host,options);
    viewer.addEventListener('conversionprogress',e=>events.push(['progress',e.detail.page,e.detail.pages]));viewer.addEventListener('conversiondone',()=>{events.push(['done']);done=true});
    try{
     const manifest=await viewer.openFile(converter,new Uint8Array([1,2]),{name:'test'});
     if(mode==='stream')await wait(()=>done&&calls.includes('close'));
     if(mode==='cancel'){await wait(()=>!!release);await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});release();await wait(()=>calls.filter(x=>x==='close').length>=2)}
     out.push({kind,mode,view:viewer.view?.id,manifest:manifest.views[0].id,calls:[...calls],events:[...events]});
    }finally{viewer.destroy();host.remove()}
   }
   return out;
  });
  for(let i=0;i<3;i++){const {kind:_a,...a}=outcomes[i],{kind:_b,...b}=outcomes[i+3];assert.deepEqual(b,a,b.mode+' conversion');}
  assert.deepEqual(outcomes[0].events,[['progress',0,3],['progress',1,3],['progress',2,3],['done']]);
  assert.deepEqual(outcomes[1].calls,['convert']);
  assert.ok(!outcomes[2].calls.some(x=>x.startsWith('add:')),'cancelled stream added a page');
 }finally{await page.close()}
}
