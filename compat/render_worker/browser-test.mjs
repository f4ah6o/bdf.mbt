import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

function compare(expected,actual,label){
 const a=PNG.sync.read(Buffer.from(expected.split(',')[1],'base64')),b=PNG.sync.read(Buffer.from(actual.split(',')[1],'base64'));
 assert.deepEqual([b.width,b.height],[a.width,a.height],`${label}: bitmap size`);let changed=0;for(let i=0;i<a.data.length;i+=4)if(a.data[i]!==b.data[i]||a.data[i+1]!==b.data[i+1]||a.data[i+2]!==b.data[i+2]||a.data[i+3]!==b.data[i+3])changed++;assert.ok(changed/(a.width*a.height)<=0.0005,`${label}: ${changed} pixels differ`);
}
export async function verifyRenderWorker(browser, visualBase){
 const page=await browser.newPage();await page.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
 const snapshots=await page.evaluate(async()=>{
  const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js'),bdf=await import('/_build/js/debug/build/browser/browser.js');
  const read=async url=>new Uint8Array(await(await fetch(url)).arrayBuffer()),bitmap=img=>{const c=document.createElement('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').drawImage(img,0,0);img.close();return c.toDataURL()};
  const out=[];
  for(const [name,clientKind,workerKind] of [['upstream','upstream','upstream'],['moon-client','moon','upstream'],['moon-worker','upstream','moon'],['moon','moon','moon']]){
   const url=workerKind==='upstream'?'/node_modules/@bdfkit/render/dist/worker.js':'/_build/js/debug/build/render_worker/render_worker.js',worker=new Worker(url,{type:'module'}),client=clientKind==='upstream'?new BdfWorkerClient(worker):bdf.bdf_render_worker_client(worker),images={},items={};
   try{
    const rich=await read('/compat/visual/fixture.bdf'),buffer=rich.slice().buffer,manifest=await client.open({kind:'buffer',buffer});items.detached=buffer.byteLength===0;items.manifest=manifest;const id=manifest.views[0].id;
    for(const zoom of [0.75,1,1.5])images[`page-${zoom}`]=bitmap(await client.page(id,0,zoom));
    items.text=await client.text(id,0);items.content=await client.content(id,0);const query=items.text.find(r=>r.text.trim())?.text.slice(0,3)??"missing";items.search=await client.search(id,query);items.locate=await client.locate(id,items.search);images.roles=bitmap(await client.page(id,0,1,['annotation']));items.noPlay=await client.play(id);items.noAudio=await client.audio(id);
    const single=await client.open({kind:'single',url:'/compat/visual/fixture.bdf'});images.single=bitmap(await client.page(single.views[0].id,0,1));
    const split=await client.open({kind:'split',base:'/compat/visual/split-fixture/'});images.split=bitmap(await client.page(split.views[0].id,0,1));
    const continuous=await read('/compat/continuous/flow.bdf'),flow=await client.open({kind:'buffer',buffer:continuous.buffer});images.continuous=bitmap(await client.continuous(flow.views[0].id,{x:0,y:40,w:220,h:260},1));items.continuousText=await client.continuousText(flow.views[0].id,{x:0,y:40,w:220,h:260});items.continuousContent=await client.continuousContent(flow.views[0].id,{x:0,y:40,w:220,h:260});
    const replacement=await read('/compat/visual/fixture.bdf');await client.addPage(flow.views[0].id,1,replacement.buffer);items.addDetached=replacement.buffer.byteLength===0;images.added=bitmap(await client.page(flow.views[0].id,1,1));
    const sheet=await read('/compat/sheet/cells.bdf'),sheetManifest=await client.replace({kind:'buffer',buffer:sheet.buffer});images.sheet=bitmap(await client.sheet(sheetManifest.views[0].id,{x:0,y:0,w:300,h:200},1));items.sheetContent=await client.sheetContent(sheetManifest.views[0].id,{x:0,y:0,w:300,h:200});items.sheetSearch=await client.search(sheetManifest.views[0].id,"Apple");items.sheetLocate=await client.locate(sheetManifest.views[0].id,items.sheetSearch);
    const music=await read('/compat/music/fixtures/ode-mml.bdf'),musicManifest=await client.open({kind:'buffer',buffer:music.buffer}),play=await client.play(musicManifest.views[0].id);items.play={seq:[...new Uint8Array(play.seq)],cues:play.cues};
    const encrypted=await read('/compat/visual/encrypted-fixture/password.bdf');try{await client.open({kind:'buffer',buffer:encrypted.buffer})}catch(e){items.passwordRequired={name:e.name,code:e.code}}try{await client.unlock('wrong')}catch(e){items.wrongPassword={name:e.name,code:e.code}}const unlocked=await client.unlock('pass');images.encrypted=bitmap(await client.page(unlocked.views[0].id,0,1));
    await client.close();try{await client.page(unlocked.views[0].id,0,1)}catch(e){items.closed=e.name}
    out.push({name,images,items});
   }finally{client.terminate()}
  }
  return out;
 });
 const [reference,...variants]=snapshots;
 assert.ok(reference.items.text.length > 0, "reference page has text");
 assert.ok(reference.items.search.length > 0, "reference search has hits");
 assert.ok(reference.items.locate.some(rects => rects.length > 0), "reference hits have measured rectangles");
 for(const variant of variants){assert.deepEqual(variant.items,reference.items,`${variant.name}: worker protocol, metadata and music`);for(const [name,image] of Object.entries(reference.images))compare(image,variant.images[name],`${variant.name} ${name}`)}
 await page.close();
}
