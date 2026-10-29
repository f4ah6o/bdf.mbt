import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { midi_document_tab } from '/_build/js/debug/build/compat/midiinput/midiinput.js';
try {
  const response = await fetch('./visual.json.gz');
  const json = await new Response(response.body.pipeThrough(new DecompressionStream('gzip'))).text();
  const fixtures = JSON.parse(json);
  const from64 = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
  for (const fixture of fixtures) {
    const bytes = document.body.dataset.converter === 'go' ? from64(fixture.bdf) : Uint8Array.from(JSON.parse(midi_document_tab(from64(fixture.input), 500, 700, 5, '', false, false, false))[0]);
    const doc = await BdfDocument.open(new BufferSource(bytes));
    const renderer = new PageRenderer(doc);
    for (const page of doc.manifest.views.flatMap(view => view.pages.slice(0, 1))) {
      const canvas = document.createElement('canvas');
      canvas.width = Math.ceil(page.w * 0.7); canvas.height = Math.ceil(page.h * 0.7);
      document.querySelector('#host').append(canvas);
      await renderer.renderPage(canvas.getContext('2d'), page, {scale: 0.7});
    }
  }
  window.bdfStatus = 'ready';
} catch (error) { window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error); }
