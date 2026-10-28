import assert from 'node:assert/strict';

export async function verifyLazyPages(browser,base){
  const page=await browser.newPage({viewport:{width:1280,height:720}});await page.goto(`${base}spread-baseline.html`,{waitUntil:'networkidle'});
  const result=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async file=>new Uint8Array(await(await fetch(file)).arrayBuffer()),metadata=JSON.parse(new TextDecoder().decode(await read('flow-split/manifest.json'))),pages=metadata.views[0].pages;
    const first=structuredClone(pages[0]),distant=structuredClone(pages[1]),far=structuredClone(pages[2]),hash=distant.layers[1].obj,farHash=far.layers[1].obj;
    metadata.views[0].pages=Array.from({length:300},(_,i)=>structuredClone(i===20?distant:i===100?far:first));const encoded=new TextEncoder().encode(JSON.stringify(metadata));
    const requests=[],host=document.createElement('div');host.style.cssText='width:200px;height:120px';document.body.append(host);
    const count=await bdf.mount_bdf_split_async(host,encoded,async part=>{requests.push(part);return read(`flow-split/parts/${part}`)},'single'),canvases=[...host.querySelectorAll('canvas')];
    const initial={count,canvasCount:canvases.length,loaded:canvases.filter(c=>c.width>0).length,indices:canvases.flatMap((c,i)=>c.width>0?[i]:[]),distantRequested:requests.includes(hash),farRequested:requests.includes(farHash)};
    const wait=predicate=>new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('lazy page timeout')),8000);const check=()=>{if(predicate()){clearTimeout(timer);resolve()}else requestAnimationFrame(check)};check()});
    host.scrollTop=20*136;await wait(()=>canvases[20].dataset.bdfPageLoaded==='ready'&&canvases[0].width===0);
    await wait(()=>canvases.every(c=>c.dataset.bdfPageLoaded!=='loading'));
    const away={distantRequested:requests.includes(hash),firstReleased:canvases[0].width===0,farRequested:requests.includes(farHash),indices:canvases.flatMap((c,i)=>c.width>0?[i]:[])};
    host.scrollTop=0;await wait(()=>canvases[0].dataset.bdfPageLoaded==='ready'&&canvases[20].width===0);bdf.bdf_set_zoom(host,1.5);await wait(()=>canvases[0].dataset.bdfPageLoaded==='ready'&&canvases[0].width===300);
    const returned={distantReleased:canvases[20].width===0,firstWidth:canvases[0].width,farRequested:requests.includes(farHash),unique:new Set(requests).size===requests.length};
    bdf.unmount_bdf(host);host.remove();

    const visual=JSON.parse(new TextDecoder().decode(await read('../visual/split-fixture/manifest.json'))),extra=visual.views[0].pages[0],image=visual.parts.find(p=>p.t==='img').h;
    const interactiveMetadata=structuredClone(metadata);interactiveMetadata.views[0].pages=[...Array.from({length:20},()=>structuredClone(first)),extra];for(const part of visual.parts)if(!interactiveMetadata.parts.some(p=>p.h===part.h))interactiveMetadata.parts.push(part);
    const flowHashes=new Set(metadata.parts.map(p=>p.h)),interactiveRequests=[],interactive=document.createElement('div');interactive.style.cssText='width:200px;height:120px';document.body.append(interactive);
    await bdf.mount_bdf_interactive_split_async(interactive,new TextEncoder().encode(JSON.stringify(interactiveMetadata)),async part=>{interactiveRequests.push(part);return read(flowHashes.has(part)?`flow-split/parts/${part}`:`../visual/split-fixture/parts/${part}`)},'single');
    const before=interactiveRequests.includes(image),found=bdf.bdf_find(interactive,'AAA',0),last=interactive.querySelectorAll('canvas')[20];await wait(()=>last.dataset.bdfPageLoaded==='ready');
    const searchable={before,after:interactiveRequests.includes(image),total:found.total,scrolled:interactive.scrollTop>0};bdf.unmount_bdf(interactive);interactive.remove();

    let imageStart,imageRelease;const imageStarted=new Promise(r=>imageStart=r),imageGate=new Promise(r=>imageRelease=r),imageHost=document.createElement('div');imageHost.style.cssText='width:200px;height:120px';document.body.append(imageHost);
    const countFonts=()=>[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length,initialFonts=countFonts(),originalClose=ImageBitmap.prototype.close;let closed=0;ImageBitmap.prototype.close=function(){closed++;return originalClose.call(this)};
    let imageCancellation;try{
      await bdf.mount_bdf_split_async(imageHost,new TextEncoder().encode(JSON.stringify(interactiveMetadata)),async part=>{if(part===image){imageStart();await imageGate}return read(flowHashes.has(part)?`flow-split/parts/${part}`:`../visual/split-fixture/parts/${part}`)},'single');
      imageHost.scrollTop=20*136;await imageStarted;bdf.unmount_bdf(imageHost);imageRelease();await wait(()=>closed>0&&countFonts()===initialFonts);imageCancellation={closed:closed>0,fontsReleased:countFonts()===initialFonts,empty:imageHost.childElementCount===0};
    }finally{ImageBitmap.prototype.close=originalClose;imageHost.remove()}

    let start,release;const started=new Promise(r=>start=r),gate=new Promise(r=>release=r),cancel=document.createElement('div');cancel.style.cssText='width:200px;height:120px';document.body.append(cancel);let errors=0;cancel.addEventListener('error',()=>errors++);
    await bdf.mount_bdf_split_async(cancel,encoded,async part=>{if(part===hash){start();await gate}return read(`flow-split/parts/${part}`)},'single');cancel.scrollTop=20*136;await started;bdf.unmount_bdf(cancel);release();await new Promise(r=>setTimeout(r,50));const cancelled={empty:cancel.childElementCount===0,errors};cancel.remove();
    let initialStart,initialRelease;const initialStarted=new Promise(r=>initialStart=r),initialGate=new Promise(r=>initialRelease=r),pendingHost=document.createElement('div');pendingHost.style.cssText='width:200px;height:120px';document.body.append(pendingHost);
    const nearMetadata=structuredClone(metadata);nearMetadata.views[0].pages=[first,distant];const pending=bdf.mount_bdf_split_async(pendingHost,new TextEncoder().encode(JSON.stringify(nearMetadata)),async part=>{if(part===hash){initialStart();await initialGate}return read(`flow-split/parts/${part}`)},'single');
    await initialStarted;bdf.unmount_bdf(pendingHost);initialRelease();let initialRejected=false;try{await pending}catch{initialRejected=true}const initialCancelled={rejected:initialRejected,empty:pendingHost.childElementCount===0};pendingHost.remove();
    let olderStart,olderRelease;const olderStarted=new Promise(r=>olderStart=r),olderGate=new Promise(r=>olderRelease=r),concurrent=document.createElement('div');concurrent.style.cssText='width:200px;height:120px';document.body.append(concurrent);
    const slow=bdf.mount_bdf_split_async(concurrent,encoded,async part=>{olderStart();await olderGate;return read(`flow-split/parts/${part}`)},'single');await olderStarted;
    await bdf.mount_bdf_split_async(concurrent,encoded,part=>read(`flow-split/parts/${part}`),'single');const current=concurrent.querySelector('canvas');olderRelease();let olderRejected=false;try{await slow}catch{olderRejected=true}const superseded={rejected:olderRejected,preserved:concurrent.querySelector('canvas')===current};bdf.unmount_bdf(concurrent);concurrent.remove();
    const largeMetadata=structuredClone(metadata);largeMetadata.views[0].pages[100].w=9000;const oversized=document.createElement('div');oversized.style.cssText='width:200px;height:120px';document.body.append(oversized);let sizeError=false;oversized.addEventListener('error',event=>{sizeError=event.detail instanceof RangeError;event.preventDefault()});
    const largeCount=await bdf.mount_bdf_split_async(oversized,new TextEncoder().encode(JSON.stringify(largeMetadata)),part=>read(`flow-split/parts/${part}`),'single');bdf.bdf_set_zoom(oversized,1.25);oversized.scrollTop=100*(120*1.25+16);await wait(()=>sizeError);const large={count:largeCount,sizeError,kept:oversized.querySelectorAll('canvas').length===300};bdf.unmount_bdf(oversized);oversized.remove();
    const detached=document.createElement('div');detached.style.cssText='width:200px;height:120px';await bdf.mount_bdf_split_async(detached,encoded,part=>read(`flow-split/parts/${part}`),'single');const detachedCanvas=detached.querySelector('canvas'),blankBefore=detachedCanvas.width===0;document.body.append(detached);await wait(()=>detachedCanvas.dataset.bdfPageLoaded==='ready');detached.remove();await new Promise(r=>setTimeout(r,0));const detachedLifecycle={blankBefore,drawn:detachedCanvas.width>0,disposed:!detached[Symbol.for('f4ah6o.bdf.pageLayout')]};
    const {BdfDocument,BufferSource}=await import('@bdfkit/core'),{PageRenderer}=await import('@bdfkit/render'),{Viewer}=await import('@bdfkit/viewer');
    const bytes=await read('flow.bdf'),upstream=await BdfDocument.open(new BufferSource(bytes));upstream.manifest.views[0].pages=metadata.views[0].pages;const renderer=new PageRenderer(upstream),reference=document.createElement('div');reference.style.cssText='width:200px;height:120px';document.body.append(reference);
    const adapter={close:async()=>{},open:async()=>upstream.manifest,page:async(_id,index,scale)=>{const source=upstream.manifest.views[0].pages[index],canvas=document.createElement('canvas');canvas.width=Math.ceil(source.w*scale);canvas.height=Math.ceil(source.h*scale);await renderer.renderPage(canvas.getContext('2d'),source,{scale});return createImageBitmap(canvas)}};
    const viewer=new Viewer(reference,{renderer:adapter,layout:'single',find:false});await viewer.open({kind:'buffer',buffer:bytes.buffer});const all=[...viewer.stage.querySelectorAll('canvas')];
    await wait(()=>all.every(c=>c.dataset.loaded==='ready'||c.width===0));const referenceInitial=all.flatMap((c,i)=>c.width>0?[i]:[]);viewer.stage.scrollTop=20*136;
    await wait(()=>all[20].dataset.loaded==='ready'&&all[0].width===0&&all.every(c=>c.dataset.loaded!=='loading'));const referenceAway=all.flatMap((c,i)=>c.width>0?[i]:[]);viewer.destroy();renderer.dispose();reference.remove();
    return {initial,away,returned,searchable,imageCancellation,cancelled,initialCancelled,superseded,large,detachedLifecycle,referenceInitial,referenceAway};
  });
  assert.equal(result.initial.count,300,'large document page count');assert.equal(result.initial.canvasCount,300,'each page has a placeholder');assert.ok(result.initial.loaded>0&&result.initial.loaded<20,'only nearby pages have bitmaps');assert.equal(result.initial.distantRequested,false,'offscreen page is not fetched');assert.equal(result.initial.farRequested,false,'far page is not fetched');
  assert.equal(result.away.distantRequested,true,'scrolling fetches a nearby page');assert.equal(result.away.firstReleased,true,'scrolling releases a distant bitmap');assert.equal(result.away.farRequested,false,'unrelated distant pages stay unloaded');
  assert.deepEqual(result.initial.indices,result.referenceInitial,'initial loaded pages match upstream viewer');assert.deepEqual(result.away.indices,result.referenceAway,'loaded pages after scrolling match upstream viewer');
  assert.deepEqual(result.returned,{distantReleased:true,firstWidth:300,farRequested:false,unique:true},'returning and zooming renders only nearby pages without duplicate fetches');
  assert.deepEqual(result.searchable,{before:false,after:true,total:1,scrolled:true},'search finds offscreen text before loading its image and reveals its page');
  assert.deepEqual(result.imageCancellation,{closed:true,fontsReleased:true,empty:true},'unmount waits for a pending image decode before releasing resources');
  assert.deepEqual(result.cancelled,{empty:true,errors:0},'unmount cancels a pending distant-page render');
  assert.deepEqual(result.initialCancelled,{rejected:true,empty:true},'unmount rejects a pending initial page render');
  assert.deepEqual(result.superseded,{rejected:true,preserved:true},'a slower page mount cannot replace a newer document');await page.close();
  assert.deepEqual(result.large,{count:300,sizeError:true,kept:true},'an oversized distant page fails only when it is requested');
  assert.deepEqual(result.detachedLifecycle,{blankBefore:true,drawn:true,disposed:true},'a detached mount starts drawing after attachment and releases its observer on removal');
}
