import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

export async function verifyWorkerResources(browser, visualBase) {
  const page=await browser.newPage();
  try {
    await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
    const result=await page.evaluate(async()=>{
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=new Uint8Array(await(await fetch('/compat/visual/fixture.bdf')).arrayBuffer());
      const image=bitmap=>{const c=document.createElement('canvas');c.width=bitmap.width;c.height=bitmap.height;c.getContext('2d').drawImage(bitmap,0,0);bitmap.close();return c.toDataURL()};
      const out=[];
      const cases=[
        {name:'default',options:{},renders:2},
        {name:'small-budget',options:{imageBudget:15},renders:2},
        {name:'exact-budget',options:{imageBudget:16},renders:2},
        {name:'zero-budget-concurrent',options:{imageBudget:0},renders:2,concurrent:true},
        {name:'hold-limit',options:{holdLimit:15},renders:1},
        {name:'hold-exact',options:{holdLimit:16},renders:1},
        {name:'pixel-limit',options:{maxImagePixels:3,holdLimit:0},renders:2},
        {name:'zero-pixels',options:{maxImagePixels:0},renders:1},
        {name:'replace-settings',options:{imageBudget:0},renders:2,replace:true},
        {name:'reopen-settings',options:{holdLimit:15},renders:1,reopen:true},
      ];
      for(const [kind,workerUrl] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']])for(const test of cases){
        let decodes=0,rasters=0;const wrapper='/compat/render_worker/instrumented-worker.mjs?worker='+encodeURIComponent(workerUrl),worker=new Worker(wrapper,{type:'module'});
        worker.addEventListener('message',event=>{if(event.data?.type==='test-image-decode')decodes++;if(event.data?.type==='rasterize')rasters++});
        await new Promise((resolve,reject)=>{worker.addEventListener('message',event=>{if(event.data?.type==='test-worker-ready')resolve()});worker.addEventListener('error',reject,{once:true})});
        const client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker),item={kind,name:test.name,images:[],errors:[]};
        try {
          const open=async(options)=>client.open({kind:'buffer',buffer:bytes.slice().buffer},undefined,options);
          let manifest=await open(test.options);const id=manifest.views[0].id;
          const draw=async()=>{try{item.images.push(image(await client.page(id,0,1)))}catch(e){item.errors.push({name:e.name,message:e.message,code:e.code})}};
          if(test.concurrent)await Promise.all(Array.from({length:test.renders},draw));
          else for(let i=0;i<test.renders;i++){if(i===1&&test.replace)await client.replace({kind:'buffer',buffer:bytes.slice().buffer});await draw()}
          if(test.reopen){manifest=await open(undefined);try{item.images.push(image(await client.page(manifest.views[0].id,0,1)))}catch(e){item.errors.push({name:e.name,message:e.message,code:e.code})}}
          item.decodes=decodes;item.rasters=rasters;
        } finally {client.terminate()}
        out.push(item);
      }
      return out;
    });
    const count=result.length/2;
    for(let i=0;i<count;i++){
      const a=result[i],b=result[i+count],{kind:_ak,images:ai,...am}=a,{kind:_bk,images:bi,...bm}=b;
      assert.deepEqual(bm,am,b.name+': resource behavior');
      assert.equal(bi.length,ai.length,b.name+': image count');
      for(let n=0;n<ai.length;n++){
        const x=PNG.sync.read(Buffer.from(ai[n].split(',')[1],'base64')),y=PNG.sync.read(Buffer.from(bi[n].split(',')[1],'base64'));
        assert.deepEqual([x.width,x.height],[y.width,y.height]);let changed=0;
        for(let j=0;j<x.data.length;j+=4)if(x.data[j]!==y.data[j]||x.data[j+1]!==y.data[j+1]||x.data[j+2]!==y.data[j+2]||x.data[j+3]!==y.data[j+3])changed++;
        assert.ok(changed/(x.width*x.height)<=0.0005,b.name+': '+changed+' pixels differ');
      }
    }
    const expected={default:[1,1], 'small-budget':[2,1], 'exact-budget':[1,1], 'zero-budget-concurrent':[1,1], 'hold-limit':[0,0], 'hold-exact':[1,1], 'pixel-limit':[0,1], 'zero-pixels':[0,1], 'replace-settings':[2,2], 'reopen-settings':[1,1]};
    for(const item of result){assert.deepEqual([item.decodes,item.rasters],expected[item.name],item.kind+' '+item.name+': decode or raster count');}
    const lifecycle=await page.evaluate(async()=>{
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=new Uint8Array(await(await fetch('/compat/visual/fixture.bdf')).arrayBuffer());
      const picture=bitmap=>{const c=document.createElement('canvas');c.width=bitmap.width;c.height=bitmap.height;c.getContext('2d').drawImage(bitmap,0,0);bitmap.close();return c.toDataURL()};
      const out=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']])for(const action of ['close','replace']){
        const worker=new Worker('/compat/render_worker/instrumented-worker.mjs?worker='+encodeURIComponent(url),{type:'module'});
        const ready=new Promise(resolve=>worker.addEventListener('message',event=>{if(event.data?.type==='test-worker-ready')resolve()}));
        let started;const decoded=new Promise(resolve=>started=resolve);worker.addEventListener('message',event=>{if(event.data?.type==='test-image-decode')started()});
        await ready;const client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker);
        try{
          const manifest=await client.open({kind:'buffer',buffer:bytes.slice().buffer});
          const pending=client.page(manifest.views[0].id,0,1);await decoded;
          if(action==='close')await client.close();else await client.replace({kind:'buffer',buffer:bytes.slice().buffer});
          const first=picture(await pending);
          const second=action==='replace'?picture(await client.page(manifest.views[0].id,0,1)):null;
          out.push({kind,action,first,second});
        }finally{client.terminate()}
      }
      return out;
    });
    for(let i=0;i<2;i++)for(const key of ['first','second']){
      const a=lifecycle[i][key],b=lifecycle[i+2][key];if(a===null){assert.equal(b,null);continue}
      const x=PNG.sync.read(Buffer.from(a.split(',')[1],'base64')),y=PNG.sync.read(Buffer.from(b.split(',')[1],'base64'));
      assert.deepEqual([x.width,x.height],[y.width,y.height]);let changed=0;
      for(let j=0;j<x.data.length;j+=4)if(x.data[j]!==y.data[j]||x.data[j+1]!==y.data[j+1]||x.data[j+2]!==y.data[j+2]||x.data[j+3]!==y.data[j+3])changed++;
      assert.ok(changed/(x.width*x.height)<=0.0005,lifecycle[i].action+' while rendering: '+changed+' pixels differ');
    }
    const multiple=await page.evaluate(async()=>{
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=new Uint8Array(await(await fetch('/compat/render_worker/resource-fixture.bdf')).arrayBuffer());
      const picture=bitmap=>{const c=document.createElement('canvas');c.width=bitmap.width;c.height=bitmap.height;c.getContext('2d').drawImage(bitmap,0,0);bitmap.close();return c.toDataURL()};
      const out=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']])for(const mode of ['lru','fits','hold-fails','hold-fits']){
        const worker=new Worker('/compat/render_worker/instrumented-worker.mjs?worker='+encodeURIComponent(url),{type:'module'});let decodes=0;
        worker.addEventListener('message',event=>{if(event.data?.type==='test-image-decode')decodes++});
        await new Promise(resolve=>worker.addEventListener('message',event=>{if(event.data?.type==='test-worker-ready')resolve()}));
        const client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker),item={kind,mode,images:[],errors:[]};
        try{
          const options=mode==='lru'?{imageBudget:32}:mode==='fits'?{imageBudget:48}:mode==='hold-fails'?{imageBudget:0,holdLimit:31}:{imageBudget:0,holdLimit:32};
          const manifest=await client.open({kind:'buffer',buffer:bytes.slice().buffer},undefined,options),view=manifest.views[0].id;
          const pages=mode==='lru'||mode==='fits'?[0,1,0,2,1]:[3,0];
          for(const index of pages){try{item.images.push(picture(await client.page(view,index,1)))}catch(e){item.errors.push({name:e.name,message:e.message,code:e.code})}}
          item.decodes=decodes;out.push(item);
        }finally{client.terminate()}
      }
      return out;
    });
    const expectedMultiple={lru:4,fits:3,'hold-fails':2,'hold-fits':3};
    for(let i=0;i<4;i++){
      const a=multiple[i],b=multiple[i+4],{kind:_a,images:ai,...x}=a,{kind:_b,images:bi,...y}=b;
      assert.deepEqual(y,x,b.mode+': multiple image cache');
      assert.equal(a.decodes,expectedMultiple[a.mode],a.mode+': decode count');
      assert.deepEqual(bi,ai,b.mode+': multiple image rendering');
    }
    const fonts=await page.evaluate(async()=>{
      const {BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=new Uint8Array(await(await fetch('/compat/visual/fixture.bdf')).arrayBuffer());
      const out=[];
      for(const [kind,url] of [['upstream','/node_modules/@bdfkit/render/dist/worker.js'],['moon','/_build/js/debug/build/render_worker/render_worker.js']]){
        const worker=new Worker('/compat/render_worker/instrumented-worker.mjs?worker='+encodeURIComponent(url),{type:'module'});
        await new Promise(resolve=>worker.addEventListener('message',event=>{if(event.data?.type==='test-worker-ready')resolve()}));
        const stats=()=>new Promise(resolve=>{const listener=event=>{if(event.data?.type==='test-stats'){worker.removeEventListener('message',listener);resolve(event.data.fonts)}};worker.addEventListener('message',listener);worker.postMessage({type:'test-stats'})});
        const client=kind==='upstream'?new BdfWorkerClient(worker):moon.bdf_render_worker_client(worker);
        try{
          const initial=await stats(),manifest=await client.open({kind:'buffer',buffer:bytes.slice().buffer});
          (await client.page(manifest.views[0].id,0,1)).close();const loaded=await stats();
          (await client.page(manifest.views[0].id,0,1)).close();const reused=await stats();
          await client.close();const closed=await stats();out.push({kind,initial,loaded,reused,closed});
        }finally{client.terminate()}
      }
      return out;
    });
    const {kind:_fontA,...fontA}=fonts[0],{kind:_fontB,...fontB}=fonts[1];
    assert.deepEqual(fontB,fontA,'worker font cache lifecycle');
    assert.deepEqual([fontA.initial,fontA.loaded,fontA.reused,fontA.closed],[0,1,1,0],'embedded font cache');
  } finally {await page.close()}
}
