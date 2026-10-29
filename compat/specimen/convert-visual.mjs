import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { convert_specimen, converted_specimen_bytes } from '/_build/js/debug/build/compat/specimen/specimen.js';
try {
  const unzip = async bytes => new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
  const from64 = value => Uint8Array.from(atob(value), c => c.charCodeAt(0));
  const fixture = JSON.parse(new TextDecoder().decode(await unzip(await (await fetch('./convert.json.gz')).arrayBuffer())));
  const sample = fixture.cases.find(item => item.visual);
  let bytes;
  if (document.body.dataset.converter === 'moon') {
    const font = await unzip(from64(fixture.files[sample.name]));
    const ui = await unzip(from64(fixture.files['stix.ttf']));
    const result = convert_specimen(font, ui, sample.selection, sample.title, sample.text, sample.system, sample.noIndex, sample.noSubset, sample.ignore);
    bytes = converted_specimen_bytes(result);
  } else bytes = from64(sample.visual);
  const doc = await BdfDocument.open(new BufferSource(bytes));
  const renderer = new PageRenderer(doc);
  for (const view of doc.manifest.views) {
    const page = view.pages[0];
    const canvas = document.createElement('canvas');
    canvas.width = Math.ceil(page.w * 0.5); canvas.height = Math.ceil(page.h * 0.5);
    document.querySelector('#host').append(canvas);
    await renderer.renderPage(canvas.getContext('2d'), page, {scale: 0.5});
  }
  window.bdfStatus = 'ready';
} catch (error) { window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error); }
