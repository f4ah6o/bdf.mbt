import assert from 'node:assert/strict';

export async function verifyViewerFind(browser,visualBase){
 const page=await browser.newPage();try{
  await page.goto(visualBase+'moon.html',{waitUntil:'networkidle'});
  const results=await page.evaluate(async()=>{
   const {Viewer}=await import('/node_modules/@bdfkit/viewer/dist/index.js'),{BdfWorkerClient}=await import('/node_modules/@bdfkit/render/dist/client.js'),moon=await import('/_build/js/debug/build/browser/browser.js');
   const bytes=new Uint8Array(await(await fetch('/compat/continuous/flow.bdf')).arrayBuffer()),out=[];
   const wait=async fn=>{const start=performance.now();while(!fn()){if(performance.now()-start>7000)throw new Error('find timed out');await new Promise(r=>setTimeout(r,15))}};
   for(const kind of ['upstream','moon']){
    const host=document.createElement('div');host.style.cssText='width:320px;height:240px;position:relative';document.body.append(host);
    const worker=new Worker('/node_modules/@bdfkit/render/dist/worker.js',{type:'module'}),renderer=new BdfWorkerClient(worker),viewer=kind==='upstream'?new Viewer(host,{renderer}):moon.bdf_create_viewer(host,{renderer}),events=[];
    viewer.addEventListener('findchange',event=>events.push(event.detail));
    try{
     await viewer.open({kind:'buffer',buffer:bytes.slice().buffer});await wait(()=>viewer.stage.querySelector('canvas')?.dataset.loaded==='ready');
     const initialBar={shown:host.querySelector('[role=search]').style.display,aria:host.querySelector('input').getAttribute('aria-label')};
     const first=await viewer.find('band'),next=await viewer.find('band'),previous=await viewer.find('band',-1);
     await wait(()=>viewer.stage.querySelectorAll('[data-bdf-hits] div').length>=3);
     const marks=viewer.stage.querySelectorAll('[data-bdf-hits] div').length;
     viewer.openFind();const bar=host.querySelector('[role=search]'),shown=bar.style.display;
     const missing=await viewer.find('no-such-match'),status=host.querySelector('[role=status]').textContent;
     viewer.clearFind();const cleared={shown:bar.style.display,input:host.querySelector('input').value,marks:viewer.stage.querySelectorAll('[data-bdf-hits]').length};
     const nav=navigator,apple=/mac|iphone|ipad|ipod/i.test(nav.userAgentData?.platform||nav.platform||nav.userAgent||'');
     const shortcut=new KeyboardEvent('keydown',{key:'f',code:'KeyF',bubbles:true,cancelable:true,metaKey:apple,ctrlKey:!apple});viewer.stage.dispatchEvent(shortcut);
     const input=host.querySelector('input');input.value='band';input.dispatchEvent(new InputEvent('input',{bubbles:true}));
     await wait(()=>host.querySelector('[role=status]').textContent.startsWith('1 / 3'));
     const typed=host.querySelector('[role=status]').textContent;input.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',bubbles:true,cancelable:true}));
     await wait(()=>host.querySelector('[role=status]').textContent.startsWith('2 / 3'));
     input.dispatchEvent(new KeyboardEvent('keydown',{key:'Escape',bubbles:true,cancelable:true}));
     const keyboard={prevented:shortcut.defaultPrevented,typed,closed:bar.style.display,focus:document.activeElement===viewer.stage};
     out.push({kind,initialBar,first,next,previous,marks,shown,missing,status,cleared,keyboard,events:[...events]});
    }finally{viewer.destroy();renderer.terminate();host.remove()}
   }
   return out;
  });
  const {kind:_a,...a}=results[0],{kind:_b,...b}=results[1];assert.deepEqual(b,a,'viewer search behavior');
  assert.equal(a.first.total,3);assert.equal(a.status,'No matches');assert.ok(a.marks>0);
 }finally{await page.close()}
}
