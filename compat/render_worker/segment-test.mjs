import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { webcrypto } from 'node:crypto';
import { deflateRawSync, inflateRawSync } from 'node:zlib';
import { PNG } from 'pngjs';

// These upstream test fixtures use a published test-only reader key. Rewrap
// their content keys for the fresh public key in each real Worker request.
const readerJwk = {kty:'EC',crv:'P-256',x:'TL6kYiUfNKSRKbTiahzyxwcAyOUy0pTL2c6JfeoqL1E',y:'OK8MOP4eHuQHLjAnrz7hubCKED1E8wPUbZYJQY-3z5I',d:'_loj2CexGXt2g1YkkUeTui4c9IeJ-BtcOYRzVL81Zi4'};
const { subtle } = webcrypto;
const info = new TextEncoder().encode('bdf ecdh v1');
const from64 = s => new Uint8Array(Buffer.from(s,'base64'));
async function kek(privateKey, publicKey, epk, rpk, usage) {
  const z = await subtle.deriveKey({name:'ECDH',public:publicKey},privateKey,{name:'HKDF'},false,['deriveKey']);
  const salt = await subtle.digest('SHA-256',Buffer.concat([epk,rpk]));
  return subtle.deriveKey({name:'HKDF',hash:'SHA-256',salt,info},z,{name:'AES-KW',length:256},false,[usage]);
}
async function rewrap(input, publicBytes) {
  const offset = Number(input.readBigUInt64LE(8)), len = Number(input.readBigUInt64LE(16));
  const raw = input.subarray(offset,offset+len);
  const manifest = JSON.parse((input[24] ? inflateRawSync(raw) : raw).toString('utf8'));
  const slot = manifest.encryption.keys.find(k => k.type === 'ecdh');
  const oldPrivate = await subtle.importKey('jwk',readerJwk,{name:'ECDH',namedCurve:'P-256'},false,['deriveKey']);
  const oldPub = await subtle.importKey('jwk',{kty:'EC',crv:'P-256',x:readerJwk.x,y:readerJwk.y},{name:'ECDH',namedCurve:'P-256'},true,[]);
  const oldRpk = Buffer.from(await subtle.exportKey('raw',oldPub));
  const oldEpk = from64(slot.epk);
  const oldWriter = await subtle.importKey('raw',oldEpk,{name:'ECDH',namedCurve:'P-256'},false,[]);
  const oldKek = await kek(oldPrivate,oldWriter,oldEpk,oldRpk,'unwrapKey');
  const content = await subtle.unwrapKey('raw',from64(slot.key),oldKek,'AES-KW',{name:'AES-GCM',length:256},true,['encrypt','decrypt']);
  const writer = await subtle.generateKey({name:'ECDH',namedCurve:'P-256'},false,['deriveKey']);
  const epk = Buffer.from(await subtle.exportKey('raw',writer.publicKey));
  const recipient = await subtle.importKey('raw',publicBytes,{name:'ECDH',namedCurve:'P-256'},false,[]);
  const newKek = await kek(writer.privateKey,recipient,epk,publicBytes,'wrapKey');
  slot.epk = epk.toString('base64'); slot.key = Buffer.from(await subtle.wrapKey('raw',content,newKek,'AES-KW')).toString('base64');
  const json = Buffer.from(JSON.stringify(manifest));
  const stored = input[24] ? deflateRawSync(json) : json;
  const header = Buffer.from(input.subarray(0,offset)); header.writeBigUInt64LE(BigInt(stored.length),16);
  return Buffer.concat([header,stored,input.subarray(offset+len)]);
}

