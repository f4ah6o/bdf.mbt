import { mount_bdf_interactive_async, bdf_selection_text, bdf_selection_cells } from '/_build/js/debug/build/browser/browser.js';
try {
  const bytes = new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const host = document.querySelector('#host');
  await mount_bdf_interactive_async(host, bytes, 'single');
  window.readSelection = () => bdf_selection_text(host);
  window.readCells = () => bdf_selection_cells(host);
  if (location.pathname.includes('selected-')) {
    const spans=[...host.querySelectorAll('[data-bdf-ordinal]')];
    const first=spans.find(s=>s.textContent==='Header'), last=spans.find(s=>s.textContent==='42');
    const range=document.createRange();range.setStart(first.firstChild,1);range.setEnd(last.firstChild,1);
    getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
  }
  window.bdfStatus='ready';
} catch (error) { window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error); }
