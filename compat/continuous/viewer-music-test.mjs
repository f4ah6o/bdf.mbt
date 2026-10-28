import assert from 'node:assert/strict';

export async function verifyViewerMusic(browser,visualBase){
 const page=await browser.newPage();try{
  await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
  const result=await page.evaluate(async()=>{
   const {Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js'),{BdfDocument,BufferSource}=await import('/node_modules/@bdfkit/core/dist/index.js'),moon=await import('/_build/js/debug/build/browser/browser.js');
   const bytes=new Uint8Array(await(await fetch('/compat/music/fixtures/ode-mml.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),out=[];
   const wait=async fn=>{const start=performance.now();while(!fn()){if(performance.now()-start>5000)throw new Error('music viewer timed out');await new Promise(r=>setTimeout(r,10))}};
   for(const kind of ['upstream','moon']){
    const host=document.createElement('div');host.style.cssText='width:300px;height:200px';document.body.append(host);const contexts=[];
    const renderer={close:async()=>{},open:async()=>structuredClone(doc.manifest),page:async(_id,index,scale)=>{const p=doc.manifest.views[0].pages[index],c=document.createElement('canvas');c.width=Math.ceil(p.w*scale);c.height=Math.ceil(p.h*scale);return createImageBitmap(c)}};
    const music=async ctx=>{contexts.push(ctx);ctx.stage.textContent='piano roll'};
    const options={renderer,music,find:false},viewer=kind==='upstream'?new Viewer(host,options):new moon.Viewer(host,options);
    try{
     await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});viewer.setMusicMode('piano-roll');await wait(()=>contexts.length===1);
     const first={text:viewer.stage.textContent,view:contexts[0].view.id,zoom:contexts[0].zoom,current:contexts[0].isCurrent(),found:await viewer.find('music')};
     viewer.setZoom(1.5);await wait(()=>contexts.length===2);
     const second={zoom:contexts[1].zoom,oldCurrent:contexts[0].isCurrent(),current:contexts[1].isCurrent()};
     viewer.setMusicMode('score');await wait(()=>viewer.stage.querySelector('canvas'));
     const score={hasCanvas:!!viewer.stage.querySelector('canvas'),oldCurrent:contexts[1].isCurrent()};
     const otherHost=document.createElement('div');document.body.append(otherHost);const noMusic=kind==='upstream'?new Viewer(otherHost,{renderer,find:false}):new moon.Viewer(otherHost,{renderer,find:false});let missing;
     try{noMusic.setMusicMode('piano-roll')}catch(e){missing={name:e.name,message:e.message}}finally{noMusic.destroy();otherHost.remove()}
     out.push({kind,first,second,score,missing});
    }finally{viewer.destroy();host.remove()}
   }
   return out;
  });
  const {kind:_a,...a}=result[0],{kind:_b,...b}=result[1];assert.deepEqual(b,a,'viewer music mode');assert.equal(a.first.text,'piano roll');assert.equal(a.second.oldCurrent,false);
 }finally{await page.close()}
}
