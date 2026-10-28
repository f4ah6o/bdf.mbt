import assert from 'node:assert/strict';
import { PNG } from 'pngjs';

export async function verifyViewerApi(browser, visualBase) {
  const page=await browser.newPage({viewport:{width:1000,height:700}});
  try {
    await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
    const result=await page.evaluate(async()=>{
      const {BdfDocument,BufferSource}=await import('/node_modules/@bdfkit/core/dist/index.js');
      const {PageRenderer}=await import('/node_modules/@bdfkit/render/dist/index.js');
      const {Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js');
      const moon=await import('/_build/js/debug/build/browser/browser.js');
      const bytes=new Uint8Array(await(await fetch('/compat/continuous/scroll.bdf')).arrayBuffer());
      const wait=async(fn)=>{const start=performance.now();while(!fn()){if(performance.now()-start>7000)throw new Error('viewer timed out');await new Promise(r=>requestAnimationFrame(r))}};
      const out=[];
      for(const kind of ['upstream','moon']){
        const doc=await BdfDocument.open(new BufferSource(bytes)),pages=new PageRenderer(doc),calls=[],host=document.createElement('div');
        host.style.cssText='width:200px;height:200px;position:relative';document.body.append(host);
        const renderer={close:async()=>calls.push('close'),open:async()=>{calls.push('open');return structuredClone(doc.manifest)},page:async(_id,index,scale)=>{calls.push('page '+index);const p=doc.manifest.views[0].pages[index],c=document.createElement('canvas');c.width=Math.ceil(p.w*scale);c.height=Math.ceil(p.h*scale);await pages.renderPage(c.getContext('2d'),p,{scale});return createImageBitmap(c)},terminate:()=>calls.push('terminate')};
        const options={renderer,layout:'spread',find:false},viewer=kind==='upstream'?new Viewer(host,options):new moon.Viewer(host,options),events=[];
        viewer.addEventListener('viewchange',e=>events.push(['viewchange',e.detail.id]));viewer.addEventListener('documentchange',e=>events.push(['documentchange',e.detail.views[0].id]));
        await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});
        await wait(()=>viewer.stage.querySelectorAll('canvas').length===3&&[...viewer.stage.querySelectorAll('canvas')].every(c=>c.dataset.loaded==='ready'));
        const snapshot=()=>({layout:viewer.pageLayout,view:viewer.view?.id,document:viewer.document?.views[0].id,background:viewer.stage.style.background,role:viewer.stage.getAttribute('role'),label:viewer.stage.getAttribute('aria-label'),frames:[...viewer.stage.querySelectorAll('[data-bdf-page]')].map(e=>({index:e.dataset.bdfPage,style:e.style.cssText,canvas:e.querySelector('canvas').toDataURL()})),scrollHeight:viewer.stage.scrollHeight,scrollWidth:viewer.stage.scrollWidth});
        const initial=snapshot();viewer.setZoom(1.5);
        await wait(()=>[...viewer.stage.querySelectorAll('canvas')].every(c=>c.dataset.loaded==='ready'));
        const zoomed=snapshot();viewer.setLayout('single');
        await wait(()=>[...viewer.stage.querySelectorAll('canvas')].every(c=>c.dataset.loaded==='ready'));
        const single=snapshot();let invalid;try{viewer.setZoom(0)}catch(e){invalid={name:e.name,message:e.message}}
        viewer.setView('missing');const missing={view:viewer.view,children:viewer.stage.children.length};viewer.setView(doc.manifest.views[0].id);
        await wait(()=>[...viewer.stage.querySelectorAll('canvas')].length===3&&[...viewer.stage.querySelectorAll('canvas')].every(c=>c.dataset.loaded==='ready'));
        const constructor=kind==='upstream'?Viewer:moon.Viewer,isTarget=viewer instanceof EventTarget,isViewer=viewer instanceof constructor,prototypeMethod=typeof constructor.prototype.open,ownOpen=Object.hasOwn(viewer,'open'),wasConnected=viewer.surface.isConnected;viewer.destroy();
        out.push({kind,initial,zoomed,single,invalid,missing,events,isTarget,isViewer,prototypeMethod,ownOpen,wasConnected,removed:!host.contains(viewer.surface),terminated:calls.includes('terminate')});
        pages.dispose();host.remove();
      }
      for(const kind of ['upstream','moon']){
        const host=document.createElement('div');document.body.append(host);const renderer={terminate(){throw new Error('external renderer terminated')}};
        const options={renderer,mode:'lightbox',find:false};const v=kind==='upstream'?new Viewer(host,options):moon.bdf_create_viewer(host,options);
        const hidden=v.surface.style.display;v.show();const shown=v.surface.style.display;v.hide();const rehidden=v.surface.style.display;v.destroy();host.remove();
        out.push({kind,hidden,shown,rehidden});
      }
      for(const kind of ['upstream','moon']){
        const host=document.createElement('div');host.style.cssText='width:200px;height:200px';document.body.append(host);
        const viewer=kind==='upstream'?new Viewer(host,{find:false}):moon.bdf_create_viewer(host,{find:false});
        try{const manifest=await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});await wait(()=>viewer.stage.querySelector('canvas')?.dataset.loaded==='ready');out.push({kind,defaultWorker:manifest.views[0].id,rendered:viewer.stage.querySelector('canvas').width>0})}
        finally{viewer.destroy();host.remove()}
      }
      return out;
    });
    const [a,b,c,d,e,f]=result;
    const withoutImages=item=>{const {kind,...rest}=structuredClone(item);for(const key of ['initial','zoomed','single'])for(const frame of rest[key].frames)delete frame.canvas;return rest};
    assert.deepEqual(withoutImages(b),withoutImages(a),'viewer control and lifecycle');
    for(const key of ['initial','zoomed','single'])for(let i=0;i<a[key].frames.length;i++){
      const x=PNG.sync.read(Buffer.from(a[key].frames[i].canvas.split(',')[1],'base64')),y=PNG.sync.read(Buffer.from(b[key].frames[i].canvas.split(',')[1],'base64'));
      assert.deepEqual([x.width,x.height],[y.width,y.height]);assert.deepEqual(x.data,y.data,key+' page '+i);
    }
    assert.deepEqual({...d,kind:undefined},{...c,kind:undefined},'lightbox controls');
    assert.deepEqual({...f,kind:undefined},{...e,kind:undefined},'owned Worker');
  } finally {await page.close()}
}
