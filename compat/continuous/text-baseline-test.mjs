import assert from 'node:assert/strict';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { createReadStream } from 'node:fs';
import { pathToFileURL } from 'node:url';
import crypto from 'node:crypto';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const buildRoot=root;
const {encodeDiagramDocument}=await import(pathToFileURL(root+'/plugin/src/diagram-bdf.js'));
const {chromium}=await import('playwright');
const bdf=await encodeDiagramDocument({source:'synthetic-baseline',title:'synthetic baseline',pages:[{width:300,height:220,primitives:[
 {kind:'text',x:20,y:50,text:'Hello',fontSize:32,family:'FixtureSTIX',baseline:'top'},
 {kind:'text',x:20,y:140,text:'Hello',fontSize:32,family:'FixtureSTIX',baseline:'alphabetic'},
]}]});
const mapping={'/browser.js':buildRoot+'/_build/js/debug/build/browser/browser.js','/worker.js':buildRoot+'/_build/js/debug/build/render_worker/render_worker.js','/font.ttf':root+'/compat/font/fixtures/stix.ttf'};
const server=createServer(async(req,res)=>{const url=new URL(req.url,'http://localhost');if(url.pathname==='/'){res.setHeader('Content-Type','text/html');res.end('<!doctype html><meta charset="utf-8"><style>body{margin:0}#host{position:relative;width:500px;height:400px}</style><div id="host"></div>');return}if(url.pathname==='/fixture.bdf'){res.setHeader('Content-Type','application/octet-stream');res.end(bdf);return}const file=mapping[url.pathname];if(!file){res.writeHead(404).end();return}res.setHeader('Content-Type',file.endsWith('.js')?'text/javascript':'font/ttf');const stream=createReadStream(file);stream.on('error',()=>res.destroy());stream.pipe(res)});
await new Promise((ok,fail)=>{server.once('error',fail);server.listen(0,'127.0.0.1',ok)});
const browser=await chromium.launch({headless:true});
try{
 const page=await browser.newPage({viewport:{width:800,height:600},deviceScaleFactor:1});
 const errors=[];page.on('pageerror',e=>errors.push(String(e)));page.on('console',m=>{if(m.type()==='error')errors.push(m.text())});
 await page.goto(`http://127.0.0.1:${server.address().port}/`,{waitUntil:'networkidle'});
 const info=await page.evaluate(async()=>{
  const font=await new FontFace('FixtureSTIX','url(/font.ttf)').load();document.fonts.add(font);await document.fonts.ready;
  const moon=await import('/browser.js'); const data=new Uint8Array(await(await fetch('/fixture.bdf')).arrayBuffer());
  const host=document.querySelector('#host');await moon.mount_bdf_interactive_async(host,data,'single');
  const wait=async()=>{const start=Date.now();while(host.querySelectorAll('[data-bdf-ordinal]').length<2||!host.querySelector('canvas')){if(Date.now()-start>10000)throw Error('viewer did not mount');await new Promise(r=>setTimeout(r,50))}};await wait();
  const canvas=host.querySelector('canvas'), bounds=canvas.getBoundingClientRect(),ctx=canvas.getContext('2d');
  const image=ctx.getImageData(0,0,canvas.width,canvas.height);
  const spans=[...host.querySelectorAll('[data-bdf-ordinal]')].map(span=>{const r=span.getBoundingClientRect(),range=document.createRange();range.selectNodeContents(span);const rr=range.getBoundingClientRect();return{text:span.textContent,ordinal:span.dataset.bdfOrdinal,x:r.x-bounds.x,y:r.y-bounds.y,w:r.width,h:r.height,range:{x:rr.x-bounds.x,y:rr.y-bounds.y,w:rr.width,h:rr.height},transform:span.style.transform}});
  const find=moon.bdf_find(host,'Hello',0);
  const bands=[[20,110],[110,190]].map(([start,end])=>{let x0=Infinity,y0=Infinity,x1=-1,y1=-1,first=null;for(let y=start;y<end;y++)for(let x=0;x<200;x++){const i=(y*image.width+x)*4;if(image.data[i+3]>100&&image.data[i]<100&&image.data[i+1]<100&&image.data[i+2]<100){if(!first)first=[x,y];x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y)}}const midX=(x0+x1)/2,midY=(y0+y1)/2;const hit=document.elementFromPoint(bounds.x+midX,bounds.y+midY);const caret=document.caretRangeFromPoint?.(bounds.x+midX,bounds.y+midY);return{ink:{x0,y0,x1,y1,first},hit:{tag:hit?.tagName,ordinal:hit?.dataset?.bdfOrdinal??null,text:hit?.textContent?.slice(0,20)??null},caret:{node:caret?.startContainer?.parentElement?.dataset?.bdfOrdinal??null,offset:caret?.startOffset??null}}});
  const client=moon.bdf_render_worker_client(new Worker('/worker.js',{type:'module'}));let legacyExtracted,legacyText,workerRects;try{const manifest=await client.open({kind:'buffer',buffer:data.slice().buffer});legacyExtracted=await client.content(manifest.views[0].id,0);legacyText=await client.text(manifest.views[0].id,0);const hits=await client.search(manifest.views[0].id,'Hello',{});workerRects=await client.locate(manifest.views[0].id,hits)}finally{await client.close().catch(()=>{});client.terminate()}
  const host2=document.createElement('div');host2.style.cssText='position:relative;width:500px;height:220px';document.body.appendChild(host2);
  const viewer=moon.bdf_create_viewer(host2,{workerUrl:'/worker.js',layout:'single'});
  let workerSpanY;
  try {
   await viewer.open({kind:'buffer',buffer:data.slice().buffer});
   const start=Date.now();
   while(host2.querySelectorAll('[data-bdf-ordinal]').length<2||!host2.querySelector('canvas')) {
    if(Date.now()-start>10000)throw Error('worker viewer did not mount');
    await new Promise(r=>setTimeout(r,50));
   }
   workerSpanY=host2.querySelector('[data-bdf-ordinal]').getBoundingClientRect().y-host2.querySelector('canvas').getBoundingClientRect().y;
  } finally { viewer.destroy();host2.remove() }
  return{workerSpanY,fontStatus:font.status,devicePixelRatio,canvas:{width:canvas.width,height:canvas.height,cssWidth:bounds.width,cssHeight:bounds.height,left:bounds.left,top:bounds.top},spans,find,bands,legacyExtracted,legacyText,workerRects};
 });
 const selections=[];for(const [label,index] of [['top',0],['alphabetic',1]]){const box=info.bands[index].ink;const y=info.canvas.top+(box.y0+box.y1)/2;await page.evaluate(()=>getSelection().removeAllRanges());await page.mouse.move(info.canvas.left+box.x0,y);await page.mouse.down();await page.mouse.move(info.canvas.left+box.x1,y,{steps:12});await page.mouse.up();selections.push({label,y:y-info.canvas.top,selected:await page.evaluate(()=>getSelection()?.toString()??'')});}
 assert.deepEqual(errors, []);
 assert.ok(Math.abs(info.workerSpanY-24.4)<0.1, `worker viewer must retain legacy position: ${info.workerSpanY}`);
 assert.deepEqual(selections.map(s=>s.selected), ['Hello', 'Hello']);
 for(let i=0;i<2;i++) {
   const {ink}=info.bands[i], span=info.spans[i], rect=info.find.rects[i];
   assert.ok(ink.y0>=span.y-2 && ink.y1<=span.y+span.h+2, `ink outside selection span ${i}`);
   assert.ok(ink.y0>=rect.y-2 && ink.y1<=rect.y+rect.h+2, `ink outside search rectangle ${i}`);
 }
 assert.equal(info.workerRects.length, 2);
 assert.ok(Math.abs(info.workerRects[0][0].y - 24.4) < 0.1, 'worker top position must retain legacy behavior');
 assert.ok(Math.abs(info.workerRects[1][0].y - 114.4) < 0.1, 'worker alphabetic search rectangle');
 // Worker methods and viewer retain the exact legacy output and position.
 const legacyRuns=JSON.parse(JSON.stringify(info.legacyExtracted.runs));
 assert.equal(info.legacyExtracted.runs[0].baseline, undefined);
 assert.equal(info.legacyExtracted.runs[1].baseline, undefined);
 const font={kind:1,family:'FixtureSTIX',weight:400,style:0};
 assert.deepEqual(JSON.parse(JSON.stringify(info.legacyText)), legacyRuns);
 assert.deepEqual(legacyRuns,[
  {text:'Hello',advance:96,size:32,font,align:0,matrix:[1,0,0,1,0,0],altText:false,x:20,y:50,sep:0,ordinal:0,node:0},
  {text:'Hello',advance:96,size:32,font,align:0,matrix:[1,0,0,1,0,0],altText:false,x:20,y:140,sep:1,ordinal:1,node:0},
 ]);
 console.log(JSON.stringify({selections,fixtureSha256:crypto.createHash('sha256').update(bdf).digest('hex'),fontSha256:crypto.createHash('sha256').update(await readFile(mapping['/font.ttf'])).digest('hex'),errors,info}));
}finally{await browser.close();await new Promise(ok=>server.close(ok))}
