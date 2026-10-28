import { BdfDocument, BufferSource, extractContent } from '@bdfkit/core';
import { CanvasRenderer, ResourceCache, buildTextLayer, installCopyHandler, selectionText, selectionCells, TEXT_LAYER_CSS, concat } from '@bdfkit/render';
try {
  const bytes = new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const doc = await BdfDocument.open(new BufferSource(bytes));
  const host = document.querySelector('#host');
  const pages = doc.manifest.views[0].pages;
  const resources = new ResourceCache(doc, document.fonts), hold = resources.hold();
  const renderer = new CanvasRenderer(resources);
  const sheet = document.createElement('style');sheet.textContent=TEXT_LAYER_CSS;document.head.appendChild(sheet);
  let top=0;
  for (const page of pages) {
    const canvas = document.createElement('canvas');
    canvas.width=page.w;canvas.height=page.h;
    Object.assign(canvas.style,{position:'absolute',left:'0px',top:top+'px'});
    canvas.setAttribute('aria-label','BDF page');host.appendChild(canvas);
    const objects = [];
    for (const item of page.layers) objects.push(await resources.prepare(item.obj, hold));
    for (const object of objects) renderer.draw(canvas.getContext('2d'),object);
    const content = concat(objects.map(object => extractContent(object, hash => resources.object(hash))));
    const layer = buildTextLayer(content, 1);
    Object.assign(layer.style,{left:'0px',top:top+'px',width:page.w+'px',height:page.h+'px'});
    host.appendChild(layer);top+=page.h+16;
  }
  host.style.minHeight=(top-16)+'px';installCopyHandler(host);
  window.readSelection = () => selectionText(document.getSelection(),host);
  window.readCells = () => selectionCells(document.getSelection(),host);
  resources.release(hold);resources.dispose();if (location.pathname.includes('selected-')) {
    const spans=[...host.querySelectorAll('[data-bdf-ordinal]')];
    const first=spans.find(s=>s.textContent==='Header'), last=spans.find(s=>s.textContent==='42');
    const range=document.createRange();range.setStart(first.firstChild,1);range.setEnd(last.firstChild,1);
    getSelection().removeAllRanges();getSelection().addRange(range);document.dispatchEvent(new Event('selectionchange'));
  }
  window.bdfStatus='ready';
} catch (error) { window.bdfStatus='error';window.bdfError=String(error?.stack??error);console.error(error); }
