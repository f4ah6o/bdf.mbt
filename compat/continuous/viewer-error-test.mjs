import assert from 'node:assert/strict';

export async function verifyViewerErrors(browser,visualBase){
 const page=await browser.newPage();try{
  await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
  const result=await page.evaluate(async()=>{
   const {Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js'),{BdfDocument,BufferSource}=await import('/node_modules/@bdfkit/core/dist/index.js'),moon=await import('/_build/js/debug/build/browser/browser.js');
   const bytes=new Uint8Array(await(await fetch('/compat/continuous/flow.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),out=[];
   const wait=async fn=>{const start=performance.now();while(!fn()){if(performance.now()-start>5000)throw new Error('error event timed out');await new Promise(r=>setTimeout(r,10))}};
   for(const kind of ['upstream','moon']){
    const host=document.createElement('div');host.style.cssText='width:300px;height:200px';document.body.append(host);
    const openError=Object.assign(new Error('password required'),{name:'BdfWorkerError',code:'password-required'}),searchError=new Error('search failed'),pageError=new Error('page failed'),convertError=new Error('conversion failed');let failOpen=true,eventError;
    const renderer={close:async()=>{},open:async()=>{if(failOpen)throw openError;return structuredClone(doc.manifest)},page:async()=>{throw pageError},search:async()=>{throw searchError}};
    const viewer=kind==='upstream'?new Viewer(host,{renderer,find:false}):moon.bdf_create_viewer(host,{renderer,find:false});viewer.addEventListener('error',event=>{event.preventDefault();eventError=event.detail});
    try{
     let openIdentity=false,searchIdentity=false,convertIdentity=false;
     try{await viewer.open({kind:'buffer',buffer:bytes.slice().buffer})}catch(e){openIdentity=e===openError}
     failOpen=false;await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});await wait(()=>eventError);
     try{await viewer.find('x')}catch(e){searchIdentity=e===searchError}
     try{await viewer.openFile({convert:async()=>{throw convertError}},new Uint8Array([1]))}catch(e){convertIdentity=e===convertError}
     out.push({kind,openIdentity,searchIdentity,convertIdentity,pageIdentity:eventError===pageError});
    }finally{viewer.destroy();host.remove()}
   }
   return out;
  });
  const {kind:_a,...a}=result[0],{kind:_b,...b}=result[1];assert.deepEqual(b,a,'viewer error identity');assert.deepEqual(a,{openIdentity:true,searchIdentity:true,convertIdentity:true,pageIdentity:true});
 }finally{await page.close()}
}
