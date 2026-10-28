import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

function compare(a, b, label) {
  const x=PNG.sync.read(Buffer.from(a.split(',')[1],'base64'));
  const y=PNG.sync.read(Buffer.from(b.split(',')[1],'base64'));
  assert.deepEqual([y.width,y.height],[x.width,x.height],`${label}: bitmap size`);
  assert.deepEqual(y.data,x.data,`${label}: pixels`);
}

export async function verifyPiano(browser, visualBase) {
  for (const dpr of [1,2]) {
    const page=await browser.newPage({viewport:{width:1200,height:700},deviceScaleFactor:dpr});
    await page.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
    const results=await page.evaluate(async()=>{
      const bdf=await import('/_build/js/debug/build/browser/browser.js');
      const {BdfDocument,BufferSource}=await import('@bdfkit/core');
      const {pianoRoll}=await import('/node_modules/@bdfkit/viewer/dist/music.js');
      const bytes=new Uint8Array(await(await fetch('/compat/music/fixtures/ode-mml.bdf')).arrayBuffer());
      const doc=await BdfDocument.open(new BufferSource(bytes)),view=doc.manifest.views[0];
      const host=document.createElement('div'),stage=document.createElement('div');
      host.style.cssText=stage.style.cssText='width:520px;height:400px;overflow:auto';document.body.append(host,stage);
      await bdf.mount_bdf_interactive_async(host,bytes,'single');
      const results=[];
      for(const width of [320,520,900]) for(const zoom of [0.5,1,1.5]){
        host.style.width=stage.style.width=width+'px';
        bdf.bdf_set_zoom(host,zoom);
        await bdf.bdf_set_music_mode_async(host,'piano-roll');
        await pianoRoll({stage,renderer:{play:()=>doc.play(view)},view,zoom,isCurrent:()=>true});
        const actual=host.querySelector('[data-bdf-piano-roll]'),expected=stage.querySelector('canvas');
        results.push({width,zoom,actual:actual.toDataURL(),expected:expected.toDataURL(),aria:actual.getAttribute('aria-label'),expectedAria:expected.getAttribute('aria-label'),css:[actual.style.width,actual.style.height],expectedCss:[expected.style.width,expected.style.height]});
      }
      const search=bdf.bdf_find(host,'a',0).total;
      const old=host.querySelector('[data-bdf-piano-roll]');bdf.bdf_set_zoom(host,0.75);
      await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('piano zoom timed out')),5000);const check=()=>{const c=host.querySelector('[data-bdf-piano-roll]');if(c&&c!==old){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
      await pianoRoll({stage,renderer:{play:()=>doc.play(view)},view,zoom:0.75,isCurrent:()=>true});
      const zoomed=host.querySelector('[data-bdf-piano-roll]').toDataURL(),zoomExpected=stage.querySelector('canvas').toDataURL();
      let independentZoom=true;
      if(devicePixelRatio===1){
        const prior=host.querySelector('[data-bdf-piano-roll]');bdf.bdf_set_zoom(host,6);
        await new Promise((resolve,reject)=>{const timeout=setTimeout(()=>reject(new Error('large piano zoom timed out')),5000);const check=()=>{const c=host.querySelector('[data-bdf-piano-roll]');if(c&&c!==prior){clearTimeout(timeout);resolve()}else requestAnimationFrame(check)};check()});
        independentZoom=!!host.querySelector('[data-bdf-piano-roll]');bdf.bdf_set_zoom(host,0.75);
      }
      await bdf.bdf_set_music_mode_async(host,'score');const restored=host.querySelector('[data-bdf-pages]').style.display===''&&!host.querySelector('[data-bdf-piano-roll]');
      let invalid=false;try{await bdf.bdf_set_music_mode_async(host,'bad')}catch(e){invalid=e instanceof RangeError}
      bdf.unmount_bdf(host);host.remove();stage.remove();
      return {results,search,zoomed,zoomExpected,restored,invalid,independentZoom};
    });
    for(const item of results.results){const label=`piano DPR ${dpr} width ${item.width} zoom ${item.zoom}`;assert.deepEqual(item.css,item.expectedCss,label);assert.equal(item.aria,item.expectedAria,label);compare(item.expected,item.actual,label)}
    compare(results.zoomExpected,results.zoomed,`piano DPR ${dpr} zoom update`);
    assert.equal(results.search,0,'piano roll has no searchable text');assert.ok(results.restored&&results.invalid&&results.independentZoom,'piano zoom is independent of score bitmap limits; score restores and rejects invalid mode');
    await page.close();
  }
  const page=await browser.newPage();await page.goto(`${visualBase}moon.html`,{waitUntil:'networkidle'});
  const split=await page.evaluate(async()=>{
    const bdf=await import('/_build/js/debug/build/browser/browser.js'),{BdfDocument,BufferSource}=await import('@bdfkit/core');
    const bytes=new Uint8Array(await(await fetch('/compat/music/fixtures/ode-mml.bdf')).arrayBuffer()),doc=await BdfDocument.open(new BufferSource(bytes));
    const manifest=doc.manifest,hash=manifest.views[0].play.seq,header=new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength),start=Number(header.getBigUint64(8,true)+header.getBigUint64(16,true));
    let requests=[],release;const blocked=new Promise(resolve=>release=resolve);let hold=false;
    const loader=async h=>{requests.push(h);if(h===hash&&hold)await blocked;const part=manifest.parts.find(p=>p.h===h);return bytes.slice(start+part.off,start+part.off+part.len)};
    const host=document.createElement('div');host.style.cssText='width:520px;height:400px';document.body.append(host);
    await bdf.mount_bdf_split_async(host,new TextEncoder().encode(JSON.stringify(manifest)),loader,'single');
    const lazy=!requests.includes(hash);hold=true;const pending=bdf.bdf_set_music_mode_async(host,'piano-roll');await new Promise(resolve=>setTimeout(resolve,20));const concurrent=bdf.bdf_set_music_mode_async(host,'piano-roll');await bdf.bdf_set_music_mode_async(host,'score');release();await Promise.all([pending,concurrent]);
    const stale=!host.querySelector('[data-bdf-piano-roll]');await bdf.bdf_set_music_mode_async(host,'piano-roll');const loaded=!!host.querySelector('[data-bdf-piano-roll]');
    bdf.unmount_bdf(host);host.remove();
    let resume,started;const gate=new Promise(resolve=>resume=resolve),entered=new Promise(resolve=>started=resolve);
    const detached=document.createElement('div');detached.style.cssText='width:520px;height:400px';document.body.append(detached);
    await bdf.mount_bdf_split_async(detached,new TextEncoder().encode(JSON.stringify(manifest)),async h=>{if(h===hash){started();await gate}return loader(h)},'single');
    const work=bdf.bdf_set_music_mode_async(detached,'piano-roll');await entered;bdf.unmount_bdf(detached);resume();await work;const unmounted=detached.childElementCount===0;detached.remove();
    const failing=document.createElement('div');failing.style.cssText='width:520px;height:400px';document.body.append(failing);let fail=true;
    await bdf.mount_bdf_split_async(failing,new TextEncoder().encode(JSON.stringify(manifest)),async h=>{if(h===hash&&fail)throw new Error('MIDI unavailable');return loader(h)},'single');
    let failed=false;try{await bdf.bdf_set_music_mode_async(failing,'piano-roll')}catch{failed=failing.querySelector('[data-bdf-pages]').style.display==='none'}
    await bdf.bdf_set_music_mode_async(failing,'score');fail=false;await bdf.bdf_set_music_mode_async(failing,'piano-roll');const recovered=!!failing.querySelector('[data-bdf-piano-roll]');bdf.unmount_bdf(failing);failing.remove();
    return {lazy,stale,loaded,unmounted,failed,recovered,requests:requests.filter(h=>h===hash).length};
  });
  assert.ok(split.lazy&&split.stale&&split.loaded&&split.unmounted&&split.failed&&split.recovered,'split MIDI loads lazily, retries failures, and stale draws do not replace score or an unmounted view');assert.equal(split.requests,3,'each split mount fetches its MIDI once');
  await page.close();
}
