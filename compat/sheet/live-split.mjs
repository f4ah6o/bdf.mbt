import {mount_bdf_split_async} from '/_build/js/debug/build/browser/browser.js';
try{
  const manifest=new Uint8Array(await(await fetch('./split/manifest.json')).arrayBuffer());window.metadata=JSON.parse(new TextDecoder().decode(manifest));window.requests=[];
  const loader=async(hash,limit)=>{window.requests.push(hash);const part=new Uint8Array(await(await fetch(`./split/parts/${hash}`)).arrayBuffer());if(part.length>limit)throw new Error('part exceeds limit');return part};
  await mount_bdf_split_async(document.querySelector('#host'),manifest,loader,'single');window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
