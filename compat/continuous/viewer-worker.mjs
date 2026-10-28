import { Viewer } from '@bdfkit/viewer';
import { BdfWorkerClient } from '/node_modules/@bdfkit/render/dist/client.js';
import { bdf_create_viewer } from '/_build/js/debug/build/browser/browser.js';

try {
  const moon=location.pathname.endsWith('-moon.html'),find=location.pathname.includes('viewer-find-');
  const url=moon?'/_build/js/debug/build/render_worker/render_worker.js':'/node_modules/@bdfkit/render/dist/worker.js';
  const renderer=new BdfWorkerClient(new Worker(url,{type:'module'}));
  const options={renderer,layout:'single',find:find?'focus':false};
  const viewer=moon?bdf_create_viewer(document.querySelector('#host'),options):new Viewer(document.querySelector('#host'),options);
  const buffer=await(await fetch('./flow.bdf')).arrayBuffer();
  await viewer.open({kind:'buffer',buffer});
  await new Promise((resolve,reject)=>{const start=performance.now();const check=()=>{const area=viewer.stage.getBoundingClientRect(),visible=[...viewer.stage.querySelectorAll('[data-bdf-page]')].filter(frame=>{const r=frame.getBoundingClientRect();return r.bottom>area.top&&r.top<area.bottom});if(visible.length&&visible.every(frame=>frame.querySelector('canvas').dataset.loaded==='ready'))resolve();else if(performance.now()-start>7000)reject(new Error('visible pages did not render'));else requestAnimationFrame(check)};check()});
  if(find){viewer.openFind();const input=viewer.surface.querySelector('input');input.value='band';input.dispatchEvent(new InputEvent('input',{bubbles:true}));await new Promise((resolve,reject)=>{const start=performance.now();const check=()=>{if(viewer.surface.querySelector('[role=status]')?.textContent.startsWith('1 / 3')&&viewer.stage.querySelectorAll('[data-bdf-hits] div').length>=3)resolve();else if(performance.now()-start>7000)reject(new Error('search marks did not render'));else requestAnimationFrame(check)};check()});viewer.stage.focus({preventScroll:true})}
  window.viewer=viewer;window.bdfStatus='ready';
} catch(error) {window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
