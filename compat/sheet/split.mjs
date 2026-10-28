import {render_bdf_sheet_region_split_async} from '/_build/js/debug/build/browser/browser.js';
try {
  const manifest=new Uint8Array(await(await fetch('./split/manifest.json')).arrayBuffer()),host=document.querySelector('#host');
  window.requests=[];
  const loader=async(hash,limit)=>{window.requests.push(hash);const bytes=new Uint8Array(await(await fetch(`./split/parts/${hash}`)).arrayBuffer());if(bytes.length>limit)throw new Error('part exceeds limit');return bytes};
  window.renderRegion=(x,y,w,h,scale)=>{window.requests=[];return render_bdf_sheet_region_split_async(host,manifest,loader,x,y,w,h,scale)};
  await window.renderRegion(0,0,400,300,1);window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
