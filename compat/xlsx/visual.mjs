import { BdfDocument, BufferSource } from '@bdfkit/core';
import { PageRenderer } from '@bdfkit/render';
import { xlsx_render_basic } from '/_build/js/debug/build/compat/xlsx/xlsx.js';
import { render_bdf_sheet_region_async } from '/_build/js/debug/build/browser/browser.js';

const cases = [
  ['row stripes, sizes 2 and default', 'plain-table-whole-paired-row-stripe-style-plain.json', 4],
  ['column stripes, sizes 2 and default', 'plain-table-whole-paired-column-stripe-style-plain.json', 4],
  ['cell fill over data-row stripe', 'plain-table-whole-paired-row-stripe-style-plain.json', 74],
  ['row font and fill, cell style precedence', 'plain-table-whole-paired-row-stripe-style-mixed.json', 10],
  ['overlapping tables, row and column styles', 'plain-table-multi-whole-paired-stripe-style.json', 6],
];
const bytes = value => Uint8Array.from(atob(value), character => character.charCodeAt(0));
// VLMKit captures in a separate browser from preflight. Keep its request open
// until this page has completed all asynchronous conversion and rendering.
const token = crypto.randomUUID();
const barrier = await fetch(`./visual-wait?token=${token}`);
if (!barrier.ok) throw new Error(`visual wait: HTTP ${barrier.status}`);
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
      await render_bdf_sheet_region_async(surface, data, 0, 0, 560, 115, 1);
    } else {
      const doc = await BdfDocument.open(new BufferSource(data));
      const canvas = document.createElement('canvas'); canvas.width = 560; canvas.height = 115;
      surface.append(canvas);
      await new PageRenderer(doc).renderSheet(canvas.getContext('2d'), doc.manifest.views[0],
        { x: 0, y: 0, w: 560, h: 115 }, { scale: 1 });
    }
  }
  window.bdfStatus = 'ready';
} catch (error) {
  window.bdfStatus = 'error'; window.bdfError = String(error?.stack ?? error); console.error(error);
} finally {
  const response = await fetch(`./visual-release?token=${token}`, { method: 'POST' });
  if (!response.ok) throw new Error(`visual release: HTTP ${response.status}`);
  await barrier.text();
}
