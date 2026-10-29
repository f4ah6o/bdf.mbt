import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { convert_fixture } from '/_build/js/debug/build/compat/csv/csv.js';

try {
  const cases = await (await fetch('./conversion.json')).json();
  const bytes = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
  const selected = [cases[1], ...['Light1', 'Medium2', 'Dark9'].map(style => cases.find(sample => sample.input.TableStyle === style))];
  for (const sample of selected) {
    const input = sample.input;
    const actual = document.body.dataset.converter === 'moon'
      ? convert_fixture(bytes(input.Data), input.Name, input.Title, input.Charset,
        input.Delimiter, input.Quote, input.Header, input.Mode, input.NoTextIndex, input.TableStyle)
      : bytes(sample.bdf);
    const doc = await BdfDocument.open(new BufferSource(actual));
    const canvas = document.createElement('canvas');
    canvas.width = 560;
    canvas.height = 145;
    document.querySelector('#host').append(canvas);
    await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
      { x: 0, y: 0, w: 560, h: 145 }, { scale: 1 });
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error';
  window.bdfError = String(error?.stack ?? error);
  console.error(error);
}
