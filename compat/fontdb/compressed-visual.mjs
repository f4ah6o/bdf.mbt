import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { new_database, add_file, csv_compressed_document } from '/_build/js/debug/build/compat/fontdb/fontdb.js';

try {
  const fixture = await (await fetch('./compressed.json')).json();
  const sample = fixture.conversions.find(item => item.bdfGzip);
  const unpack = async value => {
    const bytes = Uint8Array.from(atob(value), character => character.charCodeAt(0));
    return new Uint8Array(await new Response(new Blob([bytes]).stream().pipeThrough(new DecompressionStream('gzip'))).arrayBuffer());
  };
  let actual;
  if (document.body.dataset.converter === 'moon') {
    const db = new_database();
    for (const index of fixture.groups[sample.group]) {
      const file = fixture.files[index];
      if (add_file(db, file.path, await unpack(file.gzip)) !== 1) throw new Error('failed to load ' + file.path);
    }
    actual = csv_compressed_document(db, new TextEncoder().encode(sample.input), sample.scenario, sample.mode);
  } else {
    actual = await unpack(sample.bdfGzip);
  }
  const doc = await BdfDocument.open(new BufferSource(actual));
  const canvas = document.createElement('canvas');
  canvas.width = 560; canvas.height = 145;
  document.querySelector('#host').append(canvas);
  await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
    { x: 0, y: 0, w: 560, h: 145 }, { scale: 1 });
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
}
