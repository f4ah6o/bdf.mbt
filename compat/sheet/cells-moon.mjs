import {mount_bdf_interactive_async,bdf_selection_cells_async} from '/_build/js/debug/build/browser/browser.js';
try{
  const host=document.querySelector('#host'),bytes=new Uint8Array(await(await fetch('./cells.bdf')).arrayBuffer());await mount_bdf_interactive_async(host,bytes,'single');
  const first=[...host.querySelectorAll('span')].find(s=>s.textContent==='Header'),last=[...host.querySelectorAll('span')].find(s=>s.textContent==='End');
  const range=document.createRange();range.setStart(first.firstChild,0);range.setEnd(last.firstChild,last.textContent.length);getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
  window.selectedCells=await bdf_selection_cells_async(host);window.bdfStatus='ready';
}catch(error){window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error)}
