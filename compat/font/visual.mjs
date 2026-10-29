import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { csv_document } from '/_build/js/debug/build/compat/font/font.js';

try {
  const cases = await (await fetch('./csv.json')).json();
  const bytes = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
  for (const sample of cases.filter(sample => sample.bdf)) {
    const font = new Uint8Array(await (await fetch('../../' + sample.file)).arrayBuffer());
    const actual = document.body.dataset.converter === 'moon'
      ? csv_document(new TextEncoder().encode(sample.input), font, sample.scenario, sample.index ?? 0)
      : bytes(sample.bdf);
    const doc = await BdfDocument.open(new BufferSource(actual));
    const canvas = document.createElement('canvas');
    canvas.width = 560; canvas.height = 145;
    document.querySelector('#host').append(canvas);
    await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
      { x: 0, y: 0, w: 560, h: 145 }, { scale: 1 });
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
}
