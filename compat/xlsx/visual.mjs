import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { xlsx_render_basic } from '/_build/js/debug/build/compat/xlsx/xlsx.js';
import { render_bdf_sheet_region_async } from '/_build/js/debug/build/browser/browser.js';

const cases = [
  ['row stripes, sizes 2 and default', 'plain-table-whole-paired-row-stripe-style-plain.json', 4],
  ['column stripes, sizes 2 and default', 'plain-table-whole-paired-column-stripe-style-plain.json', 4],
  ['row font and fill, cell style precedence', 'plain-table-whole-paired-row-stripe-style-mixed.json', 10],
  ['overlapping tables, row and column stripes', 'plain-table-multi-whole-paired-stripe-style.json', 6],
];
const bytes = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
try {
  for (const [label, file, index] of cases) {
    const response = await fetch('./' + file);
    if (!response.ok) throw new Error(`${file}: HTTP ${response.status}`);
    const sample = (await response.json())[index];
    if (!sample) throw new Error(`${file}: missing case ${index}`);
    const mode = document.body.dataset.mode;
    const data = mode === 'upstream' ? bytes(sample.bdf) :
      xlsx_render_basic(bytes(sample.input), sample.mode, sample.no_index);
    if (!data.length) throw new Error(`${label}: conversion failed`);
    const section = document.createElement('section');
    const title = document.createElement('h2'); title.textContent = label;
    const surface = document.createElement('div'); surface.className = 'surface';
    section.append(title, surface); document.querySelector('#host').append(section);
    if (mode === 'moon') {
      await render_bdf_sheet_region_async(surface, data, 0, 0, 560, 145, 1);
    } else {
      const doc = await BdfDocument.open(new BufferSource(data));
      const canvas = document.createElement('canvas'); canvas.width = 560; canvas.height = 145;
      surface.append(canvas);
      await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
        { x: 0, y: 0, w: 560, h: 145 }, { scale: 1 });
    }
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
}
