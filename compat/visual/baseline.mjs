import { BdfDocument, BufferSource } from '@bdfkit/core';
import { CanvasRenderer, ResourceCache } from '@bdfkit/render';

try {
  const bytes = new Uint8Array(await (await fetch('./fixture.bdf')).arrayBuffer());
  const doc = await BdfDocument.open(new BufferSource(bytes));
  const page = doc.manifest.views[0].pages[0];
  const host = document.querySelector('#host');
  const surface = document.createElement('div');
  surface.dataset.bdfPages = '';
  Object.assign(surface.style, {position:'relative', width:`${Math.max(host.clientWidth,page.w)}px`, height:`${page.h+16}px`, background:'#e8e8e8'});
  host.appendChild(surface);
  const canvas = document.createElement('canvas');
  canvas.width = page.w;
  canvas.height = page.h;
  canvas.style.position = 'absolute';
  canvas.style.left = `${Math.max(0,(host.clientWidth-page.w)/2)}px`;
  canvas.style.top = '0px';
  canvas.setAttribute('aria-label', 'BDF page');
  surface.appendChild(canvas);
  const resources = new ResourceCache(doc, document.fonts);
  const hold = resources.hold();
  const renderer = new CanvasRenderer(resources);
  try {
    const objects = [];
    for (const layer of page.layers) objects.push(await resources.prepare(layer.obj, hold));
    const draw = () => {
      const ctx = canvas.getContext('2d');
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      for (const object of objects) renderer.draw(ctx, object);
    };
    draw();
    const misses = resources.takeMisses();
    if (misses.length && await resources.settle(misses)) draw();
  } finally {
    resources.release(hold);
    resources.dispose();
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