export async function verifySegmentWorker(browser, visualBase) {
  const fixtures = [1,4,7].map(n => readFileSync('compat/render_worker/segments/basic-' + n + '.bdf'));
  const requests = new Map();
  const aborted = new Set();
  const server = createServer((req,res) => {
    res.setHeader('Access-Control-Allow-Origin','*');
    res.setHeader('Access-Control-Allow-Headers','Content-Type');
    res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
    if(req.method === 'OPTIONS') {res.writeHead(204).end();return}
    const url = new URL(req.url,'http://localhost'), id = url.searchParams.get('id'), mode = url.searchParams.get('mode');
    if (url.pathname === '/stats') {res.end(JSON.stringify({count:(requests.get(id)??[]).length,aborted:aborted.has(id)}));return}
    const chunks=[]; req.on('data',chunk=>chunks.push(chunk));
    req.on('end',async()=>{
      try {
        const body=JSON.parse(Buffer.concat(chunks).toString());
        const log=requests.get(id)??[];log.push(body);requests.set(id,log);
        assert.equal(Buffer.from(body.key,'base64').length,65);
        if(mode==='403'||mode==='429'||mode==='500'){res.writeHead(Number(mode)).end();return}
        if((mode==='later403'||mode==='later429')&&body.page>=3){res.writeHead(Number(mode.slice(5))).end();return}
        if(mode==='slow'&&body.page>=3){
          const timer=setTimeout(()=>res.writeHead(503).end(),5000);
          res.on('close',()=>{clearTimeout(timer);if(!res.writableEnded)aborted.add(id)});
          return;
        }
        const index=Math.min(2,Math.floor(body.page/3));
        if(mode==='wrong') {res.writeHead(200).end(await rewrap(fixtures[(index+1)%3],from64(body.key)));return}
        const bytes=await rewrap(fixtures[index],from64(body.key));
        res.writeHead(200,{'Content-Type':'application/octet-stream','Content-Length':bytes.length});res.end(bytes);
      } catch(e) {res.writeHead(500).end(String(e));}
    });
  });
  await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
  const page=await browser.newPage();
  try {
    await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
    const result=await page.evaluate(async port=>{
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bitmap=img=>{const c=document.createElement('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').drawImage(img,0,0);img.close();return c.toDataURL()};
      const out=[];
      for(const [kind,workerUrl] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]) {
        for(const mode of ['normal','wrong','403','429','500','later403','later429']) {
          const id=kind+'-'+mode,worker=new Worker(workerUrl,{type:'module'}),client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker),item={id,mode};
          try {
            const manifest=await client.open({kind:'segments',url:'http://127.0.0.1:'+port+'/?id='+id+'&mode='+mode});
            item.manifest=manifest;
            const idView=manifest.views[0].id;
            item.searchBefore=await client.search(idView,'book');
            item.images=[bitmap(await client.page(idView,0,0.5))];
            const [a,b,c]=await Promise.all([client.page(idView,3,0.5),client.page(idView,4,0.5),client.text(idView,5)]);
            item.images.push(bitmap(a),bitmap(b));item.text=c;
            item.images.push(bitmap(await client.page(idView,6,0.5)));
            const plainWorker=new Worker(workerUrl,{type:'module'}),plain=kind==='upstream'?new BdfWorkerClient(plainWorker):moon.bdf_render_worker_client(plainWorker);
            try {const buffer=await(await fetch('/compat/render_worker/segments/basic.bdf')).arrayBuffer();const whole=await plain.open({kind:'buffer',buffer});item.plainImages=[];for(const index of [0,3,4,6])item.plainImages.push(bitmap(await plain.page(whole.views[0].id,index,0.5)));}finally{plain.terminate()}
            item.search=await client.search(idView,'book');
            item.locate=await client.locate(idView,item.search);
            await client.close();
          } catch(e) {item.error={name:e.name,code:e.code};}
          finally {client.terminate()}
          out.push(item);
        }
      }
      return out;
    },server.address().port);
    for(let i=0;i<7;i++) {
      const a=result[i],b=result[i+7],{id:_a,images:imagesA,plainImages:plainA,...dataA}=a,{id:_b,images:imagesB,plainImages:plainB,...dataB}=b;
      assert.deepEqual(dataB,dataA,b.id+': protocol result');
      if(plainA && plainB) for(const [images,plain,name] of [[imagesA,plainA,"upstream"],[imagesB,plainB,"moon"]]) for(let n=0;n<images.length;n++) {
        const x=PNG.sync.read(Buffer.from(plain[n].split(',')[1],'base64')),y=PNG.sync.read(Buffer.from(images[n].split(',')[1],'base64'));
        assert.deepEqual([y.width,y.height],[x.width,x.height]);let changed=0;
        for(let j=0;j<x.data.length;j+=4)if(x.data[j]!==y.data[j]||x.data[j+1]!==y.data[j+1]||x.data[j+2]!==y.data[j+2]||x.data[j+3]!==y.data[j+3])changed++;
        assert.ok(changed/(x.width*x.height)<=0.0005,name+': segment bitmap '+n+' differs: '+changed+'/'+(x.width*x.height));
      }
      if(a.mode==='normal') for(const item of [a,b]) {
        const log=requests.get(item.id); assert.ok(log.length>=3,item.id+': missing segment requests');
        assert.equal(log[0].page,0);assert.deepEqual(log[0].have,[]);
        assert.equal(log.filter(x=>x.page>=3&&x.page<6).length,1,item.id+': concurrent segment requests not coalesced');
        assert.ok(log.some(x=>x.have.some(h=>h.from===0&&h.to===3)),item.id+': missing held segment');
        assert.equal(new Set(log.map(x=>x.key)).size,log.length,item.id+': public key was reused');
        assert.ok(item.text.length>0,item.id+': missing text');
        assert.ok(item.search.length>item.searchBefore.length,item.id+': search index did not grow after segment arrival');
      }
      else assert.ok(a.error,b.id+': error expected');
    }
    const continuous = await page.evaluate(async port => {
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const picture=img=>{const c=document.createElement('canvas');c.width=img.width;c.height=img.height;c.getContext('2d').drawImage(img,0,0);img.close();return c.toDataURL()};
      const result=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]) {
        const make=()=>{const worker=new Worker(url,{type:'module'});return kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker)};
        const segment=make(),whole=make(),rect={x:0,y:0,w:420,h:3700};
        try {
          const manifest=await segment.open({kind:'segments',url:'http://127.0.0.1:'+port+'/?id='+kind+'-continuous&mode=normal'});
          const segmented=picture(await segment.continuous(manifest.views[0].id,rect,0.25));
          const content=await segment.continuousContent(manifest.views[0].id,rect);
          const buffer=await(await fetch('/compat/render_worker/segments/basic.bdf')).arrayBuffer();
          const full=await whole.open({kind:'buffer',buffer});
          result.push({kind,segmented,content,plain:picture(await whole.continuous(full.views[0].id,rect,0.25)),plainContent:await whole.continuousContent(full.views[0].id,rect)});
        } finally {segment.terminate();whole.terminate()}
      }
      return result;
    },server.address().port);
    for (const item of continuous) {
      assert.deepEqual(item.content,item.plainContent,item.kind+': continuous content');
      const x=PNG.sync.read(Buffer.from(item.plain.split(',')[1],'base64')),y=PNG.sync.read(Buffer.from(item.segmented.split(',')[1],'base64'));
      assert.deepEqual(x.data,y.data,item.kind+': continuous image');
      const log=requests.get(item.kind+'-continuous');
      assert.equal(log.filter(r=>r.page>=3&&r.page<6).length,1,item.kind+': continuous segment coalescing');
    }
    const selected = await page.evaluate(async port => {
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const result=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]) {
        const worker=new Worker(url,{type:'module'}),client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker);
        try {result.push(await client.open({kind:'segments',url:'http://127.0.0.1:'+port+'/?id='+kind+'-selected&mode=normal',view:'pages',page:3}))} finally {client.terminate()}
      }
      return result;
    },server.address().port);
    assert.deepEqual(selected[1],selected[0],'selected initial segment');
    for(const id of ['upstream-selected','moon-selected']) {
      const log=requests.get(id); assert.equal(log.length,1); assert.equal(log[0].view,'pages'); assert.equal(log[0].page,3); assert.deepEqual(log[0].have,[]);
    }
    const lifecycle = await page.evaluate(async port => {
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const result=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]) {
        const id=kind+'-slow',worker=new Worker(url,{type:'module'}),client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker);
        const stats=async()=>await(await fetch('http://127.0.0.1:'+port+'/stats?id='+id)).json();
        try {
          const manifest=await client.open({kind:'segments',url:'http://127.0.0.1:'+port+'/?id='+id+'&mode=slow'});
          (await client.page(manifest.views[0].id,0,0.5)).close();
          for(let n=0;n<100&&(await stats()).count<2;n++)await new Promise(r=>setTimeout(r,20));
          await client.close();
          let state=await stats();
          for(let n=0;n<100&&!state.aborted;n++){await new Promise(r=>setTimeout(r,20));state=await stats()}
          result.push({kind,...state});
        } finally {client.terminate()}
      }
      return result;
    },server.address().port);
    for(const item of lifecycle){assert.ok(item.count>=2,item.kind+': prefetch did not start');assert.ok(item.aborted,item.kind+': close did not abort prefetch')}
  } finally {await page.close();await new Promise(resolve=>server.close(resolve));}
}
