import assert from 'node:assert/strict';
import { mkdirSync, writeFileSync } from 'node:fs';
import { PNG } from 'pngjs';

function compareImages(expected, actual, label) {
  const a=PNG.sync.read(Buffer.from(expected.split(',')[1],'base64'));
  const b=PNG.sync.read(Buffer.from(actual.split(',')[1],'base64'));
  assert.deepEqual([b.width,b.height],[a.width,a.height],`${label}: bitmap dimensions`);
  let changed=0;for(let i=0;i<a.data.length;i+=4)if(a.data[i]!==b.data[i]||a.data[i+1]!==b.data[i+1]||a.data[i+2]!==b.data[i+2]||a.data[i+3]!==b.data[i+3])changed++;
  if(changed/(a.width*a.height)>0.0005){mkdirSync('_build/visual-diff/controls-failure',{recursive:true});writeFileSync('_build/visual-diff/controls-failure/reference.png',PNG.sync.write(a));writeFileSync('_build/visual-diff/controls-failure/actual.png',PNG.sync.write(b));}
  assert.ok(changed/(a.width*a.height)<=0.0005,`${label}: ${changed} pixels differ`);
}

export async function verifyPageControls(browser, continuousBase, interactiveBase, visualBase) {
  const scenarios=[['single',1.25],['spread',0.5],['continuous',1.5],['spread',2],['single',1]];
  for(const dpr of [1,2]){
    const snapshots={};
    for(const name of ['baseline','moon']){
      const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:dpr});
      await page.goto(`${continuousBase}spread-${name}.html`,{waitUntil:'networkidle'});
      await page.waitForFunction(()=>window.bdfStatus==='ready'||window.bdfStatus==='error');
      assert.equal(await page.evaluate(()=>window.bdfStatus),'ready',`${name}: ${await page.evaluate(()=>window.bdfError)}`);
      snapshots[name]=[];
      for(const [layout,zoom] of scenarios){
        await page.evaluate(async({name,layout,zoom})=>{const host=document.querySelector('#host');if(name==='baseline'){window.viewer.setLayout(layout);window.viewer.setZoom(zoom);window.viewer.stage.scrollTo(0,0)}else{const bdf=await import('/_build/js/debug/build/browser/browser.js');bdf.bdf_set_layout(host,layout);bdf.bdf_set_zoom(host,zoom);host.scrollTo(0,0)}},{name,layout,zoom});
        if(name==='baseline')await page.waitForFunction(()=>[...document.querySelectorAll('#host canvas')].every(c=>c.dataset.loaded==='ready'));
        snapshots[name].push(await page.evaluate(()=>{const host=document.querySelector('#host'),origin=host.getBoundingClientRect();return [...host.querySelectorAll('canvas')].map(c=>{const r=c.getBoundingClientRect();return{geometry:[r.x-origin.x,r.y-origin.y,r.width,r.height],bitmap:[c.width,c.height],image:c.toDataURL()}})}));
      }
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.scrollToPage(1);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_scroll_to_page(host,1) },name);
      snapshots[name].scroll=await page.evaluate(name=>name==='baseline'?window.viewer.stage.scrollTop:document.querySelector('#host').scrollTop,name);
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.scrollToPage(2);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_scroll_to_page(host,2)},name);
      snapshots[name].lastScroll=await page.evaluate(name=>name==='baseline'?window.viewer.stage.scrollTop:document.querySelector('#host').scrollTop,name);
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.setZoom(1.25);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_set_zoom(host,1.25)},name);
      snapshots[name].zoomScroll=await page.evaluate(name=>name==='baseline'?window.viewer.stage.scrollTop:document.querySelector('#host').scrollTop,name);
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.scrollToPage(1);else(await import('/_build/js/debug/build/browser/browser.js')).bdf_scroll_to_page(host,1)},name);
      await page.evaluate(async name=>{const host=document.querySelector('#host');if(name==='baseline')window.viewer.setLayout('spread');else(await import('/_build/js/debug/build/browser/browser.js')).bdf_set_layout(host,'spread')},name);
      snapshots[name].layoutScroll=await page.evaluate(name=>name==='baseline'?window.viewer.stage.scrollTop:document.querySelector('#host').scrollTop,name);
      await page.close();
    }
    for(let i=0;i<scenarios.length;i++)for(let j=0;j<3;j++){
      const expected=snapshots.baseline[i][j],actual=snapshots.moon[i][j],label=`DPR ${dpr} ${scenarios[i]} page ${j}`;
      assert.deepEqual(actual.geometry,expected.geometry,`${label}: geometry`);
      assert.deepEqual(actual.bitmap,expected.bitmap,`${label}: bitmap`);
      compareImages(expected.image,actual.image,label);
    }
    assert.equal(snapshots.moon.scroll,snapshots.baseline.scroll,`DPR ${dpr}: scroll to page`);
    assert.equal(snapshots.moon.lastScroll,snapshots.baseline.lastScroll,`DPR ${dpr}: scroll to the final page`);
    assert.equal(snapshots.moon.zoomScroll,snapshots.baseline.zoomScroll,`DPR ${dpr}: zoom after scrolling`);
    assert.equal(snapshots.moon.layoutScroll,snapshots.baseline.layoutScroll,`DPR ${dpr}: layout after scrolling`);
  }

  const interactive=await browser.newPage({viewport:{width:1280,height:720}});
  await interactive.goto(`${interactiveBase}moon.html`,{waitUntil:'networkidle'});
  const state=await interactive.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer()),host=document.createElement('div');
    host.style.cssText='width:900px;height:300px';document.body.append(host);await bdf.mount_bdf_interactive_async(host,bytes,'single');
    const span=host.querySelector('[data-bdf-ordinal]'),range=document.createRange();range.setStart(span.firstChild,0);range.setEnd(span.firstChild,3);getSelection().removeAllRanges();getSelection().addRange(range);
    let events=0;host.addEventListener('findchange',()=>events++);const before=bdf.bdf_find(host,'page',0),canvas=host.querySelector('canvas'),x=span.getBoundingClientRect().x-canvas.getBoundingClientRect().x,selected=getSelection().toString();
    bdf.bdf_set_zoom(host,1.5);const zoomedCanvas=host.querySelector('canvas'),scaled=span.getBoundingClientRect().x-zoomedCanvas.getBoundingClientRect().x,selectedAfter=getSelection().toString(),highlight=host.querySelector('[data-bdf-hit]');
    const after=bdf.bdf_find(host,'page',0),oldCanvas=host.querySelector('canvas');let invalid=0;
    for(const n of [0,-1,NaN,Infinity,9])try{bdf.bdf_set_zoom(host,n)}catch(e){if(e instanceof RangeError&&host.querySelector('canvas')===oldCanvas)invalid++}
    bdf.bdf_set_layout(host,'spread');const survived=host.querySelector('[data-bdf-ordinal]')===span&&getSelection().toString()===selected;
    bdf.unmount_bdf(host);let unmounted=false;try{bdf.bdf_set_zoom(host,1)}catch{unmounted=true}host.remove();return {x,scaled,selected,selectedAfter,highlight:!!highlight,before:before.total,after:after.total,events,invalid,survived,unmounted};
  });
  assert.ok(Math.abs(state.scaled-state.x*1.5)<1,'text selection geometry follows zoom');
  assert.equal(state.selectedAfter,state.selected,'zoom preserves the active text selection');
  assert.ok(state.highlight&&state.before>0&&state.after===state.before,'zoom preserves search highlights and matches');
  assert.equal(state.events,2,'zoom does not emit a spurious search event');
  assert.equal(state.invalid,5,'invalid zooms leave the rendered pages unchanged');
  assert.ok(state.survived&&state.unmounted,'layout preserves text selection and unmount disables controls');
  await interactive.close();

  const rich=await browser.newPage({viewport:{width:1280,height:720}});
  await rich.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
  const images=await rich.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),{BdfDocument,BufferSource}=await import('@bdfkit/core'),{PageRenderer}=await import('@bdfkit/render');
    const bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),renderer=new PageRenderer(doc),host=document.createElement('div');host.style.cssText='width:800px;height:600px';document.body.append(host);
    const countFonts=()=>[...document.fonts].filter(f=>f.family.startsWith('bdf-')).length,initial=countFonts(),oldClose=ImageBitmap.prototype.close;let closed=0;ImageBitmap.prototype.close=function(){closed++;return oldClose.call(this)};
    try{await bdf.mount_bdf_async(host,bytes,'single');const retained=countFonts()===initial+1,results=[];
      for(const scale of [1.5,0.75]){bdf.bdf_set_zoom(host,scale);const actual=host.querySelector('canvas').toDataURL(),canvas=document.createElement('canvas');canvas.width=Math.ceil(640*scale);canvas.height=Math.ceil(600*scale);await renderer.renderPage(canvas.getContext('2d'),doc.manifest.views[0].pages[0],{scale});results.push({scale,actual,expected:canvas.toDataURL()})}
      const old=host.querySelector('canvas');let oversized=false;try{bdf.bdf_set_zoom(host,8)}catch{oversized=host.querySelector('canvas')===old}
      renderer.dispose();const closedBeforeUnmount=closed;bdf.unmount_bdf(host);return {results,retained,released:countFonts()===initial,closed:closed-closedBeforeUnmount,oversized};
    }finally{ImageBitmap.prototype.close=oldClose;renderer.dispose();host.remove()}
  });
  for(const item of images.results)compareImages(item.expected,item.actual,`embedded image and font at ${item.scale}`);
  assert.ok(images.retained&&images.released&&images.closed>0,'page image and font resources live until unmount');
  assert.ok(images.oversized,'oversized zoom leaves the previous rendering intact');
  await rich.close();

  for(const dpr of [1,2]){
    const page=await browser.newPage({viewport:{width:1280,height:720},deviceScaleFactor:dpr});await page.goto(`${continuousBase}spread-baseline.html`,{waitUntil:'networkidle'});
    const variants=await page.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js'),{BdfDocument,BufferSource}=await import('@bdfkit/core'),{PageRenderer}=await import('@bdfkit/render');
      const bytes=new Uint8Array(await(await fetch('./svg.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes)),renderer=new PageRenderer(doc),host=document.createElement('div');host.style.cssText='width:300px;height:200px';document.body.append(host);
      try{await bdf.mount_bdf_async(host,bytes,'single');const result=[];for(const zoom of [1,0.75,2,1.3]){if(zoom!==1)bdf.bdf_set_zoom(host,zoom);const canvas=document.createElement('canvas'),scale=zoom*devicePixelRatio;canvas.width=Math.ceil(240*scale);canvas.height=Math.ceil(180*scale);await renderer.renderPage(canvas.getContext('2d'),doc.manifest.views[0].pages[0],{scale});result.push({zoom,expected:canvas.toDataURL(),actual:host.querySelector('canvas').toDataURL()})}return result}
      finally{renderer.dispose();bdf.unmount_bdf(host);host.remove()}
    });
    for(const item of variants)compareImages(item.expected,item.actual,`SVG image, source rectangle and pattern at DPR ${dpr}, zoom ${item.zoom}`);
    await page.close();
  }
}
