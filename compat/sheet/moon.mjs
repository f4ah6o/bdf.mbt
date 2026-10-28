import {render_bdf_sheet_region_async} from '/_build/js/debug/build/browser/browser.js';
try {
  const bytes=new Uint8Array(await(await fetch('./fixture.bdf')).arrayBuffer()),host=document.querySelector('#host');
  window.renderRegion=(x,y,w,h,scale)=>render_bdf_sheet_region_async(host,bytes,x,y,w,h,scale);
  await window.renderRegion(0,0,400,300,1);window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
