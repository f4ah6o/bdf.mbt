import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

function compare(expected,actual,label){
  const a=PNG.sync.read(Buffer.from(expected.split(',')[1],'base64')),b=PNG.sync.read(Buffer.from(actual.split(',')[1],'base64'));
  assert.deepEqual([b.width,b.height],[a.width,a.height],`${label}: bitmap size`);
  let changed=0;for(let i=0;i<a.data.length;i+=4)if(a.data[i]!==b.data[i]||a.data[i+1]!==b.data[i+1]||a.data[i+2]!==b.data[i+2]||a.data[i+3]!==b.data[i+3])changed++;
  assert.ok(changed/(a.width*a.height)<=0.0005,`${label}: ${changed} pixels differ`);
}

export async function verifySheetZoom(browser,base){
  for(const dpr of [1,2]){
    const snapshots={};
    for(const name of ['baseline','moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:dpr}),errors=[];page.on('pageerror',error=>errors.push(String(error)));
      await page.goto(`${base}zoom-${name}.html`,{waitUntil:'networkidle'});await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);snapshots[name]=[];
      for(const zoom of [1.5,0.5,1,2,1.25]){
        if(zoom!==1.5){await page.evaluate(async({name,zoom})=>{const h=document.querySelector('#host');if(name==='baseline')window.viewer.setZoom(zoom);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_set_zoom(h,zoom)},{name,zoom});}
        if(name==='baseline')await page.waitForFunction(()=>{const stage=window.viewer.stage,canvas=stage.querySelector('canvas');return canvas?.width===Math.ceil(stage.clientWidth*devicePixelRatio)&&canvas?.height===Math.ceil(stage.clientHeight*devicePixelRatio)});
        else await page.waitForFunction(zoom=>document.querySelector('#host canvas')?.dataset.bdfSheetZoom===String(zoom),zoom);
        snapshots[name].push(await page.evaluate(name=>{const host=name==='baseline'?window.viewer.stage:document.querySelector('#host'),canvas=host.querySelector('canvas');return{scroll:[host.scrollLeft,host.scrollTop,host.scrollWidth,host.scrollHeight],image:canvas.toDataURL()}},name));
      }
      const before=await page.evaluate(name=>name==='baseline'?window.sheetCalls:Number(document.querySelector('#host canvas').dataset.bdfSheetFrame),name);
      await page.evaluate(name=>{const host=name==='baseline'?window.viewer.stage:document.querySelector('#host');host.scrollTo(150,100)},name);
      if(name==='baseline')await page.waitForFunction(before=>window.sheetCalls>before,before);
      else await page.waitForFunction(before=>Number(document.querySelector('#host canvas').dataset.bdfSheetFrame)>before,before);
      await page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve))));
      snapshots[name].scrolled=await page.evaluate(name=>{const host=name==='baseline'?window.viewer.stage:document.querySelector('#host'),canvas=host.querySelector('canvas');return{scroll:[host.scrollLeft,host.scrollTop,host.scrollWidth,host.scrollHeight],image:canvas.toDataURL()}},name);
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.setZoom(2);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_set_zoom(host,2)},name);
      if(name==='baseline')await page.waitForFunction(()=>{const stage=window.viewer.stage,canvas=stage.querySelector('canvas');return canvas?.width===Math.ceil(stage.clientWidth*devicePixelRatio)&&canvas?.height===Math.ceil(stage.clientHeight*devicePixelRatio)});
      else await page.waitForFunction(()=>document.querySelector('#host canvas')?.dataset.bdfSheetZoom==='2');
      snapshots[name].scrolledZoom=await page.evaluate(name=>{const host=name==='baseline'?window.viewer.stage:document.querySelector('#host'),canvas=host.querySelector('canvas');return{scroll:[host.scrollLeft,host.scrollTop,host.scrollWidth,host.scrollHeight],image:canvas.toDataURL()}},name);
      assert.deepEqual(errors,[],`${name}: browser errors`);await page.close();
    }
    for(let i=0;i<snapshots.baseline.length;i++){
      assert.deepEqual(snapshots.moon[i].scroll,snapshots.baseline[i].scroll,`DPR ${dpr}: sheet extent after zoom ${i}`);
      compare(snapshots.baseline[i].image,snapshots.moon[i].image,`DPR ${dpr}: sheet zoom ${i}`);
    }
    assert.deepEqual(snapshots.moon.scrolled.scroll,snapshots.baseline.scrolled.scroll,`DPR ${dpr}: scrolled sheet extent`);
    compare(snapshots.baseline.scrolled.image,snapshots.moon.scrolled.image,`DPR ${dpr}: scrolled zoomed sheet`);
    assert.deepEqual(snapshots.moon.scrolledZoom.scroll,snapshots.baseline.scrolledZoom.scroll,`DPR ${dpr}: changing zoom while scrolled`);
    compare(snapshots.baseline.scrolledZoom.image,snapshots.moon.scrolledZoom.image,`DPR ${dpr}: zoom changed while scrolled`);
  }

  const page=await browser.newPage({viewport:{width:1280,height:720}});await page.goto(`${base}live-moon.html`,{waitUntil:'networkidle'});
  const results=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async path=>new Uint8Array(await(await fetch(path)).arrayBuffer());
    const single=await read('fixture.bdf'),manifest=await read('split/manifest.json'),encrypted=await read('encrypted.bdf'),locked=await read('encrypted-split/manifest.json'),results=[];
    for(const [name,mount] of [
      ['single',h=>bdf.mount_bdf_interactive_async(h,single,'single')],
      ['split',h=>bdf.mount_bdf_interactive_split_async(h,manifest,hash=>read(`split/parts/${hash}`),'single')],
      ['encrypted',h=>bdf.mount_bdf_interactive_encrypted_async(h,encrypted,'pass','single')],
      ['encrypted-split',h=>bdf.mount_bdf_interactive_encrypted_split_async(h,locked,hash=>read(`encrypted-split/parts/${hash}`),'pass','single')],
    ]){
      const host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);await mount(host);
      const first=host.querySelector('[data-bdf-sheet-tile="0,0"] span'),second=host.querySelector('[data-bdf-sheet-tile="1,0"] span'),range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(second.firstChild,second.textContent.length);getSelection().removeAllRanges();getSelection().addRange(range);
      const selected=bdf.bdf_selection_text(host),found=await bdf.bdf_find_async(host,'Tile',0),beforeRect=first.getBoundingClientRect(),beforeHost=host.getBoundingClientRect(),beforeHit=found.rects.find(r=>r.page===0),beforeFrame=Number(host.querySelector('canvas').dataset.bdfSheetFrame);let events=0;host.addEventListener('findchange',()=>events++);
      bdf.bdf_set_zoom(host,2);await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('interactive sheet zoom timeout')),5000);const check=()=>{const c=host.querySelector('canvas');if(Number(c.dataset.bdfSheetFrame)>beforeFrame&&c.dataset.bdfSheetZoom==='2'){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const afterRect=first.getBoundingClientRect(),afterHost=host.getBoundingClientRect(),selectedAfter=bdf.bdf_selection_text(host),after=await bdf.bdf_find_async(host,'Tile',0),afterHit=after.rects.find(r=>r.page===0),point=document.elementFromPoint(afterRect.x+afterRect.width/2,afterRect.y+afterRect.height/2);
      const copy=new ClipboardEvent('copy',{bubbles:true,cancelable:true,clipboardData:new DataTransfer()});host.dispatchEvent(copy);const oldFrame=host.querySelector('canvas').dataset.bdfSheetFrame;let invalid=0;for(const z of [0,-1,NaN,Infinity,9])try{bdf.bdf_set_zoom(host,z)}catch(e){if(e instanceof RangeError&&host.querySelector('canvas').dataset.bdfSheetFrame===oldFrame)invalid++}
      const extents=[];for(const zoom of [0.5,1,2]){bdf.bdf_set_zoom(host,zoom);await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet extent timeout')),5000);const check=()=>{if(host.querySelector('canvas')?.dataset.bdfSheetZoom===String(zoom)){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});extents.push([host.scrollWidth,host.scrollHeight])}
      const prior=Number(host.querySelector('canvas').dataset.bdfSheetFrame);bdf.bdf_set_layout(host,'spread');await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('sheet layout timeout')),5000);const check=()=>{if(Number(host.querySelector('canvas').dataset.bdfSheetFrame)>prior){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      const layoutPreserved=host.querySelector('canvas').dataset.bdfSheetZoom==='2'&&bdf.bdf_selection_text(host)===selected;
      results.push({name,selected,selectedAfter,copied:copy.clipboardData.getData('text/plain'),beforeX:beforeRect.x-beforeHost.x,afterX:afterRect.x-afterHost.x,beforeWidth:beforeRect.width,afterWidth:afterRect.width,beforeHit:beforeHit&&[beforeHit.x,beforeHit.y,beforeHit.w,beforeHit.h],afterHit:afterHit&&[afterHit.x,afterHit.y,afterHit.w,afterHit.h],found:found.total,after:after.total,events,invalid,point:point===first,extents,layoutPreserved});
      getSelection().removeAllRanges();bdf.unmount_bdf(host);host.remove();
    }return results;
  });
  for(const r of results){
    assert.equal(r.selected,'Tile 0,0\nTile 1,0',`${r.name}: selection before zoom`);assert.equal(r.selectedAfter,r.selected,`${r.name}: selection survives zoom`);assert.equal(r.copied,r.selected,`${r.name}: copy after zoom`);
    assert.ok(Math.abs(r.afterX-r.beforeX*2)<1&&Math.abs(r.afterWidth-r.beforeWidth*2)<1,`${r.name}: text geometry scales`);
    assert.ok(r.beforeHit&&r.afterHit&&r.beforeHit.every((v,i)=>Math.abs(r.afterHit[i]-v*2)<1),`${r.name}: search geometry scales`);
    assert.equal(r.found,6,`${r.name}: matches before zoom`);assert.equal(r.after,6,`${r.name}: matches after zoom`);assert.equal(r.events,1,`${r.name}: zoom does not emit a search event`);assert.equal(r.invalid,5,`${r.name}: invalid zoom rejected`);assert.equal(r.point,true,`${r.name}: zoomed text is selectable`);
    assert.deepEqual(r.extents,[[400,300],[648,504],[1296,1008]],`${r.name}: previously visited tile layers do not enlarge the sheet`);
    assert.equal(r.layoutPreserved,true,`${r.name}: changing layout leaves the sheet zoom and selection intact`);
  }
  const race=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async path=>new Uint8Array(await(await fetch(path)).arrayBuffer()),manifest=await read('split/manifest.json'),metadata=JSON.parse(new TextDecoder().decode(manifest)),delayed=metadata.views[0].tiles['2,0'];
    let start,release;const started=new Promise(resolve=>start=resolve),gate=new Promise(resolve=>release=resolve),host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);
    await bdf.mount_bdf_split_async(host,manifest,async hash=>{if(hash===delayed){start();await gate}return read(`split/parts/${hash}`)},'single');
    const canvas=host.querySelector('canvas'),frame=Number(canvas.dataset.bdfSheetFrame),updates=[],observer=new MutationObserver(()=>updates.push(canvas.dataset.bdfSheetZoom));observer.observe(canvas,{attributes:true,attributeFilter:['data-bdf-sheet-zoom']});
    bdf.bdf_set_zoom(host,0.5);await started;bdf.bdf_set_zoom(host,2);release();
    await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('superseded sheet zoom timeout')),5000);const check=()=>{if(Number(canvas.dataset.bdfSheetFrame)>frame&&canvas.dataset.bdfSheetZoom==='2'){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
    observer.disconnect();bdf.unmount_bdf(host);host.remove();return updates;
  });
  assert.ok(race.length>0&&race.every(z=>z==='2'),'a slow superseded zoom never publishes a stale frame');
  const searchRace=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async path=>new Uint8Array(await(await fetch(path)).arrayBuffer()),metadata=JSON.parse(new TextDecoder().decode(await read('split/manifest.json'))),hash='11111111111111111111111111111111';
    const a=new TextEncoder().encode('Tile 2,0'),b=new TextEncoder().encode('Tile 2,1'),index=new Uint8Array([66,84,88,84,1,0,2,2,0,0,2,a.length,...a,2,1,0,2,b.length,...b]);metadata.views[0].textIndex=hash;metadata.parts.push({h:hash,t:'idx',enc:'identity',len:index.length,size:index.length,off:0});
    let start,release;const started=new Promise(resolve=>start=resolve),gate=new Promise(resolve=>release=resolve),host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);
    await bdf.mount_bdf_interactive_split_async(host,new TextEncoder().encode(JSON.stringify(metadata)),async part=>{if(part===hash){start();await gate;return index}return read(`split/parts/${part}`)},'single');
    bdf.bdf_set_zoom(host,2);let events=0;host.addEventListener('findchange',()=>events++);const pending=bdf.bdf_find_async(host,'Tile',0);await started;bdf.bdf_set_zoom(host,0.5);release();const found=await pending;
    await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('search did not refresh after zoom')),5000);const check=()=>{if(host.querySelectorAll('[data-bdf-hit]').length===2){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
    const answer={total:found.total,marks:host.querySelectorAll('[data-bdf-hit]').length,events};bdf.unmount_bdf(host);host.remove();return answer;
  });
  assert.deepEqual(searchRace,{total:2,marks:2,events:1},'an in-flight first search refreshes newly visible hits after zoom');
  const emptyAxes=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),read=async path=>new Uint8Array(await(await fetch(path)).arrayBuffer()),metadata=JSON.parse(new TextDecoder().decode(await read('split/manifest.json')));metadata.views[0].cols=[];metadata.views[0].rows=[];
    const host=document.createElement('div');host.style.cssText='width:400px;height:300px';document.body.append(host);await bdf.mount_bdf_interactive_split_async(host,new TextEncoder().encode(JSON.stringify(metadata)),hash=>read(`split/parts/${hash}`),'single');
    bdf.bdf_set_zoom(host,2);await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('empty-axis sheet timeout')),5000);const check=()=>{if(host.querySelector('canvas')?.dataset.bdfSheetZoom==='2'){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
    const span=host.querySelector('[data-bdf-sheet-tile="0,0"] span'),rect=span.getBoundingClientRect(),point=document.elementFromPoint(rect.x+rect.width/2,rect.y+rect.height/2),result={extent:[host.scrollWidth,host.scrollHeight],visible:point===span};bdf.unmount_bdf(host);host.remove();
    metadata.views[0].tiles={};const blank=document.createElement('div');blank.style.cssText='width:400px;height:300px';document.body.append(blank);await bdf.mount_bdf_interactive_split_async(blank,new TextEncoder().encode(JSON.stringify(metadata)),hash=>read(`split/parts/${hash}`),'single');const box=blank.getBoundingClientRect();result.canvasClickable=document.elementFromPoint(box.x+200,box.y+150)===blank.querySelector('canvas');bdf.unmount_bdf(blank);blank.remove();return result;
  });
  assert.deepEqual(emptyAxes,{extent:[400,300],visible:true,canvasClickable:true},'empty sheet areas remain clickable and visible tile text stays selectable');
  await page.close();

  const drag=await browser.newPage({viewport:{width:1280,height:720}});await drag.goto(`${base}cells-moon.html`,{waitUntil:'networkidle'});await drag.waitForFunction(()=>window.bdfStatus==='ready');
  const expected=await drag.evaluate(()=>window.selectedCells);
  await drag.evaluate(async()=>{const bdf=await import('/_build/js/debug/build/browser/browser.js');bdf.bdf_set_zoom(document.querySelector('#host'),0.75);getSelection().removeAllRanges();document.dispatchEvent(new Event('selectionchange'))});
  await drag.waitForFunction(()=>document.querySelector('#host canvas')?.dataset.bdfSheetZoom==='0.75');
  const boxes=await drag.evaluate(()=>['Header','End'].map(text=>{const el=[...document.querySelectorAll('[data-bdf-ordinal]')].find(s=>s.textContent===text),r=el.getBoundingClientRect();return{x:r.x,y:r.y,w:r.width,h:r.height}}));
  await drag.mouse.move(boxes[0].x+2,boxes[0].y+boxes[0].h/2);await drag.mouse.down();await drag.mouse.move(boxes[1].x+boxes[1].w-2,boxes[1].y+boxes[1].h/2,{steps:20});await drag.mouse.up();
  const selectedCells=await drag.evaluate(async()=>{const bdf=await import('/_build/js/debug/build/browser/browser.js');return bdf.bdf_selection_cells_async(document.querySelector('#host'))});
  assert.deepEqual(selectedCells,expected,'dragging across zoomed sheet tiles selects the correct cells');await drag.close();
}
